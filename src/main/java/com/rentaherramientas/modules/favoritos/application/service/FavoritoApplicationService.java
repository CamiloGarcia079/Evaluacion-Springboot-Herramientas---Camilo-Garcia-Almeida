package com.rentaherramientas.modules.favoritos.application.service;

import com.rentaherramientas.common.exception.BusinessRuleException;
import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort;
import com.rentaherramientas.common.kernel.HerramientaConsultaPort.InfoHerramienta;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort.InfoUsuario;
import com.rentaherramientas.modules.favoritos.domain.model.Favorito;
import com.rentaherramientas.modules.favoritos.domain.model.HerramientaFavorita;
import com.rentaherramientas.modules.favoritos.domain.ports.in.GestionarFavoritosUseCase;
import com.rentaherramientas.modules.favoritos.domain.ports.out.FavoritoRepositoryPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

/**
 * Lista de herramientas favoritas de cada usuario.
 * Un usuario no guarda sus propias herramientas ni las dadas de baja.
 */
@Service
@RequiredArgsConstructor
public class FavoritoApplicationService implements GestionarFavoritosUseCase {

    public static final int MAXIMO_FAVORITOS = 50;

    private final FavoritoRepositoryPort favoritoRepositoryPort;
    private final UsuarioConsultaPort usuarioConsultaPort;
    private final HerramientaConsultaPort herramientaConsultaPort;

    @Override
    @Transactional
    public HerramientaFavorita agregar(String email, Long idHerramienta) {
        InfoUsuario usuario = usuarioConsultaPort.obtenerPorEmail(email);
        InfoHerramienta herramienta = herramientaConsultaPort.buscarPorId(idHerramienta)
                .orElseThrow(() -> new ResourceNotFoundException("No se encontró la herramienta con ID " + idHerramienta));

        var existente = favoritoRepositoryPort.buscar(usuario.idUsuario(), idHerramienta);
        if (existente.isPresent()) {
            return vista(herramienta, existente.get());
        }
        if (usuario.idUsuario().equals(herramienta.idProveedor())) {
            throw new BusinessRuleException("No puede agregar a favoritos una herramienta publicada por usted");
        }
        if (!herramienta.admiteReservas()) {
            throw new BusinessRuleException("La herramienta está fuera de servicio");
        }
        if (favoritoRepositoryPort.buscarPorUsuario(usuario.idUsuario()).size() >= MAXIMO_FAVORITOS) {
            throw new BusinessRuleException("Alcanzó el máximo de " + MAXIMO_FAVORITOS + " favoritos");
        }
        Favorito guardado = favoritoRepositoryPort.guardar(Favorito.nuevo(usuario.idUsuario(), idHerramienta));
        return vista(herramienta, guardado);
    }

    @Override
    @Transactional
    public void quitar(String email, Long idHerramienta) {
        InfoUsuario usuario = usuarioConsultaPort.obtenerPorEmail(email);
        Favorito favorito = favoritoRepositoryPort.buscar(usuario.idUsuario(), idHerramienta)
                .orElseThrow(() -> new ResourceNotFoundException("La herramienta " + idHerramienta + " no está en sus favoritos"));
        favoritoRepositoryPort.eliminar(favorito.idFavorito());
    }

    @Override
    @Transactional(readOnly = true)
    public List<HerramientaFavorita> listar(String email) {
        InfoUsuario usuario = usuarioConsultaPort.obtenerPorEmail(email);
        List<HerramientaFavorita> lista = new ArrayList<>();
        for (Favorito f : favoritoRepositoryPort.buscarPorUsuario(usuario.idUsuario())) {
            herramientaConsultaPort.buscarPorId(f.idHerramienta()).ifPresent(h -> lista.add(vista(h, f)));
        }
        return lista;
    }

    @Override
    @Transactional(readOnly = true)
    public List<Long> idsFavoritos(String email) {
        InfoUsuario usuario = usuarioConsultaPort.obtenerPorEmail(email);
        return favoritoRepositoryPort.buscarPorUsuario(usuario.idUsuario()).stream().map(Favorito::idHerramienta).toList();
    }

    private HerramientaFavorita vista(InfoHerramienta h, Favorito f) {
        return new HerramientaFavorita(h.idHerramienta(), h.nombre(), h.marca(), h.modelo(), h.tarifaDiaria(),
                h.estadoOperativo(), h.estaDisponibleAhora(), h.imagenPrincipal(), f.fechaAgregado());
    }
}
