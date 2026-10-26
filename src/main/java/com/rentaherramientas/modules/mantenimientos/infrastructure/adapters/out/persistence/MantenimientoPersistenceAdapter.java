package com.rentaherramientas.modules.mantenimientos.infrastructure.adapters.out.persistence;

import com.rentaherramientas.modules.mantenimientos.domain.model.EstadoMantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.model.Mantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.ports.out.MantenimientoRepositoryPort;
import com.rentaherramientas.modules.mantenimientos.infrastructure.adapters.out.persistence.entity.MantenimientoJpaEntity;
import com.rentaherramientas.modules.mantenimientos.infrastructure.adapters.out.persistence.repository.SpringDataMantenimientoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class MantenimientoPersistenceAdapter implements MantenimientoRepositoryPort {

    private final SpringDataMantenimientoRepository repository;

    @Override
    public Mantenimiento guardar(Mantenimiento m) {
        return toDomain(repository.save(toEntity(m)));
    }

    @Override
    public Optional<Mantenimiento> buscarPorId(Long idMantenimiento) {
        return repository.findById(idMantenimiento).map(this::toDomain);
    }

    @Override
    public List<Mantenimiento> buscarPorHerramienta(Long idHerramienta) {
        return repository.findByIdHerramientaOrderByFechaInicioDesc(idHerramienta).stream().map(this::toDomain).toList();
    }

    @Override
    public List<Mantenimiento> buscarPorHerramientas(Collection<Long> idsHerramientas) {
        if (idsHerramientas == null || idsHerramientas.isEmpty()) {
            return List.of();
        }
        return repository.findByIdHerramientaInOrderByFechaInicioDesc(idsHerramientas).stream().map(this::toDomain).toList();
    }

    @Override
    public List<Mantenimiento> buscarTodos() {
        return repository.findAllByOrderByFechaInicioDesc().stream().map(this::toDomain).toList();
    }

    @Override
    public boolean existeAbierto(Long idHerramienta) {
        return repository.existsByIdHerramientaAndEstado(idHerramienta, EstadoMantenimiento.EN_PROCESO);
    }

    private MantenimientoJpaEntity toEntity(Mantenimiento m) {
        return MantenimientoJpaEntity.builder()
                .idMantenimiento(m.getIdMantenimiento())
                .idHerramienta(m.getIdHerramienta())
                .tipo(m.getTipo())
                .descripcion(m.getDescripcion())
                .fechaInicio(m.getFechaInicio())
                .fechaFin(m.getFechaFin())
                .costo(m.getCosto())
                .estado(m.getEstado())
                .registradoPor(m.getRegistradoPor())
                .observacionesCierre(m.getObservacionesCierre())
                .build();
    }

    private Mantenimiento toDomain(MantenimientoJpaEntity e) {
        return Mantenimiento.builder()
                .idMantenimiento(e.getIdMantenimiento())
                .idHerramienta(e.getIdHerramienta())
                .tipo(e.getTipo())
                .descripcion(e.getDescripcion())
                .fechaInicio(e.getFechaInicio())
                .fechaFin(e.getFechaFin())
                .costo(e.getCosto())
                .estado(e.getEstado())
                .registradoPor(e.getRegistradoPor())
                .observacionesCierre(e.getObservacionesCierre())
                .build();
    }
}
