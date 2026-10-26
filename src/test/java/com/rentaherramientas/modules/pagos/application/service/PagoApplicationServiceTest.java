package com.rentaherramientas.modules.pagos.application.service;

import com.rentaherramientas.common.exception.AccesoDenegadoException;
import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.ReservaConsultaPort;
import com.rentaherramientas.common.kernel.ReservaConsultaPort.InfoReserva;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.pagos.application.dto.ProcesarPagoCommand;
import com.rentaherramientas.modules.pagos.domain.model.*;
import com.rentaherramientas.modules.pagos.domain.ports.out.FacturaRepositoryPort;
import com.rentaherramientas.modules.pagos.domain.ports.out.MetodoPagoRepositoryPort;
import com.rentaherramientas.modules.pagos.domain.ports.out.PagoRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PagoApplicationServiceTest {

    @Mock
    private PagoRepositoryPort pagoRepositoryPort;

    @Mock
    private FacturaRepositoryPort facturaRepositoryPort;

    @Mock
    private MetodoPagoRepositoryPort metodoPagoRepositoryPort;

    @Mock
    private UsuarioConsultaPort usuarioConsultaPort;

    @Mock
    private ReservaConsultaPort reservaConsultaPort;

    @Mock
    private HerramientaConsultaPort herramientaConsultaPort;

    @InjectMocks
    private PagoApplicationService pagoService;

    private ProcesarPagoCommand command;
    private MetodoPago metodoActivo;

    @BeforeEach
    void setUp() {
        metodoActivo = MetodoPago.builder()
                .idMetodoPago(1L)
                .nombre("PSE_BANCOLOMBIA")
                .descripcion("Transferencia PSE")
                .activo(true)
                .build();

        command = ProcesarPagoCommand.builder()
                .idReserva(10L)
                .idCliente(8L)
                .idMetodoPago(1L)
                .monto(new BigDecimal("119000.00")) // Total con IVA fácil de comprobar
                .tipoPago(TipoPago.TOTALIDAD)
                .descripcionServicio("Alquiler Mezcladora de concreto")
                .build();
    }

    @Test
    @DisplayName("Debe procesar el pago exitosamente y generar automáticamente la factura con IVA 19%")
    void procesarPago_ExitoConFacturaEmitida() {
        when(metodoPagoRepositoryPort.buscarPorId(1L)).thenReturn(Optional.of(metodoActivo));
        when(pagoRepositoryPort.guardar(any(Pago.class))).thenAnswer(inv -> {
            Pago p = inv.getArgument(0);
            return Pago.builder()
                    .idPago(50L)
                    .numeroTransaccion(p.getNumeroTransaccion())
                    .idReserva(p.getIdReserva())
                    .idMetodoPago(p.getIdMetodoPago())
                    .monto(p.getMonto())
                    .tipoPago(p.getTipoPago())
                    .estadoPago(p.getEstadoPago())
                    .fechaPago(p.getFechaPago())
                    .referenciaPasarela(p.getReferenciaPasarela())
                    .build();
        });
        when(facturaRepositoryPort.guardar(any(Factura.class))).thenAnswer(inv -> {
            Factura f = inv.getArgument(0);
            return Factura.builder()
                    .idFactura(20L)
                    .numeroFactura(f.getNumeroFactura())
                    .idPago(f.getIdPago())
                    .idCliente(f.getIdCliente())
                    .fechaEmision(f.getFechaEmision())
                    .subtotal(f.getSubtotal())
                    .iva(f.getIva())
                    .total(f.getTotal())
                    .estado(f.getEstado())
                    .urlComprobantePdf(f.getUrlComprobantePdf())
                    .detalles(f.getDetalles())
                    .build();
        });

        Pago resultado = pagoService.procesarPago(command);

        assertNotNull(resultado);
        assertEquals(50L, resultado.getIdPago());
        assertEquals(EstadoPago.APROBADO, resultado.getEstadoPago());
        assertTrue(resultado.getNumeroTransaccion().startsWith("TRX-"));
        assertTrue(resultado.getReferenciaPasarela().contains("PSE_BANCOLOMBIA"));

        // Verificación de factura adjunta
        assertNotNull(resultado.getFactura());
        assertEquals(20L, resultado.getFactura().getIdFactura());
        assertEquals(EstadoFactura.PAGADA, resultado.getFactura().getEstado());
        assertEquals(new BigDecimal("119000.00"), resultado.getFactura().getTotal());
        assertEquals(new BigDecimal("100000.00"), resultado.getFactura().getSubtotal()); // 119000 / 1.19
        assertEquals(new BigDecimal("19000.00"), resultado.getFactura().getIva()); // 119000 - 100000

        verify(pagoRepositoryPort).guardar(any(Pago.class));
        verify(facturaRepositoryPort).guardar(any(Factura.class));
    }

    @Test
    @DisplayName("Debe rechazar el procesamiento si el método de pago está inactivo")
    void procesarPago_MetodoInactivo_LanzaExcepcion() {
        MetodoPago inactivo = MetodoPago.builder()
                .idMetodoPago(2L)
                .nombre("CHEQUE")
                .activo(false)
                .build();

        command.setIdMetodoPago(2L);
        when(metodoPagoRepositoryPort.buscarPorId(2L)).thenReturn(Optional.of(inactivo));

        BusinessRuleException ex = assertThrows(BusinessRuleException.class, () ->
                pagoService.procesarPago(command)
        );

        assertTrue(ex.getMessage().contains("no se encuentra habilitado"));
        verify(pagoRepositoryPort, never()).guardar(any());
        verify(facturaRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Debe consultar una factura existente por número de radicado")
    void obtenerFacturaPorNumero_Exito() {
        Factura factura = Factura.builder()
                .idFactura(1L)
                .numeroFactura("FAC-2026-0001")
                .total(new BigDecimal("500000.00"))
                .build();

        when(facturaRepositoryPort.buscarPorNumero("FAC-2026-0001")).thenReturn(Optional.of(factura));

        Factura resultado = pagoService.obtenerFacturaPorNumero("FAC-2026-0001");
        assertNotNull(resultado);
        assertEquals("FAC-2026-0001", resultado.getNumeroFactura());
    }

    @Test
    @DisplayName("Debe lanzar excepcion si el metodo de pago solicitado no existe")
    void procesarPago_MetodoNoExistente_LanzaExcepcion() {
        when(metodoPagoRepositoryPort.buscarPorId(999L)).thenReturn(Optional.empty());
        command.setIdMetodoPago(999L);

        assertThrows(RuntimeException.class, () ->
                pagoService.procesarPago(command)
        );
        verify(pagoRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Debe lanzar excepcion si se consulta una factura inexistente")
    void obtenerFacturaPorNumero_NoExiste_LanzaExcepcion() {
        when(facturaRepositoryPort.buscarPorNumero("FAC-INEXISTENTE")).thenReturn(Optional.empty());

        assertThrows(RuntimeException.class, () ->
                pagoService.obtenerFacturaPorNumero("FAC-INEXISTENTE")
        );
    }

    // ------------------------------------------------------------------
    // Reglas del pago hecho por el cliente autenticado
    // ------------------------------------------------------------------

    private static final String EMAIL = "cliente@rentatools.com";

    private InfoReserva reserva(String estado) {
        return new InfoReserva(10L, "RES-ABC12345", 8L, estado, LocalDate.now(), LocalDate.now().plusDays(3),
                new BigDecimal("225000.00"), new BigDecimal("67500.00"), List.of(5L));
    }

    private void clienteAutenticado(Long id) {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL))
                .thenReturn(new InfoUsuario(id, "Laura Cliente", EMAIL, Set.of("ROLE_CLIENTE"), true));
    }

    @Test
    @DisplayName("Pagar: una reserva que todavía no está aprobada no se puede pagar")
    void procesarPagoCliente_ReservaSolicitada() {
        clienteAutenticado(8L);
        when(reservaConsultaPort.buscarPorId(10L)).thenReturn(Optional.of(reserva("SOLICITADA")));

        assertThrows(BusinessRuleException.class, () -> pagoService.procesarPago(EMAIL, command));
        verify(pagoRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Pagar: un cliente no puede pagar la reserva de otro")
    void procesarPagoCliente_ReservaAjena() {
        clienteAutenticado(99L);
        when(reservaConsultaPort.buscarPorId(10L)).thenReturn(Optional.of(reserva("APROBADA")));

        assertThrows(AccesoDenegadoException.class, () -> pagoService.procesarPago(EMAIL, command));
    }

    @Test
    @DisplayName("Pagar: el monto no puede superar el saldo pendiente del alquiler")
    void procesarPagoCliente_MontoMayorAlSaldo() {
        clienteAutenticado(8L);
        when(reservaConsultaPort.buscarPorId(10L)).thenReturn(Optional.of(reserva("APROBADA")));
        when(pagoRepositoryPort.buscarPorReserva(10L)).thenReturn(List.of());
        command.setMonto(new BigDecimal("300000.00"));

        assertThrows(BusinessRuleException.class, () -> pagoService.procesarPago(EMAIL, command));
    }

    @Test
    @DisplayName("Pagar: sin monto se cobra el saldo pendiente y la factura sale a nombre del cliente")
    void procesarPagoCliente_SinMontoCobraSaldo() {
        clienteAutenticado(8L);
        when(reservaConsultaPort.buscarPorId(10L)).thenReturn(Optional.of(reserva("APROBADA")));
        Pago anticipo = Pago.builder().idPago(1L).idReserva(10L).monto(new BigDecimal("100000.00"))
                .tipoPago(TipoPago.ANTICIPO).estadoPago(EstadoPago.APROBADO).build();
        when(pagoRepositoryPort.buscarPorReserva(10L)).thenReturn(List.of(anticipo));
        when(metodoPagoRepositoryPort.buscarPorId(1L)).thenReturn(Optional.of(metodoActivo));
        when(pagoRepositoryPort.guardar(any(Pago.class))).thenAnswer(inv -> inv.getArgument(0));
        when(facturaRepositoryPort.guardar(any(Factura.class))).thenAnswer(inv -> inv.getArgument(0));
        command.setMonto(null);
        command.setIdCliente(null);

        Pago pago = pagoService.procesarPago(EMAIL, command);

        assertEquals(new BigDecimal("125000.00"), pago.getMonto());
        assertEquals(EstadoPago.APROBADO, pago.getEstadoPago());
        assertEquals(8L, pago.getFactura().getIdCliente());
    }
}
