package com.rentaherramientas.modules.reservas.application.dto;

import com.rentaherramientas.modules.reservas.domain.model.EstadoDevolucion;
import com.rentaherramientas.modules.reservas.domain.model.EstadoReserva;

import java.time.LocalDate;

public record DevolucionResponseDto(
        Long idReserva,
        String codigoReserva,
        EstadoReserva estadoReserva,
        EstadoDevolucion estadoDevolucion,
        ReporteDanoDto reporteDano) {

    public record ReporteDanoDto(Long idReporteDano, String descripcion, Double costoReparacion, LocalDate fechaReporte) {}
}
