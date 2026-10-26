package com.rentaherramientas.modules.favoritos.domain.ports.in;

import com.rentaherramientas.modules.favoritos.domain.model.HerramientaFavorita;

import java.util.List;

public interface GestionarFavoritosUseCase {

    /** Agrega la herramienta. Si ya estaba, no hace nada (operacion idempotente). */
    HerramientaFavorita agregar(String email, Long idHerramienta);

    void quitar(String email, Long idHerramienta);

    List<HerramientaFavorita> listar(String email);

    List<Long> idsFavoritos(String email);
}
