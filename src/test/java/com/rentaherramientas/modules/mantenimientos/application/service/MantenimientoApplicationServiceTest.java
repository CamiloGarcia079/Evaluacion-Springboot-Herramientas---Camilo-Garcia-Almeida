package com.rentaherramientas.modules.mantenimientos.application.service;

import com.rentaherramientas.common.exception.AccesoDenegadoException;
import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort.InfoHerramienta;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.mantenimientos.domain.model.EstadoMantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.model.Mantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.model.TipoMantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.ports.out.MantenimientoRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MantenimientoApplicationServiceTest {

    private static final String EMAIL = "proveedor@rentatools.com";

    @Mock
    private MantenimientoRepositoryPort repositoryPort;
    @Mock
    private UsuarioConsultaPort usuarioConsultaPort;
    @Mock
    private HerramientaConsultaPort herramientaConsultaPort;

    @InjectMocks
    private MantenimientoApplicationService service;

    private InfoUsuario proveedor;

    @BeforeEach
    void setUp() {
        proveedor = new InfoUsuario(3L, "Ferretería Central", EMAIL, Set.of("ROLE_PROVEEDOR"), true);
    }

    private InfoHerramienta herramienta(String estado, Long idProveedor) {
        return new InfoHerramienta(5L, "Pulidora", "DeWalt", "D28", new BigDecimal("40000"), estado, idProveedor, null);
    }

    @Test
    @DisplayName("Registrar pone la herramienta EN_MANTENIMIENTO")
    void registrar_Exito() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(proveedor);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(herramienta("DISPONIBLE", 3L)));
        when(repositoryPort.existeAbierto(5L)).thenReturn(false);
        when(repositoryPort.guardar(any(Mantenimiento.class))).thenAnswer(inv -> inv.getArgument(0));

        Mantenimiento m = service.registrar(EMAIL, 5L, TipoMantenimiento.PREVENTIVO, "Cambio de carbones");

        assertEquals(EstadoMantenimiento.EN_PROCESO, m.getEstado());
        verify(herramientaConsultaPort).cambiarEstado(5L, "EN_MANTENIMIENTO");
    }

    @Test
    @DisplayName("Una herramienta alquilada no se puede enviar a mantenimiento")
    void registrar_Alquilada() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(proveedor);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(herramienta("ALQUILADA", 3L)));

        assertThrows(BusinessRuleException.class,
                () -> service.registrar(EMAIL, 5L, TipoMantenimiento.CORRECTIVO, "Motor no enciende"));
        verify(repositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("No se abren dos mantenimientos a la vez")
    void registrar_YaAbierto() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(proveedor);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(herramienta("EN_MANTENIMIENTO", 3L)));
        when(repositoryPort.existeAbierto(5L)).thenReturn(true);

        assertThrows(BusinessRuleException.class,
                () -> service.registrar(EMAIL, 5L, TipoMantenimiento.REVISION, "Revisión"));
    }

    @Test
    @DisplayName("Un proveedor no gestiona herramientas de otro")
    void registrar_ProveedorAjeno() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(proveedor);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(herramienta("DISPONIBLE", 44L)));

        assertThrows(AccesoDenegadoException.class,
                () -> service.registrar(EMAIL, 5L, TipoMantenimiento.PREVENTIVO, "x"));
    }

    @Test
    @DisplayName("Finalizar registra el costo y devuelve la herramienta a DISPONIBLE")
    void finalizar_Exito() {
        Mantenimiento abierto = Mantenimiento.builder().idMantenimiento(9L).idHerramienta(5L)
                .tipo(TipoMantenimiento.CORRECTIVO).descripcion("x").estado(EstadoMantenimiento.EN_PROCESO)
                .fechaInicio(LocalDateTime.now().minusHours(5)).registradoPor(3L).build();
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(proveedor);
        when(repositoryPort.buscarPorId(9L)).thenReturn(Optional.of(abierto));
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(herramienta("EN_MANTENIMIENTO", 3L)));
        when(repositoryPort.guardar(any(Mantenimiento.class))).thenAnswer(inv -> inv.getArgument(0));

        Mantenimiento m = service.finalizar(EMAIL, 9L, new BigDecimal("85000"), "Listo", false);

        assertEquals(EstadoMantenimiento.FINALIZADO, m.getEstado());
        assertEquals(new BigDecimal("85000.00"), m.getCosto());
        verify(herramientaConsultaPort).cambiarEstado(5L, "DISPONIBLE");
    }

    @Test
    @DisplayName("Un mantenimiento finalizado no se puede volver a cerrar")
    void finalizar_DosVeces() {
        Mantenimiento m = Mantenimiento.abrir(5L, TipoMantenimiento.REVISION, "x", 3L);
        m.finalizar(BigDecimal.ZERO, null);
        assertThrows(BusinessRuleException.class, () -> m.finalizar(BigDecimal.ONE, null));
    }
}
