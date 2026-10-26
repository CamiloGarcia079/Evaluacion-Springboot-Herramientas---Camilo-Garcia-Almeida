package com.rentaherramientas.modules.resenas.domain.ports.in;

import com.rentaherramientas.modules.resenas.domain.model.Resena;
import com.rentaherramientas.modules.resenas.domain.model.ResenaPendiente;
import com.rentaherramientas.modules.resenas.domain.model.ResumenCalificacion;

import java.util.List;

public interface GestionarResenaUseCase {

    Resena publicar(String emailCliente, Long idReserva, Long idHerramienta, Integer calificacion, String comentario);

    Resena editar(String emailCliente, Long idResena, Integer calificacion, String comentario);

    void eliminar(String emailSolicitante, Long idResena);

    List<Resena> listarPorHerramienta(Long idHerramienta);

    ResumenCalificacion resumenDeHerramienta(Long idHerramienta);

    /** Promedio de todas las herramientas que tienen al menos una resena. */
    List<ResumenCalificacion> resumenGeneral();

    List<Resena> misResenas(String emailCliente);

    List<ResenaPendiente> pendientesPorCalificar(String emailCliente);
}
