package com.rentaherramientas.modules.reservas.infrastructure.adapters.in.web;

import com.rentaherramientas.common.dto.ApiResponseDto;
import com.rentaherramientas.modules.reservas.application.dto.CrearReservaCommand;
import com.rentaherramientas.modules.reservas.application.dto.DisponibilidadResponseDto;
import com.rentaherramientas.modules.reservas.application.dto.RechazarReservaRequest;
import com.rentaherramientas.modules.reservas.application.dto.ReservaDtoMapper;
import com.rentaherramientas.modules.reservas.application.dto.ReservaResponseDto;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;
import com.rentaherramientas.modules.reservas.domain.ports.in.CambiarEstadoReservaUseCase;
import com.rentaherramientas.modules.reservas.domain.ports.in.ConsultarReservaUseCase;
import com.rentaherramientas.modules.reservas.domain.ports.in.CrearReservaUseCase;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import com.rentaherramientas.modules.reservas.application.dto.DevolucionDTO;
import com.rentaherramientas.modules.reservas.application.dto.DevolucionResponseDto;
import com.rentaherramientas.modules.reservas.domain.ports.in.DevolucionEquipoUseCase;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;

/**
 * Adaptador de entrada REST del modulo de Reservas.
 *
 * El usuario siempre sale del token (@AuthenticationPrincipal), nunca del
 * cuerpo ni de un parametro: asi nadie puede actuar a nombre de otro.
 */
@RestController
@RequestMapping("/reservas")
@RequiredArgsConstructor
@Tag(name = "5. Reservas", description = "Ciclo de vida del alquiler: solicitar, aprobar, despachar, finalizar, cancelar y consultar disponibilidad")
public class ReservaController {

    private final CrearReservaUseCase crearReservaUseCase;
    private final ConsultarReservaUseCase consultarReservaUseCase;
    private final CambiarEstadoReservaUseCase cambiarEstadoReservaUseCase;
    private final DevolucionEquipoUseCase devolucionEquipoUseCase;

    @PostMapping
    @PreAuthorize("hasAnyRole('CLIENTE', 'ADMIN')")
    @Operation(summary = "Solicitar una reserva",
            description = "El cliente sale del token y el precio de la tarifa vigente de cada herramienta. Queda en estado SOLICITADA.")
    @ApiResponses({
            @ApiResponse(responseCode = "201", description = "Reserva creada"),
            @ApiResponse(responseCode = "400", description = "Datos invalidos"),
            @ApiResponse(responseCode = "404", description = "Alguna herramienta no existe"),
            @ApiResponse(responseCode = "422", description = "Fechas pasadas, herramienta dada de baja o fechas ya ocupadas")
    })
    public ResponseEntity<ApiResponseDto<ReservaResponseDto>> crearReserva(
            @AuthenticationPrincipal UserDetails usuario,
            @Valid @RequestBody CrearReservaCommand command) {
        Reserva reserva = crearReservaUseCase.crearReserva(usuario.getUsername(), command);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponseDto.ok("Reserva " + reserva.getCodigoReserva() + " registrada con éxito",
                        ReservaDtoMapper.toResponseDto(reserva)));
    }

    @GetMapping("/mis-reservas")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Mis reservas", description = "Reservas del usuario autenticado, de la mas reciente a la mas antigua.")
    public ResponseEntity<ApiResponseDto<List<ReservaResponseDto>>> misReservas(@AuthenticationPrincipal UserDetails usuario) {
        List<ReservaResponseDto> dtos = consultarReservaUseCase.listarMisReservas(usuario.getUsername()).stream()
                .map(ReservaDtoMapper::toResponseDto).toList();
        return ResponseEntity.ok(ApiResponseDto.ok("Se encontraron " + dtos.size() + " reserva(s)", dtos));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'PROVEEDOR')")
    @Operation(summary = "Reservas para gestionar",
            description = "Administrador: todas. Proveedor: solo las que incluyen alguna de sus herramientas.")
    public ResponseEntity<ApiResponseDto<List<ReservaResponseDto>>> listarParaGestion(@AuthenticationPrincipal UserDetails usuario) {
        List<ReservaResponseDto> dtos = consultarReservaUseCase.listarParaGestion(usuario.getUsername()).stream()
                .map(ReservaDtoMapper::toResponseDto).toList();
        return ResponseEntity.ok(ApiResponseDto.ok("Se encontraron " + dtos.size() + " reserva(s)", dtos));
    }

    @GetMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Detalle de una reserva",
            description = "Solo la ven el cliente dueño, el proveedor de alguna de sus herramientas o un administrador.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Reserva encontrada"),
            @ApiResponse(responseCode = "403", description = "La reserva no es suya"),
            @ApiResponse(responseCode = "404", description = "No existe")
    })
    public ResponseEntity<ApiResponseDto<ReservaResponseDto>> obtener(
            @AuthenticationPrincipal UserDetails usuario,
            @Parameter(description = "ID de la reserva", example = "1") @PathVariable Long id) {
        Reserva reserva = consultarReservaUseCase.obtener(usuario.getUsername(), id);
        return ResponseEntity.ok(ApiResponseDto.ok(ReservaDtoMapper.toResponseDto(reserva)));
    }

    @GetMapping("/disponibilidad/{idHerramienta}")
    @Operation(summary = "Disponibilidad de una herramienta (público)",
            description = "Indica si la herramienta está libre entre dos fechas y lista los tramos ya comprometidos. "
                    + "Sin fechas consulta los próximos 30 días.")
    @ApiResponses({
            @ApiResponse(responseCode = "200", description = "Consulta realizada"),
            @ApiResponse(responseCode = "404", description = "La herramienta no existe"),
            @ApiResponse(responseCode = "422", description = "Rango invalido o mayor a un año")
    })
    public ResponseEntity<ApiResponseDto<DisponibilidadResponseDto>> disponibilidad(
            @Parameter(description = "ID de la herramienta", example = "1") @PathVariable Long idHerramienta,
            @Parameter(description = "Desde (AAAA-MM-DD)", example = "2026-11-03")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate desde,
            @Parameter(description = "Hasta (AAAA-MM-DD)", example = "2026-11-06")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate hasta) {
        DisponibilidadResponseDto dto = ReservaDtoMapper.toDisponibilidadDto(
                consultarReservaUseCase.consultarDisponibilidad(idHerramienta, desde, hasta));
        return ResponseEntity.ok(ApiResponseDto.ok(dto.mensaje(), dto));
    }

    @PatchMapping("/{id}/aprobar")
    @PreAuthorize("hasAnyRole('ADMIN', 'PROVEEDOR')")
    @Operation(summary = "Aprobar", description = "SOLICITADA -> APROBADA. Vuelve a verificar que las fechas sigan libres.")
    public ResponseEntity<ApiResponseDto<ReservaResponseDto>> aprobar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id) {
        Reserva r = cambiarEstadoReservaUseCase.aprobarReserva(usuario.getUsername(), id);
        return ResponseEntity.ok(ApiResponseDto.ok("Reserva aprobada", ReservaDtoMapper.toResponseDto(r)));
    }

    @PatchMapping("/{id}/rechazar")
    @PreAuthorize("hasAnyRole('ADMIN', 'PROVEEDOR')")
    @Operation(summary = "Rechazar", description = "SOLICITADA -> RECHAZADA con un motivo obligatorio.")
    public ResponseEntity<ApiResponseDto<ReservaResponseDto>> rechazar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id,
            @Valid @RequestBody RechazarReservaRequest request) {
        Reserva r = cambiarEstadoReservaUseCase.rechazarReserva(usuario.getUsername(), id, request.getMotivo());
        return ResponseEntity.ok(ApiResponseDto.ok("Reserva rechazada", ReservaDtoMapper.toResponseDto(r)));
    }

    @PatchMapping("/{id}/iniciar")
    @PreAuthorize("hasAnyRole('ADMIN', 'PROVEEDOR')")
    @Operation(summary = "Despachar el equipo", description = "APROBADA -> EN_CURSO. Las herramientas pasan a ALQUILADA.")
    public ResponseEntity<ApiResponseDto<ReservaResponseDto>> iniciar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id) {
        Reserva r = cambiarEstadoReservaUseCase.iniciarAlquiler(usuario.getUsername(), id);
        return ResponseEntity.ok(ApiResponseDto.ok("Equipo despachado: alquiler en curso", ReservaDtoMapper.toResponseDto(r)));
    }

    @PatchMapping("/{id}/finalizar")
    @PreAuthorize("hasAnyRole('ADMIN', 'PROVEEDOR')")
    @Operation(summary = "Finalizar sin check-in",
            description = "EN_CURSO -> FINALIZADA y las herramientas vuelven a DISPONIBLE. Para registrar daños o mora use POST /devoluciones.")
    public ResponseEntity<ApiResponseDto<ReservaResponseDto>> finalizar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id) {
        Reserva r = cambiarEstadoReservaUseCase.finalizarAlquiler(usuario.getUsername(), id);
        return ResponseEntity.ok(ApiResponseDto.ok("Alquiler finalizado", ReservaDtoMapper.toResponseDto(r)));
    }

    @PatchMapping("/{id}/cancelar")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Cancelar", description = "SOLICITADA o APROBADA -> CANCELADA. La puede cancelar el cliente dueño, el proveedor o un administrador.")
    public ResponseEntity<ApiResponseDto<ReservaResponseDto>> cancelar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id) {
        Reserva r = cambiarEstadoReservaUseCase.cancelarReserva(usuario.getUsername(), id);
        return ResponseEntity.ok(ApiResponseDto.ok("Reserva cancelada", ReservaDtoMapper.toResponseDto(r)));
    }

    @PostMapping("/{id}/registrar-devolucion")
    @PreAuthorize("hasAnyRole('ADMIN', 'PROVEEDOR')")
    @Operation(summary = "Registrar devolución del equipo",
            description = "El proveedor marca la devolución como completada. Estado OK -> DEVUELTO_OK. "
                    + "Estado DANOS -> DEVUELTO_CON_DANOS y se crea un reporte de daños. La reserva debe estar EN_CURSO.")
    public ResponseEntity<ApiResponseDto<DevolucionResponseDto>> registrarDevolucion(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id,
            @Valid @RequestBody DevolucionDTO dto) {
        DevolucionEquipoUseCase.ResultadoDevolucion r = devolucionEquipoUseCase.registrarDevolucion(
                usuario.getUsername(), id, dto.getEstado(), dto.getDescripcionDano(), dto.getCostoReparacion());
        DevolucionResponseDto.ReporteDanoDto reporte = r.reporteDano() == null ? null
                : new DevolucionResponseDto.ReporteDanoDto(r.reporteDano().getIdReporteDano(),
                        r.reporteDano().getDescripcion(), r.reporteDano().getCostoReparacion(),
                        r.reporteDano().getFechaReporte());
        DevolucionResponseDto respuesta = new DevolucionResponseDto(r.reserva().getIdReserva(),
                r.reserva().getCodigoReserva(), r.reserva().getEstado(), r.reserva().getEstadoDevolucion(), reporte);
        return ResponseEntity.ok(ApiResponseDto.ok("Devolución registrada", respuesta));
    }
}
