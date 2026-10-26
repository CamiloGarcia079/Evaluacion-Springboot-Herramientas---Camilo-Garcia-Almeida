package com.rentaherramientas.modules.identidad.infrastructure.adapters.out.kernel;

import com.rentaherramientas.common.exception.ResourceNotFoundException;
import com.rentaherramientas.common.kernel.UsuarioConsultaPort;
import com.rentaherramientas.modules.identidad.domain.model.Usuario;
import com.rentaherramientas.modules.identidad.domain.model.valueobjects.Email;
import com.rentaherramientas.modules.identidad.domain.ports.out.UsuarioRepositoryPort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.Set;

/**
 * Implementacion del puerto compartido de consulta de usuarios.
 * Es el unico punto por el que los demas modulos leen datos de Identidad.
 */
@Component
@RequiredArgsConstructor
public class UsuarioConsultaAdapter implements UsuarioConsultaPort {

    private final UsuarioRepositoryPort usuarioRepository;

    @Override
    @Transactional(readOnly = true)
    public InfoUsuario obtenerPorEmail(String email) {
        return usuarioRepository.buscarPorEmail(new Email(email))
                .map(this::aInfo)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "No existe un usuario registrado con el correo " + email));
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<InfoUsuario> buscarPorId(Long idUsuario) {
        if (idUsuario == null) {
            return Optional.empty();
        }
        return usuarioRepository.buscarPorId(idUsuario).map(this::aInfo);
    }

    private InfoUsuario aInfo(Usuario u) {
        return new InfoUsuario(
                u.getIdUsuario(),
                u.getNombreCompleto(),
                u.getEmail().valor(),
                Set.copyOf(u.nombresDeRoles()),
                u.isActivo());
    }
}
