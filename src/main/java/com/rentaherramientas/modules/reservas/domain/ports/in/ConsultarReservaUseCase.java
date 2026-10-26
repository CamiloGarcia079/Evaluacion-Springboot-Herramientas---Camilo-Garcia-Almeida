package com.rentaherramientas.modules.reservas.domain.ports.in;

import com.rentaherramientas.modules.reservas.domain.model.Disponibilidad;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;

import java.time.LocalDate;
import java.util.List;

/** Puerto de entrada: consultas sobre reservas. */
public interface ConsultarReservaUseCase {

    /** Detalle de una reserva. Solo la ven su cliente, el proveedor involucrado o un administrador. */
    Reserva obtener(String emailSolicitante, Long idReserva);

    /** Reservas del cliente autenticado, de la mas reciente a la mas antigua. */
    List<Reserva> listarMisReservas(String emailCliente);

    /** Administrador: todas. Proveedor: las que incluyen alguna de sus herramientas. */
    List<Reserva> listarParaGestion(String emailSolicitante);

    /** Consulta publica: si la herramienta esta libre entre esas fechas y que tramos estan ocupados. */
    Disponibilidad consultarDisponibilidad(Long idHerramienta, LocalDate desde, LocalDate hasta);
}
