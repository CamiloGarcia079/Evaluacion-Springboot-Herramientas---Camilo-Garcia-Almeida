package com.rentaherramientas.modules.devoluciones.domain.ports.in;

import com.rentaherramientas.modules.devoluciones.application.dto.RegistrarDevolucionCommand;
import com.rentaherramientas.modules.devoluciones.domain.model.Devolucion;

public interface RegistrarDevolucionUseCase {

    /**
     * Check-in hecho desde la API: quien recibe sale del token y debe ser
     * administrador o el proveedor de alguna herramienta de la reserva.
     */
    Devolucion registrarDevolucion(String emailReceptor, RegistrarDevolucionCommand command);

    /** Registro con el receptor ya resuelto en el comando. */
    Devolucion registrarDevolucion(RegistrarDevolucionCommand command);
}
