package com.rentaherramientas.modules.mantenimientos.infrastructure.adapters.out.persistence.entity;

import com.rentaherramientas.modules.mantenimientos.domain.model.EstadoMantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.model.TipoMantenimiento;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "mantenimientos_herramienta")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MantenimientoJpaEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_mantenimiento")
    private Long idMantenimiento;

    @Column(name = "id_herramienta", nullable = false)
    private Long idHerramienta;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", nullable = false, length = 20)
    private TipoMantenimiento tipo;

    @Column(name = "descripcion", nullable = false, length = 500)
    private String descripcion;

    @Column(name = "fecha_inicio", nullable = false)
    private LocalDateTime fechaInicio;

    @Column(name = "fecha_fin")
    private LocalDateTime fechaFin;

    @Column(name = "costo", precision = 12, scale = 2)
    private BigDecimal costo;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado", nullable = false, length = 20)
    private EstadoMantenimiento estado;

    @Column(name = "registrado_por", nullable = false)
    private Long registradoPor;

    @Column(name = "observaciones_cierre", length = 500)
    private String observacionesCierre;
}
