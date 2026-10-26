package com.rentaherramientas.modules.reservas.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/** Reporte de danos que el proveedor registra al recibir el equipo devuelto. */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReporteDano {
    private Long idReporteDano;
    private Long idReserva;
    private String descripcion;
    private Double costoReparacion;
    private LocalDate fechaReporte;
}
