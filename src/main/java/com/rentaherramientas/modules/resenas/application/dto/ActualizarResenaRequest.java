package com.rentaherramientas.modules.resenas.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ActualizarResenaRequest(
        @NotNull(message = "La calificación es obligatoria")
        @Min(value = 1, message = "La calificación mínima es 1")
        @Max(value = 5, message = "La calificación máxima es 5")
        @Schema(example = "4") Integer calificacion,

        @Size(max = 500, message = "El comentario no puede superar 500 caracteres")
        @Schema(example = "Buen equipo, aunque la batería dura poco") String comentario) {
}
