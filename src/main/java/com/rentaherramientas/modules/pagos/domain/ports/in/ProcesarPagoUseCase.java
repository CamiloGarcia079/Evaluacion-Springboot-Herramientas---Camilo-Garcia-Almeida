package com.rentaherramientas.modules.pagos.domain.ports.in;

import com.rentaherramientas.modules.pagos.application.dto.ProcesarPagoCommand;
import com.rentaherramientas.modules.pagos.domain.model.Pago;

public interface ProcesarPagoUseCase {

    /**
     * Pago hecho por un cliente desde la API: valida que la reserva sea suya,
     * que este aprobada y que el monto no exceda el saldo.
     */
    Pago procesarPago(String emailCliente, ProcesarPagoCommand command);

    /** Pasarela simulada + factura. Asume que el comando ya fue validado. */
    Pago procesarPago(ProcesarPagoCommand command);
}
