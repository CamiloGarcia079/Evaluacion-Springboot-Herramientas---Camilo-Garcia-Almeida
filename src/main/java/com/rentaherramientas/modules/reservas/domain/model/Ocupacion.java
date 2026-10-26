package com.rentaherramientas.modules.reservas.domain.model;

import java.time.LocalDate;

/**
 * Tramo de fechas en que una herramienta ya esta comprometida.
 * Es publico: no expone quien la reservo, solo cuando esta ocupada.
 */
public record Ocupacion(LocalDate desde, LocalDate hasta, EstadoReserva estado) {
}
