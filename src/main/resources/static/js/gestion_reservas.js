/* ==========================================================================
   gestion_reservas.js - Proveedor / administrador: aprobar, rechazar,
   despachar, recibir devoluciones y consultar actas de devolucion
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

    'use strict';

    if (!UI.exigirSesion('ROLE_PROVEEDOR')) return;
    UI.pintarBarra('gestion_reservas');

    const tabla = document.getElementById('tabla-gestion-reservas');
    const tablaDev = document.getElementById('tabla-devoluciones');
    const filtro = document.getElementById('filtro-estado-reserva');
    let reservas = [];

    document.getElementById('btn-refrescar-todo').addEventListener('click', cargarTodo);
    filtro.addEventListener('change', pintarReservas);
    cargarTodo();

    async function cargarTodo() {
        UI.ocultarMensaje('mensaje');
        await cargarReservas();
        cargarDevoluciones();
    }

    async function cargarReservas() {
        tabla.innerHTML = UI.filaCargando(7, 'Cargando reservas...');
        try {
            reservas = await API.reservas.paraGestion();
            pintarResumen();
            pintarReservas();
        } catch (e) {
            tabla.innerHTML = UI.filaVacia(7, 'No se pudieron cargar las reservas.');
            UI.mensaje('mensaje', e.message, 'error');
        }
    }

    function pintarResumen() {
        const contar = (estado) => reservas.filter(r => r.estado === estado).length;
        const tarjetas = [
            ['SOLICITADA', 'Por aprobar', 'kpi-aviso'],
            ['APROBADA', 'Por despachar', 'kpi-info'],
            ['EN_CURSO', 'En obra', 'kpi-exito'],
            ['FINALIZADA', 'Finalizadas', '']
        ];
        document.getElementById('resumen-estados').innerHTML = tarjetas.map(([e, t, c]) => `
            <div class="tarjeta-kpi ${c}" data-filtrar="${e}" style="cursor:pointer;">
                <div class="kpi-titulo">${t}</div><div class="kpi-valor">${contar(e)}</div>
            </div>`).join('');
        document.querySelectorAll('[data-filtrar]').forEach(k => k.addEventListener('click', () => {
            filtro.value = k.dataset.filtrar;
            pintarReservas();
        }));
    }

    function pintarReservas() {
        const lista = filtro.value ? reservas.filter(r => r.estado === filtro.value) : reservas;
        if (!lista.length) {
            tabla.innerHTML = UI.filaVacia(7, 'No hay reservas con ese estado.');
            return;
        }
        const hoy = UI.isoLocal();
        tabla.innerHTML = lista.map(r => {
            const vencida = r.estado === 'EN_CURSO' && r.fechaFin < hoy;
            const acciones = [];
            if (r.estado === 'SOLICITADA') {
                acciones.push(`<button class="boton boton-pequeno" data-accion="aprobar" data-id="${r.idReserva}">Aprobar</button>`);
                acciones.push(`<button class="boton boton-peligro boton-pequeno" data-accion="rechazar" data-id="${r.idReserva}">Rechazar</button>`);
            }
            if (r.estado === 'APROBADA') {
                acciones.push(`<button class="boton boton-pequeno" data-accion="iniciar" data-id="${r.idReserva}">Despachar</button>`);
                acciones.push(`<button class="boton boton-peligro boton-pequeno" data-accion="cancelar" data-id="${r.idReserva}">Cancelar</button>`);
            }
            if (r.estado === 'EN_CURSO') {
                acciones.push(`<button class="boton boton-pequeno" data-accion="recibir" data-id="${r.idReserva}">Recibir devolución</button>`);
            }
            if (!acciones.length) acciones.push('<span class="ayuda-campo">—</span>');
            return `<tr>
                <td><strong>${UI.esc(r.codigoReserva)}</strong></td>
                <td>${UI.esc(r.nombreCliente || ('Cliente #' + r.idCliente))}</td>
                <td>${(r.detalles || []).map(d => UI.esc(d.nombreHerramienta)).join('<br>')}</td>
                <td>${UI.fecha(r.fechaInicio)} → ${UI.fecha(r.fechaFin)}
                    ${vencida ? '<br><span class="texto-aviso">⚠ Entrega vencida</span>' : ''}</td>
                <td>${UI.insignia(r.estado)}</td>
                <td>${UI.pesos(r.montoTotalEstimado)}</td>
                <td><div class="acciones-celda">${acciones.join('')}</div></td>
            </tr>`;
        }).join('');

        tabla.querySelectorAll('[data-accion]').forEach(b => b.addEventListener('click', () => {
            const id = Number(b.dataset.id);
            const r = reservas.find(x => x.idReserva === id);
            if (b.dataset.accion === 'aprobar') ejecutar(b, () => API.reservas.aprobar(id), `Reserva ${r.codigoReserva} aprobada`);
            if (b.dataset.accion === 'iniciar') ejecutar(b, () => API.reservas.iniciar(id), `Equipo de ${r.codigoReserva} despachado`);
            if (b.dataset.accion === 'cancelar' && confirm(`¿Cancelar la reserva ${r.codigoReserva}?`)) {
                ejecutar(b, () => API.reservas.cancelar(id), `Reserva ${r.codigoReserva} cancelada`);
            }
            if (b.dataset.accion === 'rechazar') abrirRechazo(r);
            if (b.dataset.accion === 'recibir') abrirCheckin(r);
        }));
    }

    async function ejecutar(boton, accion, textoExito) {
        try {
            await UI.conBoton(boton, '⏳', accion);
            UI.toast(textoExito, 'exito');
            cargarTodo();
        } catch (e) {
            UI.mensaje('mensaje', e.message, 'error');
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    // ------------------------------------------------------------------
    // Rechazo
    // ------------------------------------------------------------------

    function abrirRechazo(r) {
        document.getElementById('rechazo-id').value = r.idReserva;
        document.getElementById('rechazo-motivo').value = '';
        document.getElementById('rechazo-subtitulo').textContent = `${r.codigoReserva} · ${r.nombreCliente || ''}`;
        UI.ocultarMensaje('rechazo-mensaje');
        UI.abrirModal('modal-rechazo');
    }

    document.getElementById('form-rechazo').addEventListener('submit', async (e) => {
        e.preventDefault();
        const id = Number(document.getElementById('rechazo-id').value);
        try {
            await UI.conBoton(document.getElementById('btn-confirmar-rechazo'), '⏳',
                () => API.reservas.rechazar(id, document.getElementById('rechazo-motivo').value.trim()));
            UI.cerrarModal('modal-rechazo');
            UI.toast('Solicitud rechazada', 'info');
            cargarTodo();
        } catch (error) {
            UI.mensaje('rechazo-mensaje', error.message, 'error');
        }
    });

    // ------------------------------------------------------------------
    // Devolucion
    // ------------------------------------------------------------------

    const checkDano = document.getElementById('checkin-tiene-dano');
    const fechaReal = document.getElementById('checkin-fecha-real');
    let reservaCheckin = null;

    checkDano.addEventListener('change', () =>
        document.getElementById('seccion-dano').classList.toggle('oculto', !checkDano.checked));
    fechaReal.addEventListener('change', avisarRetraso);

    function abrirCheckin(r) {
        reservaCheckin = r;
        document.getElementById('form-checkin').reset();
        document.getElementById('seccion-dano').classList.add('oculto');
        document.getElementById('checkin-id-reserva').value = r.idReserva;
        document.getElementById('checkin-subtitulo').textContent = `${r.codigoReserva} · ${r.nombreCliente || ''}`;
        document.getElementById('checkin-fecha-pactada').value = UI.fecha(r.fechaFin);
        fechaReal.value = UI.isoLocal();
        document.getElementById('dano-id-herramienta').innerHTML = (r.detalles || []).map(d =>
            `<option value="${d.idHerramienta}">${UI.esc(d.nombreHerramienta)}</option>`).join('');
        UI.ocultarMensaje('checkin-mensaje');
        avisarRetraso();
        UI.abrirModal('modal-checkin');
    }

    function avisarRetraso() {
        const aviso = document.getElementById('checkin-alerta-retraso');
        if (!reservaCheckin || !fechaReal.value || fechaReal.value <= reservaCheckin.fechaFin) {
            aviso.textContent = 'Entrega a tiempo: sin cargo por mora.';
            return;
        }
        const dias = UI.diasEntre(reservaCheckin.fechaFin, fechaReal.value);
        aviso.textContent = `⚠ ${dias} día(s) de retraso: se genera un cargo por mora de ${UI.pesos(dias * 25000)} (25.000 por día).`;
    }

    document.getElementById('form-checkin').addEventListener('submit', async (e) => {
        e.preventDefault();
        UI.ocultarMensaje('checkin-mensaje');
        const comando = {
            idReserva: Number(document.getElementById('checkin-id-reserva').value),
            fechaDevolucionReal: fechaReal.value,
            estadoEquipoGeneral: document.getElementById('checkin-estado-general').value,
            observaciones: document.getElementById('checkin-observaciones').value.trim() || null,
            reportesDano: []
        };
        if (checkDano.checked) {
            const descripcion = document.getElementById('dano-descripcion').value.trim();
            const costo = Number(document.getElementById('dano-costo').value);
            if (!descripcion || document.getElementById('dano-costo').value === '' || costo < 0) {
                UI.mensaje('checkin-mensaje', 'Complete la descripción y el costo del daño.', 'error');
                return;
            }
            const foto = document.getElementById('dano-foto-url').value.trim();
            comando.reportesDano.push({
                idHerramienta: Number(document.getElementById('dano-id-herramienta').value),
                tipoDano: document.getElementById('dano-tipo').value,
                descripcionDano: descripcion,
                costoEstimadoReparacion: costo,
                responsableAsume: document.getElementById('dano-responsable').value,
                evidencias: foto ? [{ urlFoto: foto, descripcionFoto: 'Evidencia del daño' }] : []
            });
        }
        try {
            const d = await UI.conBoton(document.getElementById('btn-guardar-checkin'), '⏳ Registrando...',
                () => API.devoluciones.registrar(comando));
            UI.cerrarModal('modal-checkin');
            UI.toast(`Devolución registrada. Cargos: ${UI.pesos(d.totalCargosAdicionales)}`, 'exito');
            cargarTodo();
        } catch (error) {
            UI.mensaje('checkin-mensaje', error.message, 'error');
        }
    });

    // ------------------------------------------------------------------
    // Actas de devolucion
    // ------------------------------------------------------------------

    async function cargarDevoluciones() {
        tablaDev.innerHTML = UI.filaCargando(7, 'Cargando devoluciones...');
        try {
            let lista = await API.devoluciones.listar();
            // El proveedor solo ve las devoluciones de las reservas que gestiona.
            const misReservas = new Map(reservas.map(r => [r.idReserva, r]));
            if (!API.esAdmin()) lista = lista.filter(d => misReservas.has(d.idReserva));
            if (!lista.length) {
                tablaDev.innerHTML = UI.filaVacia(7, 'Aún no hay devoluciones registradas.');
                return;
            }
            lista.sort((a, b) => b.id - a.id);
            tablaDev.innerHTML = lista.map(d => {
                const r = misReservas.get(d.idReserva);
                return `<tr>
                    <td>${d.id}</td>
                    <td>${UI.esc(r ? r.codigoReserva : '#' + d.idReserva)}</td>
                    <td>${UI.fecha(d.fechaDevolucionReal)}</td>
                    <td>${d.diasRetraso > 0 ? `<span class="texto-aviso">${d.diasRetraso} día(s)</span>` : 'A tiempo'}</td>
                    <td>${UI.esc(String(d.estadoEquipoGeneral).replace(/_/g, ' '))}</td>
                    <td>${UI.pesos(d.totalCargosAdicionales)}</td>
                    <td><button class="boton boton-secundario boton-pequeno" data-dev="${d.id}">Ver</button></td>
                </tr>`;
            }).join('');
            tablaDev.querySelectorAll('[data-dev]').forEach(b => b.addEventListener('click', () =>
                verDevolucion(lista.find(d => d.id === Number(b.dataset.dev)))));
        } catch (e) {
            tablaDev.innerHTML = UI.filaVacia(7, 'No se pudieron cargar las devoluciones.');
        }
    }

    function verDevolucion(d) {
        document.getElementById('titulo-detalle-devolucion').textContent = 'Devolución #' + d.id;
        const danos = (d.reportesDano || []).map(r => `
            <tr><td>Herramienta #${r.idHerramienta}</td><td>${UI.esc(r.tipoDano)}</td><td>${UI.esc(r.descripcionDano)}</td>
            <td>${UI.pesos(r.costoEstimadoReparacion)}</td><td>${UI.esc(r.responsableAsume)}</td></tr>`).join('');
        const cargos = (d.cargosAdicionales || []).map(c => `
            <tr><td>${UI.esc(String(c.tipoCargo).replace(/_/g, ' '))}</td><td>${UI.esc(c.descripcion)}</td>
            <td>${UI.pesos(c.monto)}</td><td>${c.pagado ? 'Pagado' : 'Pendiente'}</td></tr>`).join('');
        document.getElementById('cuerpo-detalle-devolucion').innerHTML = `
            <div class="lista-datos">
                <div class="dato"><div class="etiqueta">Fecha pactada</div><div class="valor">${UI.fecha(d.fechaDevolucionPactada)}</div></div>
                <div class="dato"><div class="etiqueta">Fecha real</div><div class="valor">${UI.fecha(d.fechaDevolucionReal)}</div></div>
                <div class="dato"><div class="etiqueta">Retraso</div><div class="valor">${d.diasRetraso} día(s)</div></div>
                <div class="dato"><div class="etiqueta">Total cargos</div><div class="valor">${UI.pesos(d.totalCargosAdicionales)}</div></div>
            </div>
            ${d.observaciones ? `<p class="ayuda-campo">${UI.esc(d.observaciones)}</p>` : ''}
            <h3 class="titulo-seccion">Daños reportados</h3>
            ${danos ? `<div class="envoltura-tabla"><table><thead><tr><th>Equipo</th><th>Tipo</th><th>Detalle</th><th>Costo</th><th>Asume</th></tr></thead><tbody>${danos}</tbody></table></div>`
                    : '<p class="ayuda-campo">Sin daños.</p>'}
            <h3 class="titulo-seccion">Cargos adicionales</h3>
            ${cargos ? `<div class="envoltura-tabla"><table><thead><tr><th>Tipo</th><th>Detalle</th><th>Monto</th><th>Estado</th></tr></thead><tbody>${cargos}</tbody></table></div>`
                     : '<p class="ayuda-campo">Sin cargos.</p>'}`;
        UI.abrirModal('modal-detalle-devolucion');
    }
});
