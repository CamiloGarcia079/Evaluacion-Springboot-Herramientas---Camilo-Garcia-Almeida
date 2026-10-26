package com.rentaherramientas.modules.resenas.domain.model;

import com.rentaherramientas.common.exception.BusinessRuleException;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Calificacion que deja un cliente sobre una herramienta que ya alquilo.
 *
 * Reglas del dominio: la nota va de 1 a 5 estrellas y el comentario es
 * opcional pero no puede pasar de 500 caracteres. Que el cliente de verdad
 * haya alquilado la herramienta lo valida el servicio, porque necesita
 * consultar el modulo de Reservas.
 */
@Getter
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class Resena {

    public static final int CALIFICACION_MINIMA = 1;
    public static final int CALIFICACION_MAXIMA = 5;
    public static final int MAX_COMENTARIO = 500;

    private Long idResena;
    private Long idHerramienta;
    private Long idCliente;
    private Long idReserva;
    private Integer calificacion;
    private String comentario;
    private LocalDateTime fechaResena;

    /** Solo para mostrar; no se guardan en la tabla. */
    private String nombreCliente;
    private String nombreHerramienta;

    public static Resena nueva(Long idHerramienta, Long idCliente, Long idReserva, Integer calificacion, String comentario) {
        validar(calificacion, comentario);
        return Resena.builder()
                .idHerramienta(idHerramienta)
                .idCliente(idCliente)
                .idReserva(idReserva)
                .calificacion(calificacion)
                .comentario(limpiar(comentario))
                .fechaResena(LocalDateTime.now())
                .build();
    }

    public void editar(Integer nuevaCalificacion, String nuevoComentario) {
        validar(nuevaCalificacion, nuevoComentario);
        this.calificacion = nuevaCalificacion;
        this.comentario = limpiar(nuevoComentario);
        this.fechaResena = LocalDateTime.now();
    }

    public boolean esDe(Long idUsuario) {
        return idUsuario != null && idUsuario.equals(this.idCliente);
    }

    public void mostrarComo(String nombreCliente) {
        this.nombreCliente = nombreCliente;
    }

    public void mostrarHerramienta(String nombreHerramienta) {
        this.nombreHerramienta = nombreHerramienta;
    }

    private static void validar(Integer calificacion, String comentario) {
        if (calificacion == null || calificacion < CALIFICACION_MINIMA || calificacion > CALIFICACION_MAXIMA) {
            throw new BusinessRuleException("La calificación debe estar entre "
                    + CALIFICACION_MINIMA + " y " + CALIFICACION_MAXIMA + " estrellas");
        }
        if (comentario != null && comentario.trim().length() > MAX_COMENTARIO) {
            throw new BusinessRuleException("El comentario no puede superar " + MAX_COMENTARIO + " caracteres");
        }
    }

    private static String limpiar(String comentario) {
        return (comentario == null || comentario.isBlank()) ? null : comentario.trim();
    }
}
