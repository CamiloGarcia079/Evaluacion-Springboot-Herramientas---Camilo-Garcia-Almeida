package com.rentaherramientas.common.kernel;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Puerto del kernel compartido para leer reservas desde otros modulos
 * (pagos, resenas). Lo implementa el modulo de Reservas.
 */
public interface ReservaConsultaPort {

    record InfoReserva(Long idReserva,
                       String codigoReserva,
                       Long idCliente,
                       String estado,
                       LocalDate fechaInicio,
                       LocalDate fechaFin,
                       BigDecimal montoTotal,
                       BigDecimal depositoGarantia,
                       List<Long> idsHerramientas) {

        /** Estados en los que el cliente ya puede pagar. */
        public boolean admitePagos() {
            return "APROBADA".equals(estado) || "EN_CURSO".equals(estado) || "FINALIZADA".equals(estado);
        }
    }

    Optional<InfoReserva> buscarPorId(Long idReserva);

    List<Long> idsDeReservasDelCliente(Long idCliente);

    /** True si el cliente tiene una reserva FINALIZADA que incluye esa herramienta. */
    boolean clienteAlquiloHerramienta(Long idCliente, Long idHerramienta);
}
