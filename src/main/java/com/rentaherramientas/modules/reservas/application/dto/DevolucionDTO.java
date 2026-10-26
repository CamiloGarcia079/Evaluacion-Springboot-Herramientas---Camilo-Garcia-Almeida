package com.rentaherramientas.modules.reservas.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Formulario de devolucion que llena el proveedor. */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class DevolucionDTO {

    @NotBlank(message = "El estado es obligatorio: OK o DANOS")
    @Schema(description = "OK si el equipo volvio bien; DANOS (o DAÑOS) si volvio danado", example = "DANOS")
    private String estado;

    @Schema(description = "Descripcion del dano. Obligatoria cuando el estado es DANOS", example = "Broca partida y carcasa rota")
    private String descripcionDano;

    @PositiveOrZero(message = "El costo de reparacion no puede ser negativo")
    @Schema(description = "Costo estimado de reparacion (opcional)", example = "150000")
    private Double costoReparacion;
}
