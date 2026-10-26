package com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence;

import com.rentaherramientas.modules.reservas.domain.model.ReporteDano;
import com.rentaherramientas.modules.reservas.domain.ports.out.ReporteDanoPort;
import com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.entity.ReporteDanoReservaJpaEntity;
import com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.repository.SpringDataReporteDanoReservaRepository;
import com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.repository.SpringDataReservaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ReporteDanoPersistenceAdapterReserva implements ReporteDanoPort {

    private final SpringDataReporteDanoReservaRepository reporteRepository;
    private final SpringDataReservaRepository reservaRepository;

    @Override
    public ReporteDano guardar(ReporteDano reporte) {
        ReporteDanoReservaJpaEntity entity = ReporteDanoReservaJpaEntity.builder()
                .idReporteDano(reporte.getIdReporteDano())
                .reserva(reservaRepository.getReferenceById(reporte.getIdReserva()))
                .descripcion(reporte.getDescripcion())
                .costoReparacion(reporte.getCostoReparacion())
                .fechaReporte(reporte.getFechaReporte())
                .build();
        return aDominio(reporteRepository.save(entity));
    }

    @Override
    public Optional<ReporteDano> buscarPorReserva(Long idReserva) {
        return reporteRepository.findByReservaIdReserva(idReserva).map(this::aDominio);
    }

    private ReporteDano aDominio(ReporteDanoReservaJpaEntity e) {
        return ReporteDano.builder()
                .idReporteDano(e.getIdReporteDano())
                .idReserva(e.getReserva().getIdReserva())
                .descripcion(e.getDescripcion())
                .costoReparacion(e.getCostoReparacion())
                .fechaReporte(e.getFechaReporte())
                .build();
    }
}
