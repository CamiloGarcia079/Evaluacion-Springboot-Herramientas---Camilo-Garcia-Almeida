package com.rentaherramientas.modules.resenas.infrastructure.adapters.in.web;

import com.rentaherramientas.common.dto.ApiResponseDto;
import com.rentaherramientas.modules.resenas.application.dto.ActualizarResenaRequest;
import com.rentaherramientas.modules.resenas.application.dto.CrearResenaRequest;
import com.rentaherramientas.modules.resenas.application.dto.ResenaDtoMapper;
import com.rentaherramientas.modules.resenas.application.dto.ResenaResponseDto;
import com.rentaherramientas.modules.resenas.domain.model.ResenaPendiente;
import com.rentaherramientas.modules.resenas.domain.model.ResumenCalificacion;
import com.rentaherramientas.modules.resenas.domain.ports.in.GestionarResenaUseCase;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/resenas")
@RequiredArgsConstructor
@Tag(name = "9. Reseñas", description = "Calificaciones de 1 a 5 estrellas de herramientas alquiladas")
public class ResenaController {

    private final GestionarResenaUseCase resenaUseCase;

    // ----------------------------------------------------------- publicos

    @GetMapping("/herramienta/{idHerramienta}")
    @SecurityRequirements
    @Operation(summary = "Reseñas de una herramienta (público)")
    @ApiResponse(responseCode = "404", description = "La herramienta no existe")
    public ResponseEntity<ApiResponseDto<List<ResenaResponseDto>>> deHerramienta(@PathVariable Long idHerramienta) {
        List<ResenaResponseDto> dtos = resenaUseCase.listarPorHerramienta(idHerramienta).stream()
                .map(ResenaDtoMapper::toDto).toList();
        return ResponseEntity.ok(ApiResponseDto.ok("Reseñas obtenidas", dtos));
    }

    @GetMapping("/herramienta/{idHerramienta}/resumen")
    @SecurityRequirements
    @Operation(summary = "Promedio de estrellas de una herramienta (público)")
    public ResponseEntity<ApiResponseDto<ResumenCalificacion>> resumen(@PathVariable Long idHerramienta) {
        return ResponseEntity.ok(ApiResponseDto.ok(resenaUseCase.resumenDeHerramienta(idHerramienta)));
    }

    @GetMapping("/resumen")
    @SecurityRequirements
    @Operation(summary = "Promedio de todas las herramientas calificadas (público)",
            description = "Lo usa el catálogo para pintar las estrellas de cada tarjeta con una sola petición.")
    public ResponseEntity<ApiResponseDto<List<ResumenCalificacion>>> resumenGeneral() {
        return ResponseEntity.ok(ApiResponseDto.ok("Resumen de calificaciones", resenaUseCase.resumenGeneral()));
    }

    // ------------------------------------------------------- autenticados

    @PostMapping
    @PreAuthorize("hasRole('CLIENTE')")
    @SecurityRequirement(name = "Bearer Authentication")
    @Operation(summary = "Calificar una herramienta",
            description = "La reserva debe ser del cliente, estar FINALIZADA e incluir la herramienta. Una reseña por herramienta y reserva.")
    @ApiResponse(responseCode = "201", description = "Reseña publicada")
    @ApiResponse(responseCode = "422", description = "Reserva no finalizada, herramienta ajena a la reserva o reseña repetida")
    public ResponseEntity<ApiResponseDto<ResenaResponseDto>> publicar(
            @AuthenticationPrincipal UserDetails usuario, @Valid @RequestBody CrearResenaRequest request) {
        var resena = resenaUseCase.publicar(usuario.getUsername(), request.idReserva(), request.idHerramienta(),
                request.calificacion(), request.comentario());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponseDto.ok("¡Gracias! Su reseña fue publicada", ResenaDtoMapper.toDto(resena)));
    }

    @GetMapping("/mis-resenas")
    @PreAuthorize("isAuthenticated()")
    @SecurityRequirement(name = "Bearer Authentication")
    @Operation(summary = "Mis reseñas")
    public ResponseEntity<ApiResponseDto<List<ResenaResponseDto>>> misResenas(@AuthenticationPrincipal UserDetails usuario) {
        List<ResenaResponseDto> dtos = resenaUseCase.misResenas(usuario.getUsername()).stream()
                .map(ResenaDtoMapper::toDto).toList();
        return ResponseEntity.ok(ApiResponseDto.ok("Reseñas obtenidas", dtos));
    }

    @GetMapping("/pendientes")
    @PreAuthorize("isAuthenticated()")
    @SecurityRequirement(name = "Bearer Authentication")
    @Operation(summary = "Herramientas que puedo calificar", description = "Alquileres finalizados aún sin reseña.")
    public ResponseEntity<ApiResponseDto<List<ResenaPendiente>>> pendientes(@AuthenticationPrincipal UserDetails usuario) {
        return ResponseEntity.ok(ApiResponseDto.ok("Pendientes por calificar",
                resenaUseCase.pendientesPorCalificar(usuario.getUsername())));
    }

    @PutMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    @SecurityRequirement(name = "Bearer Authentication")
    @Operation(summary = "Editar mi reseña")
    public ResponseEntity<ApiResponseDto<ResenaResponseDto>> editar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id,
            @Valid @RequestBody ActualizarResenaRequest request) {
        var resena = resenaUseCase.editar(usuario.getUsername(), id, request.calificacion(), request.comentario());
        return ResponseEntity.ok(ApiResponseDto.ok("Reseña actualizada", ResenaDtoMapper.toDto(resena)));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    @SecurityRequirement(name = "Bearer Authentication")
    @Operation(summary = "Eliminar una reseña", description = "El autor o un administrador (moderación).")
    public ResponseEntity<ApiResponseDto<Void>> eliminar(@AuthenticationPrincipal UserDetails usuario, @PathVariable Long id) {
        resenaUseCase.eliminar(usuario.getUsername(), id);
        return ResponseEntity.ok(ApiResponseDto.ok("Reseña eliminada", null));
    }
}
