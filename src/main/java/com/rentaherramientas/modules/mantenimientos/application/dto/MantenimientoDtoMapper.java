package com.rentaherramientas.modules.mantenimientos.application.dto;

import com.rentaherramientas.modules.mantenimientos.domain.model.Mantenimiento;

public final class MantenimientoDtoMapper {

    private MantenimientoDtoMapper() {
    }

    public static MantenimientoResponseDto toDto(Mantenimiento m) {
        return new MantenimientoResponseDto(m.getIdMantenimiento(), m.getIdHerramienta(), m.getNombreHerramienta(),
                m.getTipo() == null ? null : m.getTipo().name(), m.getDescripcion(), m.getFechaInicio(), m.getFechaFin(),
                m.getCosto(), m.getEstado() == null ? null : m.getEstado().name(), m.getRegistradoPor(),
                m.getObservacionesCierre(), m.horasFueraDeServicio());
    }
}
