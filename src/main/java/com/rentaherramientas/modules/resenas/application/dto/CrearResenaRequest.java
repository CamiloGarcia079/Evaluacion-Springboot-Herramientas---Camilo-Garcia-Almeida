package com.rentaherramientas.modules.resenas.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@Schema(description = "Calificación de una herramienta alquilada en una reserva FINALIZADA")
public record CrearResenaRequest(
        @NotNull(message = "El ID de la reserva es obligatorio")
        @Schema(example = "1") Long idReserva,

        @NotNull(message = "El ID de la herramienta es obligatorio")
        @Schema(example = "1") Long idHerramienta,

        @NotNull(message = "La calificación es obligatoria")
        @Min(value = 1, message = "La calificación mínima es 1")
        @Max(value = 5, message = "La calificación máxima es 5")
        @Schema(example = "5") Integer calificacion,

        @Size(max = 500, message = "El comentario no puede superar 500 caracteres")
        @Schema(example = "Equipo en excelente estado y muy buena atención del proveedor") String comentario) {
}
