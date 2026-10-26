package com.rentaherramientas.modules.favoritos.infrastructure.adapters.out.persistence;

import com.rentaherramientas.modules.favoritos.domain.model.Favorito;
import com.rentaherramientas.modules.favoritos.domain.ports.out.FavoritoRepositoryPort;
import com.rentaherramientas.modules.favoritos.infrastructure.adapters.out.persistence.entity.FavoritoJpaEntity;
import com.rentaherramientas.modules.favoritos.infrastructure.adapters.out.persistence.repository.SpringDataFavoritoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class FavoritoPersistenceAdapter implements FavoritoRepositoryPort {

    private final SpringDataFavoritoRepository repository;

    @Override
    public Favorito guardar(Favorito f) {
        FavoritoJpaEntity e = FavoritoJpaEntity.builder()
                .idFavorito(f.idFavorito())
                .idUsuario(f.idUsuario())
                .idHerramienta(f.idHerramienta())
                .fechaAgregado(f.fechaAgregado())
                .build();
        return toDomain(repository.save(e));
    }

    @Override
    public Optional<Favorito> buscar(Long idUsuario, Long idHerramienta) {
        return repository.findByIdUsuarioAndIdHerramienta(idUsuario, idHerramienta).map(this::toDomain);
    }

    @Override
    public List<Favorito> buscarPorUsuario(Long idUsuario) {
        return repository.findByIdUsuarioOrderByFechaAgregadoDesc(idUsuario).stream().map(this::toDomain).toList();
    }

    @Override
    public void eliminar(Long idFavorito) {
        repository.deleteById(idFavorito);
    }

    private Favorito toDomain(FavoritoJpaEntity e) {
        return new Favorito(e.getIdFavorito(), e.getIdUsuario(), e.getIdHerramienta(), e.getFechaAgregado());
    }
}
