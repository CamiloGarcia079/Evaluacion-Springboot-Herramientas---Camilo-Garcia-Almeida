package com.rentaherramientas.modules.resenas.application.service;

import com.rentaherramientas.common.exception.AccesoDenegadoException;
import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.ReservaConsultaPort;
import com.rentaherramientas.common.kernel.ReservaConsultaPort.InfoReserva;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.resenas.domain.model.Resena;
import com.rentaherramientas.modules.resenas.domain.ports.out.ResenaRepositoryPort;
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
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ResenaApplicationServiceTest {

    private static final String EMAIL = "cliente@rentatools.com";

    @Mock
    private ResenaRepositoryPort resenaRepositoryPort;
    @Mock
    private UsuarioConsultaPort usuarioConsultaPort;
    @Mock
    private ReservaConsultaPort reservaConsultaPort;
    @Mock
    private HerramientaConsultaPort herramientaConsultaPort;

    @InjectMocks
    private ResenaApplicationService service;

    private InfoUsuario cliente;

    @BeforeEach
    void setUp() {
        cliente = new InfoUsuario(8L, "Laura Cliente", EMAIL, Set.of("ROLE_CLIENTE"), true);
    }

    private InfoReserva reserva(String estado, Long idCliente) {
        return new InfoReserva(20L, "RES-AAAA1111", idCliente, estado, LocalDate.now().minusDays(5),
                LocalDate.now().minusDays(2), new BigDecimal("100000.00"), new BigDecimal("30000.00"), List.of(5L));
    }

    @Test
    @DisplayName("Publica la reseña cuando el alquiler está finalizado")
    void publicar_Exito() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(cliente);
        when(reservaConsultaPort.buscarPorId(20L)).thenReturn(Optional.of(reserva("FINALIZADA", 8L)));
        when(resenaRepositoryPort.existe(20L, 5L)).thenReturn(false);
        when(resenaRepositoryPort.guardar(any(Resena.class)))
                .thenAnswer(inv -> ((Resena) inv.getArgument(0)).toBuilder().idResena(1L).build());

        Resena r = service.publicar(EMAIL, 20L, 5L, 5, "  Excelente equipo  ");

        assertEquals(1L, r.getIdResena());
        assertEquals("Excelente equipo", r.getComentario());
        assertEquals("Laura Cliente", r.getNombreCliente());
    }

    @Test
    @DisplayName("No se califica un alquiler que no ha finalizado")
    void publicar_ReservaNoFinalizada() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(cliente);
        when(reservaConsultaPort.buscarPorId(20L)).thenReturn(Optional.of(reserva("EN_CURSO", 8L)));

        assertThrows(BusinessRuleException.class, () -> service.publicar(EMAIL, 20L, 5L, 4, null));
        verify(resenaRepositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("No se califica la reserva de otro cliente")
    void publicar_ReservaAjena() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(cliente);
        when(reservaConsultaPort.buscarPorId(20L)).thenReturn(Optional.of(reserva("FINALIZADA", 99L)));

        assertThrows(AccesoDenegadoException.class, () -> service.publicar(EMAIL, 20L, 5L, 4, null));
    }

    @Test
    @DisplayName("La herramienta debe pertenecer a la reserva")
    void publicar_HerramientaFueraDeLaReserva() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(cliente);
        when(reservaConsultaPort.buscarPorId(20L)).thenReturn(Optional.of(reserva("FINALIZADA", 8L)));

        assertThrows(BusinessRuleException.class, () -> service.publicar(EMAIL, 20L, 77L, 4, null));
    }

    @Test
    @DisplayName("Una sola reseña por herramienta y reserva")
    void publicar_Duplicada() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(cliente);
        when(reservaConsultaPort.buscarPorId(20L)).thenReturn(Optional.of(reserva("FINALIZADA", 8L)));
        when(resenaRepositoryPort.existe(20L, 5L)).thenReturn(true);

        assertThrows(BusinessRuleException.class, () -> service.publicar(EMAIL, 20L, 5L, 4, null));
    }

    @Test
    @DisplayName("Solo el autor edita su reseña")
    void editar_NoAutor() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL)).thenReturn(cliente);
        Resena ajena = Resena.builder().idResena(3L).idCliente(99L).idHerramienta(5L).calificacion(3).build();
        when(resenaRepositoryPort.buscarPorId(3L)).thenReturn(Optional.of(ajena));

        assertThrows(AccesoDenegadoException.class, () -> service.editar(EMAIL, 3L, 5, "cambio"));
    }

    @Test
    @DisplayName("El administrador puede eliminar reseñas de otros (moderación)")
    void eliminar_Admin() {
        InfoUsuario admin = new InfoUsuario(1L, "Admin", "admin@rentatools.com", Set.of("ROLE_ADMIN"), true);
        when(usuarioConsultaPort.obtenerPorEmail("admin@rentatools.com")).thenReturn(admin);
        when(resenaRepositoryPort.buscarPorId(3L))
                .thenReturn(Optional.of(Resena.builder().idResena(3L).idCliente(8L).calificacion(1).build()));

        service.eliminar("admin@rentatools.com", 3L);

        verify(resenaRepositoryPort).eliminar(3L);
    }
}
