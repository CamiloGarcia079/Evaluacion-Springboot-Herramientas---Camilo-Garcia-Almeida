package com.rentaherramientas.modules.reservas.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Una herramienta dentro de la solicitud. El precio lo pone el servidor. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DetalleReservaItemCommand {

    @NotNull(message = "El ID de la herramienta es obligatorio")
    @Schema(example = "1")
    private Long idHerramienta;

    @Min(value = 1, message = "La cantidad mínima es 1")
    @Max(value = 10, message = "La cantidad máxima por herramienta es 10")
    @Schema(description = "Unidades; si no se envia se asume 1", example = "1")
    private Integer cantidad;
}
