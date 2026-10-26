package com.rentaherramientas.modules.reservas.domain.ports.in;

import com.rentaherramientas.modules.reservas.application.dto.CrearReservaCommand;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;

/** Puerto de entrada: un cliente solicita el alquiler de una o varias herramientas. */
public interface CrearReservaUseCase {

    /**
     * @param emailCliente correo del usuario autenticado (sale del token, no del cuerpo)
     * @param command      fechas, herramientas y notas
     * @return la reserva guardada en estado SOLICITADA
     */
    Reserva crearReserva(String emailCliente, CrearReservaCommand command);
}
