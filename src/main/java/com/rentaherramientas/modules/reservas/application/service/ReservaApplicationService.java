package com.rentaherramientas.modules.reservas.application.service;

import com.rentaherramientas.common.exception.AccesoDenegadoException;
import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort.InfoHerramienta;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.reservas.application.dto.CrearReservaCommand;
import com.rentaherramientas.modules.reservas.application.dto.DetalleReservaItemCommand;
import com.rentaherramientas.modules.reservas.domain.model.DetalleReserva;
import com.rentaherramientas.modules.reservas.domain.model.Disponibilidad;
import com.rentaherramientas.modules.reservas.domain.model.EstadoReserva;
import com.rentaherramientas.modules.reservas.domain.model.Ocupacion;
import com.rentaherramientas.modules.reservas.domain.model.RangoFechas;
import com.rentaherramientas.modules.reservas.domain.model.ReporteDano;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;
import com.rentaherramientas.modules.reservas.domain.ports.in.CambiarEstadoReservaUseCase;
import com.rentaherramientas.modules.reservas.domain.ports.in.ConsultarReservaUseCase;
import com.rentaherramientas.modules.reservas.domain.ports.in.CrearReservaUseCase;
import com.rentaherramientas.modules.reservas.domain.ports.in.DevolucionEquipoUseCase;
import com.rentaherramientas.modules.reservas.domain.ports.out.AuditoriaReservaPort;
import com.rentaherramientas.modules.reservas.domain.ports.out.ReporteDanoPort;
import com.rentaherramientas.modules.reservas.domain.ports.out.ReservaRepositoryPort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * Casos de uso del modulo de Reservas.
 *
 * Reglas que se aplican aqui y que vale la pena saber explicar:
 *  - El cliente sale del token y el precio de la tarifa vigente: el cuerpo de
 *    la peticion no puede cambiar ni quien reserva ni cuanto cuesta.
 *  - No se reserva en fechas pasadas, ni una herramienta dada de baja, ni la
 *    herramienta propia.
 *  - Una herramienta no puede tener dos reservas APROBADAS o EN_CURSO que se
 *    crucen. Se verifica al crear y otra vez al aprobar, porque dos clientes
 *    pueden haber pedido las mismas fechas mientras ambas estaban SOLICITADAS.
 *  - Solo el administrador o el proveedor dueno de la herramienta gestionan la
 *    reserva (aprobar, rechazar, despachar, finalizar).
 *  - Despachar pone la herramienta ALQUILADA; finalizar la devuelve a DISPONIBLE.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ReservaApplicationService implements CrearReservaUseCase, ConsultarReservaUseCase, CambiarEstadoReservaUseCase,
        DevolucionEquipoUseCase {

    /** Estados que se muestran como ocupacion en el calendario. */
    private static final List<EstadoReserva> ESTADOS_QUE_OCUPAN =
            List.of(EstadoReserva.SOLICITADA, EstadoReserva.APROBADA, EstadoReserva.EN_CURSO);

    /** Estados que de verdad bloquean la herramienta para otra reserva. */
    private static final List<EstadoReserva> ESTADOS_QUE_BLOQUEAN =
            List.of(EstadoReserva.APROBADA, EstadoReserva.EN_CURSO);

    private static final int MAX_DIAS_CONSULTA = 366;

    private final ReservaRepositoryPort reservaRepositoryPort;
    private final AuditoriaReservaPort auditoriaReservaPort;
    private final UsuarioConsultaPort usuarioConsultaPort;
    private final HerramientaConsultaPort herramientaConsultaPort;
    private final ReporteDanoPort reporteDanoPort;

    // ------------------------------------------------------------------
    // Crear
    // ------------------------------------------------------------------

    @Override
    @Transactional
    public Reserva crearReserva(String emailCliente, CrearReservaCommand command) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        if (!cliente.activo()) {
            throw new BusinessRuleException("La cuenta se encuentra bloqueada y no puede hacer reservas");
        }

        RangoFechas rango = new RangoFechas(command.getFechaInicio(), command.getFechaFin());
        if (rango.getFechaInicio().isBefore(LocalDate.now())) {
            throw new BusinessRuleException("La fecha de inicio no puede ser anterior a hoy");
        }

        int dias = (int) rango.getDiasAlquiler();
        Set<Long> yaIncluidas = new HashSet<>();
        List<DetalleReserva> detalles = new ArrayList<>();

        for (DetalleReservaItemCommand item : command.getItems()) {
            Long idHerramienta = item.getIdHerramienta();
            if (!yaIncluidas.add(idHerramienta)) {
                throw new BusinessRuleException("La herramienta con ID " + idHerramienta
                        + " está repetida en la solicitud; use el campo cantidad");
            }

            InfoHerramienta herramienta = herramientaConsultaPort.buscarPorId(idHerramienta)
                    .orElseThrow(() -> new ResourceNotFoundException(
                            "No se encontró la herramienta con ID " + idHerramienta));

            if (!herramienta.admiteReservas()) {
                throw new BusinessRuleException("La herramienta '" + herramienta.nombre()
                        + "' está fuera de servicio y no se puede reservar");
            }
            if (herramienta.idProveedor() != null && herramienta.idProveedor().equals(cliente.idUsuario())) {
                throw new BusinessRuleException("No puede reservar una herramienta publicada por usted mismo");
            }
            if (reservaRepositoryPort.existeConflictoFechas(idHerramienta, rango.getFechaInicio(), rango.getFechaFin(), null)) {
                throw new BusinessRuleException("La herramienta con ID " + idHerramienta
                        + " ya tiene una reserva activa en las fechas seleccionadas ("
                        + rango.getFechaInicio() + " al " + rango.getFechaFin() + ")");
            }

            DetalleReserva detalle = DetalleReserva.builder()
                    .idHerramienta(idHerramienta)
                    .nombreHerramienta(herramienta.nombre())
                    .imagenHerramienta(herramienta.imagenPrincipal())
                    .cantidad(item.getCantidad() == null ? 1 : item.getCantidad())
                    .precioUnitarioDia(herramienta.tarifaDiaria())
                    .diasAlquiler(dias)
                    .build();
            detalle.calcularSubtotal();
            detalles.add(detalle);
        }

        Reserva nuevaReserva = Reserva.builder()
                .codigoReserva("RES-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase())
                .idCliente(cliente.idUsuario())
                .fechaSolicitud(LocalDateTime.now())
                .rangoFechas(rango)
                .estado(EstadoReserva.SOLICITADA)
                .detalles(detalles)
                .notasCliente(command.getNotasCliente())
                .build();
        nuevaReserva.calcularTotales();

        Reserva guardada = reservaRepositoryPort.guardar(nuevaReserva);
        auditoriaReservaPort.registrarCambioEstado(guardada.getIdReserva(), null,
                EstadoReserva.SOLICITADA.name(), cliente.idUsuario(), "Solicitud de reserva creada por el cliente");

        log.info("Reserva {} creada por {} ({} herramienta(s), {} días)",
                guardada.getCodigoReserva(), emailCliente, detalles.size(), dias);
        return enriquecer(guardada);
    }

    // ------------------------------------------------------------------
    // Consultas
    // ------------------------------------------------------------------

    @Override
    @Transactional(readOnly = true)
    public Reserva obtener(String emailSolicitante, Long idReserva) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Reserva reserva = cargar(idReserva);
        if (!reserva.perteneceAlCliente(actor.idUsuario()) && !puedeGestionar(actor, reserva)) {
            throw new AccesoDenegadoException("No tiene permiso para ver esta reserva");
        }
        return enriquecer(reserva);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Reserva> listarMisReservas(String emailCliente) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        return enriquecer(reservaRepositoryPort.buscarPorCliente(cliente.idUsuario()));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Reserva> listarParaGestion(String emailSolicitante) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        List<Reserva> reservas;
        if (actor.esAdmin()) {
            reservas = reservaRepositoryPort.buscarTodas();
        } else if (actor.esProveedor()) {
            List<Long> misHerramientas = herramientaConsultaPort.idsDeProveedor(actor.idUsuario());
            reservas = misHerramientas.isEmpty() ? List.of() : reservaRepositoryPort.buscarPorHerramientas(misHerramientas);
        } else {
            throw new AccesoDenegadoException("Solo administradores y proveedores gestionan reservas");
        }
        List<Reserva> ordenadas = new ArrayList<>(reservas);
        ordenadas.sort(Comparator.comparing(Reserva::getFechaSolicitud,
                Comparator.nullsLast(Comparator.reverseOrder())));
        return enriquecer(ordenadas);
    }

    @Override
    @Transactional(readOnly = true)
    public Disponibilidad consultarDisponibilidad(Long idHerramienta, LocalDate desde, LocalDate hasta) {
        InfoHerramienta herramienta = herramientaConsultaPort.buscarPorId(idHerramienta)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la herramienta con ID " + idHerramienta));

        LocalDate inicio = desde != null ? desde : LocalDate.now();
        LocalDate fin = hasta != null ? hasta : inicio.plusDays(30);
        RangoFechas rango = new RangoFechas(inicio, fin);
        if (ChronoUnit.DAYS.between(inicio, fin) > MAX_DIAS_CONSULTA) {
            throw new BusinessRuleException("El rango a consultar no puede superar " + MAX_DIAS_CONSULTA + " días");
        }

        List<Reserva> queSeCruzan = reservaRepositoryPort.buscarQueSeCruzan(
                idHerramienta, rango.getFechaInicio(), rango.getFechaFin(), ESTADOS_QUE_OCUPAN);

        List<Ocupacion> ocupaciones = queSeCruzan.stream()
                .map(r -> new Ocupacion(r.getRangoFechas().getFechaInicio(), r.getRangoFechas().getFechaFin(), r.getEstado()))
                .sorted(Comparator.comparing(Ocupacion::desde))
                .toList();

        boolean libre = herramienta.admiteReservas()
                && queSeCruzan.stream().noneMatch(r -> ESTADOS_QUE_BLOQUEAN.contains(r.getEstado()));

        return new Disponibilidad(idHerramienta, rango.getFechaInicio(), rango.getFechaFin(), libre, ocupaciones);
    }

    // ------------------------------------------------------------------
    // Transiciones
    // ------------------------------------------------------------------

    @Override
    @Transactional
    public Reserva aprobarReserva(String emailSolicitante, Long idReserva) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Reserva reserva = cargar(idReserva);
        exigirGestion(actor, reserva);

        // Segunda verificacion: mientras estaba SOLICITADA otra reserva pudo ser aprobada.
        for (Long idHerramienta : reserva.idsHerramientas()) {
            if (reservaRepositoryPort.existeConflictoFechas(idHerramienta,
                    reserva.getRangoFechas().getFechaInicio(), reserva.getRangoFechas().getFechaFin(), reserva.getIdReserva())) {
                throw new BusinessRuleException("No se puede aprobar: la herramienta con ID " + idHerramienta
                        + " ya está comprometida en esas fechas por otra reserva aprobada");
            }
        }

        String anterior = reserva.getEstado().name();
        reserva.aprobar();
        return guardarConAuditoria(reserva, anterior, actor, "Reserva aprobada");
    }

    @Override
    @Transactional
    public Reserva rechazarReserva(String emailSolicitante, Long idReserva, String motivo) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Reserva reserva = cargar(idReserva);
        exigirGestion(actor, reserva);

        String anterior = reserva.getEstado().name();
        reserva.rechazar(motivo);
        return guardarConAuditoria(reserva, anterior, actor, "Reserva rechazada. Motivo: " + motivo);
    }

    @Override
    @Transactional
    public Reserva iniciarAlquiler(String emailSolicitante, Long idReserva) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Reserva reserva = cargar(idReserva);
        exigirGestion(actor, reserva);

        String anterior = reserva.getEstado().name();
        reserva.iniciarAlquiler();
        // Si alguna herramienta no puede pasar a ALQUILADA (por ejemplo, esta en
        // mantenimiento) se lanza la excepcion y la transaccion completa se revierte.
        reserva.idsHerramientas().forEach(id -> herramientaConsultaPort.cambiarEstado(id, "ALQUILADA"));
        return guardarConAuditoria(reserva, anterior, actor, "Equipo despachado. Alquiler en curso");
    }

    @Override
    @Transactional
    public Reserva finalizarAlquiler(String emailSolicitante, Long idReserva) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Reserva reserva = cargar(idReserva);
        exigirGestion(actor, reserva);

        String anterior = reserva.getEstado().name();
        reserva.finalizarAlquiler();
        for (Long id : reserva.idsHerramientas()) {
            boolean sigueAlquilada = herramientaConsultaPort.buscarPorId(id)
                    .map(h -> "ALQUILADA".equals(h.estadoOperativo()))
                    .orElse(false);
            if (sigueAlquilada) {
                herramientaConsultaPort.cambiarEstado(id, "DISPONIBLE");
            }
        }
        return guardarConAuditoria(reserva, anterior, actor, "Alquiler finalizado");
    }

    @Override
    @Transactional
    public Reserva cancelarReserva(String emailSolicitante, Long idReserva) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Reserva reserva = cargar(idReserva);
        if (!reserva.perteneceAlCliente(actor.idUsuario()) && !puedeGestionar(actor, reserva)) {
            throw new AccesoDenegadoException("Solo el cliente dueño, el proveedor o un administrador pueden cancelar esta reserva");
        }

        String anterior = reserva.getEstado().name();
        reserva.cancelar();
        return guardarConAuditoria(reserva, anterior, actor, "Reserva cancelada");
    }

    // ------------------------------------------------------------------
    // Devolucion del equipo
    // ------------------------------------------------------------------

    /**
     * El proveedor (o el admin) recibe el equipo y registra como volvio.
     *  - "OK": la devolucion queda DEVUELTO_OK.
     *  - "DANOS": queda DEVUELTO_CON_DANOS y se guarda un ReporteDano ligado a la reserva;
     *    la herramienta pasa a EN_MANTENIMIENTO en vez de DISPONIBLE.
     * En ambos casos el alquiler termina (FINALIZADA).
     */
    @Override
    @Transactional
    public ResultadoDevolucion registrarDevolucion(String emailSolicitante, Long idReserva, String estado,
                                                   String descripcionDano, Double costoReparacion) {
        boolean conDanos = esDanos(estado);
        if (conDanos && (descripcionDano == null || descripcionDano.isBlank())) {
            throw new BusinessRuleException("Si la devolución tiene daños, la descripción del daño es obligatoria");
        }

        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Reserva reserva = cargar(idReserva);
        exigirGestion(actor, reserva);

        String anterior = reserva.getEstado().name();
        reserva.registrarDevolucion(conDanos);

        String estadoHerramienta = conDanos ? "EN_MANTENIMIENTO" : "DISPONIBLE";
        for (Long id : reserva.idsHerramientas()) {
            boolean sigueAlquilada = herramientaConsultaPort.buscarPorId(id)
                    .map(h -> "ALQUILADA".equals(h.estadoOperativo()))
                    .orElse(false);
            if (sigueAlquilada) {
                herramientaConsultaPort.cambiarEstado(id, estadoHerramienta);
            }
        }

        Reserva guardada = guardarConAuditoria(reserva, anterior, actor,
                conDanos ? "Devuelto con daños" : "Devuelto sin novedades");

        ReporteDano reporte = null;
        if (conDanos) {
            reporte = reporteDanoPort.guardar(ReporteDano.builder()
                    .idReserva(idReserva)
                    .descripcion(descripcionDano.trim())
                    .costoReparacion(costoReparacion == null ? 0.0 : costoReparacion)
                    .fechaReporte(LocalDate.now())
                    .build());
        }
        return new ResultadoDevolucion(guardada, reporte);
    }

    /** Acepta "OK" o "DANOS"/"DAÑOS" (sin importar mayusculas). Cualquier otro valor es un error. */
    private boolean esDanos(String estado) {
        String valor = estado == null ? "" : estado.trim().toUpperCase().replace('Ñ', 'N');
        if (valor.equals("OK")) {
            return false;
        }
        if (valor.equals("DANOS")) {
            return true;
        }
        throw new BusinessRuleException("El estado de la devolución debe ser OK o DANOS");
    }

    // ------------------------------------------------------------------
    // Apoyo
    // ------------------------------------------------------------------

    private Reserva cargar(Long idReserva) {
        return reservaRepositoryPort.buscarPorId(idReserva)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la reserva con ID: " + idReserva));
    }

    /** Administrador, o proveedor dueno de al menos una herramienta de la reserva. */
    private boolean puedeGestionar(InfoUsuario actor, Reserva reserva) {
        if (actor.esAdmin()) {
            return true;
        }
        return actor.esProveedor()
                && reserva.incluyeAlgunaHerramienta(herramientaConsultaPort.idsDeProveedor(actor.idUsuario()));
    }

    private void exigirGestion(InfoUsuario actor, Reserva reserva) {
        if (!puedeGestionar(actor, reserva)) {
            throw new AccesoDenegadoException(
                    "Solo el administrador o el proveedor de la herramienta pueden gestionar esta reserva");
        }
    }

    private Reserva guardarConAuditoria(Reserva reserva, String estadoAnterior, InfoUsuario actor, String observacion) {
        Reserva actualizada = reservaRepositoryPort.guardar(reserva);
        auditoriaReservaPort.registrarCambioEstado(reserva.getIdReserva(), estadoAnterior,
                reserva.getEstado().name(), actor.idUsuario(), observacion);
        log.info("Reserva {}: {} -> {} por {}", reserva.getIdReserva(), estadoAnterior, reserva.getEstado(), actor.email());
        return enriquecer(actualizada);
    }

    private Reserva enriquecer(Reserva reserva) {
        return enriquecer(List.of(reserva)).get(0);
    }

    /**
     * Completa nombres e imagenes para mostrar. Usa caches locales para no
     * consultar dos veces el mismo cliente o la misma herramienta en un listado.
     */
    private List<Reserva> enriquecer(List<Reserva> reservas) {
        Map<Long, Optional<InfoUsuario>> clientes = new HashMap<>();
        Map<Long, Optional<InfoHerramienta>> herramientas = new HashMap<>();
        for (Reserva r : reservas) {
            if (r == null) continue;
            clientes.computeIfAbsent(r.getIdCliente(), usuarioConsultaPort::buscarPorId)
                    .ifPresent(c -> r.mostrarComo(c.nombreCompleto()));
            if (r.getDetalles() == null) continue;
            r.getDetalles().forEach(d -> herramientas
                    .computeIfAbsent(d.getIdHerramienta(), herramientaConsultaPort::buscarPorId)
                    .ifPresent(h -> d.mostrarComo(h.nombre(), h.imagenPrincipal())));
        }
        return reservas;
    }
}
