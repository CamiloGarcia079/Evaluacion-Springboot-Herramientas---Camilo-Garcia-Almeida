package com.rentaherramientas.modules.resenas.infrastructure.adapters.out.persistence.repository;

import com.rentaherramientas.modules.resenas.infrastructure.adapters.out.persistence.entity.ResenaJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SpringDataResenaRepository extends JpaRepository<ResenaJpaEntity, Long> {

    List<ResenaJpaEntity> findByIdHerramientaOrderByFechaResenaDesc(Long idHerramienta);

    List<ResenaJpaEntity> findByIdClienteOrderByFechaResenaDesc(Long idCliente);

    boolean existsByIdReservaAndIdHerramienta(Long idReserva, Long idHerramienta);

    /** Cada fila: [idHerramienta, promedio, cantidad]. */
    @Query("SELECT r.idHerramienta, AVG(r.calificacion), COUNT(r) FROM ResenaJpaEntity r GROUP BY r.idHerramienta")
    List<Object[]> resumenPorHerramienta();

    @Query("SELECT r.idHerramienta, AVG(r.calificacion), COUNT(r) FROM ResenaJpaEntity r "
            + "WHERE r.idHerramienta = :idHerramienta GROUP BY r.idHerramienta")
    List<Object[]> resumenDeHerramienta(@Param("idHerramienta") Long idHerramienta);
}
