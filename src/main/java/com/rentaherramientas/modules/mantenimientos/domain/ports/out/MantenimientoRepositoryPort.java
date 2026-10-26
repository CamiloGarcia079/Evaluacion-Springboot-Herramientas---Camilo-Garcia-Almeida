package com.rentaherramientas.modules.mantenimientos.domain.ports.out;

import com.rentaherramientas.modules.mantenimientos.domain.model.Mantenimiento;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface MantenimientoRepositoryPort {

    Mantenimiento guardar(Mantenimiento mantenimiento);

    Optional<Mantenimiento> buscarPorId(Long idMantenimiento);

    List<Mantenimiento> buscarPorHerramienta(Long idHerramienta);

    List<Mantenimiento> buscarPorHerramientas(Collection<Long> idsHerramientas);

    List<Mantenimiento> buscarTodos();

    boolean existeAbierto(Long idHerramienta);
}
