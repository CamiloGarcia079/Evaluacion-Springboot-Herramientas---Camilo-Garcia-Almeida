package com.rentaherramientas.modules.resenas.application.dto;

import com.rentaherramientas.modules.resenas.domain.model.Resena;

public final class ResenaDtoMapper {

    private ResenaDtoMapper() {
    }

    public static ResenaResponseDto toDto(Resena r) {
        return new ResenaResponseDto(r.getIdResena(), r.getIdHerramienta(), r.getNombreHerramienta(), r.getIdReserva(), r.getIdCliente(),
                r.getNombreCliente(), r.getCalificacion(), r.getComentario(), r.getFechaResena());
    }
}
