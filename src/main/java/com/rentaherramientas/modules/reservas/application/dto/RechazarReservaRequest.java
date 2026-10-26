package com.rentaherramientas.modules.reservas.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RechazarReservaRequest {

    @NotBlank(message = "El motivo de rechazo es obligatorio")
    @Size(max = 255, message = "El motivo no puede superar 255 caracteres")
    @Schema(example = "Equipo comprometido en otra obra esas fechas")
    private String motivo;
}
