package com.rentaherramientas.modules.favoritos.infrastructure.adapters.in.web;

import com.rentaherramientas.common.dto.ApiResponseDto;
import com.rentaherramientas.modules.favoritos.domain.model.HerramientaFavorita;
import com.rentaherramientas.modules.favoritos.domain.ports.in.GestionarFavoritosUseCase;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/favoritos")
@RequiredArgsConstructor
@PreAuthorize("isAuthenticated()")
@SecurityRequirement(name = "Bearer Authentication")
@Tag(name = "11. Favoritos", description = "Herramientas guardadas por el usuario")
public class FavoritoController {

    private final GestionarFavoritosUseCase favoritosUseCase;

    @GetMapping
    @Operation(summary = "Mis herramientas favoritas")
    public ResponseEntity<ApiResponseDto<List<HerramientaFavorita>>> listar(@AuthenticationPrincipal UserDetails usuario) {
        return ResponseEntity.ok(ApiResponseDto.ok("Favoritos obtenidos", favoritosUseCase.listar(usuario.getUsername())));
    }

    @GetMapping("/ids")
    @Operation(summary = "IDs de mis favoritos", description = "Para marcar los corazones del catálogo con una sola petición.")
    public ResponseEntity<ApiResponseDto<List<Long>>> ids(@AuthenticationPrincipal UserDetails usuario) {
        return ResponseEntity.ok(ApiResponseDto.ok(favoritosUseCase.idsFavoritos(usuario.getUsername())));
    }

    @PostMapping("/{idHerramienta}")
    @Operation(summary = "Agregar a favoritos", description = "Si ya estaba, responde igual (idempotente).")
    public ResponseEntity<ApiResponseDto<HerramientaFavorita>> agregar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long idHerramienta) {
        return ResponseEntity.ok(ApiResponseDto.ok("Agregada a favoritos",
                favoritosUseCase.agregar(usuario.getUsername(), idHerramienta)));
    }

    @DeleteMapping("/{idHerramienta}")
    @Operation(summary = "Quitar de favoritos")
    public ResponseEntity<ApiResponseDto<Void>> quitar(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long idHerramienta) {
        favoritosUseCase.quitar(usuario.getUsername(), idHerramienta);
        return ResponseEntity.ok(ApiResponseDto.ok("Quitada de favoritos", null));
    }
}
