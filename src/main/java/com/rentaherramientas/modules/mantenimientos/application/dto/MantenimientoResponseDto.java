package com.rentaherramientas.modules.mantenimientos.application.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record MantenimientoResponseDto(Long idMantenimiento,
                                       Long idHerramienta,
                                       String nombreHerramienta,
                                       String tipo,
                                       String descripcion,
                                       LocalDateTime fechaInicio,
                                       LocalDateTime fechaFin,
                                       BigDecimal costo,
                                       String estado,
                                       Long registradoPor,
                                       String observacionesCierre,
                                       long horasFueraDeServicio) {
}
