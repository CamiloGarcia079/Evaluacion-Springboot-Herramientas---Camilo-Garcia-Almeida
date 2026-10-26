package com.rentaherramientas.modules.reservas.domain.model;

import com.rentaherramientas.common.exception.BusinessRuleException;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

/**
 * Entidad de dominio: Reserva.
 *
 * Es el contrato de alquiler entre un cliente y la plataforma. Concentra las
 * reglas del ciclo de vida:
 *
 *   SOLICITADA -> APROBADA -> EN_CURSO -> FINALIZADA
 *        |            |
 *        +-> RECHAZADA +-> CANCELADA
 *
 * Cualquier otra transicion lanza BusinessRuleException.
 */
@Getter
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class Reserva {

    /** Porcentaje del valor del alquiler que se cobra como deposito de garantia. */
    public static final BigDecimal PORCENTAJE_DEPOSITO = new BigDecimal("0.30");

    private Long idReserva;
    private String codigoReserva;
    private Long idCliente;
    private LocalDateTime fechaSolicitud;
    private RangoFechas rangoFechas;
    private EstadoReserva estado;
    @Builder.Default
    private EstadoDevolucion estadoDevolucion = EstadoDevolucion.PENDIENTE_DEVOLUCION;
    @Builder.Default
    private List<DetalleReserva> detalles = new ArrayList<>();
    private BigDecimal montoTotalEstimado;
    private BigDecimal depositoGarantia;
    private String notasCliente;
    private String motivoRechazo;

    /** Solo para mostrar: no se guarda en la tabla reservas. */
    private String nombreCliente;

    public boolean estaActiva() {
        return this.estado == EstadoReserva.SOLICITADA
                || this.estado == EstadoReserva.APROBADA
                || this.estado == EstadoReserva.EN_CURSO;
    }

    public boolean requiereDeposito() {
        return this.depositoGarantia != null && this.depositoGarantia.compareTo(BigDecimal.ZERO) > 0;
    }

    public boolean perteneceAlCliente(Long idClienteConsultado) {
        return idClienteConsultado != null && idClienteConsultado.equals(this.idCliente);
    }

    /** True si alguna de las herramientas de la reserva esta en la coleccion recibida. */
    public boolean incluyeAlgunaHerramienta(Collection<Long> idsHerramientas) {
        return detalles != null && detalles.stream().anyMatch(d -> idsHerramientas.contains(d.getIdHerramienta()));
    }

    public List<Long> idsHerramientas() {
        return detalles == null ? List.of() : detalles.stream().map(DetalleReserva::getIdHerramienta).toList();
    }

    public void agregarDetalle(DetalleReserva detalle) {
        if (this.detalles == null) {
            this.detalles = new ArrayList<>();
        }
        this.detalles.add(detalle);
        calcularTotales();
    }

    /** Suma los subtotales y calcula el deposito redondeado a dos decimales. */
    public void calcularTotales() {
        BigDecimal total = BigDecimal.ZERO;
        if (detalles != null) {
            for (DetalleReserva det : detalles) {
                det.calcularSubtotal();
                if (det.getSubtotal() != null) {
                    total = total.add(det.getSubtotal());
                }
            }
        }
        this.montoTotalEstimado = total.setScale(2, RoundingMode.HALF_UP);
        this.depositoGarantia = total.multiply(PORCENTAJE_DEPOSITO).setScale(2, RoundingMode.HALF_UP);
    }

    public void aprobar() {
        if (this.estado != EstadoReserva.SOLICITADA) {
            throw new BusinessRuleException("Solo se pueden aprobar reservas en estado SOLICITADA");
        }
        this.estado = EstadoReserva.APROBADA;
    }

    public void rechazar(String motivo) {
        if (this.estado != EstadoReserva.SOLICITADA) {
            throw new BusinessRuleException("Solo se pueden rechazar reservas en estado SOLICITADA");
        }
        if (motivo == null || motivo.trim().isEmpty()) {
            throw new BusinessRuleException("Debe especificarse el motivo del rechazo de la reserva");
        }
        this.motivoRechazo = motivo.trim();
        this.estado = EstadoReserva.RECHAZADA;
    }

    public void iniciarAlquiler() {
        if (this.estado != EstadoReserva.APROBADA) {
            throw new BusinessRuleException("Solo se puede iniciar el alquiler de una reserva APROBADA");
        }
        this.estado = EstadoReserva.EN_CURSO;
    }

    public void finalizarAlquiler() {
        if (this.estado != EstadoReserva.EN_CURSO) {
            throw new BusinessRuleException("Solo se puede finalizar una reserva EN_CURSO");
        }
        this.estado = EstadoReserva.FINALIZADA;
    }

    /**
     * Registra la devolucion del equipo. Solo aplica a un alquiler EN_CURSO cuya
     * devolucion siga pendiente; al registrarla el alquiler queda FINALIZADA.
     */
    public void registrarDevolucion(boolean conDanos) {
        if (this.estado != EstadoReserva.EN_CURSO) {
            throw new BusinessRuleException("Solo se puede registrar la devolución de una reserva EN_CURSO (estado actual: " + this.estado + ")");
        }
        if (this.estadoDevolucion != null && this.estadoDevolucion != EstadoDevolucion.PENDIENTE_DEVOLUCION) {
            throw new BusinessRuleException("La devolución de esta reserva ya fue registrada");
        }
        this.estadoDevolucion = conDanos ? EstadoDevolucion.DEVUELTO_CON_DANOS : EstadoDevolucion.DEVUELTO_OK;
        this.estado = EstadoReserva.FINALIZADA;
    }

    public void cancelar() {
        if (this.estado != EstadoReserva.SOLICITADA && this.estado != EstadoReserva.APROBADA) {
            throw new BusinessRuleException(
                    "Solo se puede cancelar una reserva SOLICITADA o APROBADA (estado actual: " + this.estado + ")");
        }
        this.estado = EstadoReserva.CANCELADA;
    }

    /** Completa el nombre del cliente para mostrarlo; no afecta la persistencia. */
    public void mostrarComo(String nombreCliente) {
        this.nombreCliente = nombreCliente;
    }
}
