package com.rentaherramientas.common.kernel;

import java.util.Optional;
import java.util.Set;

/**
 * Puerto del kernel compartido para consultar usuarios.
 *
 * Los modulos de negocio (reservas, pagos, devoluciones, resenas...) necesitan
 * saber quien hace cada operacion, pero no deben importar clases del modulo de
 * Identidad. Declaran su necesidad a traves de esta interfaz, y el modulo de
 * Identidad la implementa en su capa de infraestructura.
 */
public interface UsuarioConsultaPort {

    /** Vista minima y de solo lectura de un usuario, sin datos sensibles. */
    record InfoUsuario(Long idUsuario, String nombreCompleto, String email, Set<String> roles, boolean activo) {

        public boolean esAdmin() {
            return roles.contains("ROLE_ADMIN") || roles.contains("ROLE_SUPER_ADMIN");
        }

        public boolean esProveedor() {
            return roles.contains("ROLE_PROVEEDOR");
        }

        public boolean esCliente() {
            return roles.contains("ROLE_CLIENTE");
        }
    }

    /** Usuario dueno de ese correo. Lanza ResourceNotFoundException si no existe. */
    InfoUsuario obtenerPorEmail(String email);

    Optional<InfoUsuario> buscarPorId(Long idUsuario);
}
