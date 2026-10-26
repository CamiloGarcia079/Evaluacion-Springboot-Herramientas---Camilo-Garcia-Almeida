package com.rentaherramientas.modules.reservas.domain.ports.in;

import com.rentaherramientas.modules.reservas.domain.model.Reserva;

/**
 * Puerto de entrada: transiciones del ciclo de vida.
 * Todas reciben el correo de quien la ejecuta para validar permisos y dejar auditoria.
 */
public interface CambiarEstadoReservaUseCase {
    Reserva aprobarReserva(String emailSolicitante, Long idReserva);
    Reserva rechazarReserva(String emailSolicitante, Long idReserva, String motivo);
    Reserva iniciarAlquiler(String emailSolicitante, Long idReserva);
    Reserva finalizarAlquiler(String emailSolicitante, Long idReserva);
    Reserva cancelarReserva(String emailSolicitante, Long idReserva);
}
