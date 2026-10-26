package com.rentaherramientas.modules.resenas.domain.ports.out;

import com.rentaherramientas.modules.resenas.domain.model.Resena;
import com.rentaherramientas.modules.resenas.domain.model.ResumenCalificacion;

import java.util.List;
import java.util.Optional;

public interface ResenaRepositoryPort {

    Resena guardar(Resena resena);

    Optional<Resena> buscarPorId(Long idResena);

    List<Resena> buscarPorHerramienta(Long idHerramienta);

    List<Resena> buscarPorCliente(Long idCliente);

    boolean existe(Long idReserva, Long idHerramienta);

    void eliminar(Long idResena);

    Optional<ResumenCalificacion> resumenDe(Long idHerramienta);

    List<ResumenCalificacion> resumenes();
}
