package com.rentaherramientas.modules.reservas.domain.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Linea de una reserva: una herramienta, cuantas unidades y a que precio.
 *
 * El precio por dia se copia de la tarifa vigente de la herramienta al momento
 * de reservar. Asi un cambio de tarifa posterior no altera reservas ya hechas.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DetalleReserva {

    private Long idDetalleReserva;
    private Long idHerramienta;
    private String nombreHerramienta;
    private Integer cantidad;
    private BigDecimal precioUnitarioDia;
    private Integer diasAlquiler;
    private BigDecimal subtotal;

    /** Solo para mostrar: no se guarda en detalles_reserva. */
    private String imagenHerramienta;

    public void calcularSubtotal() {
        if (precioUnitarioDia != null && cantidad != null && diasAlquiler != null) {
            this.subtotal = precioUnitarioDia
                    .multiply(BigDecimal.valueOf(cantidad))
                    .multiply(BigDecimal.valueOf(diasAlquiler));
        }
    }

    /** Completa los datos de despliegue que viven en el modulo de Inventario. */
    public void mostrarComo(String nombreHerramienta, String imagenHerramienta) {
        this.nombreHerramienta = nombreHerramienta;
        this.imagenHerramienta = imagenHerramienta;
    }
}
