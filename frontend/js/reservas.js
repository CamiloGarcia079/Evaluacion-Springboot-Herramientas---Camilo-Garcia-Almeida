/* ==========================================================================
   reservas.js - "Mi cuenta": reservas, pagos, facturas, favoritos y resenas
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

    'use strict';

    if (!UI.exigirSesion()) return;
    UI.pintarBarra('reservas');

    const tablaReservas = document.getElementById('tabla-reservas');
    const tablaPagos = document.getElementById('tabla-pagos');

    let reservas = [];
    let pagos = [];
    let metodos = null;
    let facturaVisible = null;

    // ------------------------------------------------------------------
    // Pestanas
    // ------------------------------------------------------------------

    const cargadores = {
        'panel-reservas': cargarReservas,
        'panel-pagos': cargarPagos,
        'panel-favoritos': cargarFavoritos,
        'panel-resenas': cargarResenas
    };

    document.querySelectorAll('#pestanas-cuenta .pestana').forEach(p => p.addEventListener('click', () => {
        document.querySelectorAll('#pestanas-cuenta .pestana').forEach(x => x.classList.toggle('activa', x === p));
        document.querySelectorAll('.panel-pestana').forEach(panel => panel.classList.toggle('oculto', panel.id !== p.dataset.panel));
        UI.ocultarMensaje('mensaje');
        cargadores[p.dataset.panel]();
    }));

    document.getElementById('btn-refrescar').addEventListener('click', cargarReservas);
    cargarReservas();

    // ------------------------------------------------------------------
    // Reservas
    // ------------------------------------------------------------------

    function pagadoDe(idReserva, tipos) {
        return pagos
            .filter(p => p.idReserva === idReserva && p.estadoPago === 'APROBADO' && tipos.includes(p.tipoPago))
            .reduce((acc, p) => acc + Number(p.monto), 0);
    }

    function saldoAlquiler(r) {
        return Math.max(0, Number(r.montoTotalEstimado) - pagadoDe(r.idReserva, ['ANTICIPO', 'TOTALIDAD']));
    }

    function saldoDeposito(r) {
        return Math.max(0, Number(r.depositoGarantia) - pagadoDe(r.idReserva, ['DEPOSITO_GARANTIA']));
    }

    const admitePagos = (r) => ['APROBADA', 'EN_CURSO', 'FINALIZADA'].includes(r.estado);

    async function cargarReservas() {
        tablaReservas.innerHTML = UI.filaCargando(7, 'Cargando sus reservas...');
        try {
            [reservas, pagos] = await Promise.all([API.reservas.misReservas(), API.pagos.misPagos()]);
            pintarReservas();
        } catch (error) {
            tablaReservas.innerHTML = UI.filaVacia(7, 'No se pudieron cargar las reservas.');
            UI.mensaje('mensaje', error.message, 'error');
        }
    }

    function pintarReservas() {
        if (!reservas.length) {
            tablaReservas.innerHTML = UI.filaVacia(7, 'Todavía no tiene reservas. Elija un equipo en el catálogo.');
            return;
        }
        tablaReservas.innerHTML = reservas.map(r => {
            const equipos = (r.detalles || []).map(d => UI.esc(d.nombreHerramienta)).join('<br>');
            const pagado = pagadoDe(r.idReserva, ['ANTICIPO', 'TOTALIDAD', 'DEPOSITO_GARANTIA']);
            const pendiente = admitePagos(r) && (saldoAlquiler(r) > 0 || saldoDeposito(r) > 0);
            const acciones = [`<button class="boton boton-secundario boton-pequeno" data-ver="${r.idReserva}">Detalle</button>`];
            if (pendiente) {
                acciones.push(`<button class="boton boton-pequeno" data-pagar="${r.idReserva}">Pagar</button>`);
            }
            if (pagado > 0) {
                acciones.push(`<button class="boton boton-secundario boton-pequeno" data-facturas="${r.idReserva}">Facturas</button>`);
            }
            if (['SOLICITADA', 'APROBADA'].includes(r.estado)) {
                acciones.push(`<button class="boton boton-peligro boton-pequeno" data-cancelar="${r.idReserva}" data-codigo="${UI.esc(r.codigoReserva)}">Cancelar</button>`);
            }
            return `<tr>
                <td><strong>${UI.esc(r.codigoReserva)}</strong><br><span class="ayuda-campo">${UI.fecha(r.fechaSolicitud)}</span></td>
                <td>${equipos}</td>
                <td>${UI.fecha(r.fechaInicio)} → ${UI.fecha(r.fechaFin)}<br><span class="ayuda-campo">${r.diasAlquiler} día(s)</span></td>
                <td>${UI.insignia(r.estado)}</td>
                <td>${UI.pesos(r.montoTotalEstimado)}<br><span class="ayuda-campo">Depósito ${UI.pesos(r.depositoGarantia)}</span></td>
                <td>${pagado > 0 ? UI.pesos(pagado) : '<span class="ayuda-campo">—</span>'}
                    ${admitePagos(r) && saldoAlquiler(r) > 0 ? `<br><span class="texto-aviso">Saldo ${UI.pesos(saldoAlquiler(r))}</span>` : ''}</td>
                <td><div class="acciones-celda">${acciones.join('')}</div></td>
            </tr>`;
        }).join('');

        tablaReservas.querySelectorAll('[data-ver]').forEach(b => b.addEventListener('click', () => verReserva(Number(b.dataset.ver))));
        tablaReservas.querySelectorAll('[data-pagar]').forEach(b => b.addEventListener('click', () => abrirPago(Number(b.dataset.pagar))));
        tablaReservas.querySelectorAll('[data-facturas]').forEach(b => b.addEventListener('click', () => verFacturasDeReserva(Number(b.dataset.facturas))));
        tablaReservas.querySelectorAll('[data-cancelar]').forEach(b => b.addEventListener('click', () => cancelar(Number(b.dataset.cancelar), b.dataset.codigo)));
    }

    async function cancelar(id, codigo) {
        if (!confirm(`¿Cancelar la reserva ${codigo}? Esta acción no se puede deshacer.`)) return;
        try {
            await API.reservas.cancelar(id);
            UI.toast('Reserva ' + codigo + ' cancelada', 'exito');
            cargarReservas();
        } catch (e) {
            UI.mensaje('mensaje', e.message, 'error');
        }
    }

    async function verReserva(id) {
        const r = reservas.find(x => x.idReserva === id);
        if (!r) return;
        const cuerpo = document.getElementById('reserva-cuerpo');
        document.getElementById('reserva-titulo').textContent = 'Reserva ' + r.codigoReserva;
        UI.abrirModal('modal-reserva');

        const equipos = (r.detalles || []).map(d => `
            <div class="item-equipo">
                <img src="${UI.esc(UI.imagen(d.imagenHerramienta))}" alt="" onerror="this.onerror=null;this.src='${UI.IMAGEN_POR_DEFECTO}';">
                <div>
                    <strong>${UI.esc(d.nombreHerramienta)}</strong>
                    <div class="ayuda-campo">${d.cantidad} und × ${d.diasAlquiler} día(s) × ${UI.pesos(d.precioUnitarioDia)}</div>
                </div>
                <strong>${UI.pesos(d.subtotal)}</strong>
            </div>`).join('');

        let html = `
            <div class="fila-insignias">${UI.insignia(r.estado)}<span class="ayuda-campo">Solicitada el ${UI.fechaConHora(r.fechaSolicitud)}</span></div>
            <div class="lista-datos">
                <div class="dato"><div class="etiqueta">Inicio</div><div class="valor">${UI.fecha(r.fechaInicio)}</div></div>
                <div class="dato"><div class="etiqueta">Devolución</div><div class="valor">${UI.fecha(r.fechaFin)}</div></div>
                <div class="dato"><div class="etiqueta">Valor alquiler</div><div class="valor">${UI.pesos(r.montoTotalEstimado)}</div></div>
                <div class="dato"><div class="etiqueta">Depósito (30 %)</div><div class="valor">${UI.pesos(r.depositoGarantia)}</div></div>
            </div>
            ${r.motivoRechazo ? `<div class="mensaje mensaje-error visible">Motivo del rechazo: ${UI.esc(r.motivoRechazo)}</div>` : ''}
            ${r.notasCliente ? `<p class="ayuda-campo">Notas: ${UI.esc(r.notasCliente)}</p>` : ''}
            <h3 class="titulo-seccion">Equipos</h3>
            <div class="lista-equipos">${equipos}</div>`;

        if (r.estado === 'FINALIZADA') {
            html += '<h3 class="titulo-seccion">Devolución</h3><div id="detalle-devolucion" class="cargando">⏳ Consultando...</div>';
        }
        cuerpo.innerHTML = html;

        if (r.estado === 'FINALIZADA') {
            const caja = document.getElementById('detalle-devolucion');
            try {
                const d = await API.devoluciones.deReserva(r.idReserva);
                caja.className = '';
                caja.innerHTML = pintarDevolucion(d);
                caja.querySelectorAll('[data-pagar-cargo]').forEach(b => b.addEventListener('click', async () => {
                    try {
                        await UI.conBoton(b, '⏳', () => API.devoluciones.pagarCargo(Number(b.dataset.pagarCargo)));
                        UI.toast('Cargo pagado', 'exito');
                        verReserva(r.idReserva);
                    } catch (e) {
                        UI.toast(e.message, 'error');
                    }
                }));
            } catch (e) {
                caja.className = 'ayuda-campo';
                caja.textContent = e.estado === 404 ? 'La reserva se finalizó sin acta de devolución.' : e.message;
            }
        }
    }

    function pintarDevolucion(d) {
        const cargos = (d.cargosAdicionales || []).map(c => `
            <tr><td>${UI.esc(c.tipoCargo.replace(/_/g, ' '))}</td><td>${UI.esc(c.descripcion)}</td><td>${UI.pesos(c.monto)}</td>
            <td>${c.pagado ? '<span class="insignia insignia-aprobada">PAGADO</span>'
                : `<button class="boton boton-pequeno" data-pagar-cargo="${c.id}">Pagar</button>`}</td></tr>`).join('');
        return `
            <div class="lista-datos">
                <div class="dato"><div class="etiqueta">Fecha pactada</div><div class="valor">${UI.fecha(d.fechaDevolucionPactada)}</div></div>
                <div class="dato"><div class="etiqueta">Fecha real</div><div class="valor">${UI.fecha(d.fechaDevolucionReal)}</div></div>
                <div class="dato"><div class="etiqueta">Días de retraso</div><div class="valor">${d.diasRetraso}</div></div>
                <div class="dato"><div class="etiqueta">Estado del equipo</div><div class="valor">${UI.esc(String(d.estadoEquipoGeneral).replace(/_/g, ' '))}</div></div>
            </div>
            ${d.observaciones ? `<p class="ayuda-campo">${UI.esc(d.observaciones)}</p>` : ''}
            ${cargos ? `<div class="envoltura-tabla"><table><thead><tr><th>Cargo</th><th>Detalle</th><th>Monto</th><th></th></tr></thead>
              <tbody>${cargos}</tbody></table></div>` : '<p class="mensaje mensaje-exito visible">Sin cargos adicionales.</p>'}`;
    }

    // ------------------------------------------------------------------
    // Pago
    // ------------------------------------------------------------------

    const selectTipo = document.getElementById('pago-tipo');
    const selectMetodo = document.getElementById('pago-metodo');
    const inputMonto = document.getElementById('pago-monto');

    async function abrirPago(id) {
        const r = reservas.find(x => x.idReserva === id);
        if (!r) return;
        UI.ocultarMensaje('pago-mensaje');
        document.getElementById('pago-id-reserva').value = id;
        document.getElementById('pago-subtitulo').textContent =
            `${r.codigoReserva} · ${UI.fecha(r.fechaInicio)} → ${UI.fecha(r.fechaFin)}`;

        try {
            if (!metodos) metodos = await API.pagos.metodos();
        } catch (e) {
            UI.mensaje('mensaje', e.message, 'error');
            return;
        }
        selectMetodo.innerHTML = metodos.map(m =>
            `<option value="${m.idMetodoPago}">${UI.esc(m.nombre.replace(/_/g, ' '))}</option>`).join('');

        const saldo = saldoAlquiler(r);
        const nadaPagado = pagadoDe(id, ['ANTICIPO', 'TOTALIDAD']) === 0;
        const opciones = [];
        if (saldo > 0) opciones.push(['TOTALIDAD', `Saldo del alquiler (${UI.pesos(saldo)})`, saldo]);
        if (saldo > 0 && nadaPagado) opciones.push(['ANTICIPO', `Anticipo 50 % (${UI.pesos(Number(r.montoTotalEstimado) / 2)})`, Math.round(Number(r.montoTotalEstimado) * 50) / 100]);
        if (saldoDeposito(r) > 0) opciones.push(['DEPOSITO_GARANTIA', `Depósito de garantía (${UI.pesos(saldoDeposito(r))})`, saldoDeposito(r)]);

        if (!opciones.length) {
            UI.toast('Esta reserva no tiene saldos pendientes.', 'info');
            return;
        }
        selectTipo.innerHTML = opciones.map(([v, t, m]) => `<option value="${v}" data-monto="${m}">${t}</option>`).join('');
        actualizarVistaPago();
        UI.abrirModal('modal-pago');
    }

    selectTipo.addEventListener('change', actualizarVistaPago);

    function actualizarVistaPago() {
        const opcion = selectTipo.selectedOptions[0];
        const monto = opcion ? Number(opcion.dataset.monto) : 0;
        inputMonto.value = monto.toFixed(2);
        const subtotal = Math.round(monto / 1.19 * 100) / 100;
        document.getElementById('prev-subtotal').textContent = UI.pesos(subtotal);
        document.getElementById('prev-iva').textContent = UI.pesos(monto - subtotal);
        document.getElementById('prev-total').textContent = UI.pesos(monto);
        document.getElementById('pago-ayuda').textContent = selectTipo.value === 'DEPOSITO_GARANTIA'
            ? 'El depósito se devuelve al entregar el equipo sin daños.'
            : 'Las tarifas incluyen IVA; la factura lo muestra desglosado.';
    }

    document.getElementById('form-pago').addEventListener('submit', async (e) => {
        e.preventDefault();
        UI.ocultarMensaje('pago-mensaje');
        const boton = document.getElementById('btn-confirmar-pago');
        try {
            const pago = await UI.conBoton(boton, '⏳ Procesando pago...', () => API.pagos.pagar({
                idReserva: Number(document.getElementById('pago-id-reserva').value),
                idMetodoPago: Number(selectMetodo.value),
                tipoPago: selectTipo.value,
                monto: Number(inputMonto.value)
            }));
            UI.cerrarModal('modal-pago');
            UI.toast(`Pago aprobado (${pago.numeroTransaccion})`, 'exito');
            if (pago.factura) mostrarFactura(pago.factura);
            cargarReservas();
        } catch (error) {
            UI.mensaje('pago-mensaje', error.message, 'error');
        }
    });

    // ------------------------------------------------------------------
    // Facturas
    // ------------------------------------------------------------------

    async function verFacturasDeReserva(idReserva) {
        try {
            const lista = await API.facturas.deReserva(idReserva);
            if (!lista.length) {
                UI.toast('La reserva no tiene facturas.', 'info');
                return;
            }
            mostrarFactura(lista[lista.length - 1], lista);
        } catch (e) {
            UI.mensaje('mensaje', e.message, 'error');
        }
    }

    function mostrarFactura(f, todas) {
        facturaVisible = f;
        const otras = (todas || []).length > 1
            ? `<div class="fila-botones">${todas.map(x => `<button class="boton boton-secundario boton-pequeno" data-num="${UI.esc(x.numeroFactura)}">${UI.esc(x.numeroFactura)}</button>`).join('')}</div>`
            : '';
        const detalles = (f.detalles || []).map(d => `
            <tr><td>${UI.esc(d.descripcionItem)}</td><td>${d.cantidad}</td><td>${UI.pesos(d.subtotalLinea)}</td></tr>`).join('');
        document.getElementById('factura-cuerpo').innerHTML = `
            ${otras}
            <div class="caja-factura">
                <div class="factura-header">
                    <h4>${UI.esc(f.numeroFactura)}</h4>
                    ${UI.insignia(f.estado)}
                </div>
                <p class="ayuda-campo">Emitida el ${UI.fechaConHora(f.fechaEmision)} · Pago #${f.idPago}</p>
                <div class="envoltura-tabla"><table>
                    <thead><tr><th>Descripción</th><th>Cant.</th><th>Base</th></tr></thead>
                    <tbody>${detalles}</tbody>
                </table></div>
                <div class="factura-fila-total"><span>Base gravable:</span><strong>${UI.pesos(f.subtotal)}</strong></div>
                <div class="factura-fila-total"><span>IVA 19 %:</span><strong>${UI.pesos(f.iva)}</strong></div>
                <div class="factura-fila-total gran-total"><span>Total pagado:</span><strong>${UI.pesos(f.total)}</strong></div>
            </div>`;
        document.querySelectorAll('#factura-cuerpo [data-num]').forEach(b => b.addEventListener('click', () => {
            mostrarFactura(todas.find(x => x.numeroFactura === b.dataset.num), todas);
        }));
        UI.abrirModal('modal-factura');
    }

    document.getElementById('btn-descargar-factura').addEventListener('click', async (e) => {
        if (!facturaVisible) return;
        try {
            const texto = await UI.conBoton(e.currentTarget, '⏳', () => API.facturas.descargar(facturaVisible.numeroFactura));
            const url = URL.createObjectURL(new Blob([texto], { type: 'text/plain;charset=utf-8' }));
            const a = document.createElement('a');
            a.href = url;
            a.download = facturaVisible.numeroFactura + '.txt';
            document.body.appendChild(a);
            a.click();
            a.remove();
            setTimeout(() => URL.revokeObjectURL(url), 1000);
        } catch (error) {
            UI.toast(error.message, 'error');
        }
    });

    async function cargarPagos() {
        tablaPagos.innerHTML = UI.filaCargando(6, 'Cargando pagos...');
        try {
            const [lista, facturas] = await Promise.all([API.pagos.misPagos(), API.facturas.misFacturas()]);
            if (!reservas.length) reservas = await API.reservas.misReservas();
            pagos = lista;
            const codigo = (id) => (reservas.find(r => r.idReserva === id) || {}).codigoReserva || ('#' + id);
            const facturaDe = (idPago) => facturas.find(f => f.idPago === idPago);
            if (!lista.length) {
                tablaPagos.innerHTML = UI.filaVacia(6, 'Aún no ha realizado pagos.');
                return;
            }
            tablaPagos.innerHTML = lista.map(p => {
                const f = facturaDe(p.idPago);
                return `<tr>
                    <td><code>${UI.esc(p.numeroTransaccion)}</code></td>
                    <td>${UI.esc(codigo(p.idReserva))}</td>
                    <td>${UI.esc(String(p.tipoPago).replace(/_/g, ' '))}</td>
                    <td>${UI.pesos(p.monto)}</td>
                    <td>${UI.fechaConHora(p.fechaPago)}</td>
                    <td>${f ? `<button class="boton boton-secundario boton-pequeno" data-factura="${f.idFactura}">${UI.esc(f.numeroFactura)}</button>` : '—'}</td>
                </tr>`;
            }).join('');
            tablaPagos.querySelectorAll('[data-factura]').forEach(b => b.addEventListener('click', () =>
                mostrarFactura(facturas.find(f => f.idFactura === Number(b.dataset.factura)))));
        } catch (e) {
            tablaPagos.innerHTML = UI.filaVacia(6, 'No se pudieron cargar los pagos.');
            UI.mensaje('mensaje', e.message, 'error');
        }
    }

    // ------------------------------------------------------------------
    // Favoritos
    // ------------------------------------------------------------------

    async function cargarFavoritos() {
        const caja = document.getElementById('lista-favoritos');
        UI.cargando(caja, 'Cargando favoritos...');
        try {
            const lista = await API.favoritos.listar();
            if (!lista.length) {
                UI.vacio(caja, 'No tiene favoritos. En el catálogo toque el corazón 🤍 de un equipo para guardarlo.', '❤️');
                return;
            }
            caja.innerHTML = lista.map(h => `
                <article class="tarjeta-herramienta">
                    <div class="imagen-herramienta">
                        <img src="${UI.esc(UI.imagen(h.imagenPrincipal))}" alt="${UI.esc(h.nombre)}" onerror="this.onerror=null;this.src='${UI.IMAGEN_POR_DEFECTO}';">
                        <div class="badge-flotante">${UI.insignia(h.estadoOperativo)}</div>
                    </div>
                    <div class="cuerpo-tarjeta">
                        <h3>${UI.esc(h.nombre)}</h3>
                        <p class="marca-modelo">${UI.esc(h.marca)} · ${UI.esc(h.modelo)}</p>
                        <div class="precio-caja"><div class="precio">${UI.pesos(h.tarifaDiaria)} <small>/ día</small></div></div>
                        <p class="ayuda-campo">Guardada el ${UI.fecha(h.fechaAgregado)}</p>
                        <div class="botones-tarjeta">
                            <a class="boton boton-pequeno" href="index.html">Ir al catálogo</a>
                            <button class="boton boton-peligro boton-pequeno" data-quitar="${h.idHerramienta}">Quitar</button>
                        </div>
                    </div>
                </article>`).join('');
            caja.querySelectorAll('[data-quitar]').forEach(b => b.addEventListener('click', async () => {
                try {
                    await API.favoritos.quitar(Number(b.dataset.quitar));
                    UI.toast('Quitada de favoritos', 'info');
                    cargarFavoritos();
                } catch (e) {
                    UI.toast(e.message, 'error');
                }
            }));
        } catch (e) {
            caja.innerHTML = '';
            UI.mensaje('mensaje', e.message, 'error');
        }
    }

    // ------------------------------------------------------------------
    // Resenas
    // ------------------------------------------------------------------

    async function cargarResenas() {
        const cajaPendientes = document.getElementById('lista-pendientes');
        const cajaMias = document.getElementById('lista-mis-resenas');
        UI.cargando(cajaPendientes);
        UI.cargando(cajaMias);
        try {
            const [pendientes, mias] = await Promise.all([API.resenas.pendientes(), API.resenas.misResenas()]);
            pintarPendientes(cajaPendientes, pendientes);
            pintarMias(cajaMias, mias);
        } catch (e) {
            cajaPendientes.innerHTML = '';
            cajaMias.innerHTML = '';
            UI.mensaje('mensaje', e.message, 'error');
        }
    }

    function selectorEstrellas(nombre, valor) {
        let html = `<div class="selector-estrellas" data-nombre="${nombre}">`;
        for (let i = 5; i >= 1; i--) {
            html += `<input type="radio" id="${nombre}-${i}" name="${nombre}" value="${i}" ${valor === i ? 'checked' : ''}>
                     <label for="${nombre}-${i}" title="${i} estrella(s)">★</label>`;
        }
        return html + '</div>';
    }

    function pintarPendientes(caja, lista) {
        if (!lista.length) {
            caja.innerHTML = '<p class="ayuda-campo">No tiene equipos pendientes por calificar.</p>';
            return;
        }
        caja.innerHTML = lista.map((p, i) => `
            <form class="pendiente" data-reserva="${p.idReserva}" data-herramienta="${p.idHerramienta}">
                <img src="${UI.esc(UI.imagen(p.imagenHerramienta))}" alt="" onerror="this.onerror=null;this.src='${UI.IMAGEN_POR_DEFECTO}';">
                <div class="pendiente-cuerpo">
                    <strong>${UI.esc(p.nombreHerramienta)}</strong>
                    <span class="ayuda-campo">Reserva ${UI.esc(p.codigoReserva)} · devuelta el ${UI.fecha(p.fechaFin)}</span>
                    ${selectorEstrellas('cal-' + i, 5)}
                    <textarea name="comentario" rows="2" maxlength="500" placeholder="¿Cómo le fue con el equipo? (opcional)"></textarea>
                    <button type="submit" class="boton boton-pequeno">Publicar reseña</button>
                </div>
            </form>`).join('');
        caja.querySelectorAll('form.pendiente').forEach(form => form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const marcada = form.querySelector('input[type=radio]:checked');
            try {
                await UI.conBoton(form.querySelector('button'), '⏳', () => API.resenas.publicar({
                    idReserva: Number(form.dataset.reserva),
                    idHerramienta: Number(form.dataset.herramienta),
                    calificacion: marcada ? Number(marcada.value) : 5,
                    comentario: form.comentario.value.trim() || null
                }));
                UI.toast('¡Gracias! Su reseña ya aparece en el catálogo.', 'exito');
                cargarResenas();
            } catch (error) {
                UI.toast(error.message, 'error');
            }
        }));
    }

    function pintarMias(caja, lista) {
        if (!lista.length) {
            caja.innerHTML = '<p class="ayuda-campo">Todavía no ha publicado reseñas.</p>';
            return;
        }
        caja.innerHTML = lista.map(r => `
            <div class="resena">
                <div class="resena-cabecera">
                    <strong>${UI.esc(r.nombreHerramienta || ('Herramienta #' + r.idHerramienta))}</strong>
                    ${UI.estrellas(r.calificacion)}
                    <span class="ayuda-campo">${UI.fecha(r.fechaResena)}</span>
                </div>
                ${r.comentario ? `<p>${UI.esc(r.comentario)}</p>` : ''}
                <div class="acciones-celda">
                    <button class="boton boton-secundario boton-pequeno" data-editar="${r.idResena}" data-cal="${r.calificacion}"
                            data-com="${UI.esc(r.comentario || '')}">Editar</button>
                    <button class="boton boton-peligro boton-pequeno" data-eliminar="${r.idResena}">Eliminar</button>
                </div>
            </div>`).join('');
        caja.querySelectorAll('[data-editar]').forEach(b => b.addEventListener('click', async () => {
            const nueva = prompt('Nueva calificación (1 a 5):', b.dataset.cal);
            if (nueva === null) return;
            const comentario = prompt('Comentario:', b.dataset.com);
            if (comentario === null) return;
            try {
                await API.resenas.editar(Number(b.dataset.editar), { calificacion: Number(nueva), comentario: comentario.trim() || null });
                UI.toast('Reseña actualizada', 'exito');
                cargarResenas();
            } catch (e) {
                UI.toast(e.message, 'error');
            }
        }));
        caja.querySelectorAll('[data-eliminar]').forEach(b => b.addEventListener('click', async () => {
            if (!confirm('¿Eliminar esta reseña?')) return;
            try {
                await API.resenas.eliminar(Number(b.dataset.eliminar));
                UI.toast('Reseña eliminada', 'info');
                cargarResenas();
            } catch (e) {
                UI.toast(e.message, 'error');
            }
        }));
    }
});
