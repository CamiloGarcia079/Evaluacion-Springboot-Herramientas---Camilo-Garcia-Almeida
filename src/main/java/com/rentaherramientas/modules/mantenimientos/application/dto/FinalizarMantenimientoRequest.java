package com.rentaherramientas.modules.mantenimientos.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record FinalizarMantenimientoRequest(
        @DecimalMin(value = "0.00", message = "El costo no puede ser negativo")
        @Schema(example = "85000") BigDecimal costo,

        @Size(max = 500, message = "Las observaciones no pueden superar 500 caracteres")
        @Schema(example = "Se reemplazaron carbones. Equipo probado y funcionando") String observaciones,

        @Schema(description = "true si el equipo no tuvo arreglo y se da de baja", example = "false") Boolean darDeBaja) {
}
