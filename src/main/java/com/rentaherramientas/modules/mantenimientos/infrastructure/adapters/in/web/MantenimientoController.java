package com.rentaherramientas.modules.mantenimientos.infrastructure.adapters.in.web;

import com.rentaherramientas.common.dto.ApiResponseDto;
import com.rentaherramientas.modules.mantenimientos.application.dto.FinalizarMantenimientoRequest;
import com.rentaherramientas.modules.mantenimientos.application.dto.MantenimientoDtoMapper;
import com.rentaherramientas.modules.mantenimientos.application.dto.MantenimientoResponseDto;
import com.rentaherramientas.modules.mantenimientos.application.dto.RegistrarMantenimientoRequest;
import com.rentaherramientas.modules.mantenimientos.domain.model.Mantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.ports.in.GestionarMantenimientoUseCase;
import io.swagger.v3.oas.annotations.Operation;
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
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/mantenimientos")
@RequiredArgsConstructor
@PreAuthorize("hasAnyRole('PROVEEDOR', 'ADMIN')")
@SecurityRequirement(name = "Bearer Authentication")
@Tag(name = "10. Mantenimientos", description = "Historial de mantenimiento preventivo y correctivo de las herramientas")
public class MantenimientoController {

    private final GestionarMantenimientoUseCase mantenimientoUseCase;

    @PostMapping
    @Operation(summary = "Enviar una herramienta a mantenimiento",
            description = "La herramienta pasa a EN_MANTENIMIENTO y deja de poder despacharse. No aplica si está ALQUILADA.")
    @ApiResponse(responseCode = "201", description = "Mantenimiento registrado")
    @ApiResponse(responseCode = "403", description = "La herramienta es de otro proveedor")
    @ApiResponse(responseCode = "422", description = "Herramienta alquilada o con un mantenimiento ya abierto")
    public ResponseEntity<ApiResponseDto<MantenimientoResponseDto>> registrar(
            @AuthenticationPrincipal UserDetails usuario, @Valid @RequestBody RegistrarMantenimientoRequest request) {
        Mantenimiento m = mantenimientoUseCase.registrar(usuario.getUsername(), request.idHerramienta(),
                request.tipo(), request.descripcion());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponseDto.ok("Herramienta enviada a mantenimiento", MantenimientoDtoMapper.toDto(m)));
    }

    @PatchMapping("/{id}/finalizar")
    @Operation(summary = "Finalizar un mantenimiento",
            description = "Registra el costo. La herramienta vuelve a DISPONIBLE, o queda FUERA_DE_SERVICIO si darDeBaja=true.")
    public ResponseEntity<ApiResponseDto<MantenimientoResponseDto>> finalizar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id,
            @Valid @RequestBody(required = false) FinalizarMantenimientoRequest request) {
        FinalizarMantenimientoRequest datos = request != null ? request : new FinalizarMantenimientoRequest(null, null, false);
        Mantenimiento m = mantenimientoUseCase.finalizar(usuario.getUsername(), id, datos.costo(), datos.observaciones(),
                Boolean.TRUE.equals(datos.darDeBaja()));
        return ResponseEntity.ok(ApiResponseDto.ok("Mantenimiento finalizado", MantenimientoDtoMapper.toDto(m)));
    }

    @GetMapping
    @Operation(summary = "Listar mantenimientos", description = "Admin: todos. Proveedor: los de sus herramientas.")
    public ResponseEntity<ApiResponseDto<List<MantenimientoResponseDto>>> listar(
            @AuthenticationPrincipal UserDetails usuario,
            @RequestParam(defaultValue = "false") boolean soloAbiertos) {
        List<MantenimientoResponseDto> dtos = mantenimientoUseCase.listar(usuario.getUsername(), soloAbiertos).stream()
                .map(MantenimientoDtoMapper::toDto).toList();
        return ResponseEntity.ok(ApiResponseDto.ok("Mantenimientos obtenidos", dtos));
    }

    @GetMapping("/herramienta/{idHerramienta}")
    @Operation(summary = "Historial de mantenimiento de una herramienta")
    public ResponseEntity<ApiResponseDto<List<MantenimientoResponseDto>>> historial(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long idHerramienta) {
        List<MantenimientoResponseDto> dtos = mantenimientoUseCase.historialDeHerramienta(usuario.getUsername(), idHerramienta)
                .stream().map(MantenimientoDtoMapper::toDto).toList();
        return ResponseEntity.ok(ApiResponseDto.ok("Historial obtenido", dtos));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Consultar un mantenimiento")
    public ResponseEntity<ApiResponseDto<MantenimientoResponseDto>> obtener(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id) {
        return ResponseEntity.ok(ApiResponseDto.ok(
                MantenimientoDtoMapper.toDto(mantenimientoUseCase.obtener(usuario.getUsername(), id))));
    }
}
