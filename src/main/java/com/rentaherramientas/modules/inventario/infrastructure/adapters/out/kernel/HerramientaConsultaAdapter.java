package com.rentaherramientas.modules.inventario.infrastructure.adapters.out.kernel;

import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.modules.inventario.domain.model.EstadoHerramienta;
import com.rentaherramientas.modules.inventario.domain.model.Herramienta;
import com.rentaherramientas.modules.inventario.domain.model.ImagenHerramienta;
import com.rentaherramientas.modules.inventario.domain.ports.out.HerramientaRepositoryPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

/**
 * Implementacion del puerto compartido de herramientas.
 *
 * Los cambios de estado pasan por el modelo de dominio (Herramienta.cambiarEstado),
 * asi que las mismas reglas de transicion aplican sin importar que modulo las pida.
 */
@Component
@RequiredArgsConstructor
public class HerramientaConsultaAdapter implements HerramientaConsultaPort {

    private final HerramientaRepositoryPort herramientaRepository;

    @Override
    @Transactional(readOnly = true)
    public Optional<InfoHerramienta> buscarPorId(Long idHerramienta) {
        if (idHerramienta == null) {
            return Optional.empty();
        }
        return herramientaRepository.buscarPorId(idHerramienta).map(this::aInfo);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> idsDeProveedor(Long idProveedor) {
        return herramientaRepository.listarPorProveedor(idProveedor).stream()
                .map(Herramienta::getIdHerramienta)
                .toList();
    }

    @Override
    @Transactional
    public void cambiarEstado(Long idHerramienta, String nuevoEstado) {
        Herramienta herramienta = herramientaRepository.buscarPorId(idHerramienta)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "No se encontro la herramienta con id " + idHerramienta));

        EstadoHerramienta destino;
        try {
            destino = EstadoHerramienta.valueOf(nuevoEstado);
        } catch (IllegalArgumentException | NullPointerException ex) {
            throw new BusinessRuleException("Estado de herramienta desconocido: " + nuevoEstado);
        }

        // Si ya esta en ese estado no hay nada que hacer: evita errores al
        // repetir una operacion (por ejemplo, devolver dos veces la misma).
        if (herramienta.getEstadoOperativo() == destino) {
            return;
        }
        herramienta.cambiarEstado(destino);
        herramientaRepository.guardar(herramienta);
    }

    private InfoHerramienta aInfo(Herramienta h) {
        String imagen = h.imagenPrincipal().map(ImagenHerramienta::getUrlFoto).orElse(null);
        return new InfoHerramienta(
                h.getIdHerramienta(),
                h.getNombre(),
                h.getMarca(),
                h.getModelo(),
                h.getTarifaDiaria(),
                h.getEstadoOperativo().name(),
                h.getIdProveedor(),
                imagen);
    }
}
