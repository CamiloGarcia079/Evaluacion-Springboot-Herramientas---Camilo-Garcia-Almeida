package com.rentaherramientas.modules.favoritos.infrastructure.adapters.out.persistence.entity;

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
@Table(name = "favoritos",
        uniqueConstraints = @UniqueConstraint(name = "uq_favorito_usuario_herramienta", columnNames = {"id_usuario", "id_herramienta"}))
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FavoritoJpaEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_favorito")
    private Long idFavorito;

    @Column(name = "id_usuario", nullable = false)
    private Long idUsuario;

    @Column(name = "id_herramienta", nullable = false)
    private Long idHerramienta;

    @Column(name = "fecha_agregado", nullable = false)
    private LocalDateTime fechaAgregado;
}
