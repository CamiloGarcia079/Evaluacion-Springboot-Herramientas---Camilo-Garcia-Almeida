package com.rentaherramientas.modules.reservas.domain.ports.out;

import com.rentaherramientas.modules.reservas.domain.model.ReporteDano;

import java.util.Optional;

public interface ReporteDanoPort {
    ReporteDano guardar(ReporteDano reporte);
    Optional<ReporteDano> buscarPorReserva(Long idReserva);
}
