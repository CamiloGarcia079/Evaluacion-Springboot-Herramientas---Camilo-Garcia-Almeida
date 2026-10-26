package com.rentaherramientas.modules.reservas.domain.ports.out;

import com.rentaherramientas.modules.reservas.domain.model.EstadoReserva;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface ReservaRepositoryPort {
    Reserva guardar(Reserva reserva);
    Optional<Reserva> buscarPorId(Long id);
    Optional<Reserva> buscarPorCodigo(String codigo);
    List<Reserva> buscarPorCliente(Long idCliente);
    List<Reserva> buscarTodas();

    /** Reservas que incluyen al menos una de esas herramientas. */
    List<Reserva> buscarPorHerramientas(Collection<Long> idsHerramientas);

    /** Reservas de la herramienta en esos estados cuyo rango se cruza con [desde, hasta]. */
    List<Reserva> buscarQueSeCruzan(Long idHerramienta, LocalDate desde, LocalDate hasta, Collection<EstadoReserva> estados);

    /**
     * True si otra reserva APROBADA o EN_CURSO ya compromete la herramienta en ese rango.
     * @param idReservaExcluida reserva que no se cuenta (la que se esta aprobando); puede ser null
     */
    boolean existeConflictoFechas(Long idHerramienta, LocalDate inicio, LocalDate fin, Long idReservaExcluida);
}
