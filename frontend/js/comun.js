/* ==========================================================================
   comun.js - Utilidades compartidas: formato, barra superior, sesion, modales
   ========================================================================== */

const UI = (() => {

    'use strict';

    // ------------------------------------------------------------------
    // Mensajes
    // ------------------------------------------------------------------

    function mensaje(idContenedor, texto, tipo = 'error') {
        const caja = document.getElementById(idContenedor);
        if (!caja) return;
        caja.textContent = texto;
        caja.className = 'mensaje mensaje-' + tipo + ' visible';
        if (tipo === 'exito') setTimeout(() => ocultarMensaje(idContenedor), 6000);
    }

    function ocultarMensaje(idContenedor) {
        const caja = document.getElementById(idContenedor);
        if (caja) caja.className = 'mensaje';
    }

    function toast(texto, tipo = 'info') {
        let contenedor = document.getElementById('toast-container');
        if (!contenedor) {
            contenedor = document.createElement('div');
            contenedor.id = 'toast-container';
            document.body.appendChild(contenedor);
        }
        const item = document.createElement('div');
        item.className = 'mensaje mensaje-' + tipo + ' visible toast';
        const icono = tipo === 'exito' ? '✅' : tipo === 'error' ? '⚠️' : 'ℹ️';
        item.innerHTML = `<span>${icono}</span><span>${esc(texto)}</span>`;
        contenedor.appendChild(item);
        setTimeout(() => {
            item.classList.add('saliendo');
            setTimeout(() => item.remove(), 350);
        }, tipo === 'error' ? 6000 : 4000);
    }

    // ------------------------------------------------------------------
    // Formato
    // ------------------------------------------------------------------

    function pesos(valor) {
        const n = Number(valor);
        if (valor === null || valor === undefined || isNaN(n)) return '$ 0';
        return new Intl.NumberFormat('es-CO', {
            style: 'currency', currency: 'COP', minimumFractionDigits: 0, maximumFractionDigits: 0
        }).format(n);
    }

    /**
     * Convierte 'AAAA-MM-DD' en una fecha LOCAL. new Date('2026-10-26') la
     * interpreta en UTC y en Colombia (UTC-5) se mostraba el dia anterior.
     */
    function aFecha(valor) {
        if (!valor) return null;
        if (valor instanceof Date) return valor;
        const soloFecha = /^(\d{4})-(\d{2})-(\d{2})$/.exec(valor);
        if (soloFecha) return new Date(Number(soloFecha[1]), Number(soloFecha[2]) - 1, Number(soloFecha[3]));
        const d = new Date(valor);
        return isNaN(d.getTime()) ? null : d;
    }

    function fecha(valor) {
        const d = aFecha(valor);
        return d ? d.toLocaleDateString('es-CO', { year: 'numeric', month: 'short', day: '2-digit' }) : '-';
    }

    function fechaConHora(valor) {
        const d = aFecha(valor);
        return d ? d.toLocaleString('es-CO', { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' }) : '-';
    }

    /** Fecha local en formato AAAA-MM-DD (lo que esperan los input date y el backend). */
    function isoLocal(d) {
        const f = d || new Date();
        return `${f.getFullYear()}-${String(f.getMonth() + 1).padStart(2, '0')}-${String(f.getDate()).padStart(2, '0')}`;
    }

    function sumarDias(iso, n) {
        const d = aFecha(iso) || new Date();
        d.setDate(d.getDate() + n);
        return isoLocal(d);
    }

    /** Dias cobrados, igual que el backend: diferencia entre fechas, minimo 1. */
    function diasEntre(inicioIso, finIso) {
        const a = aFecha(inicioIso), b = aFecha(finIso);
        if (!a || !b) return 0;
        const dif = Math.round((b - a) / 86400000);
        return dif <= 0 ? 1 : dif;
    }

    function esc(texto) {
        if (texto === null || texto === undefined) return '';
        return String(texto)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#039;');
    }

    function insignia(estado) {
        if (!estado) return '';
        const clave = String(estado).toLowerCase().replace(/\s+/g, '_');
        return `<span class="insignia insignia-${clave}">${esc(String(estado).replace(/_/g, ' '))}</span>`;
    }

    /** Estrellas de 0 a 5 (admite medios puntos). */
    function estrellas(valor, total) {
        const v = Math.max(0, Math.min(5, Number(valor) || 0));
        let html = '';
        for (let i = 1; i <= 5; i++) {
            const clase = v >= i ? 'llena' : (v >= i - 0.5 ? 'media' : 'vacia');
            html += `<span class="estrella ${clase}">★</span>`;
        }
        const texto = total === undefined ? '' :
            (total > 0 ? `<span class="estrellas-texto">${v.toFixed(1)} (${total})</span>` : '<span class="estrellas-texto">Sin reseñas</span>');
        return `<span class="estrellas" title="${v.toFixed(1)} de 5">${html}${texto}</span>`;
    }

    const IMAGEN_POR_DEFECTO = 'img/herramientas/sin-imagen.svg';

    function imagen(url) {
        return url ? url : IMAGEN_POR_DEFECTO;
    }

    function cargando(contenedor, texto = 'Cargando información...') {
        contenedor.innerHTML = `<div class="cargando">⏳ ${esc(texto)}</div>`;
    }

    function vacio(contenedor, texto = 'No hay registros disponibles', icono = '📦') {
        contenedor.innerHTML = `<div class="estado-vacio"><div class="icono">${icono}</div><p>${esc(texto)}</p></div>`;
    }

    function filaVacia(columnas, texto) {
        return `<tr><td colspan="${columnas}" class="estado-vacio">${esc(texto)}</td></tr>`;
    }

    function filaCargando(columnas, texto = 'Cargando...') {
        return `<tr><td colspan="${columnas}" class="cargando">⏳ ${esc(texto)}</td></tr>`;
    }

    // ------------------------------------------------------------------
    // Tema claro / oscuro
    // ------------------------------------------------------------------

    function leer(clave) { try { return localStorage.getItem(clave); } catch (e) { return null; } }
    function guardar(clave, valor) { try { localStorage.setItem(clave, valor); } catch (e) { /* modo privado */ } }

    function temaActual() {
        const guardado = leer('rh_tema');
        if (guardado) return guardado;
        return window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
    }

    function aplicarTema(tema) {
        document.documentElement.setAttribute('data-theme', tema);
        guardar('rh_tema', tema);
        document.querySelectorAll('.boton-toggle-tema').forEach(btn => {
            btn.textContent = tema === 'dark' ? '☀️ Día' : '🌙 Noche';
            btn.title = tema === 'dark' ? 'Cambiar a modo día' : 'Cambiar a modo noche';
        });
    }

    function alternarTema() {
        aplicarTema(temaActual() === 'dark' ? 'light' : 'dark');
    }

    aplicarTema(temaActual());

    // ------------------------------------------------------------------
    // Barra superior
    // ------------------------------------------------------------------

    function textoEstado(online) {
        if (online === true) return '🟢 Servidor conectado';
        if (online === false) return '🔴 Servidor no disponible';
        return '⏳ Buscando servidor...';
    }

    function pintarBarra(paginaActual) {
        let barraDemo = document.getElementById('barra-demo-rapido');
        if (!barraDemo) {
            barraDemo = document.createElement('div');
            barraDemo.id = 'barra-demo-rapido';
            barraDemo.className = 'barra-demo';
            document.body.insertBefore(barraDemo, document.body.firstChild);
        }

        barraDemo.innerHTML = `
            <div class="barra-demo-grupo">
                <span class="barra-demo-titulo">⚡ Acceso rápido de prueba:</span>
                <button class="boton-demo-rol" data-demo="CLIENTE" title="${esc(API.CUENTAS_DEMO.CLIENTE.email)}">👤 Cliente</button>
                <button class="boton-demo-rol" data-demo="PROVEEDOR" title="${esc(API.CUENTAS_DEMO.PROVEEDOR.email)}">🏢 Proveedor</button>
                <button class="boton-demo-rol" data-demo="ADMIN" title="${esc(API.CUENTAS_DEMO.ADMIN.email)}">⚙️ Administrador</button>
            </div>
            <div class="barra-demo-grupo">
                <span class="badge-estado-conexion" id="badge-api-status" title="${esc(API.baseActual())}">${textoEstado(API.esOnline() ? true : null)}</span>
                <button class="boton-demo-rol" id="btn-reintentar-api" title="Volver a buscar el backend">🔄 Verificar</button>
            </div>
        `;
        actualizarEstadoConexion();

        barraDemo.querySelectorAll('[data-demo]').forEach(boton => {
            boton.addEventListener('click', async () => {
                const rol = boton.dataset.demo;
                const original = boton.textContent;
                boton.disabled = true;
                boton.textContent = '⏳ Entrando...';
                try {
                    await API.auth.iniciarComoDemo(rol);
                    toast('Sesión iniciada como ' + API.CUENTAS_DEMO[rol].nombre, 'exito');
                    setTimeout(() => { window.location.href = destinoPorRol(); }, 350);
                } catch (error) {
                    toast(error.message, 'error');
                    boton.disabled = false;
                    boton.textContent = original;
                }
            });
        });

        document.getElementById('btn-reintentar-api').addEventListener('click', async (e) => {
            const btn = e.currentTarget;
            btn.textContent = '⏳';
            const ok = await API.verificarBackend();
            btn.textContent = '🔄 Verificar';
            toast(ok ? 'Conectado al servidor en ' + API.baseActual()
                     : 'No se encontró el backend. Ejecute el script iniciar y vuelva a intentar.', ok ? 'exito' : 'error');
        });

        const contenedor = document.getElementById('menu-sesion');
        if (!contenedor) return;

        const usuario = API.obtenerUsuario();
        const enlace = (href, clave, texto) =>
            `<a href="${href}"${paginaActual === clave ? ' class="activo"' : ''}>${texto}</a>`;

        let enlaces = enlace('index.html', 'catalogo', '🚜 Catálogo');
        if (usuario) enlaces += enlace('reservas.html', 'reservas', '📋 Mi cuenta');
        if (API.esProveedor() || API.esAdmin()) {
            enlaces += enlace('proveedor.html', 'proveedor', API.esAdmin() ? '📦 Inventario' : '📦 Mi inventario');
            enlaces += enlace('gestion_reservas.html', 'gestion_reservas', '🚚 Gestión');
            enlaces += enlace('dashboard.html', 'dashboard', '📊 Dashboard');
        }
        if (API.esAdmin()) enlaces += enlace('admin.html', 'admin', '👥 Usuarios');

        const botonTema = `<button class="boton-toggle-tema boton-toggle-nav" type="button"></button>`;

        if (!usuario) {
            contenedor.innerHTML = `${enlaces}
                <div class="menu-acciones">
                    ${botonTema}
                    <a href="login.html" class="boton boton-pequeno">Iniciar sesión</a>
                    <a href="registro.html" class="boton boton-secundario boton-pequeno">Registrarse</a>
                </div>`;
        } else {
            contenedor.innerHTML = `${enlaces}
                <div class="menu-acciones">
                    ${botonTema}
                    <span class="usuario-sesion">
                        <span class="etiqueta-rol">${esc(API.rolPrincipal())}</span>
                        <span>${esc(usuario.nombreCompleto)}</span>
                    </span>
                    <button class="boton boton-secundario boton-pequeno" id="btn-salir" type="button">Salir</button>
                </div>`;
            document.getElementById('btn-salir').addEventListener('click', () => API.auth.logout());
        }
        contenedor.querySelectorAll('.boton-toggle-tema').forEach(b => b.addEventListener('click', alternarTema));
        aplicarTema(temaActual());
    }

    function actualizarEstadoConexion() {
        const badge = document.getElementById('badge-api-status');
        if (!badge) return;
        const online = API.esOnline();
        badge.className = 'badge-estado-conexion ' + (online ? 'online' : 'offline');
        badge.textContent = textoEstado(online ? true : (badge.dataset.verificado ? false : null));
        badge.title = API.baseActual();
    }

    window.addEventListener('api-status-changed', (e) => {
        const badge = document.getElementById('badge-api-status');
        if (badge) badge.dataset.verificado = '1';
        actualizarEstadoConexion();
        if (badge && e.detail && !e.detail.online) badge.textContent = textoEstado(false);
    });

    function destinoPorRol() {
        if (API.esAdmin()) return 'admin.html';
        if (API.esProveedor()) return 'proveedor.html';
        return 'index.html';
    }

    /**
     * Guardia de las paginas privadas. Sin sesion se va al login; con un rol
     * que no corresponde se vuelve al inicio. El backend valida igual el token
     * y el rol en cada peticion: esto solo evita mostrar una pantalla vacia.
     */
    function exigirSesion(...rolesPermitidos) {
        if (!API.haySesion()) {
            window.location.href = 'login.html?volver=' + encodeURIComponent(location.pathname.split('/').pop());
            return false;
        }
        if (rolesPermitidos.length && !rolesPermitidos.some(r => API.tieneRol(r)) && !API.esAdmin()) {
            toast('Su usuario no tiene permiso para esta sección.', 'error');
            setTimeout(() => { window.location.href = 'index.html'; }, 900);
            return false;
        }
        return true;
    }

    // ------------------------------------------------------------------
    // Modales y formularios
    // ------------------------------------------------------------------

    function abrirModal(id) {
        const m = document.getElementById(id);
        if (m) {
            m.classList.add('visible');
            document.body.style.overflow = 'hidden';
        }
    }

    function cerrarModal(id) {
        const m = document.getElementById(id);
        if (m) m.classList.remove('visible');
        if (!document.querySelector('.fondo-modal.visible')) document.body.style.overflow = '';
    }

    function leerFormulario(formulario) {
        const datos = {};
        new FormData(formulario).forEach((valor, clave) => {
            const v = typeof valor === 'string' ? valor.trim() : valor;
            if (v !== '') datos[clave] = v;
        });
        return datos;
    }

    /** Deshabilita un boton mientras corre la accion y lo restaura al final. */
    async function conBoton(boton, textoEspera, accion) {
        const original = boton.textContent;
        boton.disabled = true;
        boton.textContent = textoEspera;
        try {
            return await accion();
        } finally {
            boton.disabled = false;
            boton.textContent = original;
        }
    }

    document.addEventListener('click', (e) => {
        const cerrar = e.target.closest('[data-cerrar]');
        if (cerrar) {
            cerrarModal(cerrar.dataset.cerrar);
            return;
        }
        if (e.target.classList.contains('fondo-modal')) cerrarModal(e.target.id);
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') document.querySelectorAll('.fondo-modal.visible').forEach(m => cerrarModal(m.id));
    });

    return {
        mensaje, ocultarMensaje, toast,
        pesos, fecha, fechaConHora, isoLocal, sumarDias, diasEntre, aFecha,
        esc, insignia, estrellas, imagen, IMAGEN_POR_DEFECTO,
        cargando, vacio, filaVacia, filaCargando,
        pintarBarra, exigirSesion, destinoPorRol,
        abrirModal, cerrarModal, leerFormulario, conBoton,
        aplicarTema, alternarTema
    };

})();
