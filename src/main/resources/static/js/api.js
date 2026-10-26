/* ==========================================================================
   api.js - Comunicacion con el backend Spring Boot (/api/v1)

   Todas las pantallas hablan con el servidor a traves de este archivo.
   No hay datos simulados: si el backend no responde se muestra un error
   claro, porque una pantalla que "funciona" con datos falsos esconde el
   problema real (base de datos sin cargar, servidor apagado, puerto errado).

   Donde esta el backend:
     1. Si la pagina la sirve el propio Spring Boot (http://localhost:8081/api/v1/index.html)
        se usa ese mismo origen. Es la forma recomendada.
     2. Si se abre con Live Server u otro servidor, se prueban en orden los
        puertos 8080, 8081 y 8082 y se recuerda el primero que responda.
   ========================================================================== */

const API = (() => {

    'use strict';

    const CONTEXTO = '/api/v1';
    const PUERTOS_CANDIDATOS = [8080, 8081, 8082];
    const CLAVE_BASE    = 'rh_api_base';
    const CLAVE_ACCESS  = 'rh_access_token';
    const CLAVE_REFRESH = 'rh_refresh_token';
    const CLAVE_USUARIO = 'rh_usuario';

    // La primera peticion a un Spring Boot recien arrancado puede tardar varios
    // segundos (JVM en frio + pool de conexiones), por eso el limite es amplio.
    const TIMEOUT_PETICION_MS = 20000;
    const TIMEOUT_SONDEO_MS   = 2500;

    let urlBase = null;          // se resuelve una sola vez
    let resolviendo = null;      // promesa compartida mientras se busca el backend
    let backendEnLinea = null;   // null = sin verificar

    // ------------------------------------------------------------------
    // Errores
    // ------------------------------------------------------------------

    class ErrorApi extends Error {
        constructor(mensaje, estado, datos) {
            super(mensaje);
            this.name = 'ErrorApi';
            this.estado = estado;
            this.datos = datos;
        }
    }

    // ------------------------------------------------------------------
    // Localizacion del backend
    // ------------------------------------------------------------------

    function servidoPorSpring() {
        return typeof window !== 'undefined'
            && /^https?:$/.test(window.location.protocol)
            && window.location.pathname.startsWith(CONTEXTO + '/');
    }

    async function responde(base) {
        const control = new AbortController();
        const temporizador = setTimeout(() => control.abort(), TIMEOUT_SONDEO_MS);
        try {
            const res = await fetch(base + '/categorias', { signal: control.signal, headers: { 'Accept': 'application/json' } });
            if (!res.ok) return false;
            const json = await res.json().catch(() => null);
            return !!(json && json.success);
        } catch (e) {
            return false;
        } finally {
            clearTimeout(temporizador);
        }
    }

    async function resolverBase() {
        if (urlBase) return urlBase;
        if (servidoPorSpring()) {
            urlBase = window.location.origin + CONTEXTO;
            return urlBase;
        }
        if (resolviendo) return resolviendo;

        resolviendo = (async () => {
            const guardada = leerLocal(CLAVE_BASE);
            const candidatos = [];
            if (guardada) candidatos.push(guardada);
            PUERTOS_CANDIDATOS.forEach(p => {
                const c = `http://localhost:${p}${CONTEXTO}`;
                if (!candidatos.includes(c)) candidatos.push(c);
            });

            for (const candidato of candidatos) {
                if (await responde(candidato)) {
                    escribirLocal(CLAVE_BASE, candidato);
                    return candidato;
                }
            }
            // Nadie respondio: se deja el primero para que el error indique una URL concreta.
            return guardada || candidatos[0];
        })();

        const base = await resolviendo;
        resolviendo = null;
        urlBase = base;
        return base;
    }

    /** Vuelve a buscar el backend (boton "Verificar" de la barra). */
    async function verificarBackend() {
        urlBase = null;
        const base = await resolverBase();
        backendEnLinea = await responde(base);
        if (!backendEnLinea && !servidoPorSpring()) {
            urlBase = null; // en el proximo intento se vuelve a buscar
        }
        notificarEstado();
        return backendEnLinea;
    }

    function notificarEstado() {
        window.dispatchEvent(new CustomEvent('api-status-changed', { detail: { online: backendEnLinea === true } }));
    }

    function esOnline() { return backendEnLinea === true; }

    function baseActual() { return urlBase || (servidoPorSpring() ? window.location.origin + CONTEXTO : leerLocal(CLAVE_BASE) || '(buscando servidor...)'); }

    // ------------------------------------------------------------------
    // Sesion (JWT en localStorage)
    // ------------------------------------------------------------------

    function leerLocal(clave) {
        try { return localStorage.getItem(clave); } catch (e) { return null; }
    }

    function escribirLocal(clave, valor) {
        try { localStorage.setItem(clave, valor); } catch (e) { /* modo privado */ }
    }

    function borrarLocal(clave) {
        try { localStorage.removeItem(clave); } catch (e) { /* modo privado */ }
    }

    function guardarSesion(datos) {
        escribirLocal(CLAVE_ACCESS, datos.accessToken);
        if (datos.refreshToken) escribirLocal(CLAVE_REFRESH, datos.refreshToken);
        escribirLocal(CLAVE_USUARIO, JSON.stringify({
            idUsuario: datos.idUsuario,
            nombreCompleto: datos.nombreCompleto,
            email: datos.email,
            roles: datos.roles || []
        }));
    }

    function borrarSesion() {
        borrarLocal(CLAVE_ACCESS);
        borrarLocal(CLAVE_REFRESH);
        borrarLocal(CLAVE_USUARIO);
    }

    function obtenerToken() { return leerLocal(CLAVE_ACCESS); }

    function obtenerUsuario() {
        try {
            const bruto = leerLocal(CLAVE_USUARIO);
            return bruto ? JSON.parse(bruto) : null;
        } catch (e) {
            return null;
        }
    }

    function haySesion() { return !!obtenerToken() && !!obtenerUsuario(); }

    function tieneRol(rol) {
        const u = obtenerUsuario();
        if (!u || !Array.isArray(u.roles)) return false;
        const buscado = rol.startsWith('ROLE_') ? rol : 'ROLE_' + rol;
        return u.roles.includes(buscado);
    }

    function esAdmin()     { return tieneRol('ROLE_ADMIN') || tieneRol('ROLE_SUPER_ADMIN'); }
    function esProveedor() { return tieneRol('ROLE_PROVEEDOR'); }
    function esCliente()   { return tieneRol('ROLE_CLIENTE'); }

    function rolPrincipal() {
        if (esAdmin()) return 'ADMIN';
        if (esProveedor()) return 'PROVEEDOR';
        if (esCliente()) return 'CLIENTE';
        return 'INVITADO';
    }

    // ------------------------------------------------------------------
    // Peticion generica
    // ------------------------------------------------------------------

    function mensajeDeError(datos, estado) {
        if (datos && datos.message) {
            // Errores de validacion: el backend manda { campo: mensaje }
            if (estado === 400 && datos.data && typeof datos.data === 'object' && !Array.isArray(datos.data)) {
                const detalle = Object.values(datos.data).filter(Boolean).join(' · ');
                if (detalle) return datos.message + ': ' + detalle;
            }
            return datos.message;
        }
        if (estado === 401) return 'Debe iniciar sesión para realizar esta acción.';
        if (estado === 403) return 'No tiene permisos para realizar esta acción.';
        if (estado === 404) return 'El recurso solicitado no existe.';
        return 'Error ' + estado + ' al comunicarse con el servidor.';
    }

    async function peticion(ruta, opciones = {}) {
        const { metodo = 'GET', cuerpo = null, publica = false, reintento = false, texto = false } = opciones;
        const base = await resolverBase();

        const cabeceras = { 'Accept': texto ? 'text/plain, application/json' : 'application/json' };
        if (cuerpo !== null) cabeceras['Content-Type'] = 'application/json';
        const token = obtenerToken();
        if (!publica && token) cabeceras['Authorization'] = 'Bearer ' + token;

        let respuesta;
        const control = new AbortController();
        const temporizador = setTimeout(() => control.abort(), TIMEOUT_PETICION_MS);
        try {
            respuesta = await fetch(base + ruta, {
                method: metodo,
                headers: cabeceras,
                body: cuerpo !== null ? JSON.stringify(cuerpo) : undefined,
                signal: control.signal
            });
        } catch (e) {
            backendEnLinea = false;
            notificarEstado();
            if (!servidoPorSpring()) urlBase = null;
            throw new ErrorApi('No hay conexión con el servidor (' + base + '). '
                + 'Verifique que el backend esté encendido con el script iniciar y vuelva a intentar.', 0, null);
        } finally {
            clearTimeout(temporizador);
        }

        if (backendEnLinea !== true) {
            backendEnLinea = true;
            notificarEstado();
        }

        if (respuesta.status === 401 && !publica && !reintento && leerLocal(CLAVE_REFRESH)) {
            if (await refrescarToken()) {
                return peticion(ruta, { ...opciones, reintento: true });
            }
            borrarSesion();
            throw new ErrorApi('Su sesión expiró. Vuelva a iniciar sesión.', 401, null);
        }

        if (texto && respuesta.ok) {
            return respuesta.text();
        }

        let datos = null;
        if ((respuesta.headers.get('content-type') || '').includes('application/json')) {
            datos = await respuesta.json().catch(() => null);
        }

        if (!respuesta.ok) {
            if (respuesta.status === 401 && !publica) borrarSesion();
            throw new ErrorApi(mensajeDeError(datos, respuesta.status), respuesta.status, datos);
        }

        return (datos && Object.prototype.hasOwnProperty.call(datos, 'data')) ? datos.data : datos;
    }

    async function refrescarToken() {
        try {
            const base = await resolverBase();
            const res = await fetch(base + '/auth/refresh', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
                body: JSON.stringify({ refreshToken: leerLocal(CLAVE_REFRESH) })
            });
            if (!res.ok) return false;
            const json = await res.json();
            if (json && json.data && json.data.accessToken) {
                guardarSesion(json.data);
                return true;
            }
            return false;
        } catch (e) {
            return false;
        }
    }

    function consulta(params) {
        const p = new URLSearchParams();
        Object.entries(params || {}).forEach(([k, v]) => {
            if (v !== null && v !== undefined && v !== '') p.append(k, v);
        });
        const q = p.toString();
        return q ? '?' + q : '';
    }

    // ------------------------------------------------------------------
    // Modulos
    // ------------------------------------------------------------------

    const CUENTAS_DEMO = {
        ADMIN:     { email: 'admin.perez@rentatool.com',  nombre: 'Carlos Pérez (Admin)' },
        PROVEEDOR: { email: 'ventas@maquiantioquia.com',  nombre: 'Maquinaria y Andamios Occidente' },
        CLIENTE:   { email: 'camilo.garcia@gmail.com',    nombre: 'Juan Camilo García' }
    };
    const PASSWORD_DEMO = 'Password123';

    const auth = {
        login: async (email, password) => {
            const datos = await peticion('/auth/login', { metodo: 'POST', cuerpo: { email, password }, publica: true });
            guardarSesion(datos);
            return datos;
        },
        /** Accesos rapidos: hacen un login REAL con el usuario de prueba. */
        iniciarComoDemo: (rol) => {
            const cuenta = CUENTAS_DEMO[rol] || CUENTAS_DEMO.CLIENTE;
            return auth.login(cuenta.email, PASSWORD_DEMO);
        },
        registrarCliente:   (cuerpo) => peticion('/auth/registro/cliente',   { metodo: 'POST', cuerpo, publica: true }),
        registrarProveedor: (cuerpo) => peticion('/auth/registro/proveedor', { metodo: 'POST', cuerpo, publica: true }),
        logout: () => {
            borrarSesion();
            window.location.href = 'login.html';
        }
    };

    const usuarios = {
        miPerfil:           ()        => peticion('/usuarios/me'),
        actualizarPerfil:   (cuerpo)  => peticion('/usuarios/me', { metodo: 'PUT', cuerpo }),
        cambiarPassword:    (cuerpo)  => peticion('/usuarios/me/password', { metodo: 'PATCH', cuerpo }),
        listar:             (rol)     => peticion('/usuarios' + consulta({ rol })),
        bloquear:           (id)      => peticion(`/usuarios/${id}/bloquear`, { metodo: 'PATCH' }),
        activar:            (id)      => peticion(`/usuarios/${id}/activar`, { metodo: 'PATCH' }),
        verificarProveedor: (id)      => peticion(`/usuarios/${id}/verificar-proveedor`, { metodo: 'PATCH' })
    };

    const catalogo = {
        buscar:       (filtros) => peticion('/catalogo' + consulta(filtros), { publica: true }),
        paginado:     (filtros) => peticion('/catalogo/paginado' + consulta(filtros), { publica: true }),
        detalle:      (id)      => peticion(`/catalogo/${id}`, { publica: true }),
        porCategoria: (idCat)   => peticion(`/catalogo/categoria/${idCat}`, { publica: true })
    };

    const categorias = {
        listar:  ()   => peticion('/categorias', { publica: true }),
        obtener: (id) => peticion(`/categorias/${id}`, { publica: true })
    };

    const herramientas = {
        miInventario: ()               => peticion('/herramientas/mi-inventario'),
        detalle:      (id)             => peticion(`/herramientas/${id}`),
        crear:        (cuerpo)         => peticion('/herramientas', { metodo: 'POST', cuerpo }),
        actualizar:   (id, cuerpo)     => peticion(`/herramientas/${id}`, { metodo: 'PUT', cuerpo }),
        eliminar:     (id)             => peticion(`/herramientas/${id}`, { metodo: 'DELETE' }),
        cambiarEstado:(id, cuerpo)     => peticion(`/herramientas/${id}/estado`, { metodo: 'PATCH', cuerpo }),
        agregarImagen:(id, cuerpo)     => peticion(`/herramientas/${id}/imagenes`, { metodo: 'POST', cuerpo })
    };

    const reservas = {
        crear:           (cuerpo)           => peticion('/reservas', { metodo: 'POST', cuerpo }),
        misReservas:     ()                 => peticion('/reservas/mis-reservas'),
        paraGestion:     ()                 => peticion('/reservas'),
        obtener:         (id)               => peticion(`/reservas/${id}`),
        disponibilidad:  (idH, desde, hasta) => peticion(`/reservas/disponibilidad/${idH}` + consulta({ desde, hasta }), { publica: true }),
        aprobar:         (id)               => peticion(`/reservas/${id}/aprobar`, { metodo: 'PATCH' }),
        rechazar:        (id, motivo)       => peticion(`/reservas/${id}/rechazar`, { metodo: 'PATCH', cuerpo: { motivo } }),
        iniciar:         (id)               => peticion(`/reservas/${id}/iniciar`, { metodo: 'PATCH' }),
        finalizar:       (id)               => peticion(`/reservas/${id}/finalizar`, { metodo: 'PATCH' }),
        cancelar:        (id)               => peticion(`/reservas/${id}/cancelar`, { metodo: 'PATCH' })
    };

    const pagos = {
        metodos:    ()          => peticion('/pagos/metodos'),
        pagar:      (cuerpo)    => peticion('/pagos', { metodo: 'POST', cuerpo }),
        misPagos:   ()          => peticion('/pagos/mis-pagos'),
        deReserva:  (idReserva) => peticion(`/pagos/reserva/${idReserva}`),
        obtener:    (id)        => peticion(`/pagos/${id}`),
        todos:      ()          => peticion('/pagos')
    };

    const facturas = {
        misFacturas: ()          => peticion('/facturas/mis-facturas'),
        deReserva:   (idReserva) => peticion(`/facturas/reserva/${idReserva}`),
        obtener:     (id)        => peticion(`/facturas/${id}`),
        porNumero:   (numero)    => peticion(`/facturas/numero/${encodeURIComponent(numero)}`),
        descargar:   (numero)    => peticion(`/facturas/${encodeURIComponent(numero)}/descargar`, { texto: true })
    };

    const devoluciones = {
        registrar:  (cuerpo)    => peticion('/devoluciones', { metodo: 'POST', cuerpo }),
        listar:     ()          => peticion('/devoluciones'),
        obtener:    (id)        => peticion(`/devoluciones/${id}`),
        deReserva:  (idReserva) => peticion(`/devoluciones/reserva/${idReserva}`),
        cargos:     (id)        => peticion(`/devoluciones/${id}/cargos`),
        pagarCargo: (idCargo)   => peticion(`/devoluciones/cargos/${idCargo}/pagar`, { metodo: 'POST' })
    };

    const reportes = {
        dashboard: () => peticion('/reportes/dashboard')
    };

    const resenas = {
        deHerramienta: (idH)        => peticion(`/resenas/herramienta/${idH}`, { publica: true }),
        resumen:       (idH)        => peticion(`/resenas/herramienta/${idH}/resumen`, { publica: true }),
        resumenGeneral:()           => peticion('/resenas/resumen', { publica: true }),
        publicar:      (cuerpo)     => peticion('/resenas', { metodo: 'POST', cuerpo }),
        misResenas:    ()           => peticion('/resenas/mis-resenas'),
        pendientes:    ()           => peticion('/resenas/pendientes'),
        editar:        (id, cuerpo) => peticion(`/resenas/${id}`, { metodo: 'PUT', cuerpo }),
        eliminar:      (id)         => peticion(`/resenas/${id}`, { metodo: 'DELETE' })
    };

    const mantenimientos = {
        listar:     (soloAbiertos) => peticion('/mantenimientos' + consulta({ soloAbiertos })),
        historial:  (idH)          => peticion(`/mantenimientos/herramienta/${idH}`),
        registrar:  (cuerpo)       => peticion('/mantenimientos', { metodo: 'POST', cuerpo }),
        finalizar:  (id, cuerpo)   => peticion(`/mantenimientos/${id}/finalizar`, { metodo: 'PATCH', cuerpo })
    };

    const favoritos = {
        listar:  ()    => peticion('/favoritos'),
        ids:     ()    => peticion('/favoritos/ids'),
        agregar: (idH) => peticion(`/favoritos/${idH}`, { metodo: 'POST' }),
        quitar:  (idH) => peticion(`/favoritos/${idH}`, { metodo: 'DELETE' })
    };

    // Se busca el backend apenas carga la pagina, para pintar el indicador de conexion.
    verificarBackend();

    return {
        ErrorApi, CUENTAS_DEMO, PASSWORD_DEMO,
        verificarBackend, esOnline, baseActual,
        haySesion, obtenerUsuario, obtenerToken, borrarSesion,
        tieneRol, esAdmin, esProveedor, esCliente, rolPrincipal,
        auth, usuarios, catalogo, categorias, herramientas,
        reservas, pagos, facturas, devoluciones, reportes,
        resenas, mantenimientos, favoritos
    };

})();
