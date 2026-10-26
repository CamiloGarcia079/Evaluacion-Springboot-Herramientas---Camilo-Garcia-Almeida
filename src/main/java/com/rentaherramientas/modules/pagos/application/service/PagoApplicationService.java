package com.rentaherramientas.modules.pagos.application.service;

import com.rentaherramientas.common.exception.AccesoDenegadoException;
import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.ReservaConsultaPort;
import com.rentaherramientas.common.kernel.ReservaConsultaPort.InfoReserva;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.pagos.application.dto.ProcesarPagoCommand;
import com.rentaherramientas.modules.pagos.domain.model.EstadoPago;
import com.rentaherramientas.modules.pagos.domain.model.Factura;
import com.rentaherramientas.modules.pagos.domain.model.MetodoPago;
import com.rentaherramientas.modules.pagos.domain.model.Pago;
import com.rentaherramientas.modules.pagos.domain.model.TipoPago;
import com.rentaherramientas.modules.pagos.domain.ports.in.ConsultarFacturaUseCase;
import com.rentaherramientas.modules.pagos.domain.ports.in.ConsultarPagoUseCase;
import com.rentaherramientas.modules.pagos.domain.ports.in.ProcesarPagoUseCase;
import com.rentaherramientas.modules.pagos.domain.ports.out.FacturaRepositoryPort;
import com.rentaherramientas.modules.pagos.domain.ports.out.MetodoPagoRepositoryPort;
import com.rentaherramientas.modules.pagos.domain.ports.out.PagoRepositoryPort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Pagos y facturacion electronica.
 *
 * Reglas:
 *  - Solo el cliente duenio de la reserva (o un administrador) paga, y solo si
 *    la reserva esta APROBADA, EN_CURSO o FINALIZADA.
 *  - Anticipo + totalidad nunca superan el valor del alquiler; el deposito
 *    nunca supera el deposito pactado.
 *  - Cada pago aprobado emite su factura con el IVA del 19 % desglosado.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PagoApplicationService implements ProcesarPagoUseCase, ConsultarPagoUseCase, ConsultarFacturaUseCase {

    private static final Set<TipoPago> PAGOS_DEL_ALQUILER = Set.of(TipoPago.ANTICIPO, TipoPago.TOTALIDAD);
    private static final BigDecimal TOLERANCIA = new BigDecimal("0.01");

    private final PagoRepositoryPort pagoRepositoryPort;
    private final FacturaRepositoryPort facturaRepositoryPort;
    private final MetodoPagoRepositoryPort metodoPagoRepositoryPort;
    private final UsuarioConsultaPort usuarioConsultaPort;
    private final ReservaConsultaPort reservaConsultaPort;
    private final HerramientaConsultaPort herramientaConsultaPort;

    // ------------------------------------------------------------------
    // Procesar
    // ------------------------------------------------------------------

    @Override
    @Transactional
    public Pago procesarPago(String emailCliente, ProcesarPagoCommand command) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        InfoReserva reserva = reservaConsultaPort.buscarPorId(command.getIdReserva())
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la reserva con ID: " + command.getIdReserva()));

        if (!cliente.esAdmin() && !cliente.idUsuario().equals(reserva.idCliente())) {
            throw new AccesoDenegadoException("Solo puede pagar sus propias reservas");
        }
        if (!reserva.admitePagos()) {
            throw new BusinessRuleException("La reserva " + reserva.codigoReserva() + " está " + reserva.estado()
                    + ". Solo se pueden pagar reservas APROBADAS, EN CURSO o FINALIZADAS");
        }

        List<Pago> previos = pagoRepositoryPort.buscarPorReserva(reserva.idReserva());
        BigDecimal monto = command.getMonto() != null
                ? command.getMonto()
                : montoSugerido(command.getTipoPago(), reserva, previos);

        validarMonto(command.getTipoPago(), monto, reserva, previos);

        command.setIdCliente(reserva.idCliente());
        command.setMonto(monto);
        if (command.getDescripcionServicio() == null || command.getDescripcionServicio().isBlank()) {
            command.setDescripcionServicio(describir(command.getTipoPago(), reserva));
        }
        return procesarPago(command);
    }

    @Override
    @Transactional
    public Pago procesarPago(ProcesarPagoCommand command) {
        MetodoPago metodo = metodoPagoRepositoryPort.buscarPorId(command.getIdMetodoPago())
                .orElseThrow(() -> new ResourceNotFoundException("El método de pago con ID " + command.getIdMetodoPago() + " no existe"));

        if (!metodo.isActivo()) {
            throw new BusinessRuleException("El método de pago '" + metodo.getNombre() + "' no se encuentra habilitado");
        }

        Pago nuevoPago = Pago.builder()
                .numeroTransaccion("TRX-" + UUID.randomUUID().toString().substring(0, 10).toUpperCase())
                .idReserva(command.getIdReserva())
                .idMetodoPago(command.getIdMetodoPago())
                .monto(command.getMonto())
                .tipoPago(command.getTipoPago())
                .estadoPago(EstadoPago.PENDIENTE)
                .fechaPago(LocalDateTime.now())
                .build();

        // Pasarela simulada: aprueba en linea y devuelve una referencia de autorizacion.
        String refPasarela = "AUTH-" + metodo.getNombre() + "-" + UUID.randomUUID().toString().substring(0, 6).toUpperCase();
        nuevoPago.aprobar(refPasarela);

        Pago pagoGuardado = pagoRepositoryPort.guardar(nuevoPago);

        Factura facturaGenerada = pagoGuardado.generarFacturaAutomatica(command.getIdCliente(), command.getDescripcionServicio());
        Factura facturaGuardada = facturaRepositoryPort.guardar(facturaGenerada);

        log.info("Pago {} aprobado por {} para la reserva {} (factura {})",
                pagoGuardado.getNumeroTransaccion(), pagoGuardado.getMonto(), pagoGuardado.getIdReserva(),
                facturaGuardada.getNumeroFactura());
        return conFactura(pagoGuardado, facturaGuardada);
    }

    private BigDecimal montoSugerido(TipoPago tipo, InfoReserva reserva, List<Pago> previos) {
        return switch (tipo) {
            case TOTALIDAD -> reserva.montoTotal().subtract(pagado(previos, PAGOS_DEL_ALQUILER));
            case ANTICIPO -> reserva.montoTotal().multiply(new BigDecimal("0.50")).setScale(2, RoundingMode.HALF_UP);
            case DEPOSITO_GARANTIA -> reserva.depositoGarantia().subtract(pagado(previos, Set.of(TipoPago.DEPOSITO_GARANTIA)));
            case MULTA_DANO, RECARGO_MORA ->
                    throw new BusinessRuleException("Para un pago de tipo " + tipo + " debe indicar el monto");
        };
    }

    private void validarMonto(TipoPago tipo, BigDecimal monto, InfoReserva reserva, List<Pago> previos) {
        if (monto == null || monto.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessRuleException("No hay saldo pendiente para un pago de tipo " + tipo + " en esta reserva");
        }
        if (PAGOS_DEL_ALQUILER.contains(tipo)) {
            BigDecimal saldo = reserva.montoTotal().subtract(pagado(previos, PAGOS_DEL_ALQUILER));
            if (monto.compareTo(saldo.add(TOLERANCIA)) > 0) {
                throw new BusinessRuleException("El pago de " + monto + " excede el saldo pendiente del alquiler (" + saldo + ")");
            }
        }
        if (tipo == TipoPago.DEPOSITO_GARANTIA) {
            BigDecimal saldo = reserva.depositoGarantia().subtract(pagado(previos, Set.of(TipoPago.DEPOSITO_GARANTIA)));
            if (monto.compareTo(saldo.add(TOLERANCIA)) > 0) {
                throw new BusinessRuleException("El depósito pendiente es de " + saldo + "; no se puede pagar " + monto);
            }
        }
    }

    private BigDecimal pagado(List<Pago> pagos, Set<TipoPago> tipos) {
        return pagos.stream()
                .filter(p -> p.getEstadoPago() == EstadoPago.APROBADO && tipos.contains(p.getTipoPago()))
                .map(Pago::getMonto)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private String describir(TipoPago tipo, InfoReserva reserva) {
        String concepto = switch (tipo) {
            case ANTICIPO -> "Anticipo de alquiler";
            case TOTALIDAD -> "Alquiler de equipos de construcción";
            case DEPOSITO_GARANTIA -> "Depósito de garantía reembolsable";
            case MULTA_DANO -> "Cargo por daño de equipo";
            case RECARGO_MORA -> "Recargo por mora en la devolución";
        };
        return concepto + " - Reserva " + reserva.codigoReserva()
                + " (" + reserva.fechaInicio() + " al " + reserva.fechaFin() + ")";
    }

    // ------------------------------------------------------------------
    // Consultas de pagos
    // ------------------------------------------------------------------

    @Override
    @Transactional(readOnly = true)
    public Pago obtenerPagoPorId(Long id) {
        Pago pago = pagoRepositoryPort.buscarPorId(id)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró el pago con ID: " + id));
        // Se adjunta la factura GUARDADA. Antes se generaba una nueva en cada
        // consulta, con otro numero, y no coincidia con la emitida.
        return facturaRepositoryPort.buscarPorPago(id).map(f -> conFactura(pago, f)).orElse(pago);
    }

    @Override
    @Transactional(readOnly = true)
    public Pago obtenerPago(String emailSolicitante, Long idPago) {
        Pago pago = obtenerPagoPorId(idPago);
        exigirAccesoAReserva(usuarioConsultaPort.obtenerPorEmail(emailSolicitante), pago.getIdReserva());
        return pago;
    }

    @Override
    @Transactional(readOnly = true)
    public Pago obtenerPagoPorTransaccion(String transaccion) {
        return pagoRepositoryPort.buscarPorTransaccion(transaccion)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró el pago con transacción: " + transaccion));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Pago> listarPagosPorReserva(Long idReserva) {
        return pagoRepositoryPort.buscarPorReserva(idReserva);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Pago> listarPagosDeReserva(String emailSolicitante, Long idReserva) {
        exigirAccesoAReserva(usuarioConsultaPort.obtenerPorEmail(emailSolicitante), idReserva);
        return pagoRepositoryPort.buscarPorReserva(idReserva);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Pago> listarMisPagos(String emailCliente) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        return pagoRepositoryPort.buscarPorReservas(reservaConsultaPort.idsDeReservasDelCliente(cliente.idUsuario()));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Pago> listarTodosLosPagos() {
        return pagoRepositoryPort.buscarTodos();
    }

    @Transactional(readOnly = true)
    public List<MetodoPago> listarMetodosPago() {
        return metodoPagoRepositoryPort.listarActivos();
    }

    // ------------------------------------------------------------------
    // Consultas de facturas
    // ------------------------------------------------------------------

    @Override
    @Transactional(readOnly = true)
    public Factura obtenerFacturaPorId(Long id) {
        return facturaRepositoryPort.buscarPorId(id)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la factura con ID: " + id));
    }

    @Override
    @Transactional(readOnly = true)
    public Factura obtenerFacturaPorNumero(String numeroFactura) {
        return facturaRepositoryPort.buscarPorNumero(numeroFactura)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la factura con número: " + numeroFactura));
    }

    @Override
    @Transactional(readOnly = true)
    public Factura obtenerFacturaPorPago(Long idPago) {
        return facturaRepositoryPort.buscarPorPago(idPago)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró factura vinculada al pago ID: " + idPago));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Factura> listarFacturasPorCliente(Long idCliente) {
        return facturaRepositoryPort.buscarPorCliente(idCliente);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Factura> listarMisFacturas(String emailCliente) {
        return facturaRepositoryPort.buscarPorCliente(usuarioConsultaPort.obtenerPorEmail(emailCliente).idUsuario());
    }

    @Override
    @Transactional(readOnly = true)
    public List<Factura> listarFacturasDeReserva(String emailSolicitante, Long idReserva) {
        exigirAccesoAReserva(usuarioConsultaPort.obtenerPorEmail(emailSolicitante), idReserva);
        List<Factura> facturas = new ArrayList<>();
        for (Pago pago : pagoRepositoryPort.buscarPorReserva(idReserva)) {
            facturaRepositoryPort.buscarPorPago(pago.getIdPago()).ifPresent(facturas::add);
        }
        return facturas;
    }

    @Override
    @Transactional(readOnly = true)
    public Factura obtenerFactura(String emailSolicitante, Long idFactura) {
        Factura factura = obtenerFacturaPorId(idFactura);
        exigirAccesoAFactura(usuarioConsultaPort.obtenerPorEmail(emailSolicitante), factura);
        return factura;
    }

    @Override
    @Transactional(readOnly = true)
    public Factura obtenerFacturaPorNumero(String emailSolicitante, String numeroFactura) {
        Factura factura = obtenerFacturaPorNumero(numeroFactura);
        exigirAccesoAFactura(usuarioConsultaPort.obtenerPorEmail(emailSolicitante), factura);
        return factura;
    }

    // ------------------------------------------------------------------
    // Apoyo
    // ------------------------------------------------------------------

    /** Cliente duenio, administrador o proveedor de alguna herramienta de la reserva. */
    private void exigirAccesoAReserva(InfoUsuario actor, Long idReserva) {
        if (actor.esAdmin()) {
            return;
        }
        InfoReserva reserva = reservaConsultaPort.buscarPorId(idReserva)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la reserva con ID: " + idReserva));
        if (actor.idUsuario().equals(reserva.idCliente())) {
            return;
        }
        if (actor.esProveedor()
                && reserva.idsHerramientas().stream().anyMatch(herramientaConsultaPort.idsDeProveedor(actor.idUsuario())::contains)) {
            return;
        }
        throw new AccesoDenegadoException("No tiene permiso para consultar los pagos de esta reserva");
    }

    private void exigirAccesoAFactura(InfoUsuario actor, Factura factura) {
        if (!actor.esAdmin() && !actor.idUsuario().equals(factura.getIdCliente())) {
            throw new AccesoDenegadoException("La factura pertenece a otro cliente");
        }
    }

    private Pago conFactura(Pago p, Factura f) {
        return Pago.builder()
                .idPago(p.getIdPago())
                .numeroTransaccion(p.getNumeroTransaccion())
                .idReserva(p.getIdReserva())
                .idMetodoPago(p.getIdMetodoPago())
                .monto(p.getMonto())
                .tipoPago(p.getTipoPago())
                .estadoPago(p.getEstadoPago())
                .fechaPago(p.getFechaPago())
                .referenciaPasarela(p.getReferenciaPasarela())
                .factura(f)
                .build();
    }
}
