package com.rentaherramientas.modules.inventario.application.dto;

import com.rentaherramientas.modules.inventario.domain.model.Herramienta;

import java.math.BigDecimal;
import java.util.Comparator;

/** Ordenamientos disponibles en el catalogo paginado. */
public enum OrdenCatalogo {

    PRECIO_ASC(Comparator.comparing(Herramienta::getTarifaDiaria, Comparator.nullsLast(BigDecimal::compareTo))),
    PRECIO_DESC(Comparator.comparing(Herramienta::getTarifaDiaria, Comparator.nullsLast(BigDecimal::compareTo)).reversed()),
    NOMBRE_ASC(Comparator.comparing(h -> h.getNombre() == null ? "" : h.getNombre().toLowerCase())),
    NOMBRE_DESC(Comparator.<Herramienta, String>comparing(h -> h.getNombre() == null ? "" : h.getNombre().toLowerCase()).reversed()),
    RECIENTES(Comparator.comparing(Herramienta::getIdHerramienta, Comparator.nullsLast(Long::compareTo)).reversed());

    private final Comparator<Herramienta> comparador;

    OrdenCatalogo(Comparator<Herramienta> comparador) {
        this.comparador = comparador;
    }

    public Comparator<Herramienta> comparador() {
        return comparador;
    }
}
