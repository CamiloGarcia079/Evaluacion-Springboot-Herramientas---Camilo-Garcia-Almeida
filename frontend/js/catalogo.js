/* ==========================================================================
   catalogo.js - Catalogo publico: busqueda paginada, ficha, disponibilidad,
                 resenas, favoritos y solicitud de reserva
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

    'use strict';

    UI.pintarBarra('catalogo');

    const TAMANIO_PAGINA = 9;
    const formFiltros = document.getElementById('form-filtros');
    const contenedor = document.getElementById('resultados');
    const paginacion = document.getElementById('paginacion');
    const pildoras = document.getElementById('contenedor-pildoras');

    let paginaActual = 0;
    let herramientaActual = null;
    let calificaciones = new Map();   // idHerramienta -> { promedio, totalResenas }
    let favoritos = new Set();        // ids de herramientas favoritas del usuario

    iniciar();

    async function iniciar() {
        await Promise.all([cargarCategorias(), cargarCalificaciones(), cargarFavoritos(), cargarEstadisticas()]);
        buscar(0);
    }

    // ------------------------------------------------------------------
    // Datos de apoyo
    // ------------------------------------------------------------------

    async function cargarCategorias() {
        try {
            const categorias = await API.categorias.listar();
            const select = document.getElementById('idCategoria');
            categorias.forEach(c => select.insertAdjacentHTML('beforeend',
                `<option value="${c.idCategoria}">${UI.esc(c.nombre)}</option>`));

            categorias.slice(0, 10).forEach(c => pildoras.insertAdjacentHTML('beforeend',
                `<button class="pildora-cat" data-cat="${c.idCategoria}">${UI.esc(c.nombre)}</button>`));
            pildoras.querySelectorAll('.pildora-cat').forEach(btn => btn.addEventListener('click', () => {
                select.value = btn.dataset.cat;
                marcarPildora(btn.dataset.cat);
                buscar(0);
            }));
            document.getElementById('stat-categorias').textContent = categorias.length;
        } catch (e) {
            UI.mensaje('mensaje', e.message, 'error');
        }
    }

    async function cargarCalificaciones() {
        try {
            const resumen = await API.resenas.resumenGeneral();
            calificaciones = new Map(resumen.map(r => [r.idHerramienta, r]));
            const total = resumen.reduce((acc, r) => acc + r.totalResenas, 0);
            document.getElementById('stat-resenas').textContent = total;
        } catch (e) {
            calificaciones = new Map();
        }
    }

    async function cargarFavoritos() {
        if (!API.haySesion()) return;
        try {
            favoritos = new Set(await API.favoritos.ids());
        } catch (e) {
            favoritos = new Set();
        }
    }

    async function cargarEstadisticas() {
        try {
            const todas = await API.catalogo.buscar({ soloDisponibles: false });
            document.getElementById('stat-equipos').textContent = todas.length;
            document.getElementById('stat-disponibles').textContent = todas.filter(h => h.disponible).length;
        } catch (e) {
            /* el mensaje de conexion ya lo muestra la busqueda principal */
        }
    }

    function marcarPildora(idCat) {
        pildoras.querySelectorAll('.pildora-cat').forEach(b =>
            b.classList.toggle('activa', b.dataset.cat === String(idCat || '')));
    }

    // ------------------------------------------------------------------
    // Busqueda paginada
    // ------------------------------------------------------------------

    formFiltros.addEventListener('submit', (e) => {
        e.preventDefault();
        marcarPildora(document.getElementById('idCategoria').value);
        buscar(0);
    });

    document.getElementById('orden').addEventListener('change', () => buscar(0));

    document.getElementById('btn-limpiar').addEventListener('click', () => {
        formFiltros.reset();
        marcarPildora('');
        buscar(0);
    });

    async function buscar(pagina) {
        paginaActual = pagina;
        UI.cargando(contenedor, 'Consultando el catálogo...');
        paginacion.innerHTML = '';
        UI.ocultarMensaje('mensaje');

        const filtros = UI.leerFormulario(formFiltros);
        const minimo = Number(filtros.precioMinimo), maximo = Number(filtros.precioMaximo);
        if (filtros.precioMinimo && filtros.precioMaximo && minimo > maximo) {
            contenedor.innerHTML = '';
            UI.mensaje('mensaje', 'La tarifa mínima no puede ser mayor que la máxima.', 'error');
            return;
        }

        try {
            const resultado = await API.catalogo.paginado({ ...filtros, pagina, tamanio: TAMANIO_PAGINA });
            pintarTarjetas(resultado.contenido || []);
            pintarPaginacion(resultado);
            document.getElementById('titulo-resultados').textContent = `Equipos (${resultado.totalElementos})`;
            document.getElementById('subtitulo-resultados').textContent = resultado.totalElementos
                ? `Página ${resultado.pagina + 1} de ${resultado.totalPaginas}`
                : '';
        } catch (error) {
            contenedor.innerHTML = '';
            UI.mensaje('mensaje', error.message, 'error');
        }
    }

    function pintarTarjetas(lista) {
        if (lista.length === 0) {
            UI.vacio(contenedor, 'No hay equipos con esos filtros. Pruebe con otros criterios.', '🚜');
            return;
        }
        const conSesion = API.haySesion();

        contenedor.innerHTML = lista.map(h => {
            const cal = calificaciones.get(h.idHerramienta);
            const esFavorito = favoritos.has(h.idHerramienta);
            const deBaja = h.estadoOperativo === 'FUERA_DE_SERVICIO';
            return `
            <article class="tarjeta-herramienta">
                <div class="imagen-herramienta">
                    <img src="${UI.esc(UI.imagen(h.imagenPrincipal))}" alt="${UI.esc(h.nombre)}" loading="lazy"
                         onerror="this.onerror=null;this.src='${UI.IMAGEN_POR_DEFECTO}';">
                    <div class="badge-flotante">${UI.insignia(h.estadoOperativo)}</div>
                    ${conSesion ? `<button class="boton-favorito ${esFavorito ? 'activo' : ''}" data-fav="${h.idHerramienta}"
                        title="${esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos'}" aria-label="Favorito">${esFavorito ? '❤️' : '🤍'}</button>` : ''}
                </div>
                <div class="cuerpo-tarjeta">
                    <span class="categoria-tag">${UI.esc(h.categoriaPrincipal || 'Equipo')}</span>
                    <h3>${UI.esc(h.nombre)}</h3>
                    <p class="marca-modelo">${UI.esc(h.marca)} · ${UI.esc(h.modelo)}</p>
                    ${UI.estrellas(cal ? cal.promedio : 0, cal ? cal.totalResenas : 0)}
                    <div class="precio-caja">
                        <div class="precio">${UI.pesos(h.tarifaDiaria)} <small>/ día</small></div>
                        <span class="ayuda-campo">IVA incluido</span>
                    </div>
                    <div class="botones-tarjeta">
                        <button class="boton boton-pequeno" data-reservar="${h.idHerramienta}" ${deBaja ? 'disabled title="Fuera de servicio"' : ''}>Reservar</button>
                        <button class="boton boton-secundario boton-pequeno" data-detalle="${h.idHerramienta}">Ver ficha</button>
                    </div>
                </div>
            </article>`;
        }).join('');

        contenedor.querySelectorAll('[data-detalle]').forEach(b =>
            b.addEventListener('click', () => verDetalle(Number(b.dataset.detalle))));
        contenedor.querySelectorAll('[data-reservar]').forEach(b =>
            b.addEventListener('click', () => reservarDesdeTarjeta(Number(b.dataset.reservar), b)));
        contenedor.querySelectorAll('[data-fav]').forEach(b =>
            b.addEventListener('click', () => alternarFavorito(Number(b.dataset.fav), b)));
    }

    function pintarPaginacion(p) {
        if (!p || p.totalPaginas <= 1) {
            paginacion.innerHTML = '';
            return;
        }
        let html = `<button class="boton boton-secundario boton-pequeno" data-pag="${p.pagina - 1}" ${p.primera ? 'disabled' : ''}>« Anterior</button>`;
        for (let i = 0; i < p.totalPaginas; i++) {
            html += `<button class="boton boton-pequeno ${i === p.pagina ? '' : 'boton-secundario'}" data-pag="${i}">${i + 1}</button>`;
        }
        html += `<button class="boton boton-secundario boton-pequeno" data-pag="${p.pagina + 1}" ${p.ultima ? 'disabled' : ''}>Siguiente »</button>`;
        paginacion.innerHTML = html;
        paginacion.querySelectorAll('[data-pag]').forEach(b => b.addEventListener('click', () => {
            buscar(Number(b.dataset.pag));
            document.getElementById('titulo-resultados').scrollIntoView({ behavior: 'smooth' });
        }));
    }

    async function alternarFavorito(idHerramienta, boton) {
        boton.disabled = true;
        try {
            if (favoritos.has(idHerramienta)) {
                await API.favoritos.quitar(idHerramienta);
                favoritos.delete(idHerramienta);
                UI.toast('Quitada de favoritos', 'info');
            } else {
                await API.favoritos.agregar(idHerramienta);
                favoritos.add(idHerramienta);
                UI.toast('Agregada a favoritos. La encuentra en Mi cuenta.', 'exito');
            }
            const activo = favoritos.has(idHerramienta);
            boton.classList.toggle('activo', activo);
            boton.textContent = activo ? '❤️' : '🤍';
        } catch (e) {
            UI.toast(e.message, 'error');
        } finally {
            boton.disabled = false;
        }
    }

    // ------------------------------------------------------------------
    // Ficha de la herramienta
    // ------------------------------------------------------------------

    async function verDetalle(id) {
        const cuerpo = document.getElementById('detalle-cuerpo');
        document.getElementById('detalle-titulo').textContent = 'Ficha del equipo';
        UI.cargando(cuerpo, 'Cargando ficha técnica, disponibilidad y reseñas...');
        UI.abrirModal('modal-detalle');

        const hoy = UI.isoLocal();
        try {
            const [h, resenas, disponibilidad] = await Promise.all([
                API.catalogo.detalle(id),
                API.resenas.deHerramienta(id).catch(() => []),
                API.reservas.disponibilidad(id, hoy, UI.sumarDias(hoy, 45)).catch(() => null)
            ]);
            herramientaActual = h;
            document.getElementById('detalle-titulo').textContent = h.nombre;
            document.getElementById('btn-abrir-reserva').disabled = h.estadoOperativo === 'FUERA_DE_SERVICIO';

            const imagenes = (h.imagenes && h.imagenes.length) ? h.imagenes : [{ urlFoto: null, descripcion: h.nombre }];
            const galeria = imagenes.map((img, i) => `
                <img src="${UI.esc(UI.imagen(img.urlFoto))}" alt="${UI.esc(img.descripcion || h.nombre)}"
                     class="${i === 0 ? 'principal' : ''}" onerror="this.onerror=null;this.src='${UI.IMAGEN_POR_DEFECTO}';">`).join('');

            const especificaciones = (h.especificaciones || []).map(e => `
                <div class="dato"><div class="etiqueta">${UI.esc(e.atributo)}</div>
                <div class="valor">${UI.esc(e.valor)} ${UI.esc(e.unidadMedida || '')}</div></div>`).join('')
                || '<p class="ayuda-campo">El proveedor no registró ficha técnica.</p>';

            const tarifas = (h.tarifas || []).map(t => `
                <tr><td>${UI.esc(t.descripcionTipo || t.tipoTarifa)}</td><td><strong>${UI.pesos(t.valor)}</strong></td>
                <td>${UI.pesos(t.valorPorDia)} / día</td></tr>`).join('')
                || `<tr><td>Diaria</td><td><strong>${UI.pesos(h.tarifaDiaria)}</strong></td><td>${UI.pesos(h.tarifaDiaria)} / día</td></tr>`;

            const cal = calificaciones.get(h.idHerramienta);

            cuerpo.innerHTML = `
                <div class="galeria">${galeria}</div>
                <div class="fila-insignias">
                    ${UI.insignia(h.estadoOperativo)}
                    ${UI.estrellas(cal ? cal.promedio : 0, cal ? cal.totalResenas : 0)}
                    <span class="ayuda-campo">Serie: <code>${UI.esc(h.numeroSerie)}</code></span>
                </div>
                <p class="texto-descripcion">${UI.esc(h.descripcion)}</p>

                <div class="lista-datos">
                    <div class="dato"><div class="etiqueta">Marca</div><div class="valor">${UI.esc(h.marca)}</div></div>
                    <div class="dato"><div class="etiqueta">Modelo</div><div class="valor">${UI.esc(h.modelo)}</div></div>
                    <div class="dato"><div class="etiqueta">Tarifa diaria</div><div class="valor texto-acento">${UI.pesos(h.tarifaDiaria)}</div></div>
                    <div class="dato"><div class="etiqueta">Categoría</div><div class="valor">${UI.esc(h.categoriaPrincipal ? h.categoriaPrincipal.nombre : '-')}</div></div>
                </div>

                <h3 class="titulo-seccion">📅 Disponibilidad (próximos 45 días)</h3>
                ${pintarDisponibilidad(disponibilidad, h)}

                <h3 class="titulo-seccion">📋 Ficha técnica</h3>
                <div class="lista-datos">${especificaciones}</div>

                <h3 class="titulo-seccion">💰 Tarifas</h3>
                <div class="envoltura-tabla"><table>
                    <thead><tr><th>Modalidad</th><th>Valor</th><th>Equivale a</th></tr></thead>
                    <tbody>${tarifas}</tbody>
                </table></div>

                <h3 class="titulo-seccion">⭐ Reseñas de clientes (${resenas.length})</h3>
                ${pintarResenas(resenas)}
            `;
        } catch (error) {
            cuerpo.innerHTML = `<div class="mensaje mensaje-error visible">${UI.esc(error.message)}</div>`;
        }
    }

    function pintarDisponibilidad(d, h) {
        if (!d) return '<p class="ayuda-campo">No se pudo consultar el calendario.</p>';
        if (h.estadoOperativo === 'FUERA_DE_SERVICIO') return '<p class="mensaje mensaje-error visible">Este equipo está fuera de servicio.</p>';
        if (!d.ocupaciones.length) return '<p class="mensaje mensaje-exito visible">Sin reservas en los próximos 45 días.</p>';
        return `<ul class="lista-ocupaciones">${d.ocupaciones.map(o => `
            <li>${UI.insignia(o.estado)} ${UI.fecha(o.desde)} → ${UI.fecha(o.hasta)}
            ${o.estado === 'SOLICITADA' ? '<span class="ayuda-campo">(pendiente de aprobación, aún no bloquea)</span>' : ''}</li>`).join('')}
        </ul>`;
    }

    function pintarResenas(lista) {
        if (!lista.length) return '<p class="ayuda-campo">Aún no hay reseñas. Los clientes califican al terminar el alquiler.</p>';
        return `<div class="lista-resenas">${lista.slice(0, 8).map(r => `
            <div class="resena">
                <div class="resena-cabecera">
                    <strong>${UI.esc(r.nombreCliente || 'Cliente')}</strong>
                    ${UI.estrellas(r.calificacion)}
                    <span class="ayuda-campo">${UI.fecha(r.fechaResena)}</span>
                </div>
                ${r.comentario ? `<p>${UI.esc(r.comentario)}</p>` : ''}
            </div>`).join('')}</div>`;
    }

    // ------------------------------------------------------------------
    // Solicitud de reserva
    // ------------------------------------------------------------------

    const inputInicio = document.getElementById('reserva-fecha-inicio');
    const inputFin = document.getElementById('reserva-fecha-fin');
    const avisoDisponibilidad = document.getElementById('reserva-disponibilidad');
    let temporizadorDisponibilidad = null;

    document.getElementById('btn-abrir-reserva').addEventListener('click', () => {
        if (!herramientaActual) return;
        UI.cerrarModal('modal-detalle');
        abrirModalReserva(herramientaActual);
    });

    async function reservarDesdeTarjeta(id, boton) {
        try {
            const h = await UI.conBoton(boton, '⏳', () => API.catalogo.detalle(id));
            abrirModalReserva(h);
        } catch (e) {
            UI.toast(e.message, 'error');
        }
    }

    function abrirModalReserva(h) {
        if (!API.haySesion()) {
            UI.toast('Inicie sesión con una cuenta de cliente para reservar.', 'info');
            setTimeout(() => { window.location.href = 'login.html?volver=index.html'; }, 900);
            return;
        }
        if (!API.esCliente() && !API.esAdmin()) {
            UI.toast('Las reservas se hacen con una cuenta de cliente. Use el acceso rápido "Cliente".', 'error');
            return;
        }
        herramientaActual = h;
        document.getElementById('reserva-id-herramienta').value = h.idHerramienta;
        document.getElementById('reserva-tarifa-diaria').value = h.tarifaDiaria;
        document.getElementById('reserva-modal-subtitulo').textContent = `${h.nombre} · ${h.marca} ${h.modelo}`;
        document.getElementById('reserva-notas').value = '';

        const hoy = UI.isoLocal();
        inputInicio.min = hoy;
        inputFin.min = hoy;
        inputInicio.value = UI.sumarDias(hoy, 1);
        inputFin.value = UI.sumarDias(hoy, 4);

        UI.ocultarMensaje('reserva-mensaje');
        recalcular();
        UI.abrirModal('modal-crear-reserva');
    }

    inputInicio.addEventListener('change', () => {
        if (inputFin.value < inputInicio.value) inputFin.value = UI.sumarDias(inputInicio.value, 1);
        inputFin.min = inputInicio.value;
        recalcular();
    });
    inputFin.addEventListener('change', recalcular);

    function recalcular() {
        if (!inputInicio.value || !inputFin.value) return;
        const tarifa = Number(document.getElementById('reserva-tarifa-diaria').value) || 0;
        const dias = UI.diasEntre(inputInicio.value, inputFin.value);
        const alquiler = tarifa * dias;
        const deposito = Math.round(alquiler * 0.30 * 100) / 100;

        document.getElementById('reserva-dias-calculados').textContent = `${dias} ${dias === 1 ? 'día' : 'días'}`;
        document.getElementById('reserva-monto-calculado').textContent = UI.pesos(alquiler);
        document.getElementById('reserva-deposito-calculado').textContent = UI.pesos(deposito);
        document.getElementById('reserva-total-compromiso').textContent = UI.pesos(alquiler + deposito);

        clearTimeout(temporizadorDisponibilidad);
        temporizadorDisponibilidad = setTimeout(verificarFechas, 250);
    }

    async function verificarFechas() {
        const id = document.getElementById('reserva-id-herramienta').value;
        if (!id || !inputInicio.value || !inputFin.value || inputFin.value < inputInicio.value) {
            avisoDisponibilidad.className = 'aviso-disponibilidad';
            return;
        }
        avisoDisponibilidad.className = 'aviso-disponibilidad visible';
        avisoDisponibilidad.textContent = '⏳ Verificando disponibilidad...';
        try {
            const d = await API.reservas.disponibilidad(id, inputInicio.value, inputFin.value);
            const pendientes = d.ocupaciones.filter(o => o.estado === 'SOLICITADA').length;
            if (d.disponible) {
                avisoDisponibilidad.className = 'aviso-disponibilidad visible libre';
                avisoDisponibilidad.textContent = '✅ Disponible en esas fechas'
                    + (pendientes ? ` (hay ${pendientes} solicitud(es) pendiente(s); se aprueba la primera que confirme el proveedor)` : '');
            } else {
                const bloqueos = d.ocupaciones.filter(o => o.estado !== 'SOLICITADA')
                    .map(o => `${UI.fecha(o.desde)} al ${UI.fecha(o.hasta)}`).join(', ');
                avisoDisponibilidad.className = 'aviso-disponibilidad visible ocupada';
                avisoDisponibilidad.textContent = '⛔ No disponible: ' + (bloqueos || d.mensaje);
            }
        } catch (e) {
            avisoDisponibilidad.className = 'aviso-disponibilidad visible ocupada';
            avisoDisponibilidad.textContent = e.message;
        }
    }

    document.getElementById('form-crear-reserva').addEventListener('submit', async (e) => {
        e.preventDefault();
        UI.ocultarMensaje('reserva-mensaje');
        if (inputFin.value < inputInicio.value) {
            UI.mensaje('reserva-mensaje', 'La fecha de devolución no puede ser anterior a la de inicio.', 'error');
            return;
        }
        const boton = document.getElementById('btn-confirmar-reserva');
        try {
            const reserva = await UI.conBoton(boton, '⏳ Enviando...', () => API.reservas.crear({
                fechaInicio: inputInicio.value,
                fechaFin: inputFin.value,
                notasCliente: document.getElementById('reserva-notas').value.trim() || null,
                items: [{ idHerramienta: Number(document.getElementById('reserva-id-herramienta').value), cantidad: 1 }]
            }));
            UI.cerrarModal('modal-crear-reserva');
            UI.toast(`Solicitud ${reserva.codigoReserva} enviada por ${UI.pesos(reserva.montoTotalEstimado)}. El proveedor debe aprobarla.`, 'exito');
            setTimeout(() => { window.location.href = 'reservas.html'; }, 1600);
        } catch (error) {
            UI.mensaje('reserva-mensaje', error.message, 'error');
        }
    });
});
