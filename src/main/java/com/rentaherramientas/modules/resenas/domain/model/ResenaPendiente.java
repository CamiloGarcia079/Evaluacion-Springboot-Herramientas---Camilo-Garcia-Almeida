package com.rentaherramientas.modules.resenas.domain.model;

import java.time.LocalDate;

/** Herramienta de un alquiler finalizado que el cliente todavia no ha calificado. */
public record ResenaPendiente(Long idReserva,
                              String codigoReserva,
                              Long idHerramienta,
                              String nombreHerramienta,
                              String imagenHerramienta,
                              LocalDate fechaFin) {
}
