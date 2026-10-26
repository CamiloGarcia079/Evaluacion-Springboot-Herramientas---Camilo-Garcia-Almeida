package com.rentaherramientas.common.dto;

import com.rentaherramientas.common.exception.BusinessRuleException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PaginaDtoTest {

    private final List<Integer> veinticinco = IntStream.rangeClosed(1, 25).boxed().toList();

    @Test
    @DisplayName("Divide 25 elementos en 3 páginas de 10")
    void paginas() {
        PaginaDto<Integer> p = PaginaDto.de(veinticinco, 2, 10);
        assertEquals(List.of(21, 22, 23, 24, 25), p.contenido());
        assertEquals(3, p.totalPaginas());
        assertEquals(25, p.totalElementos());
        assertTrue(p.ultima());
        assertFalse(p.primera());
    }

    @Test
    @DisplayName("Una página fuera de rango devuelve lista vacía")
    void paginaFueraDeRango() {
        assertTrue(PaginaDto.de(veinticinco, 10, 10).contenido().isEmpty());
    }

    @Test
    @DisplayName("Tamaño y página inválidos se rechazan")
    void parametrosInvalidos() {
        assertThrows(BusinessRuleException.class, () -> PaginaDto.de(veinticinco, -1, 10));
        assertThrows(BusinessRuleException.class, () -> PaginaDto.de(veinticinco, 0, 0));
        assertThrows(BusinessRuleException.class, () -> PaginaDto.de(veinticinco, 0, 51));
    }
}
