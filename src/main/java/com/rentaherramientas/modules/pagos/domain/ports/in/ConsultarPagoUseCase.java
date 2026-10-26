package com.rentaherramientas.modules.pagos.domain.ports.in;

import com.rentaherramientas.modules.pagos.domain.model.Pago;

import java.util.List;

public interface ConsultarPagoUseCase {
    Pago obtenerPagoPorId(Long id);
    Pago obtenerPagoPorTransaccion(String transaccion);
    List<Pago> listarPagosPorReserva(Long idReserva);
    List<Pago> listarTodosLosPagos();

    /** Pagos de todas las reservas del usuario autenticado. */
    List<Pago> listarMisPagos(String emailCliente);

    /** Pagos de una reserva, si el solicitante tiene permiso para verla. */
    List<Pago> listarPagosDeReserva(String emailSolicitante, Long idReserva);

    Pago obtenerPago(String emailSolicitante, Long idPago);
}
