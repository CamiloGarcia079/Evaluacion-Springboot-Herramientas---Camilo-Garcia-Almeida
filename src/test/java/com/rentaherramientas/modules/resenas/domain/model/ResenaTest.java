package com.rentaherramientas.modules.resenas.domain.model;

import com.rentaherramientas.common.exception.BusinessRuleException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ResenaTest {

    @Test
    @DisplayName("La calificación debe estar entre 1 y 5")
    void calificacionFueraDeRango() {
        assertThrows(BusinessRuleException.class, () -> Resena.nueva(1L, 2L, 3L, 0, null));
        assertThrows(BusinessRuleException.class, () -> Resena.nueva(1L, 2L, 3L, 6, null));
        assertThrows(BusinessRuleException.class, () -> Resena.nueva(1L, 2L, 3L, null, null));
    }

    @Test
    @DisplayName("Un comentario en blanco se guarda como null")
    void comentarioEnBlanco() {
        assertNull(Resena.nueva(1L, 2L, 3L, 4, "   ").getComentario());
    }

    @Test
    @DisplayName("El comentario no puede pasar de 500 caracteres")
    void comentarioLargo() {
        assertThrows(BusinessRuleException.class, () -> Resena.nueva(1L, 2L, 3L, 4, "a".repeat(501)));
    }

    @Test
    @DisplayName("El promedio se redondea a un decimal")
    void promedioRedondeado() {
        assertEquals("4.7", ResumenCalificacion.de(1L, 4.666, 3L).promedio().toPlainString());
    }
}
