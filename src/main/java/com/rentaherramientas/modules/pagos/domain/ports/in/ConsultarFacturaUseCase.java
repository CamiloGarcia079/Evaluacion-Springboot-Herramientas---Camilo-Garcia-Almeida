package com.rentaherramientas.modules.pagos.domain.ports.in;

import com.rentaherramientas.modules.pagos.domain.model.Factura;

import java.util.List;

public interface ConsultarFacturaUseCase {
    Factura obtenerFacturaPorId(Long id);
    Factura obtenerFacturaPorNumero(String numeroFactura);
    Factura obtenerFacturaPorPago(Long idPago);
    List<Factura> listarFacturasPorCliente(Long idCliente);

    List<Factura> listarMisFacturas(String emailCliente);
    List<Factura> listarFacturasDeReserva(String emailSolicitante, Long idReserva);

    /** Factura por id o por numero, si pertenece al solicitante o es administrador. */
    Factura obtenerFactura(String emailSolicitante, Long idFactura);
    Factura obtenerFacturaPorNumero(String emailSolicitante, String numeroFactura);
}
