package com.rentaherramientas.modules.pagos.application.dto;

import com.rentaherramientas.modules.pagos.domain.model.TipoPago;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Pago de una reserva.
 *
 * El cliente sale del token. El monto es opcional: si no se envia, se cobra
 * el saldo pendiente (TOTALIDAD), la mitad del alquiler (ANTICIPO) o el
 * deposito de garantia (DEPOSITO_GARANTIA).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProcesarPagoCommand {

    @NotNull(message = "El ID de la reserva es obligatorio")
    @Schema(example = "21")
    private Long idReserva;

    /** Lo completa el servidor con el usuario autenticado; si se envia, se ignora. */
    @Schema(hidden = true)
    private Long idCliente;

    @NotNull(message = "El método de pago es obligatorio")
    @Schema(description = "Ver GET /pagos/metodos", example = "1")
    private Long idMetodoPago;

    @DecimalMin(value = "0.01", message = "El monto debe ser mayor a 0")
    @Schema(description = "Opcional. Si no se envia se calcula segun el tipo de pago", example = "150000")
    private BigDecimal monto;

    @NotNull(message = "El tipo de pago es obligatorio")
    @Schema(example = "TOTALIDAD")
    private TipoPago tipoPago;

    @Size(max = 200, message = "La descripción no puede superar 200 caracteres")
    private String descripcionServicio;
}
