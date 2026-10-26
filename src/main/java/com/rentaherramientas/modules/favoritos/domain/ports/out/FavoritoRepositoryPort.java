package com.rentaherramientas.modules.favoritos.domain.ports.out;

import com.rentaherramientas.modules.favoritos.domain.model.Favorito;

import java.util.List;
import java.util.Optional;

public interface FavoritoRepositoryPort {

    Favorito guardar(Favorito favorito);

    Optional<Favorito> buscar(Long idUsuario, Long idHerramienta);

    List<Favorito> buscarPorUsuario(Long idUsuario);

    void eliminar(Long idFavorito);
}
