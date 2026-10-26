package com.rentaherramientas.modules.mantenimientos.infrastructure.adapters.out.persistence.repository;

import com.rentaherramientas.modules.mantenimientos.domain.model.EstadoMantenimiento;
import com.rentaherramientas.modules.mantenimientos.infrastructure.adapters.out.persistence.entity.MantenimientoJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface SpringDataMantenimientoRepository extends JpaRepository<MantenimientoJpaEntity, Long> {

    List<MantenimientoJpaEntity> findByIdHerramientaOrderByFechaInicioDesc(Long idHerramienta);

    List<MantenimientoJpaEntity> findByIdHerramientaInOrderByFechaInicioDesc(Collection<Long> idsHerramientas);

    List<MantenimientoJpaEntity> findAllByOrderByFechaInicioDesc();

    boolean existsByIdHerramientaAndEstado(Long idHerramienta, EstadoMantenimiento estado);
}
