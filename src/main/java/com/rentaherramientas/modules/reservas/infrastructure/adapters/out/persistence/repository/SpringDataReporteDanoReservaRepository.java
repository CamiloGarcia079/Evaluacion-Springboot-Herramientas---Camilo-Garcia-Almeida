package com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.repository;

import com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.entity.ReporteDanoReservaJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface SpringDataReporteDanoReservaRepository extends JpaRepository<ReporteDanoReservaJpaEntity, Long> {
    Optional<ReporteDanoReservaJpaEntity> findByReservaIdReserva(Long idReserva);
}
