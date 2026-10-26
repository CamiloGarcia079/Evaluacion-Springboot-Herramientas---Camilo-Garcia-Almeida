package com.rentaherramientas.modules.reservas.application.dto;

import java.time.LocalDate;
import java.util.List;

/** Respuesta publica de disponibilidad: no revela quien tiene reservada la herramienta. */
public record DisponibilidadResponseDto(Long idHerramienta,
                                        LocalDate desde,
                                        LocalDate hasta,
                                        boolean disponible,
                                        String mensaje,
                                        List<OcupacionDto> ocupaciones) {

    public record OcupacionDto(LocalDate desde, LocalDate hasta, String estado) {
    }
}
