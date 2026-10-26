package com.rentaherramientas.modules.pagos.infrastructure.adapters.in.web;

import com.rentaherramientas.common.dto.ApiResponseDto;
import com.rentaherramientas.modules.pagos.application.dto.MetodoPagoDto;
import com.rentaherramientas.modules.pagos.application.dto.PagoDtoMapper;
import com.rentaherramientas.modules.pagos.application.dto.PagoResponseDto;
import com.rentaherramientas.modules.pagos.application.dto.ProcesarPagoCommand;
import com.rentaherramientas.modules.pagos.application.service.PagoApplicationService;
import com.rentaherramientas.modules.pagos.domain.model.Pago;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Pagos en linea con pasarela simulada. Cada pago aprobado emite su factura.
 */
@RestController
@RequestMapping("/pagos")
@RequiredArgsConstructor
@Tag(name = "6. Pagos", description = "Pago de reservas aprobadas y consulta de transacciones")
@SecurityRequirement(name = "Bearer Authentication")
public class PagoController {

    private final PagoApplicationService pagoApplicationService;

    @PostMapping
    @PreAuthorize("hasAnyRole('CLIENTE', 'ADMIN')")
    @Operation(summary = "Pagar una reserva",
            description = "La reserva debe ser del usuario y estar APROBADA, EN_CURSO o FINALIZADA. "
                    + "Si no se envía 'monto' se cobra el saldo pendiente (TOTALIDAD), el 50 % (ANTICIPO) o el depósito pendiente (DEPOSITO_GARANTIA).")
    @ApiResponse(responseCode = "201", description = "Pago aprobado y factura emitida")
    @ApiResponse(responseCode = "403", description = "La reserva es de otro cliente")
    @ApiResponse(responseCode = "422", description = "Reserva sin aprobar, monto mayor al saldo o método inactivo")
    public ResponseEntity<ApiResponseDto<PagoResponseDto>> procesarPago(
            @AuthenticationPrincipal UserDetails usuario,
            @Valid @RequestBody ProcesarPagoCommand command) {
        Pago pago = pagoApplicationService.procesarPago(usuario.getUsername(), command);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponseDto.ok("Pago aprobado y factura emitida con éxito", PagoDtoMapper.toPagoResponseDto(pago)));
    }

    @GetMapping("/mis-pagos")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Mis pagos", description = "Pagos de todas las reservas del usuario autenticado.")
    public ResponseEntity<ApiResponseDto<List<PagoResponseDto>>> misPagos(@AuthenticationPrincipal UserDetails usuario) {
        return ResponseEntity.ok(ApiResponseDto.ok("Pagos obtenidos",
                aDtos(pagoApplicationService.listarMisPagos(usuario.getUsername()))));
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Listar todas las transacciones (admin)")
    public ResponseEntity<ApiResponseDto<List<PagoResponseDto>>> listarTodos() {
        return ResponseEntity.ok(ApiResponseDto.ok("Transacciones de pago obtenidas con éxito",
                aDtos(pagoApplicationService.listarTodosLosPagos())));
    }

    @GetMapping("/metodos")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Métodos de pago activos", description = "PSE, tarjetas, Nequi, Daviplata, etc.")
    public ResponseEntity<ApiResponseDto<List<MetodoPagoDto>>> listarMetodosPago() {
        List<MetodoPagoDto> dtos = pagoApplicationService.listarMetodosPago().stream()
                .map(PagoDtoMapper::toMetodoPagoDto).toList();
        return ResponseEntity.ok(ApiResponseDto.ok("Métodos de pago activos obtenidos", dtos));
    }

    @GetMapping("/reserva/{idReserva}")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Pagos de una reserva", description = "Visible para el cliente de la reserva, su proveedor o un administrador.")
    public ResponseEntity<ApiResponseDto<List<PagoResponseDto>>> listarPorReserva(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long idReserva) {
        return ResponseEntity.ok(ApiResponseDto.ok("Pagos de la reserva obtenidos",
                aDtos(pagoApplicationService.listarPagosDeReserva(usuario.getUsername(), idReserva))));
    }

    @GetMapping("/transaccion/{numeroTransaccion}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Buscar pago por número de transacción (admin)")
    public ResponseEntity<ApiResponseDto<PagoResponseDto>> obtenerPorTransaccion(@PathVariable String numeroTransaccion) {
        return ResponseEntity.ok(ApiResponseDto.ok(
                PagoDtoMapper.toPagoResponseDto(pagoApplicationService.obtenerPagoPorTransaccion(numeroTransaccion))));
    }

    @GetMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Consultar un pago", description = "Incluye la factura emitida.")
    @ApiResponse(responseCode = "404", description = "Pago no encontrado")
    public ResponseEntity<ApiResponseDto<PagoResponseDto>> obtenerPorId(
            @AuthenticationPrincipal UserDetails usuario,
            @Parameter(description = "ID del pago") @PathVariable Long id) {
        return ResponseEntity.ok(ApiResponseDto.ok(
                PagoDtoMapper.toPagoResponseDto(pagoApplicationService.obtenerPago(usuario.getUsername(), id))));
    }

    private List<PagoResponseDto> aDtos(List<Pago> pagos) {
        return pagos.stream().map(PagoDtoMapper::toPagoResponseDto).toList();
    }
}
