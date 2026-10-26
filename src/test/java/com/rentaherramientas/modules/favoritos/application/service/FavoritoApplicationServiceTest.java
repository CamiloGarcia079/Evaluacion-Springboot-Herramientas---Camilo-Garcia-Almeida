package com.rentaherramientas.modules.favoritos.application.service;

import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort.InfoHerramienta;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.favoritos.domain.model.Favorito;
import com.rentaherramientas.modules.favoritos.domain.ports.out.FavoritoRepositoryPort;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
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
class FavoritoApplicationServiceTest {

    private static final String EMAIL = "cliente@rentatools.com";

    @Mock
    private FavoritoRepositoryPort repositoryPort;
    @Mock
    private UsuarioConsultaPort usuarioConsultaPort;
    @Mock
    private HerramientaConsultaPort herramientaConsultaPort;

    @InjectMocks
    private FavoritoApplicationService service;

    private InfoHerramienta taladro;

    @BeforeEach
    void setUp() {
        when(usuarioConsultaPort.obtenerPorEmail(EMAIL))
                .thenReturn(new InfoUsuario(8L, "Laura", EMAIL, Set.of("ROLE_CLIENTE"), true));
        taladro = new InfoHerramienta(5L, "Taladro", "Bosch", "GSB", new BigDecimal("75000"), "DISPONIBLE", 3L, null);
    }

    @Test
    @DisplayName("Agregar dos veces la misma herramienta no la duplica")
    void agregar_Idempotente() {
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));
        when(repositoryPort.buscar(8L, 5L)).thenReturn(Optional.of(Favorito.nuevo(8L, 5L)));

        assertEquals(5L, service.agregar(EMAIL, 5L).idHerramienta());
        verify(repositoryPort, never()).guardar(any());
    }

    @Test
    @DisplayName("No se agrega una herramienta fuera de servicio")
    void agregar_FueraDeServicio() {
        InfoHerramienta baja = new InfoHerramienta(5L, "Taladro", "Bosch", "GSB", BigDecimal.TEN, "FUERA_DE_SERVICIO", 3L, null);
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(baja));
        when(repositoryPort.buscar(8L, 5L)).thenReturn(Optional.empty());

        assertThrows(BusinessRuleException.class, () -> service.agregar(EMAIL, 5L));
    }

    @Test
    @DisplayName("Agrega la herramienta a la lista")
    void agregar_Exito() {
        when(herramientaConsultaPort.buscarPorId(5L)).thenReturn(Optional.of(taladro));
        when(repositoryPort.buscar(8L, 5L)).thenReturn(Optional.empty());
        when(repositoryPort.buscarPorUsuario(8L)).thenReturn(List.of());
        when(repositoryPort.guardar(any(Favorito.class))).thenAnswer(inv -> inv.getArgument(0));

        assertEquals("Taladro", service.agregar(EMAIL, 5L).nombre());
    }

    @Test
    @DisplayName("Quitar una herramienta que no está en favoritos responde 404")
    void quitar_NoExiste() {
        when(repositoryPort.buscar(8L, 5L)).thenReturn(Optional.empty());

        assertThrows(ResourceNotFoundException.class, () -> service.quitar(EMAIL, 5L));
    }
}
