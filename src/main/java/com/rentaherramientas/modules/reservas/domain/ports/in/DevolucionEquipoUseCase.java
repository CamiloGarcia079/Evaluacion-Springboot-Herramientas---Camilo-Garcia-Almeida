package com.rentaherramientas.modules.reservas.domain.ports.in;

import com.rentaherramientas.modules.reservas.domain.model.ReporteDano;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;

/** Puerto de entrada: el proveedor registra la devolucion del equipo. */
public interface DevolucionEquipoUseCase {

    /** Resultado: la reserva actualizada y el reporte de danos (null si se devolvio sin danos). */
    record ResultadoDevolucion(Reserva reserva, ReporteDano reporteDano) {}

    ResultadoDevolucion registrarDevolucion(String emailSolicitante, Long idReserva, String estado,
                                            String descripcionDano, Double costoReparacion);
}
