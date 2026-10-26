package com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

/** Tabla reporte_dano: un reporte de danos por reserva (relacion OneToOne). */
@Entity
@Table(name = "reporte_dano")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReporteDanoReservaJpaEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_reporte_dano")
    private Long idReporteDano;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_reserva", nullable = false, unique = true)
    private ReservaJpaEntity reserva;

    @Column(name = "descripcion", nullable = false, length = 500)
    private String descripcion;

    @Column(name = "costo_reparacion", nullable = false)
    private Double costoReparacion;

    @Column(name = "fecha_reporte", nullable = false)
    private LocalDate fechaReporte;
}
