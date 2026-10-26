package com.rentaherramientas.modules.reservas.infrastructure.adapters.out.kernel;

import com.rentaherramientas.common.kernel.ReservaConsultaPort;
import com.rentaherramientas.modules.reservas.domain.model.Reserva;
import com.rentaherramientas.modules.reservas.domain.ports.out.ReservaRepositoryPort;
import com.rentaherramientas.modules.reservas.infrastructure.adapters.out.persistence.repository.SpringDataReservaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/** Implementacion del puerto compartido: lo que los demas modulos pueden leer de una reserva. */
@Component
@RequiredArgsConstructor
public class ReservaConsultaAdapter implements ReservaConsultaPort {

    private final ReservaRepositoryPort reservaRepository;
    private final SpringDataReservaRepository springDataReservaRepository;

    @Override
    @Transactional(readOnly = true)
    public Optional<InfoReserva> buscarPorId(Long idReserva) {
        if (idReserva == null) {
            return Optional.empty();
        }
        return reservaRepository.buscarPorId(idReserva).map(this::aInfo);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> idsDeReservasDelCliente(Long idCliente) {
        return reservaRepository.buscarPorCliente(idCliente).stream().map(Reserva::getIdReserva).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public boolean clienteAlquiloHerramienta(Long idCliente, Long idHerramienta) {
        return springDataReservaRepository.clienteFinalizoAlquiler(idCliente, idHerramienta);
    }

    private InfoReserva aInfo(Reserva r) {
        return new InfoReserva(
                r.getIdReserva(),
                r.getCodigoReserva(),
                r.getIdCliente(),
                r.getEstado().name(),
                r.getRangoFechas().getFechaInicio(),
                r.getRangoFechas().getFechaFin(),
                r.getMontoTotalEstimado(),
                r.getDepositoGarantia(),
                r.idsHerramientas());
    }
}
