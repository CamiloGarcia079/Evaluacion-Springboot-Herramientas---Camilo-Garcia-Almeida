package com.rentaherramientas.modules.reservas.application.dto;

import com.rentaherramientas.modules.reservas.domain.model.Disponibilidad;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;

import java.util.ArrayList;
import java.util.List;

public final class ReservaDtoMapper {

    private ReservaDtoMapper() {
    }

    public static ReservaResponseDto toResponseDto(Reserva domain) {
        if (domain == null) return null;

        List<DetalleReservaResponseDto> detallesDto = new ArrayList<>();
        if (domain.getDetalles() != null) {
            detallesDto = domain.getDetalles().stream()
                    .map(d -> DetalleReservaResponseDto.builder()
                            .idDetalleReserva(d.getIdDetalleReserva())
                            .idHerramienta(d.getIdHerramienta())
                            .nombreHerramienta(d.getNombreHerramienta())
                            .imagenHerramienta(d.getImagenHerramienta())
                            .cantidad(d.getCantidad())
                            .precioUnitarioDia(d.getPrecioUnitarioDia())
                            .diasAlquiler(d.getDiasAlquiler())
                            .subtotal(d.getSubtotal())
                            .build())
                    .toList();
        }

        return ReservaResponseDto.builder()
                .idReserva(domain.getIdReserva())
                .codigoReserva(domain.getCodigoReserva())
                .idCliente(domain.getIdCliente())
                .nombreCliente(domain.getNombreCliente())
                .fechaSolicitud(domain.getFechaSolicitud())
                .fechaInicio(domain.getRangoFechas().getFechaInicio())
                .fechaFin(domain.getRangoFechas().getFechaFin())
                .diasAlquiler(domain.getRangoFechas().getDiasAlquiler())
                .estado(domain.getEstado())
                .estadoDevolucion(domain.getEstadoDevolucion())
                .detalles(detallesDto)
                .montoTotalEstimado(domain.getMontoTotalEstimado())
                .depositoGarantia(domain.getDepositoGarantia())
                .notasCliente(domain.getNotasCliente())
                .motivoRechazo(domain.getMotivoRechazo())
                .build();
    }

    public static DisponibilidadResponseDto toDisponibilidadDto(Disponibilidad d) {
        List<DisponibilidadResponseDto.OcupacionDto> ocupaciones = d.ocupaciones().stream()
                .map(o -> new DisponibilidadResponseDto.OcupacionDto(o.desde(), o.hasta(), o.estado().name()))
                .toList();
        String mensaje = d.disponible()
                ? "La herramienta está libre entre " + d.desde() + " y " + d.hasta()
                : "La herramienta ya está comprometida en parte de ese rango";
        return new DisponibilidadResponseDto(d.idHerramienta(), d.desde(), d.hasta(), d.disponible(), mensaje, ocupaciones);
    }
}
