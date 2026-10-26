package com.rentaherramientas.modules.resenas.application.service;

import com.rentaherramientas.common.exception.AccesoDenegadoException;
import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort.InfoHerramienta;
import com.rentaherramientas.common.kernel.ReservaConsultaPort;
import com.rentaherramientas.common.kernel.ReservaConsultaPort.InfoReserva;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.resenas.domain.model.Resena;
import com.rentaherramientas.modules.resenas.domain.model.ResenaPendiente;
import com.rentaherramientas.modules.resenas.domain.model.ResumenCalificacion;
import com.rentaherramientas.modules.resenas.domain.ports.in.GestionarResenaUseCase;
import com.rentaherramientas.modules.resenas.domain.ports.out.ResenaRepositoryPort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Resenas y calificaciones de herramientas.
 *
 * Reglas:
 *  - Solo califica quien alquilo: la reserva debe ser del cliente, estar
 *    FINALIZADA e incluir la herramienta.
 *  - Una resena por herramienta y por reserva (no se puede inflar la nota
 *    calificando varias veces el mismo alquiler).
 *  - Edita solo el autor; elimina el autor o un administrador (moderacion).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ResenaApplicationService implements GestionarResenaUseCase {

    private final ResenaRepositoryPort resenaRepositoryPort;
    private final UsuarioConsultaPort usuarioConsultaPort;
    private final ReservaConsultaPort reservaConsultaPort;
    private final HerramientaConsultaPort herramientaConsultaPort;

    @Override
    @Transactional
    public Resena publicar(String emailCliente, Long idReserva, Long idHerramienta, Integer calificacion, String comentario) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        InfoReserva reserva = reservaConsultaPort.buscarPorId(idReserva)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la reserva con ID: " + idReserva));

        if (!cliente.idUsuario().equals(reserva.idCliente())) {
            throw new AccesoDenegadoException("Solo puede calificar herramientas de sus propias reservas");
        }
        if (!"FINALIZADA".equals(reserva.estado())) {
            throw new BusinessRuleException("Solo se pueden calificar herramientas de alquileres FINALIZADOS (estado actual: "
                    + reserva.estado() + ")");
        }
        if (!reserva.idsHerramientas().contains(idHerramienta)) {
            throw new BusinessRuleException("La herramienta con ID " + idHerramienta + " no hace parte de la reserva "
                    + reserva.codigoReserva());
        }
        if (resenaRepositoryPort.existe(idReserva, idHerramienta)) {
            throw new BusinessRuleException("Ya calificó esta herramienta para la reserva " + reserva.codigoReserva()
                    + ". Puede editar su reseña existente");
        }

        Resena guardada = resenaRepositoryPort.guardar(
                Resena.nueva(idHerramienta, cliente.idUsuario(), idReserva, calificacion, comentario));
        guardada.mostrarComo(cliente.nombreCompleto());
        log.info("Reseña {} publicada por {} para la herramienta {} ({} estrellas)",
                guardada.getIdResena(), emailCliente, idHerramienta, calificacion);
        return guardada;
    }

    @Override
    @Transactional
    public Resena editar(String emailCliente, Long idResena, Integer calificacion, String comentario) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        Resena resena = cargar(idResena);
        if (!resena.esDe(cliente.idUsuario())) {
            throw new AccesoDenegadoException("Solo el autor puede editar la reseña");
        }
        resena.editar(calificacion, comentario);
        Resena actualizada = resenaRepositoryPort.guardar(resena);
        actualizada.mostrarComo(cliente.nombreCompleto());
        return actualizada;
    }

    @Override
    @Transactional
    public void eliminar(String emailSolicitante, Long idResena) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Resena resena = cargar(idResena);
        if (!resena.esDe(actor.idUsuario()) && !actor.esAdmin()) {
            throw new AccesoDenegadoException("Solo el autor o un administrador pueden eliminar la reseña");
        }
        resenaRepositoryPort.eliminar(idResena);
        log.info("Reseña {} eliminada por {}", idResena, emailSolicitante);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Resena> listarPorHerramienta(Long idHerramienta) {
        exigirHerramienta(idHerramienta);
        return conNombres(resenaRepositoryPort.buscarPorHerramienta(idHerramienta));
    }

    @Override
    @Transactional(readOnly = true)
    public ResumenCalificacion resumenDeHerramienta(Long idHerramienta) {
        exigirHerramienta(idHerramienta);
        return resenaRepositoryPort.resumenDe(idHerramienta).orElse(ResumenCalificacion.vacio(idHerramienta));
    }

    @Override
    @Transactional(readOnly = true)
    public List<ResumenCalificacion> resumenGeneral() {
        return resenaRepositoryPort.resumenes();
    }

    @Override
    @Transactional(readOnly = true)
    public List<Resena> misResenas(String emailCliente) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        List<Resena> resenas = resenaRepositoryPort.buscarPorCliente(cliente.idUsuario());
        Map<Long, Optional<InfoHerramienta>> cache = new HashMap<>();
        for (Resena r : resenas) {
            r.mostrarComo(cliente.nombreCompleto());
            cache.computeIfAbsent(r.getIdHerramienta(), herramientaConsultaPort::buscarPorId)
                    .ifPresent(h -> r.mostrarHerramienta(h.nombre()));
        }
        return resenas;
    }

    @Override
    @Transactional(readOnly = true)
    public List<ResenaPendiente> pendientesPorCalificar(String emailCliente) {
        InfoUsuario cliente = usuarioConsultaPort.obtenerPorEmail(emailCliente);
        List<ResenaPendiente> pendientes = new ArrayList<>();
        for (Long idReserva : reservaConsultaPort.idsDeReservasDelCliente(cliente.idUsuario())) {
            Optional<InfoReserva> reserva = reservaConsultaPort.buscarPorId(idReserva);
            if (reserva.isEmpty() || !"FINALIZADA".equals(reserva.get().estado())) {
                continue;
            }
            for (Long idHerramienta : reserva.get().idsHerramientas()) {
                if (resenaRepositoryPort.existe(idReserva, idHerramienta)) {
                    continue;
                }
                Optional<InfoHerramienta> h = herramientaConsultaPort.buscarPorId(idHerramienta);
                pendientes.add(new ResenaPendiente(idReserva, reserva.get().codigoReserva(), idHerramienta,
                        h.map(InfoHerramienta::nombre).orElse("Herramienta #" + idHerramienta),
                        h.map(InfoHerramienta::imagenPrincipal).orElse(null),
                        reserva.get().fechaFin()));
            }
        }
        return pendientes;
    }

    private Resena cargar(Long idResena) {
        return resenaRepositoryPort.buscarPorId(idResena)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la reseña con ID: " + idResena));
    }

    private void exigirHerramienta(Long idHerramienta) {
        if (herramientaConsultaPort.buscarPorId(idHerramienta).isEmpty()) {
            throw new ResourceNotFoundException("No se encontró la herramienta con ID " + idHerramienta);
        }
    }

    private List<Resena> conNombres(List<Resena> resenas) {
        Map<Long, Optional<InfoUsuario>> cache = new HashMap<>();
        for (Resena r : resenas) {
            cache.computeIfAbsent(r.getIdCliente(), usuarioConsultaPort::buscarPorId)
                    .ifPresent(u -> r.mostrarComo(u.nombreCompleto()));
        }
        return resenas;
    }
}
