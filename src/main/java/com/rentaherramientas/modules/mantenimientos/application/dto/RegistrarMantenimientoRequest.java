package com.rentaherramientas.modules.mantenimientos.application.dto;

import com.rentaherramientas.modules.mantenimientos.domain.model.TipoMantenimiento;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record RegistrarMantenimientoRequest(
        @NotNull(message = "El ID de la herramienta es obligatorio")
        @Schema(example = "1") Long idHerramienta,

        @NotNull(message = "El tipo es obligatorio (PREVENTIVO, CORRECTIVO o REVISION)")
        @Schema(example = "PREVENTIVO") TipoMantenimiento tipo,

        @NotBlank(message = "La descripción es obligatoria")
        @Size(max = 500, message = "La descripción no puede superar 500 caracteres")
        @Schema(example = "Cambio de carbones y limpieza general del motor") String descripcion) {
}
