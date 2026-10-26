package com.rentaherramientas.modules.mantenimientos.application.service;

import com.rentaherramientas.common.exception.AccesoDenegadoException;
import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort.InfoHerramienta;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.mantenimientos.domain.model.Mantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.model.TipoMantenimiento;
import com.rentaherramientas.modules.mantenimientos.domain.ports.in.GestionarMantenimientoUseCase;
import com.rentaherramientas.modules.mantenimientos.domain.ports.out.MantenimientoRepositoryPort;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Historial de mantenimiento de las herramientas.
 *
 * Reglas:
 *  - Solo el proveedor dueno de la herramienta o un administrador registran y
 *    cierran mantenimientos.
 *  - No se manda a mantenimiento una herramienta ALQUILADA (la tiene el
 *    cliente) ni se abren dos mantenimientos a la vez para la misma.
 *  - Abrir pone la herramienta EN_MANTENIMIENTO (sale del catalogo y no se
 *    puede despachar); cerrar la devuelve a DISPONIBLE o la da de baja.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MantenimientoApplicationService implements GestionarMantenimientoUseCase {

    private final MantenimientoRepositoryPort mantenimientoRepositoryPort;
    private final UsuarioConsultaPort usuarioConsultaPort;
    private final HerramientaConsultaPort herramientaConsultaPort;

    @Override
    @Transactional
    public Mantenimiento registrar(String emailSolicitante, Long idHerramienta, TipoMantenimiento tipo, String descripcion) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        InfoHerramienta herramienta = herramientaPropia(actor, idHerramienta);

        if ("ALQUILADA".equals(herramienta.estadoOperativo())) {
            throw new BusinessRuleException("La herramienta '" + herramienta.nombre()
                    + "' está alquilada. Registre el mantenimiento cuando el cliente la devuelva");
        }
        if (mantenimientoRepositoryPort.existeAbierto(idHerramienta)) {
            throw new BusinessRuleException("La herramienta '" + herramienta.nombre()
                    + "' ya tiene un mantenimiento en proceso");
        }

        Mantenimiento guardado = mantenimientoRepositoryPort.guardar(
                Mantenimiento.abrir(idHerramienta, tipo, descripcion, actor.idUsuario()));
        herramientaConsultaPort.cambiarEstado(idHerramienta, "EN_MANTENIMIENTO");

        log.info("Mantenimiento {} ({}) abierto para la herramienta {} por {}",
                guardado.getIdMantenimiento(), tipo, idHerramienta, emailSolicitante);
        guardado.mostrarComo(herramienta.nombre());
        return guardado;
    }

    @Override
    @Transactional
    public Mantenimiento finalizar(String emailSolicitante, Long idMantenimiento, BigDecimal costo,
                                   String observaciones, boolean darDeBaja) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Mantenimiento mantenimiento = cargar(idMantenimiento);
        InfoHerramienta herramienta = herramientaPropia(actor, mantenimiento.getIdHerramienta());

        mantenimiento.finalizar(costo, observaciones);
        Mantenimiento guardado = mantenimientoRepositoryPort.guardar(mantenimiento);
        herramientaConsultaPort.cambiarEstado(herramienta.idHerramienta(), darDeBaja ? "FUERA_DE_SERVICIO" : "DISPONIBLE");

        log.info("Mantenimiento {} finalizado. Herramienta {} -> {}", idMantenimiento,
                herramienta.idHerramienta(), darDeBaja ? "FUERA_DE_SERVICIO" : "DISPONIBLE");
        guardado.mostrarComo(herramienta.nombre());
        return guardado;
    }

    @Override
    @Transactional(readOnly = true)
    public Mantenimiento obtener(String emailSolicitante, Long idMantenimiento) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        Mantenimiento mantenimiento = cargar(idMantenimiento);
        mantenimiento.mostrarComo(herramientaPropia(actor, mantenimiento.getIdHerramienta()).nombre());
        return mantenimiento;
    }

    @Override
    @Transactional(readOnly = true)
    public List<Mantenimiento> historialDeHerramienta(String emailSolicitante, Long idHerramienta) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        InfoHerramienta herramienta = herramientaPropia(actor, idHerramienta);
        List<Mantenimiento> historial = mantenimientoRepositoryPort.buscarPorHerramienta(idHerramienta);
        historial.forEach(m -> m.mostrarComo(herramienta.nombre()));
        return historial;
    }

    @Override
    @Transactional(readOnly = true)
    public List<Mantenimiento> listar(String emailSolicitante, boolean soloAbiertos) {
        InfoUsuario actor = usuarioConsultaPort.obtenerPorEmail(emailSolicitante);
        List<Mantenimiento> lista;
        if (actor.esAdmin()) {
            lista = mantenimientoRepositoryPort.buscarTodos();
        } else if (actor.esProveedor()) {
            List<Long> mias = herramientaConsultaPort.idsDeProveedor(actor.idUsuario());
            lista = mias.isEmpty() ? List.of() : mantenimientoRepositoryPort.buscarPorHerramientas(mias);
        } else {
            throw new AccesoDenegadoException("Solo administradores y proveedores consultan mantenimientos");
        }
        List<Mantenimiento> resultado = soloAbiertos
                ? lista.stream().filter(Mantenimiento::estaAbierto).toList()
                : lista;

        Map<Long, Optional<InfoHerramienta>> cache = new HashMap<>();
        resultado.forEach(m -> cache.computeIfAbsent(m.getIdHerramienta(), herramientaConsultaPort::buscarPorId)
                .ifPresent(h -> m.mostrarComo(h.nombre())));
        return resultado;
    }

    private Mantenimiento cargar(Long idMantenimiento) {
        return mantenimientoRepositoryPort.buscarPorId(idMantenimiento)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró el mantenimiento con ID: " + idMantenimiento));
    }

    /** Herramienta existente y del proveedor que hace la peticion (o cualquiera si es admin). */
    private InfoHerramienta herramientaPropia(InfoUsuario actor, Long idHerramienta) {
        InfoHerramienta herramienta = herramientaConsultaPort.buscarPorId(idHerramienta)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la herramienta con ID " + idHerramienta));
        boolean esDuenio = herramienta.idProveedor() != null && herramienta.idProveedor().equals(actor.idUsuario());
        if (!actor.esAdmin() && !esDuenio) {
            throw new AccesoDenegadoException("Solo el proveedor dueño de la herramienta o un administrador pueden gestionar su mantenimiento");
        }
        return herramienta;
    }
}
