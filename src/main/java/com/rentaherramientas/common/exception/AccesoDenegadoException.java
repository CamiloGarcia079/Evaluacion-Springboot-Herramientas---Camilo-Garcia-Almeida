package com.rentaherramientas.common.exception;

/**
 * El usuario esta autenticado y su rol le permite usar el endpoint, pero el
 * recurso concreto no es suyo (por ejemplo, la reserva de otro cliente).
 *
 * Se lanza desde la capa de aplicacion sin depender de Spring Security; el
 * GlobalExceptionHandler la traduce a un 403.
 */
public class AccesoDenegadoException extends RuntimeException {
    public AccesoDenegadoException(String message) {
        super(message);
    }
}
