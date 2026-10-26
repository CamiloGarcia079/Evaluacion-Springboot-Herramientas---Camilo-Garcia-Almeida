package com.rentaherramientas.modules.favoritos.domain.model;

import java.time.LocalDateTime;

/** Herramienta que un usuario guardo para alquilar despues. */
public record Favorito(Long idFavorito, Long idUsuario, Long idHerramienta, LocalDateTime fechaAgregado) {

    public static Favorito nuevo(Long idUsuario, Long idHerramienta) {
        return new Favorito(null, idUsuario, idHerramienta, LocalDateTime.now());
    }
}
