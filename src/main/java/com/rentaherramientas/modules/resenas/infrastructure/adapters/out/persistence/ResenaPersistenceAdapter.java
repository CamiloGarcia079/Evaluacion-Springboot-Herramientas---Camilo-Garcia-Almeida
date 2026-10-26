package com.rentaherramientas.modules.resenas.infrastructure.adapters.out.persistence;

import com.rentaherramientas.modules.resenas.domain.model.Resena;
import com.rentaherramientas.modules.resenas.domain.model.ResumenCalificacion;
import com.rentaherramientas.modules.resenas.domain.ports.out.ResenaRepositoryPort;
import com.rentaherramientas.modules.resenas.infrastructure.adapters.out.persistence.entity.ResenaJpaEntity;
import com.rentaherramientas.modules.resenas.infrastructure.adapters.out.persistence.repository.SpringDataResenaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ResenaPersistenceAdapter implements ResenaRepositoryPort {

    private final SpringDataResenaRepository repository;

    @Override
    public Resena guardar(Resena resena) {
        return toDomain(repository.save(toEntity(resena)));
    }

    @Override
    public Optional<Resena> buscarPorId(Long idResena) {
        return repository.findById(idResena).map(this::toDomain);
    }

    @Override
    public List<Resena> buscarPorHerramienta(Long idHerramienta) {
        return repository.findByIdHerramientaOrderByFechaResenaDesc(idHerramienta).stream().map(this::toDomain).toList();
    }

    @Override
    public List<Resena> buscarPorCliente(Long idCliente) {
        return repository.findByIdClienteOrderByFechaResenaDesc(idCliente).stream().map(this::toDomain).toList();
    }

    @Override
    public boolean existe(Long idReserva, Long idHerramienta) {
        return repository.existsByIdReservaAndIdHerramienta(idReserva, idHerramienta);
    }

    @Override
    public void eliminar(Long idResena) {
        repository.deleteById(idResena);
    }

    @Override
    public Optional<ResumenCalificacion> resumenDe(Long idHerramienta) {
        return repository.resumenDeHerramienta(idHerramienta).stream().findFirst().map(this::toResumen);
    }

    @Override
    public List<ResumenCalificacion> resumenes() {
        return repository.resumenPorHerramienta().stream().map(this::toResumen).toList();
    }

    private ResumenCalificacion toResumen(Object[] fila) {
        return ResumenCalificacion.de(((Number) fila[0]).longValue(),
                fila[1] == null ? null : ((Number) fila[1]).doubleValue(),
                fila[2] == null ? 0L : ((Number) fila[2]).longValue());
    }

    private ResenaJpaEntity toEntity(Resena r) {
        return ResenaJpaEntity.builder()
                .idResena(r.getIdResena())
                .idHerramienta(r.getIdHerramienta())
                .idCliente(r.getIdCliente())
                .idReserva(r.getIdReserva())
                .calificacion(r.getCalificacion())
                .comentario(r.getComentario())
                .fechaResena(r.getFechaResena())
                .build();
    }

    private Resena toDomain(ResenaJpaEntity e) {
        return Resena.builder()
                .idResena(e.getIdResena())
                .idHerramienta(e.getIdHerramienta())
                .idCliente(e.getIdCliente())
                .idReserva(e.getIdReserva())
                .calificacion(e.getCalificacion())
                .comentario(e.getComentario())
                .fechaResena(e.getFechaResena())
                .build();
    }
}
