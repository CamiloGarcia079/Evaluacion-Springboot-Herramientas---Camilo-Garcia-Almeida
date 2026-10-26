package com.rentaherramientas.modules.pagos.infrastructure.adapters.in.web;

import com.rentaherramientas.common.dto.ApiResponseDto;
import com.rentaherramientas.modules.pagos.application.dto.FacturaResponseDto;
import com.rentaherramientas.modules.pagos.application.dto.PagoDtoMapper;
import com.rentaherramientas.modules.pagos.application.service.PagoApplicationService;
import com.rentaherramientas.modules.pagos.domain.model.Factura;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Facturas electronicas (IVA 19 % desglosado). Cada cliente ve solo las suyas.
 */
@RestController
@RequestMapping("/facturas")
@RequiredArgsConstructor
@Tag(name = "7. Facturas", description = "Consulta y descarga de facturas electrónicas")
@SecurityRequirement(name = "Bearer Authentication")
public class FacturaController {

    private final PagoApplicationService pagoApplicationService;

    @GetMapping("/mis-facturas")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Mis facturas")
    public ResponseEntity<ApiResponseDto<List<FacturaResponseDto>>> misFacturas(@AuthenticationPrincipal UserDetails usuario) {
        return ResponseEntity.ok(ApiResponseDto.ok("Facturas obtenidas",
                aDtos(pagoApplicationService.listarMisFacturas(usuario.getUsername()))));
    }

    @GetMapping("/reserva/{idReserva}")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Facturas de una reserva")
    public ResponseEntity<ApiResponseDto<List<FacturaResponseDto>>> deReserva(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long idReserva) {
        return ResponseEntity.ok(ApiResponseDto.ok("Facturas de la reserva obtenidas",
                aDtos(pagoApplicationService.listarFacturasDeReserva(usuario.getUsername(), idReserva))));
    }

    @GetMapping("/cliente/{idCliente}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Facturas de un cliente (admin)")
    public ResponseEntity<ApiResponseDto<List<FacturaResponseDto>>> listarPorCliente(@PathVariable Long idCliente) {
        return ResponseEntity.ok(ApiResponseDto.ok("Facturas del cliente obtenidas",
                aDtos(pagoApplicationService.listarFacturasPorCliente(idCliente))));
    }

    @GetMapping("/numero/{numeroFactura}")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Consultar factura por número", description = "Ejemplo: FAC-2026-0001")
    public ResponseEntity<ApiResponseDto<FacturaResponseDto>> obtenerPorNumero(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable String numeroFactura) {
        return ResponseEntity.ok(ApiResponseDto.ok(PagoDtoMapper.toFacturaResponseDto(
                pagoApplicationService.obtenerFacturaPorNumero(usuario.getUsername(), numeroFactura))));
    }

    @GetMapping("/pago/{idPago}")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Factura de un pago")
    public ResponseEntity<ApiResponseDto<FacturaResponseDto>> obtenerPorPago(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long idPago) {
        Factura factura = pagoApplicationService.obtenerFacturaPorPago(idPago);
        pagoApplicationService.obtenerFactura(usuario.getUsername(), factura.getIdFactura());
        return ResponseEntity.ok(ApiResponseDto.ok(PagoDtoMapper.toFacturaResponseDto(factura)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Consultar factura por ID")
    public ResponseEntity<ApiResponseDto<FacturaResponseDto>> obtenerPorId(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable Long id) {
        return ResponseEntity.ok(ApiResponseDto.ok(PagoDtoMapper.toFacturaResponseDto(
                pagoApplicationService.obtenerFactura(usuario.getUsername(), id))));
    }

    @GetMapping("/{numeroFactura}/descargar")
    @PreAuthorize("isAuthenticated()")
    @Operation(summary = "Descargar comprobante (.txt)")
    public ResponseEntity<String> descargarComprobante(
            @AuthenticationPrincipal UserDetails usuario, @PathVariable String numeroFactura) {
        Factura factura = pagoApplicationService.obtenerFacturaPorNumero(usuario.getUsername(), numeroFactura);

        String recibo = String.format("""
                ========================================================================
                          PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS
                                  FACTURA ELECTRONICA DE VENTA
                ========================================================================
                Factura No: %s
                Fecha Emision: %s
                ID Cliente: %d
                ID Pago Asociado: %d
                Estado: %s
                ------------------------------------------------------------------------
                Subtotal (Base Gravable): $ %,.2f COP
                IVA (19%%):               $ %,.2f COP
                ------------------------------------------------------------------------
                TOTAL PAGADO:            $ %,.2f COP
                ========================================================================
                """,
                factura.getNumeroFactura(), factura.getFechaEmision(), factura.getIdCliente(),
                factura.getIdPago(), factura.getEstado(),
                factura.getSubtotal(), factura.getIva(), factura.getTotal());

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(new MediaType(MediaType.TEXT_PLAIN, StandardCharsets.UTF_8));
        headers.setContentDispositionFormData("attachment", factura.getNumeroFactura() + ".txt");
        return ResponseEntity.ok().headers(headers).body(recibo);
    }

    private List<FacturaResponseDto> aDtos(List<Factura> facturas) {
        return facturas.stream().map(PagoDtoMapper::toFacturaResponseDto).toList();
    }
}
