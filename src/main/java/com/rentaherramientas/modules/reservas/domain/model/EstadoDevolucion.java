package com.rentaherramientas.modules.reservas.domain.model;

/** Estado de la devolucion del equipo. Toda reserva nace en PENDIENTE_DEVOLUCION. */
public enum EstadoDevolucion {
    PENDIENTE_DEVOLUCION,
    DEVUELTO_OK,
    DEVUELTO_CON_DANOS
}
