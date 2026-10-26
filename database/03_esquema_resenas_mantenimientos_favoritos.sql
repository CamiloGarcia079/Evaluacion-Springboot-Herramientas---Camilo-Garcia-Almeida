-- ============================================================================
-- PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS DE CONSTRUCCION
--
-- SCRIPT DDL 3/3 - RESENAS, MANTENIMIENTOS Y FAVORITOS
--
-- Se ejecuta DESPUES de 01_esquema_base.sql y 02_esquema_identidad_inventario.sql.
-- Igual que el anterior, no borra nada: solo crea tablas si no existen.
-- ============================================================================

USE renta_herramientas_db;

-- ============================================================================
-- 1. RESENAS DE HERRAMIENTAS
--
-- Un cliente califica (1 a 5) una herramienta que alquilo en una reserva
-- FINALIZADA. La restriccion UNIQUE (id_reserva, id_herramienta) impide
-- calificar dos veces el mismo alquiler.
--
-- 4FN: la resena depende de la pareja reserva-herramienta, no de la reserva
-- sola (una reserva puede tener varias herramientas) ni de la herramienta
-- sola (una herramienta se alquila muchas veces). Por eso va en su propia
-- tabla y no como columnas de reservas o de herramientas.
-- ============================================================================

CREATE TABLE IF NOT EXISTS resenas_herramienta (
    id_resena      BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_herramienta BIGINT       NOT NULL,
    id_cliente     BIGINT       NOT NULL,
    id_reserva     BIGINT       NOT NULL,
    calificacion   INT          NOT NULL,
    comentario     VARCHAR(500),
    fecha_resena   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_resena_herramienta
        FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE CASCADE,
    CONSTRAINT fk_resena_cliente
        FOREIGN KEY (id_cliente) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_resena_reserva
        FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva) ON DELETE CASCADE,
    CONSTRAINT uq_resena_reserva_herramienta UNIQUE (id_reserva, id_herramienta),
    CONSTRAINT chk_resena_calificacion CHECK (calificacion BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- ============================================================================
-- 2. MANTENIMIENTOS DE HERRAMIENTAS
--
-- Historial de taller: preventivo (programado), correctivo (reparacion) o
-- revision. Mientras esta EN_PROCESO la herramienta queda EN_MANTENIMIENTO y
-- no se puede despachar. fecha_fin y costo se llenan al cerrarlo.
-- ============================================================================

CREATE TABLE IF NOT EXISTS mantenimientos_herramienta (
    id_mantenimiento     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_herramienta       BIGINT        NOT NULL,
    tipo                 ENUM('PREVENTIVO', 'CORRECTIVO', 'REVISION') NOT NULL,
    descripcion          VARCHAR(500)  NOT NULL,
    fecha_inicio         DATETIME      NOT NULL,
    fecha_fin            DATETIME      NULL,
    costo                DECIMAL(12, 2) NULL,
    estado               ENUM('EN_PROCESO', 'FINALIZADO') NOT NULL DEFAULT 'EN_PROCESO',
    registrado_por       BIGINT        NOT NULL,
    observaciones_cierre VARCHAR(500),
    CONSTRAINT fk_mantenimiento_herramienta
        FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE CASCADE,
    CONSTRAINT fk_mantenimiento_usuario
        FOREIGN KEY (registrado_por) REFERENCES usuarios (id_usuario) ON DELETE RESTRICT,
    CONSTRAINT chk_mantenimiento_costo CHECK (costo IS NULL OR costo >= 0),
    CONSTRAINT chk_mantenimiento_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
) ENGINE=InnoDB;

-- ============================================================================
-- 3. FAVORITOS
--
-- Herramientas que un usuario guarda para alquilar despues. La pareja
-- (usuario, herramienta) es unica: no se repite el mismo favorito.
-- ============================================================================

CREATE TABLE IF NOT EXISTS favoritos (
    id_favorito    BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_usuario     BIGINT   NOT NULL,
    id_herramienta BIGINT   NOT NULL,
    fecha_agregado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_favorito_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_favorito_herramienta
        FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE CASCADE,
    CONSTRAINT uq_favorito_usuario_herramienta UNIQUE (id_usuario, id_herramienta)
) ENGINE=InnoDB;

-- ============================================================================
-- FIN DEL SCRIPT
-- ============================================================================

-- Examen: reporte de danos ligado a la reserva (relacion 1 a 1)
CREATE TABLE IF NOT EXISTS reporte_dano (
    id_reporte_dano BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_reserva BIGINT NOT NULL UNIQUE,
    descripcion VARCHAR(500) NOT NULL,
    costo_reparacion DOUBLE NOT NULL DEFAULT 0,
    fecha_reporte DATE NOT NULL,
    CONSTRAINT fk_reporte_dano_reserva FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva) ON DELETE CASCADE
) ENGINE=InnoDB;

