package com.rentaherramientas.modules.resenas.infrastructure.adapters.out.persistence.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Table(name = "resenas_herramienta",
        uniqueConstraints = @UniqueConstraint(name = "uq_resena_reserva_herramienta", columnNames = {"id_reserva", "id_herramienta"}))
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ResenaJpaEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_resena")
    private Long idResena;

    @Column(name = "id_herramienta", nullable = false)
    private Long idHerramienta;

    @Column(name = "id_cliente", nullable = false)
    private Long idCliente;

    @Column(name = "id_reserva", nullable = false)
    private Long idReserva;

    @Column(name = "calificacion", nullable = false)
    private Integer calificacion;

    @Column(name = "comentario", length = 500)
    private String comentario;

    @Column(name = "fecha_resena", nullable = false)
    private LocalDateTime fechaResena;
}
