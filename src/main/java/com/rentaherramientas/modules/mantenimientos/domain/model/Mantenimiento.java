package com.rentaherramientas.modules.mantenimientos.domain.model;

import com.rentaherramientas.common.exception.BusinessRuleException;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDateTime;

/**
 * Orden de mantenimiento de una herramienta.
 *
 * Mientras esta EN_PROCESO la herramienta queda EN_MANTENIMIENTO y no se puede
 * despachar. Al finalizar se registra el costo y la herramienta vuelve a
 * DISPONIBLE (o se da de baja si no tuvo arreglo).
 */
@Getter
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class Mantenimiento {

    private Long idMantenimiento;
    private Long idHerramienta;
    private TipoMantenimiento tipo;
    private String descripcion;
    private LocalDateTime fechaInicio;
    private LocalDateTime fechaFin;
    private BigDecimal costo;
    private EstadoMantenimiento estado;
    private Long registradoPor;
    private String observacionesCierre;

    /** Solo para mostrar. */
    private String nombreHerramienta;

    public static Mantenimiento abrir(Long idHerramienta, TipoMantenimiento tipo, String descripcion, Long registradoPor) {
        if (tipo == null) {
            throw new BusinessRuleException("El tipo de mantenimiento es obligatorio");
        }
        if (descripcion == null || descripcion.isBlank()) {
            throw new BusinessRuleException("Debe describir el trabajo a realizar");
        }
        return Mantenimiento.builder()
                .idHerramienta(idHerramienta)
                .tipo(tipo)
                .descripcion(descripcion.trim())
                .fechaInicio(LocalDateTime.now())
                .estado(EstadoMantenimiento.EN_PROCESO)
                .registradoPor(registradoPor)
                .build();
    }

    public void finalizar(BigDecimal costo, String observaciones) {
        if (this.estado != EstadoMantenimiento.EN_PROCESO) {
            throw new BusinessRuleException("El mantenimiento ya fue finalizado");
        }
        if (costo != null && costo.compareTo(BigDecimal.ZERO) < 0) {
            throw new BusinessRuleException("El costo no puede ser negativo");
        }
        this.costo = costo == null ? BigDecimal.ZERO.setScale(2) : costo.setScale(2, RoundingMode.HALF_UP);
        this.observacionesCierre = (observaciones == null || observaciones.isBlank()) ? null : observaciones.trim();
        this.fechaFin = LocalDateTime.now();
        this.estado = EstadoMantenimiento.FINALIZADO;
    }

    public boolean estaAbierto() {
        return this.estado == EstadoMantenimiento.EN_PROCESO;
    }

    /** Horas que la herramienta estuvo (o lleva) fuera del catalogo. */
    public long horasFueraDeServicio() {
        LocalDateTime hasta = fechaFin != null ? fechaFin : LocalDateTime.now();
        return fechaInicio == null ? 0 : Duration.between(fechaInicio, hasta).toHours();
    }

    public void mostrarComo(String nombreHerramienta) {
        this.nombreHerramienta = nombreHerramienta;
    }
}
