package com.rentaherramientas.modules.favoritos.infrastructure.adapters.out.persistence.repository;

import com.rentaherramientas.modules.favoritos.infrastructure.adapters.out.persistence.entity.FavoritoJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface SpringDataFavoritoRepository extends JpaRepository<FavoritoJpaEntity, Long> {

    Optional<FavoritoJpaEntity> findByIdUsuarioAndIdHerramienta(Long idUsuario, Long idHerramienta);

    List<FavoritoJpaEntity> findByIdUsuarioOrderByFechaAgregadoDesc(Long idUsuario);
}
