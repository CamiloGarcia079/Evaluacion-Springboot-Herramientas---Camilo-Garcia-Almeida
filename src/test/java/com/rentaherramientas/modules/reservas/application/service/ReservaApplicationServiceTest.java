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
import com.rentaherramientas.modules.reservas.domain.model.EstadoDevolucion;
import com.rentaherramientas.modules.reservas.domain.model.EstadoReserva;
import com.rentaherramientas.modules.reservas.domain.model.ReporteDano;
import com.rentaherramientas.modules.reservas.domain.ports.in.DevolucionEquipoUseCase.ResultadoDevolucion;
import com.rentaherramientas.modules.reservas.domain.ports.out.ReporteDanoPort;
import com.rentaherramientas.modules.reservas.domain.model.RangoFechas;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;
import com.rentaherramientas.modules.reservas.domain.ports.out.AuditoriaReservaPort;
import com.rentaherramientas.modules.reservas.domain.ports.out.ReservaRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReservaApplicationServiceTest {

    private static final String EMAIL_CLIENTE = "cliente@rentatools.com";
    private static final String EMAIL_PROVEEDOR = "proveedor@rentatools.com";
    private static final String EMAIL_OTRO_PROVEEDOR = "otro.proveedor@rentatools.com";
    private static final String EMAIL_OTRO_CLIENTE = "otro.cliente@rentatools.com";

    @Mock
    private ReservaRepositoryPort reservaRepositoryPort;
    @Mock
    private AuditoriaReservaPort auditoriaReservaPort;
    @Mock
    private UsuarioConsultaPort usuarioConsultaPort;
    @Mock
    private HerramientaConsultaPort herramientaConsultaPort;
    @Mock
    private ReporteDanoPort reporteDanoPort;

    @InjectMocks
    private ReservaApplicationService reservaService;

    private InfoUsuario cliente;
    private InfoUsuario proveedor;
    private InfoUsuario otroProveedor;
    private InfoUsuario otroCliente;
    private InfoHerramienta taladro;
    private LocalDate inicio;
    private LocalDate fin;

    @BeforeEach
    void setUp() {
        cliente = new InfoUsuario(8L, "Laura Cliente", EMAIL_CLIENTE, Set.of("ROLE_CLIENTE"), true);
        otroCliente = new InfoUsuario(9L, "Pedro Cliente", EMAIL_OTRO_CLIENTE, Set.of("ROLE_CLIENTE"), true);
        proveedor = new InfoUsuario(3L, "Ferretería Central", EMAIL_PROVEEDOR, Set.of("ROLE_PROVEEDOR"), true);
        otroProveedor = new InfoUsuario(4L, "Equipos del Norte", EMAIL_OTRO_PROVEEDOR, Set.of("ROLE_PROVEEDOR"), true);
        taladro = new InfoHerramienta(5L, "Taladro percutor", "Bosch", "GSB 13", new BigDecimal("75000.00"),
                "DISPONIBLE", 3L, "/img/herramientas/taladro.svg");
        inicio = LocalDate.now().plusDays(2);
        fin = inicio.plusDays(3);
    }

    private CrearReservaCommand comando(Long... idsHerramientas) {
        List<DetalleReservaItemCommand> items = new ArrayList<>();
        for (Long id : idsHerramientas) {
            items.add(DetalleReservaItemCommand.builder().idHerramienta(id).cantidad(1).build());
        }
        return CrearReservaCommand.builder().fechaInicio(inicio).fechaFin(fin).items(items).build();
    }

    private Reserva reservaEnEstado(EstadoReserva estado) {
        List<DetalleReserva> detalles = new ArrayList<>();
        detalles.add(DetalleReserva.builder().idDetalleReserva(1L).idHerramienta(5L).nombreHerramienta("Taladro percutor")
                .cantidad(1).precioUnitarioDia(new BigDecimal("75000.00")).diasAlquiler(3).build());
        Reserva reserva = Reserva.builder()
                .idReserva(100L)
                .codigoReserva("RES-TEST0001")
                .idCliente(8L)
                .fechaSolicitud(LocalDateTime.now())
                .rangoFechas(new RangoFechas(inicio, fin))
                .estado(estado)
                .detalles(detalles)
                .build();
        reserva.calcularTotales();
        return reserva;
    }

    // ------------------------------------------------------------------ crear

    @Test
    @DisplayName("Crear: el cliente sale del token y el precio de la tarifa vigente (30 % de depósito)")
    void crearReserva_Exito() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));
        when(reservaRepositoryPort.existeConflictoFechas(eq(5L), eq(inicio), eq(fin), isNull())).thenReturn(false);
        when(reservaRepositoryPort.guardar(any(Reserva.class))).thenAnswer(inv -> {
            Reserva r = inv.getArgument(0);
            return r.toBuilder().idReserva(100L).build();
        });

        Reserva creada = reservaService.crearReserva(EMAIL_CLIENTE, comando(5L));

        assertEquals(8L, creada.getIdCliente());
        assertEquals(EstadoReserva.SOLICITADA, creada.getEstado());
        assertEquals(new BigDecimal("225000.00"), creada.getMontoTotalEstimado());
        assertEquals(new BigDecimal("67500.00"), creada.getDepositoGarantia());
        assertEquals(new BigDecimal("75000.00"), creada.getDetalles().get(0).getPrecioUnitarioDia());
        assertTrue(creada.getCodigoReserva().startsWith("RES-"));
        verify(auditoriaReservaPort).registrarCambioEstado(eq(100L), isNull(), eq("SOLICITADA"), eq(8L), anyString());
    }

    @Test
    @DisplayName("Crear: no se permiten fechas pasadas")
    void crearReserva_FechaPasada() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        inicio = LocalDate.now().minusDays(1);
        fin = LocalDate.now().plusDays(1);

        assertThrows(BusinessRuleException.class, () -> reservaService.crearReserva(EMAIL_CLIENTE, comando(5L)));
        verify(reservaRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Crear: la fecha fin no puede ser anterior a la de inicio")
    void crearReserva_RangoInvertido() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        fin = inicio.minusDays(1);

        assertThrows(BusinessRuleException.class, () -> reservaService.crearReserva(EMAIL_CLIENTE, comando(5L)));
    }

    @Test
    @DisplayName("Crear: herramienta inexistente responde 404")
    void crearReserva_HerramientaInexistente() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        when(herramientaConsultaPort.buscarPorId(99L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> reservaService.crearReserva(EMAIL_CLIENTE, comando(99L)));
    }

    @Test
    @DisplayName("Crear: una herramienta fuera de servicio no se puede reservar")
    void crearReserva_FueraDeServicio() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        InfoHerramienta deBaja = new InfoHerramienta(5L, "Taladro percutor", "Bosch", "GSB 13",
                new BigDecimal("75000.00"), "FUERA_DE_SERVICIO", 3L, null);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(deBaja));

        assertThrows(BusinessRuleException.class, () -> reservaService.crearReserva(EMAIL_CLIENTE, comando(5L)));
    }

    @Test
    @DisplayName("Crear: un proveedor no puede reservar su propia herramienta")
    void crearReserva_HerramientaPropia() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));

        assertThrows(BusinessRuleException.class, () -> reservaService.crearReserva(EMAIL_PROVEEDOR, comando(5L)));
    }

    @Test
    @DisplayName("Crear: fechas cruzadas con una reserva aprobada se rechazan")
    void crearReserva_ConflictoDeFechas() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));
        when(reservaRepositoryPort.existeConflictoFechas(eq(5L), eq(inicio), eq(fin), isNull())).thenReturn(true);

        BusinessRuleException ex = assertThrows(BusinessRuleException.class,
                () -> reservaService.crearReserva(EMAIL_CLIENTE, comando(5L)));
        assertTrue(ex.getMessage().contains("ya tiene una reserva activa"));
        verify(reservaRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Crear: la misma herramienta repetida en la solicitud se rechaza")
    void crearReserva_HerramientaRepetida() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));
        when(reservaRepositoryPort.existeConflictoFechas(eq(5L), eq(inicio), eq(fin), isNull())).thenReturn(false);

        assertThrows(BusinessRuleException.class, () -> reservaService.crearReserva(EMAIL_CLIENTE, comando(5L, 5L)));
    }

    @Test
    @DisplayName("Crear: una cuenta bloqueada no puede reservar")
    void crearReserva_CuentaBloqueada() {
        InfoUsuario bloqueado = new InfoUsuario(8L, "Laura Cliente", EMAIL_CLIENTE, Set.of("ROLE_CLIENTE"), false);
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(bloqueado);

        assertThrows(BusinessRuleException.class, () -> reservaService.crearReserva(EMAIL_CLIENTE, comando(5L)));
    }

    // ------------------------------------------------------------- gestion

    @Test
    @DisplayName("Aprobar: el proveedor dueño de la herramienta aprueba y queda auditado")
    void aprobarReserva_ProveedorDuenio() {
        Reserva reserva = reservaEnEstado(EstadoReserva.SOLICITADA);
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reserva));
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));
        when(reservaRepositoryPort.existeConflictoFechas(5L, inicio, fin, 100L)).thenReturn(false);
        when(reservaRepositoryPort.guardar(any(Reserva.class))).thenAnswer(inv -> inv.getArgument(0));

        Reserva aprobada = reservaService.aprobarReserva(EMAIL_PROVEEDOR, 100L);

        assertEquals(EstadoReserva.APROBADA, aprobada.getEstado());
        verify(auditoriaReservaPort).registrarCambioEstado(eq(100L), eq("SOLICITADA"), eq("APROBADA"), eq(3L), anyString());
    }

    @Test
    @DisplayName("Aprobar: un proveedor ajeno recibe 403")
    void aprobarReserva_ProveedorAjeno() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_OTRO_PROVEEDOR)).thenReturn(otroProveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.SOLICITADA)));
        when(herramientaConsultaPort.idsDeProveedor(4L)).thenReturn(List.of(77L));

        assertThrows(AccesoDenegadoException.class, () -> reservaService.aprobarReserva(EMAIL_OTRO_PROVEEDOR, 100L));
        verify(reservaRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Aprobar: si otra reserva ya fue aprobada en esas fechas, no se aprueba")
    void aprobarReserva_ConflictoAlAprobar() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.SOLICITADA)));
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));
        when(reservaRepositoryPort.existeConflictoFechas(5L, inicio, fin, 100L)).thenReturn(true);

        assertThrows(BusinessRuleException.class, () -> reservaService.aprobarReserva(EMAIL_PROVEEDOR, 100L));
    }

    @Test
    @DisplayName("Rechazar: el motivo es obligatorio")
    void rechazarReserva_SinMotivo() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.SOLICITADA)));
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));

        assertThrows(BusinessRuleException.class, () -> reservaService.rechazarReserva(EMAIL_PROVEEDOR, 100L, "  "));
    }

    @Test
    @DisplayName("Iniciar: despachar el equipo pone la herramienta ALQUILADA")
    void iniciarAlquiler_CambiaEstadoHerramienta() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.APROBADA)));
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));
        when(reservaRepositoryPort.guardar(any(Reserva.class))).thenAnswer(inv -> inv.getArgument(0));

        Reserva enCurso = reservaService.iniciarAlquiler(EMAIL_PROVEEDOR, 100L);

        assertEquals(EstadoReserva.EN_CURSO, enCurso.getEstado());
        verify(herramientaConsultaPort).cambiarEstado(5L, "ALQUILADA");
    }

    @Test
    @DisplayName("Finalizar: la herramienta vuelve a DISPONIBLE")
    void finalizarAlquiler_LiberaHerramienta() {
        InfoHerramienta alquilada = new InfoHerramienta(5L, "Taladro percutor", "Bosch", "GSB 13",
                new BigDecimal("75000.00"), "ALQUILADA", 3L, null);
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.EN_CURSO)));
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(alquilada));
        when(reservaRepositoryPort.guardar(any(Reserva.class))).thenAnswer(inv -> inv.getArgument(0));

        Reserva finalizada = reservaService.finalizarAlquiler(EMAIL_PROVEEDOR, 100L);

        assertEquals(EstadoReserva.FINALIZADA, finalizada.getEstado());
        verify(herramientaConsultaPort).cambiarEstado(5L, "DISPONIBLE");
    }

    // ------------------------------------------------------------ devolucion

    private InfoHerramienta taladroAlquilado() {
        return new InfoHerramienta(5L, "Taladro percutor", "Bosch", "GSB 13",
                new BigDecimal("75000.00"), "ALQUILADA", 3L, null);
    }

    private void prepararDevolucion() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.EN_CURSO)));
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladroAlquilado()));
        when(reservaRepositoryPort.guardar(any(Reserva.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    @DisplayName("Devolución OK: DEVUELTO_OK, reserva finalizada, herramienta disponible y sin reporte")
    void registrarDevolucion_Ok() {
        prepararDevolucion();

        ResultadoDevolucion r = reservaService.registrarDevolucion(EMAIL_PROVEEDOR, 100L, "OK", null, null);

        assertEquals(EstadoDevolucion.DEVUELTO_OK, r.reserva().getEstadoDevolucion());
        assertEquals(EstadoReserva.FINALIZADA, r.reserva().getEstado());
        assertEquals(null, r.reporteDano());
        verify(herramientaConsultaPort).cambiarEstado(5L, "DISPONIBLE");
        verify(reporteDanoPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Devolución con daños: DEVUELTO_CON_DANOS y se guarda el ReporteDano de la reserva")
    void registrarDevolucion_ConDanos() {
        prepararDevolucion();
        when(reporteDanoPort.guardar(any(ReporteDano.class))).thenAnswer(inv -> inv.getArgument(0));

        ResultadoDevolucion r = reservaService.registrarDevolucion(
                EMAIL_PROVEEDOR, 100L, "DAÑOS", "Broca partida", 150000.0);

        assertEquals(EstadoDevolucion.DEVUELTO_CON_DANOS, r.reserva().getEstadoDevolucion());
        ArgumentCaptor<ReporteDano> captor = ArgumentCaptor.forClass(ReporteDano.class);
        verify(reporteDanoPort).guardar(captor.capture());
        assertEquals(100L, captor.getValue().getIdReserva());
        assertEquals("Broca partida", captor.getValue().getDescripcion());
        assertEquals(150000.0, captor.getValue().getCostoReparacion());
        assertEquals(LocalDate.now(), captor.getValue().getFechaReporte());
        verify(herramientaConsultaPort).cambiarEstado(5L, "EN_MANTENIMIENTO");
    }

    @Test
    @DisplayName("Devolución con daños sin descripción: se rechaza")
    void registrarDevolucion_DanosSinDescripcion() {
        assertThrows(BusinessRuleException.class,
                () -> reservaService.registrarDevolucion(EMAIL_PROVEEDOR, 100L, "DANOS", " ", 100.0));
        verify(reporteDanoPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Devolución: un estado distinto de OK o DANOS se rechaza")
    void registrarDevolucion_EstadoInvalido() {
        assertThrows(BusinessRuleException.class,
                () -> reservaService.registrarDevolucion(EMAIL_PROVEEDOR, 100L, "ROTO", null, null));
    }

    @Test
    @DisplayName("Devolución: solo aplica a reservas EN_CURSO")
    void registrarDevolucion_ReservaNoEnCurso() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.APROBADA)));
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));

        assertThrows(BusinessRuleException.class,
                () -> reservaService.registrarDevolucion(EMAIL_PROVEEDOR, 100L, "OK", null, null));
        verify(reservaRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("Devolución: un proveedor ajeno no puede registrarla")
    void registrarDevolucion_ProveedorAjeno() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_OTRO_PROVEEDOR)).thenReturn(otroProveedor);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.EN_CURSO)));
        when(herramientaConsultaPort.idsDeProveedor(otroProveedor.idUsuario())).thenReturn(List.of(99L));

        assertThrows(AccesoDenegadoException.class,
                () -> reservaService.registrarDevolucion(EMAIL_OTRO_PROVEEDOR, 100L, "OK", null, null));
    }

    // ------------------------------------------------------------ cancelar

    @Test
    @DisplayName("Cancelar: el cliente dueño cancela su reserva solicitada")
    void cancelarReserva_PorSuDuenio() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.SOLICITADA)));
        when(reservaRepositoryPort.guardar(any(Reserva.class))).thenAnswer(inv -> inv.getArgument(0));

        assertEquals(EstadoReserva.CANCELADA, reservaService.cancelarReserva(EMAIL_CLIENTE, 100L).getEstado());
    }

    @Test
    @DisplayName("Cancelar: otro cliente no puede cancelar una reserva ajena")
    void cancelarReserva_ClienteAjeno() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_OTRO_CLIENTE)).thenReturn(otroCliente);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.SOLICITADA)));

        assertThrows(AccesoDenegadoException.class, () -> reservaService.cancelarReserva(EMAIL_OTRO_CLIENTE, 100L));
    }

    @Test
    @DisplayName("Cancelar: una reserva en curso ya no se puede cancelar")
    void cancelarReserva_EnCurso() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.EN_CURSO)));

        assertThrows(BusinessRuleException.class, () -> reservaService.cancelarReserva(EMAIL_CLIENTE, 100L));
    }

    // ------------------------------------------------------------ consultas

    @Test
    @DisplayName("Consultar: un cliente no ve reservas de otro cliente")
    void obtener_ReservaAjena() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_OTRO_CLIENTE)).thenReturn(otroCliente);
        when(reservaRepositoryPort.buscarPorId(100L)).thenReturn(Optional.of(reservaEnEstado(EstadoReserva.SOLICITADA)));

        assertThrows(AccesoDenegadoException.class, () -> reservaService.obtener(EMAIL_OTRO_CLIENTE, 100L));
    }

    @Test
    @DisplayName("Gestión: un cliente no puede listar las reservas de gestión")
    void listarParaGestion_Cliente() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);

        assertThrows(AccesoDenegadoException.class, () -> reservaService.listarParaGestion(EMAIL_CLIENTE));
    }

    @Test
    @DisplayName("Gestión: el proveedor ve solo las reservas de sus herramientas")
    void listarParaGestion_Proveedor() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_PROVEEDOR)).thenReturn(proveedor);
        when(herramientaConsultaPort.idsDeProveedor(3L)).thenReturn(List.of(5L));
        when(reservaRepositoryPort.buscarPorHerramientas(List.of(5L)))
                .thenReturn(List.of(reservaEnEstado(EstadoReserva.SOLICITADA)));

        assertEquals(1, reservaService.listarParaGestion(EMAIL_PROVEEDOR).size());
        verify(reservaRepositoryPort, never()).buscarTodas();
    }

    @Test
    @DisplayName("Disponibilidad: una solicitud pendiente se muestra pero no bloquea")
    void disponibilidad_SoloSolicitada() {
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));
        when(reservaRepositoryPort.buscarQueSeCruzan(eq(5L), eq(inicio), eq(fin), any()))
                .thenReturn(List.of(reservaEnEstado(EstadoReserva.SOLICITADA)));

        Disponibilidad d = reservaService.consultarDisponibilidad(5L, inicio, fin);

        assertTrue(d.disponible());
        assertEquals(1, d.ocupaciones().size());
    }

    @Test
    @DisplayName("Disponibilidad: una reserva aprobada en el rango bloquea la herramienta")
    void disponibilidad_Aprobada() {
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));
        when(reservaRepositoryPort.buscarQueSeCruzan(eq(5L), eq(inicio), eq(fin), any()))
                .thenReturn(List.of(reservaEnEstado(EstadoReserva.APROBADA)));

        assertFalse(reservaService.consultarDisponibilidad(5L, inicio, fin).disponible());
    }

    @Test
    @DisplayName("Reserva no encontrada responde 404")
    void reservaNoEncontrada() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL_CLIENTE)).thenReturn(cliente);
        when(reservaRepositoryPort.buscarPorId(anyLong())).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> reservaService.obtener(EMAIL_CLIENTE, 999L));
    }
}
