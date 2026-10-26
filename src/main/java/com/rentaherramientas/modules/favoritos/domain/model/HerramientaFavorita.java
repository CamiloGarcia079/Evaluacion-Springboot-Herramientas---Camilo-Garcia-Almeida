package com.rentaherramientas.modules.favoritos.domain.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/** Vista para la lista de favoritos: datos basicos de la herramienta guardada. */
public record HerramientaFavorita(Long idHerramienta,
                                  String nombre,
                                  String marca,
                                  String modelo,
                                  BigDecimal tarifaDiaria,
                                  String estadoOperativo,
                                  boolean disponible,
                                  String imagenPrincipal,
                                  LocalDateTime fechaAgregado) {
}
