package com.rentaherramientas.modules.reservas.application.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.util.List;

/**
 * Solicitud de reserva que envia el cliente.
 *
 * No trae el id del cliente ni los precios: el cliente sale del token JWT y el
 * precio de la tarifa vigente de cada herramienta. Asi nadie puede reservar a
 * nombre de otro ni ponerle el precio que quiera.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CrearReservaCommand {

    @NotNull(message = "La fecha de inicio es obligatoria")
    @Schema(description = "Primer dia del alquiler (no puede ser una fecha pasada)", example = "2026-11-03")
    private LocalDate fechaInicio;

    @NotNull(message = "La fecha de fin es obligatoria")
    @Schema(description = "Dia de devolucion pactado", example = "2026-11-06")
    private LocalDate fechaFin;

    @NotEmpty(message = "La reserva debe contener al menos una herramienta")
    @Valid
    private List<DetalleReservaItemCommand> items;

    @Size(max = 255, message = "Las notas no pueden superar 255 caracteres")
    @Schema(description = "Direccion de entrega o indicaciones", example = "Entrega en obra, Calle 45 # 12-30")
    private String notasCliente;
}
