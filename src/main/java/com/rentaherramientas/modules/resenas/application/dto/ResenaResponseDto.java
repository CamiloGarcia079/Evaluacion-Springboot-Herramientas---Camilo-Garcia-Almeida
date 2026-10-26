package com.rentaherramientas.modules.resenas.application.dto;

import java.time.LocalDateTime;

public record ResenaResponseDto(Long idResena,
                                Long idHerramienta,
                                String nombreHerramienta,
                                Long idReserva,
                                Long idCliente,
                                String nombreCliente,
                                Integer calificacion,
                                String comentario,
                                LocalDateTime fechaResena) {
}
