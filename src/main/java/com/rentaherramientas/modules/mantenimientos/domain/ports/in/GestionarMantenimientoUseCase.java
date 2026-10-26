package com.rentaherramientas.modules.mantenimientos.domain.ports.in;

import com.rentaherramientas.modules.mantenimientos.domain.model.Mantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.model.TipoMantenimiento;

import java.math.BigDecimal;
import java.util.List;

public interface GestionarMantenimientoUseCase {

    Mantenimiento registrar(String emailSolicitante, Long idHerramienta, TipoMantenimiento tipo, String descripcion);

    /**
     * Cierra el mantenimiento. Si darDeBaja es true la herramienta queda
     * FUERA_DE_SERVICIO; si no, vuelve a DISPONIBLE.
     */
    Mantenimiento finalizar(String emailSolicitante, Long idMantenimiento, BigDecimal costo, String observaciones, boolean darDeBaja);

    Mantenimiento obtener(String emailSolicitante, Long idMantenimiento);

    List<Mantenimiento> historialDeHerramienta(String emailSolicitante, Long idHerramienta);

    /** Admin: todos. Proveedor: los de sus herramientas. */
    List<Mantenimiento> listar(String emailSolicitante, boolean soloAbiertos);
}
