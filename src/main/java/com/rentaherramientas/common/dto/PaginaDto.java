package com.rentaherramientas.common.dto;

import com.rentaherramientas.common.exception.BusinessRuleException;

import java.util.List;

/**
 * Una pagina de resultados.
 *
 * @param contenido      elementos de la pagina pedida
 * @param pagina         numero de pagina, empieza en 0
 * @param tamanio        elementos por pagina
 * @param totalElementos total de resultados que cumplen el filtro
 * @param totalPaginas   cantidad de paginas
 * @param primera        true si es la primera pagina
 * @param ultima         true si es la ultima pagina
 */
public record PaginaDto<T>(List<T> contenido,
                           int pagina,
                           int tamanio,
                           long totalElementos,
                           int totalPaginas,
                           boolean primera,
                           boolean ultima) {

    public static final int TAMANIO_MAXIMO = 50;

    /** Corta una lista ya filtrada y ordenada. */
    public static <T> PaginaDto<T> de(List<T> todos, int pagina, int tamanio) {
        if (pagina < 0) {
            throw new BusinessRuleException("El número de página no puede ser negativo");
        }
        if (tamanio < 1 || tamanio > TAMANIO_MAXIMO) {
            throw new BusinessRuleException("El tamaño de página debe estar entre 1 y " + TAMANIO_MAXIMO);
        }
        int total = todos.size();
        int totalPaginas = total == 0 ? 0 : (int) Math.ceil((double) total / tamanio);
        int desde = Math.min(pagina * tamanio, total);
        int hasta = Math.min(desde + tamanio, total);
        return new PaginaDto<>(List.copyOf(todos.subList(desde, hasta)), pagina, tamanio, total, totalPaginas,
                pagina == 0, totalPaginas == 0 || pagina >= totalPaginas - 1);
    }
}
