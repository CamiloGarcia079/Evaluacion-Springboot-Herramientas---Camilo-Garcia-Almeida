package com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.repository;

import com.rentaherramientas.modules.reservas.domain.model.EstadoReserva;
import com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.entity.ReservaJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface SpringDataReservaRepository extends JpaRepository<ReservaJpaEntity, Long> {

    Optional<ReservaJpaEntity> findByCodigoReserva(String codigoReserva);

    List<ReservaJpaEntity> findByIdClienteOrderByFechaSolicitudDesc(Long idCliente);

    /**
     * Dos rangos [a, b] y [c, d] se cruzan cuando a <= d y c <= b.
     * Solo cuentan las reservas APROBADAS o EN_CURSO; una solicitud pendiente
     * todavia no bloquea la herramienta.
     *
     * idExcluida permite ignorar la propia reserva al re-verificar en la
     * aprobacion. Cuando no hay nada que excluir se envia -1.
     */
    @Query("SELECT COUNT(d) > 0 FROM DetalleReservaJpaEntity d " +
           "JOIN d.reserva r " +
           "WHERE d.idHerramienta = :idHerramienta " +
           "AND r.estado IN (com.rentaherramientas.modules.reservas.domain.model.EstadoReserva.APROBADA, " +
           "                 com.rentaherramientas.modules.reservas.domain.model.EstadoReserva.EN_CURSO) " +
           "AND r.fechaFin >= :inicio AND r.fechaInicio <= :fin " +
           "AND r.idReserva <> :idExcluida")
    boolean existsConflictoFechas(
            @Param("idHerramienta") Long idHerramienta,
            @Param("inicio") LocalDate inicio,
            @Param("fin") LocalDate fin,
            @Param("idExcluida") Long idExcluida
    );

    @Query("SELECT DISTINCT r FROM ReservaJpaEntity r JOIN r.detalles d " +
           "WHERE d.idHerramienta IN :ids ORDER BY r.fechaSolicitud DESC")
    List<ReservaJpaEntity> buscarPorHerramientas(@Param("ids") Collection<Long> ids);

    @Query("SELECT DISTINCT r FROM ReservaJpaEntity r JOIN r.detalles d " +
           "WHERE d.idHerramienta = :idHerramienta AND r.estado IN :estados " +
           "AND r.fechaFin >= :desde AND r.fechaInicio <= :hasta " +
           "ORDER BY r.fechaInicio ASC")
    List<ReservaJpaEntity> buscarQueSeCruzan(
            @Param("idHerramienta") Long idHerramienta,
            @Param("desde") LocalDate desde,
            @Param("hasta") LocalDate hasta,
            @Param("estados") Collection<EstadoReserva> estados
    );

    @Query("SELECT COUNT(d) > 0 FROM DetalleReservaJpaEntity d JOIN d.reserva r " +
           "WHERE r.idCliente = :idCliente AND d.idHerramienta = :idHerramienta " +
           "AND r.estado = com.rentaherramientas.modules.reservas.domain.model.EstadoReserva.FINALIZADA")
    boolean clienteFinalizoAlquiler(@Param("idCliente") Long idCliente, @Param("idHerramienta") Long idHerramienta);
}
