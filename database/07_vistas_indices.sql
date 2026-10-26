-- ============================================================================
-- PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS DE CONSTRUCCION
-- INDICES DE APOYO Y VISTAS ANALITICAS
--
-- Se puede ejecutar varias veces sin error:
--   * MySQL 8 no admite "CREATE INDEX IF NOT EXISTS", asi que cada indice se
--     crea solo si no aparece en information_schema.
--   * Las vistas usan CREATE OR REPLACE.
-- ============================================================================

USE renta_herramientas_db;

-- ----------------------------------------------------------------------------
-- 1. INDICES
-- ----------------------------------------------------------------------------

-- Busqueda de cruces de fechas al reservar (consulta mas frecuente del sistema)
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'reservas' AND INDEX_NAME = 'idx_reservas_fechas_estado');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_reservas_fechas_estado ON reservas (fecha_inicio, fecha_fin, estado)',
    'SELECT ''El indice idx_reservas_fechas_estado ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Reservas de un cliente (pantalla Mis reservas)
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'reservas' AND INDEX_NAME = 'idx_reservas_cliente');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_reservas_cliente ON reservas (id_cliente, fecha_solicitud)',
    'SELECT ''El indice idx_reservas_cliente ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Reservas que incluyen una herramienta (calendario de disponibilidad)
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'detalles_reserva' AND INDEX_NAME = 'idx_detalles_reserva_herramienta');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_detalles_reserva_herramienta ON detalles_reserva (id_herramienta, id_reserva)',
    'SELECT ''El indice idx_detalles_reserva_herramienta ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Pagos de una reserva
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pagos' AND INDEX_NAME = 'idx_pagos_reserva');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_pagos_reserva ON pagos (id_reserva, estado_pago)',
    'SELECT ''El indice idx_pagos_reserva ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Facturas de un cliente ordenadas por fecha
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'facturas' AND INDEX_NAME = 'idx_facturas_cliente_fecha');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_facturas_cliente_fecha ON facturas (id_cliente, fecha_emision)',
    'SELECT ''El indice idx_facturas_cliente_fecha ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Devoluciones con retraso
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'devoluciones' AND INDEX_NAME = 'idx_devoluciones_retraso');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_devoluciones_retraso ON devoluciones (dias_retraso, fecha_devolucion_pactada)',
    'SELECT ''El indice idx_devoluciones_retraso ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Cargos pendientes por tipo
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cargos_adicionales' AND INDEX_NAME = 'idx_cargos_tipo_pagado');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_cargos_tipo_pagado ON cargos_adicionales (tipo_cargo, pagado)',
    'SELECT ''El indice idx_cargos_tipo_pagado ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Promedio de estrellas por herramienta
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'resenas_herramienta' AND INDEX_NAME = 'idx_resenas_herramienta');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_resenas_herramienta ON resenas_herramienta (id_herramienta, calificacion)',
    'SELECT ''El indice idx_resenas_herramienta ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Mantenimiento abierto de una herramienta
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mantenimientos_herramienta' AND INDEX_NAME = 'idx_mantenimientos_estado');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_mantenimientos_estado ON mantenimientos_herramienta (id_herramienta, estado)',
    'SELECT ''El indice idx_mantenimientos_estado ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;


-- ----------------------------------------------------------------------------
-- 2. VISTAS
-- ----------------------------------------------------------------------------

-- Reservas con cliente, cantidad de herramientas y duracion
CREATE OR REPLACE VIEW vista_resumen_reservas AS
SELECT
    r.id_reserva,
    r.codigo_reserva,
    r.id_cliente,
    u.nombre_completo                   AS cliente,
    r.estado,
    r.fecha_inicio,
    r.fecha_fin,
    GREATEST(DATEDIFF(r.fecha_fin, r.fecha_inicio), 1) AS dias_alquiler,
    r.monto_total_estimado,
    r.deposito_garantia,
    COUNT(dr.id_detalle_reserva)        AS cantidad_herramientas
FROM reservas r
JOIN usuarios u ON u.id_usuario = r.id_cliente
LEFT JOIN detalles_reserva dr ON dr.id_reserva = r.id_reserva
GROUP BY r.id_reserva, r.codigo_reserva, r.id_cliente, u.nombre_completo, r.estado,
         r.fecha_inicio, r.fecha_fin, r.monto_total_estimado, r.deposito_garantia;

-- Facturacion con IVA desglosado y estado del pago
CREATE OR REPLACE VIEW vista_control_facturacion_iva AS
SELECT
    f.id_factura,
    f.numero_factura,
    f.id_pago,
    f.id_cliente,
    f.fecha_emision,
    f.subtotal          AS base_gravable,
    f.iva               AS iva_19,
    f.total             AS total_facturado,
    f.estado_factura,
    p.numero_transaccion,
    p.tipo_pago,
    p.estado_pago
FROM facturas f
JOIN pagos p ON p.id_pago = f.id_pago;

-- Danos reportados con su cantidad de fotos de evidencia
CREATE OR REPLACE VIEW vista_siniestralidad_herramientas AS
SELECT
    rd.id_reporte_dano,
    rd.id_devolucion,
    rd.id_herramienta,
    h.nombre                    AS herramienta,
    rd.tipo_dano,
    rd.responsable_asume,
    rd.costo_estimado_reparacion,
    COUNT(ed.id_evidencia)      AS total_fotos_evidencia
FROM reportes_dano rd
JOIN herramientas h ON h.id_herramienta = rd.id_herramienta
LEFT JOIN evidencias_dano ed ON ed.id_reporte_dano = rd.id_reporte_dano
GROUP BY rd.id_reporte_dano, rd.id_devolucion, rd.id_herramienta, h.nombre, rd.tipo_dano,
         rd.responsable_asume, rd.costo_estimado_reparacion;

-- Flota, alquileres e ingresos por proveedor (no cuenta reservas rechazadas ni canceladas)
CREATE OR REPLACE VIEW vista_ingresos_proveedor AS
SELECT
    u.id_usuario                                    AS id_proveedor,
    u.nombre_completo                               AS proveedor,
    COUNT(DISTINCT h.id_herramienta)                AS flota_total,
    COUNT(DISTINCT r.id_reserva)                    AS total_alquileres,
    COALESCE(SUM(CASE WHEN r.id_reserva IS NOT NULL THEN dr.subtotal END), 0.00) AS ingresos_totales
FROM usuarios u
JOIN herramientas h ON h.id_proveedor = u.id_usuario
LEFT JOIN detalles_reserva dr ON dr.id_herramienta = h.id_herramienta
LEFT JOIN reservas r ON r.id_reserva = dr.id_reserva
                    AND r.estado IN ('APROBADA', 'EN_CURSO', 'FINALIZADA')
GROUP BY u.id_usuario, u.nombre_completo;

-- Promedio de estrellas y numero de resenas de cada herramienta
CREATE OR REPLACE VIEW vista_calificacion_herramientas AS
SELECT
    h.id_herramienta,
    h.nombre,
    COUNT(rs.id_resena)                         AS total_resenas,
    ROUND(COALESCE(AVG(rs.calificacion), 0), 1) AS promedio_estrellas
FROM herramientas h
LEFT JOIN resenas_herramienta rs ON rs.id_herramienta = h.id_herramienta
GROUP BY h.id_herramienta, h.nombre;

-- Costo acumulado de taller por herramienta
CREATE OR REPLACE VIEW vista_costos_mantenimiento AS
SELECT
    h.id_herramienta,
    h.nombre,
    COUNT(m.id_mantenimiento)               AS total_mantenimientos,
    SUM(m.estado = 'EN_PROCESO')            AS abiertos,
    COALESCE(SUM(m.costo), 0.00)            AS costo_total
FROM herramientas h
LEFT JOIN mantenimientos_herramienta m ON m.id_herramienta = h.id_herramienta
GROUP BY h.id_herramienta, h.nombre;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================
