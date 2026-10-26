package com.rentaherramientas.modules.inventario.infrastructure.adapters.out.persistence.mapper;

import com.rentaherramientas.modules.inventario.domain.model.Categoria;
import com.rentaherramientas.modules.inventario.domain.model.EspecificacionTecnica;
import com.rentaherramientas.modules.inventario.domain.model.Herramienta;
import com.rentaherramientas.modules.inventario.domain.model.ImagenHerramienta;
import com.rentaherramientas.modules.inventario.domain.model.TarifaAlquiler;
import com.rentaherramientas.modules.inventario.infrastructure.adapters.out.persistence.entity.CategoriaJpaEntity;
import com.rentaherramientas.modules.inventario.infrastructure.adapters.out.persistence.entity.EspecificacionTecnicaJpaEntity;
import com.rentaherramientas.modules.inventario.infrastructure.adapters.out.persistence.entity.HerramientaJpaEntity;
import com.rentaherramientas.modules.inventario.infrastructure.adapters.out.persistence.entity.ImagenHerramientaJpaEntity;
import com.rentaherramientas.modules.inventario.infrastructure.adapters.out.persistence.entity.TarifaHerramientaJpaEntity;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/** Traductor entre el dominio del inventario y sus entidades JPA. */
@Component
public class HerramientaPersistenceMapper {

    // ------------------------------------------------------------------
    // JPA -> DOMINIO
    // ------------------------------------------------------------------

    public Herramienta toDomain(HerramientaJpaEntity entity) {
        if (entity == null) {
            return null;
        }

        List<ImagenHerramienta> imagenes = entity.getImagenes() == null ? new ArrayList<>()
                : entity.getImagenes().stream().map(this::toImagenDomain)
                        .collect(Collectors.toCollection(ArrayList::new));

        List<EspecificacionTecnica> especificaciones = entity.getEspecificaciones() == null
                ? new ArrayList<>()
                : entity.getEspecificaciones().stream().map(this::toEspecificacionDomain)
                        .collect(Collectors.toCollection(ArrayList::new));

        List<TarifaAlquiler> tarifas = entity.getTarifas() == null ? new ArrayList<>()
                : entity.getTarifas().stream().map(this::toTarifaDomain)
                        .collect(Collectors.toCollection(ArrayList::new));

        Set<Categoria> categorias = entity.getCategorias() == null ? new HashSet<>()
                : entity.getCategorias().stream().map(this::toCategoriaDomain)
                        .collect(Collectors.toCollection(HashSet::new));

        return Herramienta.builder()
                .idHerramienta(entity.getIdHerramienta())
                .idProveedor(entity.getIdProveedor())
                .nombre(entity.getNombre())
                .descripcion(entity.getDescripcion())
                .marca(entity.getMarca())
                .modelo(entity.getModelo())
                .numeroSerie(entity.getNumeroSerie())
                .estadoOperativo(entity.getEstadoOperativo())
                .tarifaDiaria(entity.getTarifaDiaria())
                .valorReposicion(entity.getValorReposicion())
                .ubicacionBodega(entity.getUbicacionBodega())
                .fechaRegistro(entity.getFechaRegistro())
                .categoriaPrincipal(toCategoriaDomain(entity.getCategoriaPrincipal()))
                .categorias(categorias)
                .imagenes(imagenes)
                .especificaciones(especificaciones)
                .tarifas(tarifas)
                .build();
    }

    public Categoria toCategoriaDomain(CategoriaJpaEntity entity) {
        if (entity == null) {
            return null;
        }
        return Categoria.builder()
                .idCategoria(entity.getIdCategoria())
                .nombre(entity.getNombre())
                .descripcion(entity.getDescripcion())
                .build();
    }

    public ImagenHerramienta toImagenDomain(ImagenHerramientaJpaEntity entity) {
        if (entity == null) {
            return null;
        }
        return ImagenHerramienta.builder()
                .idImagen(entity.getIdImagen())
                .idHerramienta(entity.getHerramienta() != null
                        ? entity.getHerramienta().getIdHerramienta() : null)
                .urlFoto(entity.getUrlFoto())
                .descripcion(entity.getDescripcion())
                .principal(entity.isPrincipal())
                .orden(entity.getOrden())
                .build();
    }

    public EspecificacionTecnica toEspecificacionDomain(EspecificacionTecnicaJpaEntity entity) {
        if (entity == null) {
            return null;
        }
        return EspecificacionTecnica.builder()
                .idEspecificacion(entity.getIdEspecificacion())
                .idHerramienta(entity.getHerramienta() != null
                        ? entity.getHerramienta().getIdHerramienta() : null)
                .atributo(entity.getAtributo())
                .valor(entity.getValor())
                .unidadMedida(entity.getUnidadMedida())
                .build();
    }

    public TarifaAlquiler toTarifaDomain(TarifaHerramientaJpaEntity entity) {
        if (entity == null) {
            return null;
        }
        return TarifaAlquiler.builder()
                .idTarifa(entity.getIdTarifa())
                .idHerramienta(entity.getHerramienta() != null
                        ? entity.getHerramienta().getIdHerramienta() : null)
                .tipoTarifa(entity.getTipoTarifa())
                .valor(entity.getValor())
                .activa(entity.isActiva())
                .build();
    }

    // ------------------------------------------------------------------
    // DOMINIO -> JPA
    // ------------------------------------------------------------------

    /**
     * Vuelca el agregado sobre la entidad JPA.
     *
     * Para las colecciones hijas se vacia y se vuelve a llenar la lista
     * existente (no se reemplaza por una nueva). Es importante hacerlo asi
     * porque con orphanRemoval = true Hibernate lanza error si se le cambia
     * la referencia de la coleccion que el esta administrando.
     */
    public HerramientaJpaEntity toEntity(Herramienta herramienta,
                                         HerramientaJpaEntity existente,
                                         CategoriaJpaEntity categoriaPrincipal,
                                         Set<CategoriaJpaEntity> categorias) {

        HerramientaJpaEntity entity = (existente != null) ? existente : new HerramientaJpaEntity();

        entity.setIdHerramienta(herramienta.getIdHerramienta());
        entity.setIdProveedor(herramienta.getIdProveedor());
        entity.setCategoriaPrincipal(categoriaPrincipal);
        entity.setNombre(herramienta.getNombre());
        entity.setDescripcion(herramienta.getDescripcion());
        entity.setMarca(herramienta.getMarca());
        entity.setModelo(herramienta.getModelo());
        entity.setNumeroSerie(herramienta.getNumeroSerie());
        entity.setEstadoOperativo(herramienta.getEstadoOperativo());
        entity.setTarifaDiaria(herramienta.getTarifaDiaria());
        entity.setValorReposicion(herramienta.getValorReposicion());
        entity.setUbicacionBodega(herramienta.getUbicacionBodega());
        entity.setFechaRegistro(herramienta.getFechaRegistro());

        if (categorias != null) {
            if (entity.getCategorias() == null) {
                entity.setCategorias(new HashSet<>());
            }
            entity.getCategorias().clear();
            entity.getCategorias().addAll(categorias);
        }

        // Los hijos (imagenes, ficha tecnica, tarifas) se sincronizan en lugar de borrarse y
        // volver a insertarse: Hibernate inserta antes de borrar, y las restricciones UNIQUE
        // (id_herramienta + url / atributo / tipo) fallaban con "Duplicate entry" en cualquier
        // cambio de estado de la herramienta.
        sincronizarImagenes(entity, herramienta.getImagenes());
        sincronizarEspecificaciones(entity, herramienta.getEspecificaciones());
        sincronizarTarifas(entity, herramienta.getTarifas());

        return entity;
    }

    private void sincronizarImagenes(HerramientaJpaEntity entity, List<ImagenHerramienta> nuevas) {
        List<ImagenHerramienta> lista = nuevas == null ? List.of() : nuevas;
        if (entity.getImagenes() == null) {
            entity.setImagenes(new ArrayList<>());
        }
        entity.getImagenes().removeIf(actual -> lista.stream()
                .noneMatch(n -> n.getUrlFoto().equals(actual.getUrlFoto())));
        for (ImagenHerramienta n : lista) {
            ImagenHerramientaJpaEntity actual = entity.getImagenes().stream()
                    .filter(i -> i.getUrlFoto().equals(n.getUrlFoto())).findFirst().orElse(null);
            if (actual == null) {
                entity.agregarImagen(ImagenHerramientaJpaEntity.builder()
                        .urlFoto(n.getUrlFoto()).descripcion(n.getDescripcion())
                        .principal(n.isPrincipal()).orden(n.getOrden()).build());
            } else {
                actual.setDescripcion(n.getDescripcion());
                actual.setPrincipal(n.isPrincipal());
                actual.setOrden(n.getOrden());
            }
        }
    }

    private void sincronizarEspecificaciones(HerramientaJpaEntity entity, List<EspecificacionTecnica> nuevas) {
        List<EspecificacionTecnica> lista = nuevas == null ? List.of() : nuevas;
        if (entity.getEspecificaciones() == null) {
            entity.setEspecificaciones(new ArrayList<>());
        }
        entity.getEspecificaciones().removeIf(actual -> lista.stream()
                .noneMatch(n -> n.getAtributo().equals(actual.getAtributo())));
        for (EspecificacionTecnica n : lista) {
            EspecificacionTecnicaJpaEntity actual = entity.getEspecificaciones().stream()
                    .filter(e -> e.getAtributo().equals(n.getAtributo())).findFirst().orElse(null);
            if (actual == null) {
                entity.agregarEspecificacion(EspecificacionTecnicaJpaEntity.builder()
                        .atributo(n.getAtributo()).valor(n.getValor()).unidadMedida(n.getUnidadMedida()).build());
            } else {
                actual.setValor(n.getValor());
                actual.setUnidadMedida(n.getUnidadMedida());
            }
        }
    }

    private void sincronizarTarifas(HerramientaJpaEntity entity, List<TarifaAlquiler> nuevas) {
        List<TarifaAlquiler> lista = nuevas == null ? List.of() : nuevas;
        if (entity.getTarifas() == null) {
            entity.setTarifas(new ArrayList<>());
        }
        entity.getTarifas().removeIf(actual -> lista.stream()
                .noneMatch(n -> n.getTipoTarifa() == actual.getTipoTarifa()));
        for (TarifaAlquiler n : lista) {
            TarifaHerramientaJpaEntity actual = entity.getTarifas().stream()
                    .filter(t -> t.getTipoTarifa() == n.getTipoTarifa()).findFirst().orElse(null);
            if (actual == null) {
                entity.agregarTarifa(TarifaHerramientaJpaEntity.builder()
                        .tipoTarifa(n.getTipoTarifa()).valor(n.getValor()).activa(n.isActiva()).build());
            } else {
                actual.setValor(n.getValor());
                actual.setActiva(n.isActiva());
            }
        }
    }

    public CategoriaJpaEntity toCategoriaEntity(Categoria categoria, CategoriaJpaEntity existente) {
        CategoriaJpaEntity entity = (existente != null) ? existente : new CategoriaJpaEntity();
        entity.setIdCategoria(categoria.getIdCategoria());
        entity.setNombre(categoria.getNombre());
        entity.setDescripcion(categoria.getDescripcion());
        return entity;
    }
}
