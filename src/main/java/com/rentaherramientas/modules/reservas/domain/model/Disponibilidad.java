package com.rentaherramientas.modules.reservas.domain.model;

import java.time.LocalDate;
import java.util.List;

/**
 * Resultado de consultar si una herramienta esta libre en un rango de fechas.
 *
 * @param disponible   true si ninguna reserva APROBADA o EN_CURSO choca con el rango
 * @param ocupaciones  todos los tramos comprometidos que se cruzan con el rango,
 *                     incluidas las solicitudes pendientes (que aun no bloquean)
 */
public record Disponibilidad(Long idHerramienta,
                             LocalDate desde,
                             LocalDate hasta,
                             boolean disponible,
                             List<Ocupacion> ocupaciones) {
}
