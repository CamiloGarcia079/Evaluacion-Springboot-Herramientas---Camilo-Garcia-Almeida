package com.rentaherramientas.modules.resenas.domain.model;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Promedio de estrellas y cantidad de resenas de una herramienta. */
public record ResumenCalificacion(Long idHerramienta, BigDecimal promedio, long totalResenas) {

    public static ResumenCalificacion de(Long idHerramienta, Double promedio, Long total) {
        BigDecimal valor = promedio == null ? BigDecimal.ZERO : BigDecimal.valueOf(promedio).setScale(1, RoundingMode.HALF_UP);
        return new ResumenCalificacion(idHerramienta, valor, total == null ? 0 : total);
    }

    public static ResumenCalificacion vacio(Long idHerramienta) {
        return new ResumenCalificacion(idHerramienta, BigDecimal.ZERO.setScale(1), 0);
    }
}
