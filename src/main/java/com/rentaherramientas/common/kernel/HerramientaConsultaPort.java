package com.rentaherramientas.common.kernel;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * Puerto del kernel compartido para consultar y mover el estado de las herramientas.
 *
 * Lo usan reservas, devoluciones, mantenimientos, resenas y favoritos. La
 * implementacion vive en el modulo de Inventario y respeta sus reglas de
 * negocio: un cambio de estado invalido (por ejemplo, despachar una herramienta
 * que esta en mantenimiento) se rechaza igual que si se hiciera desde Inventario.
 */
public interface HerramientaConsultaPort {

    record InfoHerramienta(Long idHerramienta,
                           String nombre,
                           String marca,
                           String modelo,
                           BigDecimal tarifaDiaria,
                           String estadoOperativo,
                           Long idProveedor,
                           String imagenPrincipal) {

        /** Una herramienta dada de baja no se puede reservar. */
        public boolean admiteReservas() {
            return !"FUERA_DE_SERVICIO".equals(estadoOperativo);
        }

        public boolean estaDisponibleAhora() {
            return "DISPONIBLE".equals(estadoOperativo);
        }
    }

    Optional<InfoHerramienta> buscarPorId(Long idHerramienta);

    /** Ids de todas las herramientas que publico un proveedor. */
    List<Long> idsDeProveedor(Long idProveedor);

    /**
     * Cambia el estado operativo aplicando las transiciones permitidas por el
     * dominio de Inventario. Lanza BusinessRuleException si la transicion no
     * es valida.
     */
    void cambiarEstado(Long idHerramienta, String nuevoEstado);
}
