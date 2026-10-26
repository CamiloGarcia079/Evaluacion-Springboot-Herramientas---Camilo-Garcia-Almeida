package com.rentaherramientas.modules.mantenimientos.domain.model;

public enum TipoMantenimiento {
    /** Programado: cambio de aceite, filtros, calibracion. */
    PREVENTIVO,
    /** Reparacion de una falla o de un dano reportado en una devolucion. */
    CORRECTIVO,
    /** Inspeccion general antes de volver a alquilar. */
    REVISION
}
