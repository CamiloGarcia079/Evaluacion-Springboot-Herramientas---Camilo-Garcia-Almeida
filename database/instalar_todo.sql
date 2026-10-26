-- ============================================================================
-- INSTALACION COMPLETA DE LA BASE DE DATOS (un solo archivo)
--
-- Une, en orden, los 7 scripts de esta carpeta. Ejecutarlo BORRA y vuelve a
-- crear renta_herramientas_db con todos los datos de prueba.
--
--   Consola:    mysql -u root -p < database/instalar_todo.sql
--   Workbench:  File > Open SQL Script > instalar_todo.sql > rayo (Execute)
--
-- Usuario de prueba: cualquiera de la tabla usuarios, contrasena Password123
-- ============================================================================

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 01_esquema_base.sql <<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- ============================================================================
-- PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS DE CONSTRUCCIÓN
-- SCRIPT DDL 1/3: CREACIÓN DE LA BASE DE DATOS Y TABLAS PRINCIPALES (4FN)
--
-- Orden de ejecución (o usar database/instalar_todo.sql, que los une):
--   01_esquema_base.sql  ->  02_esquema_identidad_inventario.sql  ->
--   03_esquema_resenas_mantenimientos_favoritos.sql  ->  04_datos_base.sql  ->
--   05_datos_identidad_inventario.sql  ->  06_datos_operacion.sql  ->
--   07_vistas_indices.sql
-- ============================================================================

DROP DATABASE IF EXISTS renta_herramientas_db;
CREATE DATABASE renta_herramientas_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE renta_herramientas_db;

-- ============================================================================
-- 1. TABLAS DEL MÓDULO DE IDENTIDAD Y USUARIOS
-- ============================================================================

CREATE TABLE roles (
    id_rol BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE usuarios (
    id_usuario BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(120) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    direccion VARCHAR(180) NOT NULL,
    tipo_documento ENUM('CC', 'NIT', 'CE', 'PASAPORTE') NOT NULL,
    numero_documento VARCHAR(30) NOT NULL UNIQUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 4FN: Descomposición de la dependencia multivaluada id_usuario ->-> id_rol
CREATE TABLE usuarios_roles (
    id_usuario BIGINT NOT NULL,
    id_rol BIGINT NOT NULL,
    PRIMARY KEY (id_usuario, id_rol),
    CONSTRAINT fk_usuariorol_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_usuariorol_rol FOREIGN KEY (id_rol) REFERENCES roles (id_rol) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- 2. TABLAS DEL MÓDULO DE HERRAMIENTAS E INVENTARIO
-- ============================================================================

CREATE TABLE categorias (
    id_categoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL UNIQUE,
    descripcion VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE herramientas (
    id_herramienta BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_proveedor BIGINT NOT NULL,
    id_categoria BIGINT NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    descripcion TEXT NOT NULL,
    marca VARCHAR(60) NOT NULL,
    modelo VARCHAR(60) NOT NULL,
    numero_serie VARCHAR(80) NOT NULL UNIQUE,
    estado_operativo ENUM('DISPONIBLE', 'ALQUILADA', 'EN_MANTENIMIENTO', 'FUERA_DE_SERVICIO') NOT NULL DEFAULT 'DISPONIBLE',
    tarifa_diaria DECIMAL(12, 2) NOT NULL,
    valor_reposicion DECIMAL(12, 2) NOT NULL,
    fecha_registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_herramienta_proveedor FOREIGN KEY (id_proveedor) REFERENCES usuarios (id_usuario) ON DELETE RESTRICT,
    CONSTRAINT fk_herramienta_categoria FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- 3. TABLAS DEL MÓDULO DE RESERVAS Y ALQUILERES
-- ============================================================================

CREATE TABLE reservas (
    id_reserva BIGINT AUTO_INCREMENT PRIMARY KEY,
    codigo_reserva VARCHAR(30) NOT NULL UNIQUE,
    id_cliente BIGINT NOT NULL,
    fecha_solicitud TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado ENUM('SOLICITADA', 'APROBADA', 'RECHAZADA', 'EN_CURSO', 'FINALIZADA', 'CANCELADA') NOT NULL DEFAULT 'SOLICITADA',
    estado_devolucion ENUM('PENDIENTE_DEVOLUCION', 'DEVUELTO_OK', 'DEVUELTO_CON_DANOS') NOT NULL DEFAULT 'PENDIENTE_DEVOLUCION',
    monto_total_estimado DECIMAL(12, 2) NOT NULL,
    deposito_garantia DECIMAL(12, 2) NOT NULL,
    notas_cliente VARCHAR(255),
    motivo_rechazo VARCHAR(255),
    CONSTRAINT fk_reserva_cliente FOREIGN KEY (id_cliente) REFERENCES usuarios (id_usuario) ON DELETE RESTRICT,
    CONSTRAINT chk_rango_fechas CHECK (fecha_fin >= fecha_inicio)
) ENGINE=InnoDB;

CREATE INDEX idx_reserva_fechas ON reservas (fecha_inicio, fecha_fin, estado);

-- 4FN: Desacopla las herramientas reservadas de cualquier otra característica multivaluada
CREATE TABLE detalles_reserva (
    id_detalle_reserva BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_reserva BIGINT NOT NULL,
    id_herramienta BIGINT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario_dia DECIMAL(12, 2) NOT NULL,
    dias_alquiler INT NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL,
    CONSTRAINT fk_detallereserva_reserva FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva) ON DELETE CASCADE,
    CONSTRAINT fk_detallereserva_herramienta FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE RESTRICT,
    CONSTRAINT uq_reserva_herramienta UNIQUE (id_reserva, id_herramienta)
) ENGINE=InnoDB;

-- 4FN: Desacopla la auditoría temporal de transiciones de estado de la reserva
CREATE TABLE auditoria_estados_reserva (
    id_auditoria BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_reserva BIGINT NOT NULL,
    estado_anterior VARCHAR(30),
    estado_nuevo VARCHAR(30) NOT NULL,
    fecha_cambio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cambiado_por BIGINT NOT NULL,
    observacion VARCHAR(255),
    CONSTRAINT fk_auditoria_reserva FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva) ON DELETE CASCADE,
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (cambiado_por) REFERENCES usuarios (id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- 4. TABLAS DEL MÓDULO DE PAGOS Y FACTURACIÓN
-- ============================================================================

CREATE TABLE metodos_pago (
    id_metodo_pago BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE pagos (
    id_pago BIGINT AUTO_INCREMENT PRIMARY KEY,
    numero_transaccion VARCHAR(60) NOT NULL UNIQUE,
    id_reserva BIGINT NOT NULL,
    id_metodo_pago BIGINT NOT NULL,
    monto DECIMAL(12, 2) NOT NULL,
    tipo_pago ENUM('ANTICIPO', 'TOTALIDAD', 'DEPOSITO_GARANTIA', 'MULTA_DANO', 'RECARGO_MORA') NOT NULL,
    estado_pago ENUM('PENDIENTE', 'APROBADO', 'RECHAZADO', 'REEMBOLSADO') NOT NULL DEFAULT 'PENDIENTE',
    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia_pasarela VARCHAR(120),
    CONSTRAINT fk_pago_reserva FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva) ON DELETE RESTRICT,
    CONSTRAINT fk_pago_metodo FOREIGN KEY (id_metodo_pago) REFERENCES metodos_pago (id_metodo_pago) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE facturas (
    id_factura BIGINT AUTO_INCREMENT PRIMARY KEY,
    numero_factura VARCHAR(40) NOT NULL UNIQUE,
    id_pago BIGINT NOT NULL UNIQUE,
    id_cliente BIGINT NOT NULL,
    fecha_emision TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    subtotal DECIMAL(12, 2) NOT NULL,
    iva DECIMAL(12, 2) NOT NULL,
    total DECIMAL(12, 2) NOT NULL,
    estado_factura ENUM('EMITIDA', 'ANULADA', 'PAGADA') NOT NULL DEFAULT 'EMITIDA',
    url_comprobante_pdf VARCHAR(255),
    CONSTRAINT fk_factura_pago FOREIGN KEY (id_pago) REFERENCES pagos (id_pago) ON DELETE RESTRICT,
    CONSTRAINT fk_factura_cliente FOREIGN KEY (id_cliente) REFERENCES usuarios (id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE detalles_factura (
    id_detalle_factura BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_factura BIGINT NOT NULL,
    descripcion_item VARCHAR(200) NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(12, 2) NOT NULL,
    subtotal_linea DECIMAL(12, 2) NOT NULL,
    CONSTRAINT fk_detallefactura_factura FOREIGN KEY (id_factura) REFERENCES facturas (id_factura) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- 5. TABLAS DEL MÓDULO DE DEVOLUCIONES, DAÑOS Y CARGOS
-- ============================================================================

CREATE TABLE devoluciones (
    id_devolucion BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_reserva BIGINT NOT NULL UNIQUE,
    fecha_devolucion_pactada DATE NOT NULL,
    fecha_devolucion_real DATE NOT NULL,
    recibido_por BIGINT NOT NULL,
    estado_equipo_general ENUM('BUEN_ESTADO', 'DANO_LEVE', 'DANO_GRAVE', 'PERDIDA_TOTAL') NOT NULL DEFAULT 'BUEN_ESTADO',
    dias_retraso INT NOT NULL DEFAULT 0,
    observaciones TEXT,
    CONSTRAINT fk_devolucion_reserva FOREIGN KEY (id_reserva) REFERENCES reservas (id_reserva) ON DELETE RESTRICT,
    CONSTRAINT fk_devolucion_usuario FOREIGN KEY (recibido_por) REFERENCES usuarios (id_usuario) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE reportes_dano (
    id_reporte_dano BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_devolucion BIGINT NOT NULL,
    id_herramienta BIGINT NOT NULL,
    tipo_dano ENUM('ESTETICO', 'MECANICO', 'ELECTRICO', 'FALTANTE_PIEZA', 'IRREPARABLE') NOT NULL,
    descripcion_dano TEXT NOT NULL,
    costo_estimado_reparacion DECIMAL(12, 2) NOT NULL,
    responsable_asume ENUM('CLIENTE', 'PROVEEDOR', 'POLIZA_GARANTIA') NOT NULL,
    fecha_reporte TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reporte_devolucion FOREIGN KEY (id_devolucion) REFERENCES devoluciones (id_devolucion) ON DELETE CASCADE,
    CONSTRAINT fk_reporte_herramienta FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 4FN: Desacopla la lista multivaluada de fotos de evidencia de los atributos escalares del daño
CREATE TABLE evidencias_dano (
    id_evidencia BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_reporte_dano BIGINT NOT NULL,
    url_foto VARCHAR(255) NOT NULL,
    descripcion_foto VARCHAR(200),
    fecha_subida TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_evidencia_reporte FOREIGN KEY (id_reporte_dano) REFERENCES reportes_dano (id_reporte_dano) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cargos_adicionales (
    id_cargo BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_devolucion BIGINT NOT NULL,
    tipo_cargo ENUM('MORA_RETRASO', 'REPARACION_DANO', 'LIMPIEZA_PROFUNDA', 'REPOSICION_EQUIPO') NOT NULL,
    monto DECIMAL(12, 2) NOT NULL,
    pagado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_cargo TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    descripcion VARCHAR(255) NOT NULL,
    CONSTRAINT fk_cargo_devolucion FOREIGN KEY (id_devolucion) REFERENCES devoluciones (id_devolucion) ON DELETE CASCADE
) ENGINE=InnoDB;

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 02_esquema_identidad_inventario.sql <<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- ============================================================================
-- PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS DE CONSTRUCCION
--
-- SCRIPT DDL 2/3 - MODULOS DE IDENTIDAD, CATALOGO E INVENTARIO
--
-- Es COMPLEMENTARIO: se ejecuta DESPUES de 01_esquema_base.sql. No vuelve a
-- crear la base de datos ni toca las tablas que ya existen; agrega las tablas
-- que completan la normalizacion en 4FN de identidad e inventario.
-- ============================================================================

USE renta_herramientas_db;

-- ============================================================================
-- 1. PERMISOS Y SU RELACION CON LOS ROLES
--
-- 4FN: un rol tiene muchos permisos y un permiso pertenece a muchos roles.
-- Guardar los permisos como una lista dentro de la fila del rol
-- (permisos = 'CREAR,EDITAR,BORRAR') romperia incluso la 1FN. La tabla puente
-- roles_permisos descompone esa dependencia multivaluada.
-- ============================================================================

CREATE TABLE IF NOT EXISTS permisos (
    id_permiso  BIGINT AUTO_INCREMENT PRIMARY KEY,
    codigo      VARCHAR(60)  NOT NULL UNIQUE,
    descripcion VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS roles_permisos (
    id_rol     BIGINT NOT NULL,
    id_permiso BIGINT NOT NULL,
    PRIMARY KEY (id_rol, id_permiso),
    CONSTRAINT fk_rolpermiso_rol
        FOREIGN KEY (id_rol) REFERENCES roles (id_rol) ON DELETE CASCADE,
    CONSTRAINT fk_rolpermiso_permiso
        FOREIGN KEY (id_permiso) REFERENCES permisos (id_permiso) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- 2. PERFILES DIFERENCIADOS DE USUARIO
--
-- 4FN: los datos de proveedor (razon social, verificacion) y los de cliente
-- (cupo de credito, tipo de cliente) son conjuntos de atributos independientes
-- entre si. Si vivieran dentro de la tabla usuarios, cada cliente tendria en
-- NULL todas las columnas de proveedor y viceversa.
--
-- La relacion es 1 a 1 opcional, garantizada con UNIQUE sobre id_usuario.
-- ============================================================================

CREATE TABLE IF NOT EXISTS perfiles_proveedor (
    id_perfil_proveedor   BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_usuario            BIGINT NOT NULL UNIQUE,
    razon_social          VARCHAR(150) NOT NULL,
    nombre_comercial      VARCHAR(120),
    ciudad_operacion      VARCHAR(80)  NOT NULL,
    sitio_web             VARCHAR(150),
    fecha_vinculacion     DATE         NOT NULL,
    verificado            BOOLEAN      NOT NULL DEFAULT FALSE,
    calificacion_promedio INT          DEFAULT 0,
    CONSTRAINT fk_perfilproveedor_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT chk_calificacion_proveedor
        CHECK (calificacion_promedio BETWEEN 0 AND 5)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS perfiles_cliente (
    id_perfil_cliente     BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_usuario            BIGINT NOT NULL UNIQUE,
    tipo_cliente          ENUM('PARTICULAR', 'EMPRESARIAL') NOT NULL DEFAULT 'PARTICULAR',
    ciudad_residencia     VARCHAR(80),
    cupo_credito          DECIMAL(12, 2) DEFAULT 0.00,
    fecha_registro        DATE NOT NULL,
    alquileres_realizados INT  DEFAULT 0,
    CONSTRAINT fk_perfilcliente_usuario
        FOREIGN KEY (id_usuario) REFERENCES usuarios (id_usuario) ON DELETE CASCADE,
    CONSTRAINT chk_cupo_no_negativo CHECK (cupo_credito >= 0)
) ENGINE=InnoDB;

-- ============================================================================
-- 3. COLUMNA ADICIONAL DE HERRAMIENTAS
--
-- Se agrega la ubicacion fisica en bodega, que necesita el panel del proveedor.
-- Va como columna normal porque es un dato escalar y monovaluado: cada
-- herramienta esta en un solo lugar.
--
-- Nota: MySQL 8 no admite "ADD COLUMN IF NOT EXISTS". Para que el script se
-- pueda ejecutar varias veces sin error, se consulta primero el diccionario
-- de datos y se arma la sentencia dinamicamente.
--
-- Se usa este patron y no un procedimiento almacenado a proposito: evita la
-- directiva DELIMITER, que es propia del cliente de consola de MySQL y falla
-- en varios gestores graficos.
-- ============================================================================

SET @existe_columna := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = 'herramientas'
      AND COLUMN_NAME  = 'ubicacion_bodega'
);

SET @sentencia := IF(@existe_columna = 0,
    'ALTER TABLE herramientas ADD COLUMN ubicacion_bodega VARCHAR(120) NULL AFTER valor_reposicion',
    'SELECT ''La columna ubicacion_bodega ya existia, no se modifico nada'' AS aviso');

PREPARE stmt FROM @sentencia;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 4. CATEGORIAS MULTIPLES POR HERRAMIENTA
--
-- 4FN: una herramienta puede pertenecer a varias categorias (un martillo
-- demoledor es "Demolicion" y tambien "Electricas"). Esa lista es independiente
-- de su galeria de fotos y de sus tarifas.
--
-- Si se guardaran las tres cosas en una sola tabla, para una herramienta con
-- 3 categorias, 4 fotos y 3 tarifas harian falta 3 x 4 x 3 = 36 filas con
-- datos repetidos. Separandolas quedan 3 + 4 + 3 = 10 filas. Esa explosion
-- combinatoria es exactamente lo que elimina la 4FN.
-- ============================================================================

CREATE TABLE IF NOT EXISTS herramientas_categorias (
    id_herramienta BIGINT NOT NULL,
    id_categoria   BIGINT NOT NULL,
    PRIMARY KEY (id_herramienta, id_categoria),
    CONSTRAINT fk_herrcat_herramienta
        FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE CASCADE,
    CONSTRAINT fk_herrcat_categoria
        FOREIGN KEY (id_categoria) REFERENCES categorias (id_categoria) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- 5. GALERIA DE IMAGENES
--
-- 4FN: la lista de fotos es multivaluada e independiente de las categorias y
-- de las tarifas. Columnas tipo foto1, foto2, foto3 violarian la 1FN y ademas
-- limitarian artificialmente la cantidad de imagenes.
-- ============================================================================

CREATE TABLE IF NOT EXISTS herramientas_imagenes (
    id_imagen           BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_herramienta      BIGINT NOT NULL,
    url_foto            VARCHAR(255) NOT NULL,
    descripcion_foto    VARCHAR(200),
    es_principal        BOOLEAN NOT NULL DEFAULT FALSE,
    orden_visualizacion INT     NOT NULL DEFAULT 1,
    fecha_subida        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_imagen_herramienta
        FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE CASCADE,
    CONSTRAINT uq_imagen_url UNIQUE (id_herramienta, url_foto)
) ENGINE=InnoDB;

SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'herramientas_imagenes'
                  AND INDEX_NAME = 'idx_imagen_herramienta');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_imagen_herramienta ON herramientas_imagenes (id_herramienta, es_principal)',
    'SELECT ''El indice idx_imagen_herramienta ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 6. FICHA TECNICA
--
-- 4FN: cada tipo de maquina tiene atributos distintos (un andamio no tiene
-- voltaje, un taladro no tiene altura maxima). Modelarlos como pares
-- atributo/valor evita una tabla con decenas de columnas casi siempre en NULL.
-- ============================================================================

CREATE TABLE IF NOT EXISTS especificaciones_tecnicas (
    id_especificacion BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_herramienta    BIGINT NOT NULL,
    atributo          VARCHAR(80)  NOT NULL,
    valor             VARCHAR(120) NOT NULL,
    unidad_medida     VARCHAR(20),
    CONSTRAINT fk_especificacion_herramienta
        FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE CASCADE,
    CONSTRAINT uq_especificacion_atributo UNIQUE (id_herramienta, atributo)
) ENGINE=InnoDB;

-- ============================================================================
-- 7. TARIFAS POR MODALIDAD
--
-- 4FN: una herramienta puede tener tarifa diaria, de fin de semana, semanal y
-- mensual. Es otra dependencia multivaluada independiente de las fotos y de
-- las categorias, por lo que exige su propia tabla.
--
-- La restriccion UNIQUE impide registrar dos tarifas del mismo tipo para la
-- misma herramienta.
-- ============================================================================

CREATE TABLE IF NOT EXISTS tarifas_herramienta (
    id_tarifa      BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_herramienta BIGINT NOT NULL,
    tipo_tarifa    ENUM('DIARIA', 'FIN_DE_SEMANA', 'SEMANAL', 'MENSUAL') NOT NULL,
    valor          DECIMAL(12, 2) NOT NULL,
    activa         BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_tarifa_herramienta
        FOREIGN KEY (id_herramienta) REFERENCES herramientas (id_herramienta) ON DELETE CASCADE,
    CONSTRAINT uq_tarifa_tipo UNIQUE (id_herramienta, tipo_tarifa),
    CONSTRAINT chk_tarifa_positiva CHECK (valor > 0)
) ENGINE=InnoDB;

SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tarifas_herramienta'
                  AND INDEX_NAME = 'idx_tarifa_herramienta');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_tarifa_herramienta ON tarifas_herramienta (id_herramienta, activa)',
    'SELECT ''El indice idx_tarifa_herramienta ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 8. INDICES DE APOYO PARA LAS CONSULTAS DEL CATALOGO
--
-- El catalogo filtra constantemente por estado, por precio y por proveedor.
-- Estos indices evitan recorrer la tabla completa en cada busqueda.
-- ============================================================================

SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'herramientas'
                  AND INDEX_NAME = 'idx_herramienta_estado');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_herramienta_estado ON herramientas (estado_operativo)',
    'SELECT ''El indice idx_herramienta_estado ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'herramientas'
                  AND INDEX_NAME = 'idx_herramienta_tarifa');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_herramienta_tarifa ON herramientas (tarifa_diaria)',
    'SELECT ''El indice idx_herramienta_tarifa ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'herramientas'
                  AND INDEX_NAME = 'idx_herramienta_proveedor');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_herramienta_proveedor ON herramientas (id_proveedor)',
    'SELECT ''El indice idx_herramienta_proveedor ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @existe := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuarios'
                  AND INDEX_NAME = 'idx_usuario_email');
SET @sentencia := IF(@existe = 0,
    'CREATE INDEX idx_usuario_email ON usuarios (email)',
    'SELECT ''El indice idx_usuario_email ya existia'' AS aviso');
PREPARE stmt FROM @sentencia; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ============================================================================
-- FIN DEL SCRIPT DDL COMPLEMENTARIO
-- ============================================================================

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 03_esquema_resenas_mantenimientos_favoritos.sql <<<<<<<<<<<<<<<<<<<<<<<<<<<<
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

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 04_datos_base.sql <<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- ============================================================================
-- PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS DE CONSTRUCCIÓN
-- SCRIPT DML 1/3: DATOS BASE (roles, usuarios, categorias, herramientas y
--                 metodos de pago). Minimo 20 registros por entidad.
--
-- Los hashes de este archivo son de ejemplo; 05_datos_identidad_inventario.sql
-- los reemplaza por un BCrypt real. Contrasena de todos: Password123
-- ============================================================================

USE renta_herramientas_db;

-- ----------------------------------------------------------------------------
-- 1. ENTIDAD: roles (20 registros)
-- ----------------------------------------------------------------------------
INSERT INTO roles (id_rol, nombre, descripcion) VALUES
(1, 'ROLE_ADMIN', 'Administrador general del sistema con acceso total'),
(2, 'ROLE_PROVEEDOR', 'Proveedor de maquinaria y herramientas'),
(3, 'ROLE_CLIENTE', 'Cliente particular o contratista que alquila equipos'),
(4, 'ROLE_SUPER_ADMIN', 'Super Administrador con facultades de auditoria y configuracion'),
(5, 'ROLE_PROVEEDOR_PREMIUM', 'Proveedor certificado con prioridad de listado y beneficios'),
(6, 'ROLE_CLIENTE_EMPRESARIAL', 'Empresa constructora con linea de credito y tarifas corporativas'),
(7, 'ROLE_AUDITOR', 'Auditor de transacciones financieras y estados de equipos'),
(8, 'ROLE_SOPORTE_TECNICO', 'Personal de mesa de ayuda y soporte en plataforma'),
(9, 'ROLE_SUPERVISOR_ENTREGAS', 'Encargado de inspeccion fisica y despacho de maquinaria'),
(10, 'ROLE_INSPECTOR_DEVOLUCION', 'Especialista tecnico que evalua estado y desgaste al devolver'),
(11, 'ROLE_CONTADOR', 'Encargado de conciliacion contable y facturacion electronica'),
(12, 'ROLE_COORDINADOR_LOGISTICA', 'Gestiona despachos, fletes y transporte de maquinaria pesada'),
(13, 'ROLE_GESTOR_COBRANZAS', 'Encargado de seguimiento a carteras vencidas y moras'),
(14, 'ROLE_PERITO_DANOS', 'Valuador oficial de siniestros y reclamos de garantias'),
(15, 'ROLE_ASISTENTE_VENTAS', 'Ejecutivo comercial para captacion de contratistas'),
(16, 'ROLE_SUPERVISOR_PROVEEDORES', 'Verifica legalidad y documentacion de proveedores'),
(17, 'ROLE_OPERADOR_BODEGA', 'Control de patio de herramientas y almacenamiento'),
(18, 'ROLE_ANALISTA_RIESGO', 'Evaluacion crediticia de clientes antes de alquileres grandes'),
(19, 'ROLE_CLIENTE_FRECUENTE', 'Cliente particular con historial positivo y descuentos especiales'),
(20, 'ROLE_INVITADO', 'Usuario en proceso de verificacion documental');

-- ----------------------------------------------------------------------------
-- 2. ENTIDAD: usuarios (20 registros)
-- (Contraseñas hash bcrypt simuladas compatibles con Spring Security)
-- ----------------------------------------------------------------------------
INSERT INTO usuarios (id_usuario, nombre_completo, email, password_hash, telefono, direccion, tipo_documento, numero_documento, activo) VALUES
(1, 'Carlos Andres Perez', 'admin.perez@rentatool.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3105550101', 'Calle 100 # 15-20, Bogota', 'CC', '1010202301', TRUE),
(2, 'Maria Fernanda Gomez', 'admin.gomez@rentatool.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3115550102', 'Carrera 7 # 72-10, Bogota', 'CC', '1010202302', TRUE),
(3, 'Constructora Equipos del Norte SAS', 'contacto@equiposnorte.co', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3125550103', 'Autopista Norte Km 18, Chia', 'NIT', '900123456-1', TRUE),
(4, 'Maquinaria y Andamios Occidente', 'ventas@maquiantioquia.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3135550104', 'Calle 50 # 45-30, Medellin', 'NIT', '900987654-2', TRUE),
(5, 'Suministros Civiles de la Sabana', 'gerencia@sumiciviles.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3145550105', 'Zona Industrial Manzana B, Cota', 'NIT', '901234567-3', TRUE),
(6, 'RentaTools Santander Ltda', 'info@rentasandander.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3155550106', 'Bulevar Santander # 28-14, Bucaramanga', 'NIT', '901345678-4', TRUE),
(7, 'Ferreteria y Maquinaria El Progreso', 'contacto@ferreprogreso.co', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3165550107', 'Avenida Colombia # 10-55, Cali', 'NIT', '901456789-5', TRUE),
(8, 'Santiago Andres Rojas', 'santiago.rojas@gmail.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3175550108', 'Calle 80 # 68-12, Bogota', 'CC', '1098765432', TRUE),
(9, 'Juan Camilo Garcia', 'camilo.garcia@gmail.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3185550109', 'Carrera 33 # 48-19, Bucaramanga', 'CC', '1098765433', TRUE),
(10, 'Inversiones y Construcciones Bolivar', 'compras@inverbolivar.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3195550110', 'Avenida El Dorado # 69-70, Bogota', 'NIT', '900555666-8', TRUE),
(11, 'Obras y Estructuras Caribe SAS', 'licitaciones@obrascaribe.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3205550111', 'Calle 72 # 56-40, Barranquilla', 'NIT', '900777888-9', TRUE),
(12, 'Andres Mauricio Restrepo', 'andres.restrepo@hotmail.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3215550112', 'Transversal 39 # 74-20, Medellin', 'CC', '1020304050', TRUE),
(13, 'Alejandra Sofia Benitez', 'aleja.benitez@yahoo.es', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3225550113', 'Calle 134 # 19-45, Bogota', 'CC', '1030405060', TRUE),
(14, 'Consorcio Vial Del Pacifico', 'operaciones@vialpacifico.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3235550114', 'Carrera 1 # 14-80, Buenaventura', 'NIT', '901112233-4', TRUE),
(15, 'Camilo Ernesto Vargas', 'camilovargas.arq@gmail.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3245550115', 'Carrera 15 # 85-30, Bogota', 'CC', '1040506070', TRUE),
(16, 'Disenos y Cimentaciones Andinas', 'proyectos@cimentacionesandinas.co', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3255550116', 'Calle 67 # 12-09, Pereira', 'NIT', '901998877-6', TRUE),
(17, 'Gustavo Adolfo Quintero', 'tavogquintero@gmail.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3265550117', 'Calle 9 # 42-18, Cali', 'CC', '1050607080', TRUE),
(18, 'Soluciones Electricas e Hidraulicas', 'info@solucioneseh.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3275550118', 'Carrera 27 # 36-15, Floridablanca', 'NIT', '901554433-2', TRUE),
(19, 'Laura Marcela Ospina', 'laura.ospina@gmail.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3285550119', 'Calle 140 # 11-25, Bogota', 'CC', '1060708090', TRUE),
(20, 'Julian David Morales', 'jmorales.civil@outlook.com', '$2a$10$w8TKnN6wQ14b8Z5Zg1j0m.bQYjVd8zN6C8o1t.3J9F1kR0m5yq1yW', '3295550120', 'Avenida Las Vegas # 16-40, Envigado', 'CC', '1070809010', TRUE);

-- ----------------------------------------------------------------------------
-- 3. ENTIDAD: usuarios_roles (20 registros)
-- ----------------------------------------------------------------------------
INSERT INTO usuarios_roles (id_usuario, id_rol) VALUES
(1, 1),  (1, 4),  (2, 1),  (3, 2),  (3, 5),
(4, 2),  (5, 2),  (6, 2),  (7, 2),  (8, 3),
(8, 19), (9, 3),  (10, 3), (10, 6), (11, 3),
(11, 6), (12, 3), (13, 3), (14, 3), (15, 3);

-- ----------------------------------------------------------------------------
-- 4. ENTIDAD: categorias (20 registros)
-- ----------------------------------------------------------------------------
INSERT INTO categorias (id_categoria, nombre, descripcion) VALUES
(1, 'Compactacion y Suelos', 'Vibrocompactadores, bailarinas y rodillos manuales'),
(2, 'Demolicion y Perforacion', 'Martillos demoledores, rotomartillos y taladros de impacto'),
(3, 'Corte y Desbaste', 'Cortadoras de concreto, pulidoras y sierras circulares'),
(4, 'Concreto y Mezclado', 'Mezcladoras de bulto, tolvas y vibradores de concreto'),
(5, 'Trabajo en Alturas', 'Andamios certificados, arneses y plataformas elevadoras'),
(6, 'Generacion de Energia', 'Plantas electricas diesel y a gasolina e inversores'),
(7, 'Bombeo y Achique', 'Motobombas sumergibles, autocebantes y de lodos'),
(8, 'Soldadura y Corte Termico', 'Soldadores inverter, equipos oxiacetilenicos y de microalambre'),
(9, 'Topografia y Medicion', 'Niveles opticos, estaciones totales y distanciómetros laser'),
(10, 'Limpieza Industrial', 'Hidrolavadoras de alta presion y aspiradoras industriales'),
(11, 'Elevacion y Carga', 'Polipastos, malacates de obra y diferenciales manuales'),
(12, 'Pintura y Recubrimientos', 'Equipos airless, compresores de aire y pistolas neumaticas'),
(13, 'Fijacion y Ensamble', 'Pistolas de fijacion neumatica, clavadoras y remachadoras'),
(14, 'Iluminacion de Obra', 'Torres de iluminacion portatiles y reflectores LED de alto poder'),
(15, 'Equipos Neumaticos', 'Compresores de piston, mangueras de alta presion y rompedores'),
(16, 'Jardineria y Movimiento Liviano', 'Desbrozadoras, ahoyadoras y motosierras de despeje'),
(17, 'Seguridad y Senalizacion', 'Vallas de contencion, conos viales y senales reflectivas'),
(18, 'Climatizacion y Secado', 'Calefactores de obra, extractores de aire y deshumidificadores'),
(19, 'Herramientas Inalambricas', 'Kits a bateria de 18V/20V para ensamble ligero'),
(20, 'Pruebas Hidraulicas', 'Bombas manuales y electricas de prueba de presion hidrostatica');

-- ----------------------------------------------------------------------------
-- 5. ENTIDAD: herramientas (20 registros)
-- ----------------------------------------------------------------------------
INSERT INTO herramientas (id_herramienta, id_proveedor, id_categoria, nombre, descripcion, marca, modelo, numero_serie, estado_operativo, tarifa_diaria, valor_reposicion) VALUES
(1, 3, 1, 'Vibrocompactador Tipo Rana 5.5 HP', 'Placa vibratoria para compactacion de asfalto y gravilla', 'Wacker Neuson', 'WP1550', 'WN-RANA-2024-001', 'DISPONIBLE', 75000.00, 4800000.00),
(2, 3, 1, 'Apisonador Canguro 4 Tiempos', 'Bailarina compactadora de zanjas y cimentaciones estrechas', 'Mikasa', 'MTX70', 'MK-CANG-2024-002', 'DISPONIBLE', 85000.00, 6200000.00),
(3, 4, 2, 'Martillo Demoledor Hexagonal 30 kg', 'Rompedor de concreto reforzado con energia de impacto 68J', 'Bosch', 'GSH 27 VC', 'BS-DEM-2023-101', 'ALQUILADA', 110000.00, 8500000.00),
(4, 4, 2, 'Rotomartillo SDS Max 1500W', 'Taladro percutor de trabajo pesado para anclajes quimicos', 'DeWalt', 'D25763K', 'DW-ROTO-2023-202', 'DISPONIBLE', 55000.00, 3100000.00),
(5, 5, 3, 'Cortadora de Pavimento 13 HP', 'Disco diamantado de 14 pulgadas para cortes de juntas', 'Husqvarna', 'FS400-LV', 'HQ-CORT-2024-301', 'DISPONIBLE', 130000.00, 9400000.00),
(6, 5, 4, 'Mezcladora de Concreto 1.5 Bultos', 'Trompo mezclador con motor a gasolina 9 HP', 'Kipor', 'KCM-350', 'KP-MEZ-2023-401', 'ALQUILADA', 65000.00, 3900000.00),
(7, 3, 4, 'Vibrador de Concreto a Gasolina 5.5 HP', 'Manguera de aguja de 4 metros con acople rapido dynapac', 'Enar', 'Dingo-Gas', 'EN-VIB-2024-501', 'DISPONIBLE', 45000.00, 2200000.00),
(8, 4, 5, 'Seccion Andamio Multidireccional Certificado', 'Modulo de 2x2x1.5m galvanizado norma OSHA', 'Layher', 'Allround-HD', 'LH-AND-2023-601', 'DISPONIBLE', 25000.00, 1500000.00),
(9, 6, 6, 'Generador Electrico Diesel 7.5 kVA', 'Planta insonorizada monofasica y trifasica con arranque electrico', 'Caterpillar', 'RP7500E', 'CAT-GEN-2024-701', 'DISPONIBLE', 150000.00, 11000000.00),
(10, 6, 7, 'Motobomba Autocebante 3 Pulgadas', 'Bomba para desalojo rapido de aguas turbias con solidos', 'Honda', 'WT30X', 'HN-BOMB-2023-801', 'DISPONIBLE', 60000.00, 3400000.00),
(11, 7, 8, 'Soldador Inverter Multiproceso 250A', 'Soldadora TIG/MIG/MMA digital para estructuras pesadas', 'Lincoln Electric', 'PowerMIG-210', 'LE-SOLD-2024-901', 'DISPONIBLE', 90000.00, 5600000.00),
(12, 7, 9, 'Estacion Total Laser 2 Segundos', 'Instrumento topografico electronico con prisma de alcance 3km', 'Topcon', 'ES-105', 'TP-TOP-2023-010', 'DISPONIBLE', 220000.00, 18500000.00),
(13, 3, 10, 'Hidrolavadora Industrial a Gasolina 3600 PSI', 'Lavadora de alta presion para lavado de fachadas y losas', 'Karcher', 'HD 7/16-4 Cage', 'KR-HID-2024-011', 'DISPONIBLE', 70000.00, 4200000.00),
(14, 5, 11, 'Malacate de Obra 1 Tonelada con Guaya 60m', 'Elevador de carga para materiales en pisos superiores', 'Imer', 'ET-1000N', 'IM-MAL-2023-012', 'DISPONIBLE', 120000.00, 8900000.00),
(15, 4, 12, 'Equipo Pintura Airless Profesional', 'Pulverizador electrico sin aire para aplicacion de vinilos y esmaltes', 'Graco', 'UltraMax-II-490', 'GC-AIR-2024-013', 'DISPONIBLE', 95000.00, 7800000.00),
(16, 6, 14, 'Torre de Iluminacion LED Portatil 4x350W', 'Mastil telescopico de 7 metros con generador diesel integrado', 'Doosan', 'LSC-60Hz', 'DS-TOR-2023-014', 'DISPONIBLE', 280000.00, 24000000.00),
(17, 7, 15, 'Compresor de Aire Portatil 185 CFM', 'Tornillo rotativo diesel para alimentacion de rompedores triples', 'Atlas Copco', 'XAS-88', 'AC-COMP-2024-015', 'DISPONIBLE', 320000.00, 38000000.00),
(18, 5, 3, 'Pulidora Angular Industrial 9 Pulgadas', 'Esmeriladora de alto desempeno 2600W con guarda antipolvo', 'Makita', 'GA9020', 'MK-PUL-2023-016', 'DISPONIBLE', 30000.00, 950000.00),
(19, 3, 18, 'Extractor / Ventilador Axial de Obra 16 Pulgadas', 'Extractor para ventilacion en tuneles y sotanos confinados', 'Canarm', 'AX-400', 'CN-EXT-2024-017', 'DISPONIBLE', 40000.00, 1800000.00),
(20, 4, 20, 'Bomba Hidrostatica de Prueba 50 Bar', 'Bomba para verificacion de fugas en tuberias de gas y acueducto', 'Rothenberger', 'RP-50-S', 'RB-PRU-2023-018', 'DISPONIBLE', 35000.00, 1200000.00);

-- ----------------------------------------------------------------------------
-- 6. ENTIDAD: metodos_pago (20 registros)
-- ----------------------------------------------------------------------------
INSERT INTO metodos_pago (id_metodo_pago, nombre, descripcion, activo) VALUES
(1, 'PSE_BANCOLOMBIA', 'Transferencia directa cuenta Bancolombia via PSE', TRUE),
(2, 'PSE_DAVIVIENDA', 'Transferencia directa cuenta Davivienda via PSE', TRUE),
(3, 'PSE_BANCO_BOGOTA', 'Transferencia directa Banco de Bogota via PSE', TRUE),
(4, 'PSE_BBVA', 'Transferencia directa BBVA Colombia via PSE', TRUE),
(5, 'PSE_BANCO_OCCIDENTE', 'Transferencia directa Banco de Occidente via PSE', TRUE),
(6, 'TARJETA_CREDITO_VISA', 'Pago seguro pasarela de pagos Visa', TRUE),
(7, 'TARJETA_CREDITO_MASTERCARD', 'Pago seguro pasarela de pagos Mastercard', TRUE),
(8, 'TARJETA_CREDITO_AMEX', 'Tarjeta American Express para corporativos', TRUE),
(9, 'NEQUI', 'Billetera digital Nequi mediante codigo QR o push', TRUE),
(10, 'DAVIPLATA', 'Billetera digital Daviplata enlace directo', TRUE),
(11, 'TRANSFERENCIA_BANCARIA_DIRECTA', 'Consignacion en cuenta corriente empresarial', TRUE),
(12, 'EFECTIVO_CONTRA_ENTREGA', 'Pago en efectivo al momento del retiro en patio', TRUE),
(13, 'CHEQUE_GERENCIA_CONSIGNADO', 'Cheque de gerencia verificado por area contable', TRUE),
(14, 'LINEA_CREDITO_CORPORATIVO_30D', 'Credito a 30 dias para constructoras autorizadas', TRUE),
(15, 'LINEA_CREDITO_CORPORATIVO_60D', 'Credito a 60 dias con orden de compra radicada', TRUE),
(16, 'TARJETA_DEBITO_PRESENCIAL', 'Datafono presencial en patio de despacho', TRUE),
(17, 'PAGOS_BOLD_LINK', 'Enlace de cobro rapido Bold', TRUE),
(18, 'PAGOS_WOMPI_QR', 'Pasarela digital Wompi de Bancolombia', TRUE),
(19, 'MERCADO_PAGO_GATEWAY', 'Pasarela integrada MercadoPago', TRUE),
(20, 'DEPOSITO_ANTICIPADO_CUENTA', 'Abono previo transferido antes de reserva', TRUE);

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 05_datos_identidad_inventario.sql <<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- ==========================================================================
-- PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS DE CONSTRUCCION
--
-- SCRIPT DML 2/3 - MODULOS DE IDENTIDAD, CATALOGO E INVENTARIO
--
-- Cumple el requisito de MINIMO 20 REGISTROS POR CADA ENTIDAD.
-- Se ejecuta DESPUES de 04_datos_base.sql.
--
-- IMPORTANTE SOBRE LAS CONTRASENAS:
--   El script 04_datos_base.sql carga hashes de ejemplo que NO fueron
--   generados con BCrypt real, por lo que el login siempre fallaria.
--   Mas abajo se actualizan TODOS los usuarios con un hash BCrypt valido.
--   Contrasena de todos los usuarios de prueba: Password123
-- ==========================================================================

USE renta_herramientas_db;

-- --------------------------------------------------------------------------
-- ENTIDAD: permisos (24 registros)
-- --------------------------------------------------------------------------
INSERT INTO permisos (id_permiso, codigo, descripcion) VALUES
(1, 'USUARIO_LEER', 'Consultar la informacion de los usuarios'),
(2, 'USUARIO_CREAR', 'Registrar nuevos usuarios en la plataforma'),
(3, 'USUARIO_EDITAR', 'Modificar los datos de un usuario'),
(4, 'USUARIO_BLOQUEAR', 'Bloquear o reactivar la cuenta de un usuario'),
(5, 'USUARIO_ELIMINAR', 'Eliminar definitivamente una cuenta'),
(6, 'PROVEEDOR_VERIFICAR', 'Validar la documentacion legal de un proveedor'),
(7, 'PROVEEDOR_LEER', 'Consultar los perfiles de proveedor'),
(8, 'CLIENTE_LEER', 'Consultar los perfiles de cliente'),
(9, 'HERRAMIENTA_LEER', 'Consultar el catalogo de herramientas'),
(10, 'HERRAMIENTA_CREAR', 'Registrar una herramienta en el inventario'),
(11, 'HERRAMIENTA_EDITAR', 'Modificar los datos de una herramienta'),
(12, 'HERRAMIENTA_ELIMINAR', 'Eliminar una herramienta del inventario'),
(13, 'HERRAMIENTA_CAMBIAR_ESTADO', 'Cambiar el estado operativo de una herramienta'),
(14, 'CATEGORIA_LEER', 'Consultar las categorias del catalogo'),
(15, 'CATEGORIA_CREAR', 'Crear una categoria nueva'),
(16, 'CATEGORIA_EDITAR', 'Modificar una categoria existente'),
(17, 'CATEGORIA_ELIMINAR', 'Eliminar una categoria sin herramientas asociadas'),
(18, 'TARIFA_GESTIONAR', 'Administrar las tarifas de alquiler'),
(19, 'IMAGEN_GESTIONAR', 'Administrar la galeria de fotos de las herramientas'),
(20, 'ESPECIFICACION_GESTIONAR', 'Administrar la ficha tecnica de las herramientas'),
(21, 'RESERVA_LEER', 'Consultar las reservas de alquiler'),
(22, 'RESERVA_APROBAR', 'Aprobar o rechazar solicitudes de alquiler'),
(23, 'PAGO_LEER', 'Consultar los pagos registrados'),
(24, 'REPORTE_VER', 'Acceder a los reportes y estadisticas');

-- --------------------------------------------------------------------------
-- ENTIDAD: roles_permisos (40 registros)
-- 4FN: descompone la relacion muchos a muchos entre roles y permisos.
-- --------------------------------------------------------------------------
INSERT INTO roles_permisos (id_rol, id_permiso) VALUES
(1, 1),
(1, 2),
(1, 3),
(1, 4),
(1, 5),
(1, 6),
(1, 7),
(1, 8),
(1, 9),
(1, 10),
(1, 11),
(1, 12),
(1, 13),
(1, 14),
(1, 15),
(1, 16),
(1, 17),
(1, 18),
(1, 19),
(1, 20),
(1, 21),
(1, 22),
(1, 23),
(1, 24),
(2, 9),
(2, 10),
(2, 11),
(2, 12),
(2, 13),
(2, 14),
(2, 18),
(2, 19),
(2, 20),
(2, 21),
(2, 22),
(2, 23),
(3, 9),
(3, 14),
(3, 21),
(3, 23);

-- --------------------------------------------------------------------------
-- ENTIDAD: usuarios (22 registros ADICIONALES)
-- Se agregan para que perfiles_proveedor y perfiles_cliente puedan tener
-- 20 registros cada una respetando su restriccion UNIQUE sobre id_usuario.
-- --------------------------------------------------------------------------
INSERT INTO usuarios (id_usuario, nombre_completo, email, password_hash, telefono, direccion, tipo_documento, numero_documento, activo) VALUES
(21, 'Equipos Pesados del Huila SAS', 'contacto@equipohuila.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110001', 'Calle 8 # 12-45, Neiva', 'NIT', '901700001-1', TRUE),
(22, 'Alquileres Tecnicos de Boyaca', 'ventas@alquiboyaca.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110002', 'Carrera 11 # 20-30, Tunja', 'NIT', '901700002-2', TRUE),
(23, 'Maquinaria Industrial del Cauca', 'info@maquicauca.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110003', 'Calle 5 # 18-22, Popayan', 'NIT', '901700003-3', TRUE),
(24, 'Renta Equipos Nariño Ltda', 'gerencia@rentanarino.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110004', 'Carrera 27 # 14-08, Pasto', 'NIT', '901700004-4', TRUE),
(25, 'Herramientas del Magdalena SAS', 'compras@herramagdalena.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110005', 'Calle 22 # 3-40, Santa Marta', 'NIT', '901700005-5', TRUE),
(26, 'Equipos Constructivos del Meta', 'contacto@equipometa.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110006', 'Avenida 40 # 25-60, Villavicencio', 'NIT', '901700006-6', TRUE),
(27, 'Alquiler Total Caldas SAS', 'info@alquilercaldas.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110007', 'Carrera 23 # 62-15, Manizales', 'NIT', '901700007-7', TRUE),
(28, 'Maquinados y Montajes Quindio', 'ventas@maquiquindio.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110008', 'Calle 19 # 14-30, Armenia', 'NIT', '901700008-8', TRUE),
(29, 'Proveedora Industrial del Tolima', 'gerencia@proindtolima.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110009', 'Carrera 5 # 37-12, Ibague', 'NIT', '901700009-9', TRUE),
(30, 'Equipos y Andamios del Cesar', 'contacto@equiposcesar.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110010', 'Calle 16 # 9-55, Valledupar', 'NIT', '901700010-1', TRUE),
(31, 'Rental Tools Risaralda SAS', 'info@rentalrisaralda.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110011', 'Avenida 30 de Agosto # 40-20, Pereira', 'NIT', '901700011-2', TRUE),
(32, 'Servicios Tecnicos de Cordoba', 'ventas@sertecordoba.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110012', 'Carrera 6 # 62-18, Monteria', 'NIT', '901700012-3', TRUE),
(33, 'Hector Fabio Mejia Maquinaria', 'hfmejia.maquinaria@gmail.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3301110013', 'Calle 44 # 70-25, Barranquilla', 'CC', '7208090100', TRUE),
(34, 'Sandra Milena Cardenas', 'sandra.cardenas@gmail.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220001', 'Calle 53 # 24-10, Bucaramanga', 'CC', '6301020301', TRUE),
(35, 'Oscar Ivan Pelaez', 'oscar.pelaez@outlook.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220002', 'Carrera 70 # 44-18, Medellin', 'CC', '7101020302', TRUE),
(36, 'Constructora Monteverde SAS', 'proyectos@monteverde.co', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220003', 'Calle 98 # 15-30, Bogota', 'NIT', '901800001-1', TRUE),
(37, 'Diana Carolina Rojas', 'diana.rojas@gmail.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220004', 'Calle 12 # 8-40, Tunja', 'CC', '5201020303', TRUE),
(38, 'Edificaciones del Oriente Ltda', 'compras@edificaoriente.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220005', 'Carrera 33 # 52-14, Bucaramanga', 'NIT', '901800002-2', TRUE),
(39, 'Wilson Andres Beltran', 'wilson.beltran@yahoo.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220006', 'Calle 80 # 102-11, Bogota', 'CC', '8001020304', TRUE),
(40, 'Remodelaciones Integrales SAS', 'contacto@remodelintegral.co', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220007', 'Avenida 6 # 23-50, Cali', 'NIT', '901800003-3', TRUE),
(41, 'Paola Andrea Suarez', 'paola.suarez@gmail.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220008', 'Carrera 50 # 10-22, Barranquilla', 'CC', '4501020305', TRUE),
(42, 'Obras Civiles Arismendi', 'gerencia@obrasarismendi.com', '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e', '3302220009', 'Calle 28 # 16-08, Cucuta', 'NIT', '901800004-4', TRUE);

-- --------------------------------------------------------------------------
-- ENTIDAD: usuarios_roles (27 registros ADICIONALES)
-- --------------------------------------------------------------------------
INSERT INTO usuarios_roles (id_usuario, id_rol) VALUES
(16, 2),
(17, 2),
(18, 3),
(19, 3),
(20, 3),
(21, 2),
(22, 2),
(23, 2),
(24, 2),
(25, 2),
(26, 2),
(27, 2),
(28, 2),
(29, 2),
(30, 2),
(31, 2),
(32, 2),
(33, 2),
(34, 3),
(35, 3),
(36, 3),
(37, 3),
(38, 3),
(39, 3),
(40, 3),
(41, 3),
(42, 3);

-- --------------------------------------------------------------------------
-- ENTIDAD: perfiles_proveedor (20 registros)
-- 4FN: atributos exclusivos del proveedor, separados de la tabla usuarios.
-- --------------------------------------------------------------------------
INSERT INTO perfiles_proveedor (id_usuario, razon_social, nombre_comercial, ciudad_operacion, sitio_web, fecha_vinculacion, verificado, calificacion_promedio) VALUES
(3, 'Constructora Equipos del Norte SAS', 'EquiNorte', 'Chia', 'https://www.equiposnorte.co', '2021-03-15', TRUE, 5),
(4, 'Maquinaria y Andamios Occidente SAS', 'MaquiOccidente', 'Medellin', 'https://www.maquiantioquia.com', '2020-07-02', TRUE, 5),
(5, 'Suministros Civiles de la Sabana SAS', 'SumiCiviles', 'Cota', 'https://www.sumiciviles.com', '2022-01-20', TRUE, 4),
(6, 'RentaTools Santander Ltda', 'RentaTools', 'Bucaramanga', 'https://www.rentasandander.com', '2019-11-08', TRUE, 5),
(7, 'Ferreteria y Maquinaria El Progreso SAS', 'El Progreso', 'Cali', 'https://www.ferreprogreso.co', '2021-09-30', TRUE, 4),
(16, 'Disenos y Cimentaciones Andinas SAS', 'Cimentaciones Andinas', 'Pereira', 'https://www.cimentacionesandinas.co', '2022-05-18', TRUE, 4),
(17, 'Gustavo Quintero Equipos', 'GQ Equipos', 'Cali', NULL, '2023-02-14', FALSE, 3),
(21, 'Equipos Pesados del Huila SAS', 'EquiHuila', 'Neiva', 'https://www.equipohuila.com', '2023-04-10', TRUE, 4),
(22, 'Alquileres Tecnicos de Boyaca SAS', 'AlquiBoyaca', 'Tunja', NULL, '2023-06-22', TRUE, 3),
(23, 'Maquinaria Industrial del Cauca SAS', 'MaquiCauca', 'Popayan', 'https://www.maquicauca.com', '2022-08-05', TRUE, 4),
(24, 'Renta Equipos Nariño Ltda', 'RentaNarino', 'Pasto', NULL, '2023-09-12', FALSE, 3),
(25, 'Herramientas del Magdalena SAS', 'HerraMagdalena', 'Santa Marta', 'https://www.herramagdalena.com', '2021-12-01', TRUE, 5),
(26, 'Equipos Constructivos del Meta SAS', 'EquiMeta', 'Villavicencio', NULL, '2024-01-25', TRUE, 3),
(27, 'Alquiler Total Caldas SAS', 'AlquilerTotal', 'Manizales', 'https://www.alquilercaldas.com', '2022-03-17', TRUE, 4),
(28, 'Maquinados y Montajes Quindio SAS', 'MaquiQuindio', 'Armenia', NULL, '2023-11-09', FALSE, 2),
(29, 'Proveedora Industrial del Tolima SAS', 'ProIndTolima', 'Ibague', 'https://www.proindtolima.com', '2020-10-14', TRUE, 5),
(30, 'Equipos y Andamios del Cesar SAS', 'EquiCesar', 'Valledupar', NULL, '2024-02-28', TRUE, 3),
(31, 'Rental Tools Risaralda SAS', 'RentalRisaralda', 'Pereira', 'https://www.rentalrisaralda.com', '2021-06-11', TRUE, 4),
(32, 'Servicios Tecnicos de Cordoba SAS', 'SerTeCordoba', 'Monteria', NULL, '2023-07-19', FALSE, 3),
(33, 'Hector Fabio Mejia Maquinaria', 'HFM Maquinaria', 'Barranquilla', NULL, '2024-03-05', TRUE, 4);

-- --------------------------------------------------------------------------
-- ENTIDAD: perfiles_cliente (20 registros)
-- 4FN: atributos exclusivos del cliente, separados de la tabla usuarios.
-- --------------------------------------------------------------------------
INSERT INTO perfiles_cliente (id_usuario, tipo_cliente, ciudad_residencia, cupo_credito, fecha_registro, alquileres_realizados) VALUES
(8, 'PARTICULAR', 'Bogota', 0.00, '2023-01-12', 4),
(9, 'PARTICULAR', 'Bucaramanga', 500000.00, '2023-02-20', 3),
(10, 'EMPRESARIAL', 'Bogota', 15000000.00, '2022-05-03', 12),
(11, 'EMPRESARIAL', 'Barranquilla', 12000000.00, '2022-08-17', 9),
(12, 'PARTICULAR', 'Medellin', 800000.00, '2023-04-28', 5),
(13, 'PARTICULAR', 'Bogota', 0.00, '2023-06-09', 2),
(14, 'EMPRESARIAL', 'Buenaventura', 20000000.00, '2021-11-22', 18),
(15, 'PARTICULAR', 'Bogota', 1200000.00, '2023-08-14', 6),
(18, 'EMPRESARIAL', 'Floridablanca', 9000000.00, '2022-10-05', 7),
(19, 'PARTICULAR', 'Bogota', 600000.00, '2023-09-19', 3),
(20, 'PARTICULAR', 'Envigado', 0.00, '2024-01-08', 1),
(34, 'PARTICULAR', 'Bucaramanga', 700000.00, '2024-02-11', 2),
(35, 'PARTICULAR', 'Medellin', 450000.00, '2024-02-25', 1),
(36, 'EMPRESARIAL', 'Bogota', 18000000.00, '2023-03-30', 14),
(37, 'PARTICULAR', 'Tunja', 0.00, '2024-03-16', 1),
(38, 'EMPRESARIAL', 'Bucaramanga', 11000000.00, '2022-12-07', 10),
(39, 'PARTICULAR', 'Bogota', 950000.00, '2024-04-02', 4),
(40, 'EMPRESARIAL', 'Cali', 7500000.00, '2023-05-21', 8),
(41, 'PARTICULAR', 'Barranquilla', 300000.00, '2024-04-18', 2),
(42, 'EMPRESARIAL', 'Cucuta', 6200000.00, '2023-10-26', 6);

-- --------------------------------------------------------------------------
-- ENTIDAD: herramientas_categorias (41 registros)
-- 4FN: una herramienta puede estar en varias categorias, y esa lista es
-- independiente de sus fotos y de sus tarifas.
-- --------------------------------------------------------------------------
INSERT INTO herramientas_categorias (id_herramienta, id_categoria) VALUES
(1, 1),
(1, 15),
(2, 1),
(2, 15),
(3, 2),
(3, 19),
(4, 2),
(4, 13),
(4, 19),
(5, 2),
(5, 3),
(6, 4),
(6, 11),
(7, 4),
(7, 15),
(8, 5),
(8, 17),
(9, 6),
(9, 14),
(10, 7),
(10, 20),
(11, 3),
(11, 8),
(12, 9),
(12, 17),
(13, 7),
(13, 10),
(14, 5),
(14, 11),
(15, 10),
(15, 12),
(16, 6),
(16, 14),
(17, 2),
(17, 15),
(18, 3),
(18, 19),
(19, 10),
(19, 18),
(20, 7),
(20, 20);

-- --------------------------------------------------------------------------
-- ENTIDAD: herramientas_imagenes (40 registros)
-- 4FN: galeria multivaluada en tabla propia, no como columnas foto1/foto2.
-- --------------------------------------------------------------------------
INSERT INTO herramientas_imagenes (id_herramienta, url_foto, descripcion_foto, es_principal, orden_visualizacion) VALUES
(1, 'img/vibrocompactador.jpg', 'Fotografia del equipo en obra', TRUE, 1),
(1, 'img/herramientas/vibrocompactador-rana-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(2, 'img/herramientas/apisonador-canguro.svg', 'Vista frontal del equipo', TRUE, 1),
(2, 'img/herramientas/apisonador-canguro-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(3, 'img/martillo_demoledor.jpg', 'Fotografia del equipo en obra', TRUE, 1),
(3, 'img/herramientas/martillo-demoledor-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(4, 'img/herramientas/rotomartillo-sdsmax.svg', 'Vista frontal del equipo', TRUE, 1),
(4, 'img/herramientas/rotomartillo-sdsmax-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(5, 'img/herramientas/cortadora-pavimento.svg', 'Vista frontal del equipo', TRUE, 1),
(5, 'img/herramientas/cortadora-pavimento-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(6, 'img/herramientas/mezcladora-concreto.svg', 'Vista frontal del equipo', TRUE, 1),
(6, 'img/herramientas/mezcladora-concreto-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(7, 'img/herramientas/vibrador-concreto.svg', 'Vista frontal del equipo', TRUE, 1),
(7, 'img/herramientas/vibrador-concreto-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(8, 'img/herramientas/andamio-multidireccional.svg', 'Vista frontal del equipo', TRUE, 1),
(8, 'img/herramientas/andamio-multidireccional-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(9, 'img/herramientas/generador-diesel.svg', 'Vista frontal del equipo', TRUE, 1),
(9, 'img/herramientas/generador-diesel-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(10, 'img/herramientas/motobomba-autocebante.svg', 'Vista frontal del equipo', TRUE, 1),
(10, 'img/herramientas/motobomba-autocebante-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(11, 'img/herramientas/soldador-inverter.svg', 'Vista frontal del equipo', TRUE, 1),
(11, 'img/herramientas/soldador-inverter-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(12, 'img/herramientas/estacion-total.svg', 'Vista frontal del equipo', TRUE, 1),
(12, 'img/herramientas/estacion-total-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(13, 'img/herramientas/hidrolavadora-industrial.svg', 'Vista frontal del equipo', TRUE, 1),
(13, 'img/herramientas/hidrolavadora-industrial-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(14, 'img/herramientas/malacate-obra.svg', 'Vista frontal del equipo', TRUE, 1),
(14, 'img/herramientas/malacate-obra-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(15, 'img/herramientas/equipo-airless.svg', 'Vista frontal del equipo', TRUE, 1),
(15, 'img/herramientas/equipo-airless-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(16, 'img/herramientas/torre-iluminacion.svg', 'Vista frontal del equipo', TRUE, 1),
(16, 'img/herramientas/torre-iluminacion-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(17, 'img/herramientas/compresor-aire.svg', 'Vista frontal del equipo', TRUE, 1),
(17, 'img/herramientas/compresor-aire-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(18, 'img/herramientas/pulidora-angular.svg', 'Vista frontal del equipo', TRUE, 1),
(18, 'img/herramientas/pulidora-angular-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(19, 'img/herramientas/extractor-axial.svg', 'Vista frontal del equipo', TRUE, 1),
(19, 'img/herramientas/extractor-axial-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2),
(20, 'img/herramientas/bomba-hidrostatica.svg', 'Vista frontal del equipo', TRUE, 1),
(20, 'img/herramientas/bomba-hidrostatica-ficha.svg', 'Ficha tecnica ilustrada', FALSE, 2);

-- --------------------------------------------------------------------------
-- ENTIDAD: especificaciones_tecnicas (60 registros)
-- 4FN: ficha tecnica como pares atributo/valor. Evita una tabla con
-- decenas de columnas que estarian en NULL segun el tipo de maquina.
-- --------------------------------------------------------------------------
INSERT INTO especificaciones_tecnicas (id_herramienta, atributo, valor, unidad_medida) VALUES
(1, 'Potencia', '5.5', 'HP'),
(1, 'Peso', '88', 'kg'),
(1, 'Fuerza centrifuga', '15', 'kN'),
(2, 'Potencia', '4', 'HP'),
(2, 'Peso', '70', 'kg'),
(2, 'Golpes por minuto', '650', 'gpm'),
(3, 'Potencia', '2000', 'W'),
(3, 'Energia de impacto', '68', 'J'),
(3, 'Peso', '30', 'kg'),
(4, 'Potencia', '1500', 'W'),
(4, 'Encastre', 'SDS Max', NULL),
(4, 'Peso', '10', 'kg'),
(5, 'Potencia', '13', 'HP'),
(5, 'Diametro de disco', '14', 'pulgadas'),
(5, 'Profundidad de corte', '125', 'mm'),
(6, 'Capacidad', '1.5', 'bultos'),
(6, 'Potencia', '9', 'HP'),
(6, 'Peso', '180', 'kg'),
(7, 'Potencia', '5.5', 'HP'),
(7, 'Longitud de manguera', '4', 'm'),
(7, 'Diametro de aguja', '45', 'mm'),
(8, 'Dimensiones', '2x2x1.5', 'm'),
(8, 'Carga maxima', '450', 'kg'),
(8, 'Acabado', 'Galvanizado', NULL),
(9, 'Potencia', '7.5', 'kVA'),
(9, 'Combustible', 'Diesel', NULL),
(9, 'Autonomia', '10', 'h'),
(10, 'Diametro', '3', 'pulgadas'),
(10, 'Caudal', '1100', 'L/min'),
(10, 'Potencia', '7', 'HP'),
(11, 'Amperaje', '250', 'A'),
(11, 'Procesos', 'TIG/MIG/MMA', NULL),
(11, 'Voltaje', '220', 'V'),
(12, 'Precision angular', '2', 'segundos'),
(12, 'Alcance con prisma', '3000', 'm'),
(12, 'Peso', '5.2', 'kg'),
(13, 'Presion', '3600', 'PSI'),
(13, 'Caudal', '16', 'L/min'),
(13, 'Combustible', 'Gasolina', NULL),
(14, 'Capacidad de carga', '1000', 'kg'),
(14, 'Longitud de guaya', '60', 'm'),
(14, 'Potencia', '1.5', 'kW'),
(15, 'Presion maxima', '3300', 'PSI'),
(15, 'Caudal', '3.1', 'L/min'),
(15, 'Potencia', '1100', 'W'),
(16, 'Potencia luminica', '1400', 'W'),
(16, 'Altura de mastil', '7', 'm'),
(16, 'Autonomia', '60', 'h'),
(17, 'Caudal de aire', '185', 'CFM'),
(17, 'Presion', '7', 'bar'),
(17, 'Combustible', 'Diesel', NULL),
(18, 'Potencia', '2600', 'W'),
(18, 'Diametro de disco', '9', 'pulgadas'),
(18, 'Velocidad', '6600', 'rpm'),
(19, 'Diametro', '16', 'pulgadas'),
(19, 'Caudal de aire', '3200', 'm3/h'),
(19, 'Voltaje', '110', 'V'),
(20, 'Presion maxima', '50', 'bar'),
(20, 'Capacidad de deposito', '12', 'L'),
(20, 'Peso', '11', 'kg');

-- --------------------------------------------------------------------------
-- ENTIDAD: tarifas_herramienta (58 registros)
-- 4FN: las modalidades de cobro son multivaluadas e independientes de la
-- galeria y de las categorias. La tarifa SEMANAL cobra 7 dias al precio de
-- 6 y la MENSUAL 30 dias al precio de 24.
-- --------------------------------------------------------------------------
INSERT INTO tarifas_herramienta (id_herramienta, tipo_tarifa, valor, activa) VALUES
(1, 'DIARIA', 75000.00, TRUE),
(1, 'SEMANAL', 450000.00, TRUE),
(1, 'MENSUAL', 1800000.00, TRUE),
(2, 'DIARIA', 85000.00, TRUE),
(2, 'SEMANAL', 510000.00, TRUE),
(3, 'DIARIA', 110000.00, TRUE),
(3, 'SEMANAL', 660000.00, TRUE),
(4, 'DIARIA', 55000.00, TRUE),
(4, 'SEMANAL', 330000.00, TRUE),
(4, 'FIN_DE_SEMANA', 99000.00, TRUE),
(5, 'DIARIA', 130000.00, TRUE),
(5, 'SEMANAL', 780000.00, TRUE),
(5, 'MENSUAL', 3120000.00, TRUE),
(6, 'DIARIA', 65000.00, TRUE),
(6, 'SEMANAL', 390000.00, TRUE),
(6, 'MENSUAL', 1560000.00, TRUE),
(7, 'DIARIA', 45000.00, TRUE),
(7, 'SEMANAL', 270000.00, TRUE),
(7, 'FIN_DE_SEMANA', 81000.00, TRUE),
(8, 'DIARIA', 25000.00, TRUE),
(8, 'SEMANAL', 150000.00, TRUE),
(8, 'FIN_DE_SEMANA', 45000.00, TRUE),
(9, 'DIARIA', 150000.00, TRUE),
(9, 'SEMANAL', 900000.00, TRUE),
(9, 'MENSUAL', 3600000.00, TRUE),
(10, 'DIARIA', 60000.00, TRUE),
(10, 'SEMANAL', 360000.00, TRUE),
(10, 'FIN_DE_SEMANA', 108000.00, TRUE),
(11, 'DIARIA', 90000.00, TRUE),
(11, 'SEMANAL', 540000.00, TRUE),
(11, 'FIN_DE_SEMANA', 162000.00, TRUE),
(12, 'DIARIA', 220000.00, TRUE),
(12, 'SEMANAL', 1320000.00, TRUE),
(12, 'MENSUAL', 5280000.00, TRUE),
(13, 'DIARIA', 70000.00, TRUE),
(13, 'SEMANAL', 420000.00, TRUE),
(13, 'FIN_DE_SEMANA', 126000.00, TRUE),
(14, 'DIARIA', 120000.00, TRUE),
(14, 'SEMANAL', 720000.00, TRUE),
(14, 'MENSUAL', 2880000.00, TRUE),
(15, 'DIARIA', 95000.00, TRUE),
(15, 'SEMANAL', 570000.00, TRUE),
(15, 'FIN_DE_SEMANA', 171000.00, TRUE),
(16, 'DIARIA', 280000.00, TRUE),
(16, 'SEMANAL', 1680000.00, TRUE),
(16, 'MENSUAL', 6720000.00, TRUE),
(17, 'DIARIA', 320000.00, TRUE),
(17, 'SEMANAL', 1920000.00, TRUE),
(17, 'MENSUAL', 7680000.00, TRUE),
(18, 'DIARIA', 30000.00, TRUE),
(18, 'SEMANAL', 180000.00, TRUE),
(18, 'FIN_DE_SEMANA', 54000.00, TRUE),
(19, 'DIARIA', 40000.00, TRUE),
(19, 'SEMANAL', 240000.00, TRUE),
(19, 'FIN_DE_SEMANA', 72000.00, TRUE),
(20, 'DIARIA', 35000.00, TRUE),
(20, 'SEMANAL', 210000.00, TRUE),
(20, 'FIN_DE_SEMANA', 63000.00, TRUE);

-- --------------------------------------------------------------------------
-- Ubicacion en bodega de las 20 herramientas existentes
-- --------------------------------------------------------------------------
UPDATE herramientas SET ubicacion_bodega = 'Pasillo A - Estante 1' WHERE id_herramienta = 1;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo B - Estante 1' WHERE id_herramienta = 2;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo C - Estante 1' WHERE id_herramienta = 3;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo D - Estante 1' WHERE id_herramienta = 4;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo E - Estante 1' WHERE id_herramienta = 5;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo A - Estante 2' WHERE id_herramienta = 6;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo B - Estante 2' WHERE id_herramienta = 7;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo C - Estante 2' WHERE id_herramienta = 8;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo D - Estante 2' WHERE id_herramienta = 9;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo E - Estante 2' WHERE id_herramienta = 10;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo A - Estante 3' WHERE id_herramienta = 11;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo B - Estante 3' WHERE id_herramienta = 12;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo C - Estante 3' WHERE id_herramienta = 13;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo D - Estante 3' WHERE id_herramienta = 14;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo E - Estante 3' WHERE id_herramienta = 15;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo A - Estante 4' WHERE id_herramienta = 16;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo B - Estante 4' WHERE id_herramienta = 17;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo C - Estante 4' WHERE id_herramienta = 18;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo D - Estante 4' WHERE id_herramienta = 19;
UPDATE herramientas SET ubicacion_bodega = 'Pasillo E - Estante 4' WHERE id_herramienta = 20;

-- --------------------------------------------------------------------------
-- ACTUALIZACION DE CONTRASENAS A UN HASH BCrypt REAL
--
-- Los hashes cargados en 04_datos_base.sql son de ejemplo y no validan
-- contra ninguna contrasena, por lo que el endpoint /auth/login siempre
-- respondería 'Credenciales invalidas'.
--
-- Este UPDATE deja a TODOS los usuarios de prueba con la contrasena:
--
--     Password123
--
-- El hash corresponde a BCrypt con 10 rondas, compatible con el
-- BCryptPasswordEncoder configurado en SecurityConfig.
-- --------------------------------------------------------------------------
-- (El WHERE sobre la llave primaria evita el bloqueo de 'safe updates' de MySQL Workbench.)
UPDATE usuarios SET password_hash = '$2b$10$atEV.h0BQLn6quCDnDKLQ..3WjyU6Oab0CNUfctbYQYXC9dD41L6e' WHERE id_usuario > 0;

-- --------------------------------------------------------------------------
-- CONSULTAS DE VERIFICACION
-- Se ejecutan al final para comprobar que cada entidad quedo con al menos
-- 20 registros, tal como exige el enunciado.
-- --------------------------------------------------------------------------
SELECT 'permisos'                  AS entidad, COUNT(*) AS registros FROM permisos
UNION ALL SELECT 'roles_permisos', COUNT(*) FROM roles_permisos
UNION ALL SELECT 'perfiles_proveedor', COUNT(*) FROM perfiles_proveedor
UNION ALL SELECT 'perfiles_cliente', COUNT(*) FROM perfiles_cliente
UNION ALL SELECT 'herramientas_categorias', COUNT(*) FROM herramientas_categorias
UNION ALL SELECT 'herramientas_imagenes', COUNT(*) FROM herramientas_imagenes
UNION ALL SELECT 'especificaciones_tecnicas', COUNT(*) FROM especificaciones_tecnicas
UNION ALL SELECT 'tarifas_herramienta', COUNT(*) FROM tarifas_herramienta
UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
;

-- ==========================================================================
-- FIN DEL SCRIPT DML
-- ==========================================================================

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 06_datos_operacion.sql <<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- ============================================================================
-- PLATAFORMA DE RENTA DE HERRAMIENTAS Y EQUIPOS DE CONSTRUCCION
-- SCRIPT DML 3/3: OPERACION (reservas, pagos, facturas, devoluciones, danos,
--                cargos, resenas, mantenimientos y favoritos)
--
-- Las fechas son RELATIVAS al dia de carga (CURDATE()). Asi la demostracion
-- siempre tiene solicitudes futuras por aprobar, alquileres en curso, una
-- entrega vencida (para ver el cargo por mora) y un historial coherente.
--
-- Reglas que respetan los datos:
--   * Deposito de garantia = 30 % del valor del alquiler.
--   * Ninguna herramienta tiene dos reservas activas que se crucen
--     (excepto una SOLICITADA puesta a proposito para demostrar el bloqueo).
--   * Solo hay pagos de reservas APROBADAS, EN CURSO o FINALIZADAS.
--   * Solo hay devoluciones de reservas FINALIZADAS, y resenas de clientes
--     que de verdad alquilaron la herramienta.
-- ============================================================================

USE renta_herramientas_db;

-- Estado actual de la flota segun los alquileres en curso y el taller
UPDATE herramientas SET estado_operativo = 'DISPONIBLE' WHERE id_herramienta > 0;
UPDATE herramientas SET estado_operativo = 'ALQUILADA' WHERE id_herramienta IN (4, 9, 15);
UPDATE herramientas SET estado_operativo = 'EN_MANTENIMIENTO' WHERE id_herramienta = 18;

-- ----------------------------------------------------------------------------
-- reservas (42 registros)
-- ----------------------------------------------------------------------------
INSERT INTO reservas (id_reserva, codigo_reserva, id_cliente, fecha_solicitud, fecha_inicio, fecha_fin, estado, monto_total_estimado, deposito_garantia, notas_cliente, motivo_rechazo) VALUES
(1, 'RES-2026-0001', 36, TIMESTAMP(CURDATE() - INTERVAL 153 DAY, '09:30:00'), CURDATE() - INTERVAL 148 DAY, CURDATE() - INTERVAL 142 DAY, 'FINALIZADA', 600000.00, 180000.00, 'Pavimentacion de acceso', NULL),
(2, 'RES-2026-0002', 18, TIMESTAMP(CURDATE() - INTERVAL 138 DAY, '09:30:00'), CURDATE() - INTERVAL 135 DAY, CURDATE() - INTERVAL 131 DAY, 'FINALIZADA', 100000.00, 30000.00, 'Limpieza post obra', NULL),
(3, 'RES-2026-0003', 18, TIMESTAMP(CURDATE() - INTERVAL 114 DAY, '09:30:00'), CURDATE() - INTERVAL 108 DAY, CURDATE() - INTERVAL 107 DAY, 'FINALIZADA', 200000.00, 60000.00, 'Cimentacion de cerramiento', NULL),
(4, 'RES-2026-0004', 15, TIMESTAMP(CURDATE() - INTERVAL 102 DAY, '09:30:00'), CURDATE() - INTERVAL 98 DAY, CURDATE() - INTERVAL 93 DAY, 'FINALIZADA', 650000.00, 195000.00, 'Mantenimiento de bodega', NULL),
(5, 'RES-2026-0005', 37, TIMESTAMP(CURDATE() - INTERVAL 100 DAY, '09:30:00'), CURDATE() - INTERVAL 95 DAY, CURDATE() - INTERVAL 90 DAY, 'FINALIZADA', 300000.00, 90000.00, 'Reparacion de cubierta', NULL),
(6, 'RES-2026-0006', 35, TIMESTAMP(CURDATE() - INTERVAL 87 DAY, '09:30:00'), CURDATE() - INTERVAL 83 DAY, CURDATE() - INTERVAL 78 DAY, 'FINALIZADA', 475000.00, 142500.00, 'Cimentacion de cerramiento', NULL),
(7, 'RES-2026-0007', 8, TIMESTAMP(CURDATE() - INTERVAL 85 DAY, '09:30:00'), CURDATE() - INTERVAL 82 DAY, CURDATE() - INTERVAL 77 DAY, 'FINALIZADA', 1000000.00, 300000.00, 'Instalaciones electricas provisionales', NULL),
(8, 'RES-2026-0008', 42, TIMESTAMP(CURDATE() - INTERVAL 81 DAY, '09:30:00'), CURDATE() - INTERVAL 75 DAY, CURDATE() - INTERVAL 69 DAY, 'FINALIZADA', 900000.00, 270000.00, 'Limpieza post obra', NULL),
(9, 'RES-2026-0009', 37, TIMESTAMP(CURDATE() - INTERVAL 77 DAY, '09:30:00'), CURDATE() - INTERVAL 73 DAY, CURDATE() - INTERVAL 69 DAY, 'FINALIZADA', 880000.00, 264000.00, 'Obra civil conjunto residencial', NULL),
(10, 'RES-2026-0010', 11, TIMESTAMP(CURDATE() - INTERVAL 75 DAY, '09:30:00'), CURDATE() - INTERVAL 70 DAY, CURDATE() - INTERVAL 64 DAY, 'FINALIZADA', 240000.00, 72000.00, 'Obra civil conjunto residencial', NULL),
(11, 'RES-2026-0011', 11, TIMESTAMP(CURDATE() - INTERVAL 68 DAY, '09:30:00'), CURDATE() - INTERVAL 66 DAY, CURDATE() - INTERVAL 63 DAY, 'FINALIZADA', 870000.00, 261000.00, 'Ampliacion de local comercial', NULL),
(12, 'RES-2026-0012', 9, TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '09:30:00'), CURDATE() - INTERVAL 60 DAY, CURDATE() - INTERVAL 57 DAY, 'FINALIZADA', 225000.00, 67500.00, 'Compactacion de patio trasero para placa', NULL),
(13, 'RES-2026-0013', 19, TIMESTAMP(CURDATE() - INTERVAL 64 DAY, '09:30:00'), CURDATE() - INTERVAL 59 DAY, CURDATE() - INTERVAL 53 DAY, 'FINALIZADA', 330000.00, 99000.00, 'Obra gris casa campestre', NULL),
(14, 'RES-2026-0014', 37, TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '09:30:00'), CURDATE() - INTERVAL 56 DAY, CURDATE() - INTERVAL 52 DAY, 'FINALIZADA', 1260000.00, 378000.00, 'Adecuacion de parqueadero', NULL),
(15, 'RES-2026-0015', 19, TIMESTAMP(CURDATE() - INTERVAL 59 DAY, '09:30:00'), CURDATE() - INTERVAL 55 DAY, CURDATE() - INTERVAL 54 DAY, 'FINALIZADA', 90000.00, 27000.00, 'Ampliacion de local comercial', NULL),
(16, 'RES-2026-0016', 14, TIMESTAMP(CURDATE() - INTERVAL 56 DAY, '09:30:00'), CURDATE() - INTERVAL 50 DAY, CURDATE() - INTERVAL 45 DAY, 'FINALIZADA', 450000.00, 135000.00, 'Reparacion de cubierta', NULL),
(17, 'RES-2026-0017', 38, TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '09:30:00'), CURDATE() - INTERVAL 45 DAY, CURDATE() - INTERVAL 44 DAY, 'FINALIZADA', 110000.00, 33000.00, 'Cimentacion de cerramiento', NULL),
(18, 'RES-2026-0018', 9, TIMESTAMP(CURDATE() - INTERVAL 43 DAY, '09:30:00'), CURDATE() - INTERVAL 40 DAY, CURDATE() - INTERVAL 36 DAY, 'FINALIZADA', 580000.00, 174000.00, 'Demolicion de muro y prueba de tuberia del bano', NULL),
(19, 'RES-2026-0019', 37, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '09:30:00'), CURDATE() - INTERVAL 35 DAY, CURDATE() - INTERVAL 34 DAY, 'FINALIZADA', 320000.00, 96000.00, 'Mantenimiento de bodega', NULL),
(20, 'RES-2026-0020', 9, TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '09:30:00'), CURDATE() - INTERVAL 30 DAY, CURDATE() - INTERVAL 28 DAY, 'CANCELADA', 180000.00, 54000.00, 'Soldadura de reja frontal', NULL),
(21, 'RES-2026-0021', 34, TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '09:30:00'), CURDATE() - INTERVAL 28 DAY, CURDATE() - INTERVAL 25 DAY, 'FINALIZADA', 585000.00, 175500.00, 'Limpieza post obra', NULL),
(22, 'RES-2026-0022', 12, TIMESTAMP(CURDATE() - INTERVAL 31 DAY, '09:30:00'), CURDATE() - INTERVAL 26 DAY, CURDATE() - INTERVAL 22 DAY, 'FINALIZADA', 520000.00, 156000.00, 'Pavimentacion de acceso', NULL),
(23, 'RES-2026-0023', 14, TIMESTAMP(CURDATE() - INTERVAL 28 DAY, '09:30:00'), CURDATE() - INTERVAL 24 DAY, CURDATE() - INTERVAL 23 DAY, 'FINALIZADA', 70000.00, 21000.00, 'Ampliacion de local comercial', NULL),
(24, 'RES-2026-0024', 35, TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '09:30:00'), CURDATE() - INTERVAL 23 DAY, CURDATE() - INTERVAL 21 DAY, 'FINALIZADA', 90000.00, 27000.00, 'Reparacion de cubierta', NULL),
(25, 'RES-2026-0025', 9, TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '09:30:00'), CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 17 DAY, 'FINALIZADA', 390000.00, 117000.00, 'Corte de juntas en el garaje', NULL),
(26, 'RES-2026-0026', 13, TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '09:30:00'), CURDATE() - INTERVAL 20 DAY, CURDATE() - INTERVAL 15 DAY, 'RECHAZADA', 275000.00, 82500.00, 'Perforaciones multiples', 'El cliente no adjunto el permiso de obra del conjunto'),
(27, 'RES-2026-0027', 14, TIMESTAMP(CURDATE() - INTERVAL 17 DAY, '09:30:00'), CURDATE() - INTERVAL 12 DAY, CURDATE() - INTERVAL 10 DAY, 'CANCELADA', 130000.00, 39000.00, 'Vaciado de placa cancelado por lluvias', NULL),
(28, 'RES-2026-0028', 39, TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '09:30:00'), CURDATE() - INTERVAL 10 DAY, CURDATE() - INTERVAL 7 DAY, 'RECHAZADA', 960000.00, 288000.00, 'Rompedores en via publica', 'Equipo comprometido en mantenimiento programado'),
(29, 'RES-2026-0029', 12, TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '09:30:00'), CURDATE() - INTERVAL 8 DAY, CURDATE() - INTERVAL 1 DAY, 'EN_CURSO', 665000.00, 199500.00, 'Pintura de fachada edificio Los Pinos (entrega vencida)', NULL),
(30, 'RES-2026-0030', 14, TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '09:30:00'), CURDATE() - INTERVAL 4 DAY, CURDATE() + INTERVAL 6 DAY, 'EN_CURSO', 1500000.00, 450000.00, 'Energia provisional para campamento vial', NULL),
(31, 'RES-2026-0031', 9, TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '09:30:00'), CURDATE() - INTERVAL 2 DAY, CURDATE() + INTERVAL 3 DAY, 'EN_CURSO', 275000.00, 82500.00, 'Anclajes quimicos para escalera metalica', NULL),
(32, 'RES-2026-0032', 38, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '09:30:00'), CURDATE() + INTERVAL 1 DAY, CURDATE() + INTERVAL 4 DAY, 'APROBADA', 225000.00, 67500.00, 'Compactacion de subbase para anden', NULL),
(33, 'RES-2026-0033', 9, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '09:30:00'), CURDATE() + INTERVAL 2 DAY, CURDATE() + INTERVAL 5 DAY, 'APROBADA', 75000.00, 22500.00, 'Andamio para pintar segundo piso', NULL),
(34, 'RES-2026-0034', 11, TIMESTAMP(CURDATE(), '09:30:00'), CURDATE() + INTERVAL 3 DAY, CURDATE() + INTERVAL 6 DAY, 'APROBADA', 660000.00, 198000.00, 'Replanteo topografico de lote', NULL),
(35, 'RES-2026-0035', 20, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '09:30:00'), CURDATE() + INTERVAL 3 DAY, CURDATE() + INTERVAL 6 DAY, 'SOLICITADA', 315000.00, 94500.00, 'Vaciado de columnas y achique de zanja', NULL),
(36, 'RES-2026-0036', 10, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '09:30:00'), CURDATE() + INTERVAL 4 DAY, CURDATE() + INTERVAL 8 DAY, 'APROBADA', 440000.00, 132000.00, 'Demolicion de placa en sotano', NULL),
(37, 'RES-2026-0037', 34, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '09:30:00'), CURDATE() + INTERVAL 4 DAY, CURDATE() + INTERVAL 6 DAY, 'SOLICITADA', 50000.00, 15000.00, 'Andamio para cambio de canales', NULL),
(38, 'RES-2026-0038', 19, TIMESTAMP(CURDATE(), '09:30:00'), CURDATE() + INTERVAL 5 DAY, CURDATE() + INTERVAL 7 DAY, 'SOLICITADA', 140000.00, 42000.00, 'Lavado de fachada en piedra', NULL),
(39, 'RES-2026-0039', 9, TIMESTAMP(CURDATE(), '09:30:00'), CURDATE() + INTERVAL 6 DAY, CURDATE() + INTERVAL 9 DAY, 'SOLICITADA', 105000.00, 31500.00, 'Prueba hidrostatica red de gas del apartamento', NULL),
(40, 'RES-2026-0040', 36, TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '09:30:00'), CURDATE() + INTERVAL 7 DAY, CURDATE() + INTERVAL 10 DAY, 'APROBADA', 840000.00, 252000.00, 'Jornada nocturna de pavimentacion', NULL),
(41, 'RES-2026-0041', 15, TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '09:30:00'), CURDATE() + INTERVAL 10 DAY, CURDATE() + INTERVAL 12 DAY, 'SOLICITADA', 110000.00, 33000.00, 'Perforaciones para chazos en muro', NULL),
(42, 'RES-2026-0042', 13, TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '09:30:00'), CURDATE() + INTERVAL 12 DAY, CURDATE() + INTERVAL 15 DAY, 'SOLICITADA', 330000.00, 99000.00, 'Regata para tuberia sanitaria', NULL);

-- detalles_reserva (51 registros)
INSERT INTO detalles_reserva (id_detalle_reserva, id_reserva, id_herramienta, cantidad, precio_unitario_dia, dias_alquiler, subtotal) VALUES
(1, 1, 10, 1, 60000.00, 6, 360000.00),
(2, 1, 19, 1, 40000.00, 6, 240000.00),
(3, 2, 8, 1, 25000.00, 4, 100000.00),
(4, 3, 5, 1, 130000.00, 1, 130000.00),
(5, 3, 13, 1, 70000.00, 1, 70000.00),
(6, 4, 5, 1, 130000.00, 5, 650000.00),
(7, 5, 10, 1, 60000.00, 5, 300000.00),
(8, 6, 10, 1, 60000.00, 5, 300000.00),
(9, 6, 20, 1, 35000.00, 5, 175000.00),
(10, 7, 3, 1, 110000.00, 5, 550000.00),
(11, 7, 11, 1, 90000.00, 5, 450000.00),
(12, 8, 9, 1, 150000.00, 6, 900000.00),
(13, 9, 12, 1, 220000.00, 4, 880000.00),
(14, 10, 19, 1, 40000.00, 6, 240000.00),
(15, 11, 12, 1, 220000.00, 3, 660000.00),
(16, 11, 13, 1, 70000.00, 3, 210000.00),
(17, 12, 1, 1, 75000.00, 3, 225000.00),
(18, 13, 4, 1, 55000.00, 6, 330000.00),
(19, 14, 16, 1, 280000.00, 4, 1120000.00),
(20, 14, 20, 1, 35000.00, 4, 140000.00),
(21, 15, 11, 1, 90000.00, 1, 90000.00),
(22, 16, 11, 1, 90000.00, 5, 450000.00),
(23, 17, 3, 1, 110000.00, 1, 110000.00),
(24, 18, 3, 1, 110000.00, 4, 440000.00),
(25, 18, 20, 1, 35000.00, 4, 140000.00),
(26, 19, 17, 1, 320000.00, 1, 320000.00),
(27, 20, 11, 1, 90000.00, 2, 180000.00),
(28, 21, 2, 1, 85000.00, 3, 255000.00),
(29, 21, 3, 1, 110000.00, 3, 330000.00),
(30, 22, 5, 1, 130000.00, 4, 520000.00),
(31, 23, 13, 1, 70000.00, 1, 70000.00),
(32, 24, 7, 1, 45000.00, 2, 90000.00),
(33, 25, 5, 1, 130000.00, 3, 390000.00),
(34, 26, 4, 1, 55000.00, 5, 275000.00),
(35, 27, 6, 1, 65000.00, 2, 130000.00),
(36, 28, 17, 1, 320000.00, 3, 960000.00),
(37, 29, 15, 1, 95000.00, 7, 665000.00),
(38, 30, 9, 1, 150000.00, 10, 1500000.00),
(39, 31, 4, 1, 55000.00, 5, 275000.00),
(40, 32, 1, 1, 75000.00, 3, 225000.00),
(41, 33, 8, 1, 25000.00, 3, 75000.00),
(42, 34, 12, 1, 220000.00, 3, 660000.00),
(43, 35, 10, 1, 60000.00, 3, 180000.00),
(44, 35, 7, 1, 45000.00, 3, 135000.00),
(45, 36, 3, 1, 110000.00, 4, 440000.00),
(46, 37, 8, 1, 25000.00, 2, 50000.00),
(47, 38, 13, 1, 70000.00, 2, 140000.00),
(48, 39, 20, 1, 35000.00, 3, 105000.00),
(49, 40, 16, 1, 280000.00, 3, 840000.00),
(50, 41, 4, 1, 55000.00, 2, 110000.00),
(51, 42, 3, 1, 110000.00, 3, 330000.00);

-- auditoria_estados_reserva (129 registros)
INSERT INTO auditoria_estados_reserva (id_reserva, estado_anterior, estado_nuevo, fecha_cambio, cambiado_por, observacion) VALUES
(1, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 153 DAY, '09:30:00'), 36, 'Solicitud de reserva creada por el cliente'),
(1, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 152 DAY, '10:15:00'), 6, 'Reserva aprobada'),
(1, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 148 DAY, '07:45:00'), 6, 'Equipo despachado. Alquiler en curso'),
(1, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 142 DAY, '17:30:00'), 6, 'Reserva finalizada por devolucion registrada'),
(2, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 138 DAY, '09:30:00'), 18, 'Solicitud de reserva creada por el cliente'),
(2, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 137 DAY, '10:15:00'), 4, 'Reserva aprobada'),
(2, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 135 DAY, '07:45:00'), 4, 'Equipo despachado. Alquiler en curso'),
(2, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 131 DAY, '17:30:00'), 4, 'Reserva finalizada por devolucion registrada'),
(3, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 114 DAY, '09:30:00'), 18, 'Solicitud de reserva creada por el cliente'),
(3, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 113 DAY, '10:15:00'), 5, 'Reserva aprobada'),
(3, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 108 DAY, '07:45:00'), 5, 'Equipo despachado. Alquiler en curso'),
(3, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 106 DAY, '17:30:00'), 5, 'Reserva finalizada por devolucion registrada'),
(4, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 102 DAY, '09:30:00'), 15, 'Solicitud de reserva creada por el cliente'),
(4, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 101 DAY, '10:15:00'), 5, 'Reserva aprobada'),
(4, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 98 DAY, '07:45:00'), 5, 'Equipo despachado. Alquiler en curso'),
(4, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 93 DAY, '17:30:00'), 5, 'Reserva finalizada por devolucion registrada'),
(5, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 100 DAY, '09:30:00'), 37, 'Solicitud de reserva creada por el cliente'),
(5, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 99 DAY, '10:15:00'), 6, 'Reserva aprobada'),
(5, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 95 DAY, '07:45:00'), 6, 'Equipo despachado. Alquiler en curso'),
(5, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 90 DAY, '17:30:00'), 6, 'Reserva finalizada por devolucion registrada'),
(6, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 87 DAY, '09:30:00'), 35, 'Solicitud de reserva creada por el cliente'),
(6, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 86 DAY, '10:15:00'), 6, 'Reserva aprobada'),
(6, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 83 DAY, '07:45:00'), 6, 'Equipo despachado. Alquiler en curso'),
(6, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 78 DAY, '17:30:00'), 6, 'Reserva finalizada por devolucion registrada'),
(7, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 85 DAY, '09:30:00'), 8, 'Solicitud de reserva creada por el cliente'),
(7, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 84 DAY, '10:15:00'), 4, 'Reserva aprobada'),
(7, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 82 DAY, '07:45:00'), 4, 'Equipo despachado. Alquiler en curso'),
(7, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 75 DAY, '17:30:00'), 4, 'Reserva finalizada por devolucion registrada'),
(8, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 81 DAY, '09:30:00'), 42, 'Solicitud de reserva creada por el cliente'),
(8, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 80 DAY, '10:15:00'), 6, 'Reserva aprobada'),
(8, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 75 DAY, '07:45:00'), 6, 'Equipo despachado. Alquiler en curso'),
(8, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 69 DAY, '17:30:00'), 6, 'Reserva finalizada por devolucion registrada'),
(9, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 77 DAY, '09:30:00'), 37, 'Solicitud de reserva creada por el cliente'),
(9, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 76 DAY, '10:15:00'), 7, 'Reserva aprobada'),
(9, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 73 DAY, '07:45:00'), 7, 'Equipo despachado. Alquiler en curso'),
(9, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 69 DAY, '17:30:00'), 7, 'Reserva finalizada por devolucion registrada'),
(10, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 75 DAY, '09:30:00'), 11, 'Solicitud de reserva creada por el cliente'),
(10, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '10:15:00'), 3, 'Reserva aprobada'),
(10, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 70 DAY, '07:45:00'), 3, 'Equipo despachado. Alquiler en curso'),
(10, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 64 DAY, '17:30:00'), 3, 'Reserva finalizada por devolucion registrada'),
(11, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 68 DAY, '09:30:00'), 11, 'Solicitud de reserva creada por el cliente'),
(11, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 67 DAY, '10:15:00'), 7, 'Reserva aprobada'),
(11, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 66 DAY, '07:45:00'), 7, 'Equipo despachado. Alquiler en curso'),
(11, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '17:30:00'), 7, 'Reserva finalizada por devolucion registrada'),
(12, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '09:30:00'), 9, 'Solicitud de reserva creada por el cliente'),
(12, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '10:15:00'), 3, 'Reserva aprobada'),
(12, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 60 DAY, '07:45:00'), 3, 'Equipo despachado. Alquiler en curso'),
(12, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 57 DAY, '17:30:00'), 3, 'Reserva finalizada por devolucion registrada'),
(13, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 64 DAY, '09:30:00'), 19, 'Solicitud de reserva creada por el cliente'),
(13, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '10:15:00'), 4, 'Reserva aprobada'),
(13, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 59 DAY, '07:45:00'), 4, 'Equipo despachado. Alquiler en curso'),
(13, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 53 DAY, '17:30:00'), 4, 'Reserva finalizada por devolucion registrada'),
(14, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '09:30:00'), 37, 'Solicitud de reserva creada por el cliente'),
(14, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '10:15:00'), 6, 'Reserva aprobada'),
(14, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 56 DAY, '07:45:00'), 6, 'Equipo despachado. Alquiler en curso'),
(14, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 52 DAY, '17:30:00'), 6, 'Reserva finalizada por devolucion registrada'),
(15, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 59 DAY, '09:30:00'), 19, 'Solicitud de reserva creada por el cliente'),
(15, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 58 DAY, '10:15:00'), 7, 'Reserva aprobada'),
(15, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '07:45:00'), 7, 'Equipo despachado. Alquiler en curso'),
(15, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '17:30:00'), 7, 'Reserva finalizada por devolucion registrada'),
(16, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 56 DAY, '09:30:00'), 14, 'Solicitud de reserva creada por el cliente'),
(16, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '10:15:00'), 7, 'Reserva aprobada'),
(16, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '07:45:00'), 7, 'Equipo despachado. Alquiler en curso'),
(16, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '17:30:00'), 7, 'Reserva finalizada por devolucion registrada'),
(17, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '09:30:00'), 38, 'Solicitud de reserva creada por el cliente'),
(17, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 49 DAY, '10:15:00'), 4, 'Reserva aprobada'),
(17, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '07:45:00'), 4, 'Equipo despachado. Alquiler en curso'),
(17, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '17:30:00'), 4, 'Reserva finalizada por devolucion registrada'),
(18, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 43 DAY, '09:30:00'), 9, 'Solicitud de reserva creada por el cliente'),
(18, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 42 DAY, '10:15:00'), 4, 'Reserva aprobada'),
(18, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '07:45:00'), 4, 'Equipo despachado. Alquiler en curso'),
(18, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '17:30:00'), 4, 'Reserva finalizada por devolucion registrada'),
(19, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '09:30:00'), 37, 'Solicitud de reserva creada por el cliente'),
(19, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 39 DAY, '10:15:00'), 7, 'Reserva aprobada'),
(19, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 35 DAY, '07:45:00'), 7, 'Equipo despachado. Alquiler en curso'),
(19, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '17:30:00'), 7, 'Reserva finalizada por devolucion registrada'),
(20, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '09:30:00'), 9, 'Solicitud de reserva creada por el cliente'),
(20, 'SOLICITADA', 'CANCELADA', TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '16:20:00'), 9, 'Reserva cancelada'),
(21, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '09:30:00'), 34, 'Solicitud de reserva creada por el cliente'),
(21, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '10:15:00'), 3, 'Reserva aprobada'),
(21, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 28 DAY, '07:45:00'), 3, 'Equipo despachado. Alquiler en curso'),
(21, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '17:30:00'), 3, 'Reserva finalizada por devolucion registrada'),
(22, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 31 DAY, '09:30:00'), 12, 'Solicitud de reserva creada por el cliente'),
(22, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 30 DAY, '10:15:00'), 5, 'Reserva aprobada'),
(22, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '07:45:00'), 5, 'Equipo despachado. Alquiler en curso'),
(22, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '17:30:00'), 5, 'Reserva finalizada por devolucion registrada'),
(23, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 28 DAY, '09:30:00'), 14, 'Solicitud de reserva creada por el cliente'),
(23, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '10:15:00'), 3, 'Reserva aprobada'),
(23, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 24 DAY, '07:45:00'), 3, 'Equipo despachado. Alquiler en curso'),
(23, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '17:30:00'), 3, 'Reserva finalizada por devolucion registrada'),
(24, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '09:30:00'), 35, 'Solicitud de reserva creada por el cliente'),
(24, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '10:15:00'), 3, 'Reserva aprobada'),
(24, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '07:45:00'), 3, 'Equipo despachado. Alquiler en curso'),
(24, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '17:30:00'), 3, 'Reserva finalizada por devolucion registrada'),
(25, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '09:30:00'), 9, 'Solicitud de reserva creada por el cliente'),
(25, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '10:15:00'), 5, 'Reserva aprobada'),
(25, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '07:45:00'), 5, 'Equipo despachado. Alquiler en curso'),
(25, 'EN_CURSO', 'FINALIZADA', TIMESTAMP(CURDATE() - INTERVAL 17 DAY, '17:30:00'), 5, 'Reserva finalizada por devolucion registrada'),
(26, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '09:30:00'), 13, 'Solicitud de reserva creada por el cliente'),
(26, 'SOLICITADA', 'RECHAZADA', TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '11:00:00'), 4, 'Reserva rechazada. Motivo: El cliente no adjunto el permiso de obra del conjunto'),
(27, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 17 DAY, '09:30:00'), 14, 'Solicitud de reserva creada por el cliente'),
(27, 'SOLICITADA', 'CANCELADA', TIMESTAMP(CURDATE() - INTERVAL 16 DAY, '16:20:00'), 14, 'Reserva cancelada'),
(28, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 13 DAY, '09:30:00'), 39, 'Solicitud de reserva creada por el cliente'),
(28, 'SOLICITADA', 'RECHAZADA', TIMESTAMP(CURDATE() - INTERVAL 12 DAY, '11:00:00'), 7, 'Reserva rechazada. Motivo: Equipo comprometido en mantenimiento programado'),
(29, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 11 DAY, '09:30:00'), 12, 'Solicitud de reserva creada por el cliente'),
(29, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '10:15:00'), 4, 'Reserva aprobada'),
(29, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 8 DAY, '07:45:00'), 4, 'Equipo despachado. Alquiler en curso'),
(30, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 7 DAY, '09:30:00'), 14, 'Solicitud de reserva creada por el cliente'),
(30, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '10:15:00'), 6, 'Reserva aprobada'),
(30, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 4 DAY, '07:45:00'), 6, 'Equipo despachado. Alquiler en curso'),
(31, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '09:30:00'), 9, 'Solicitud de reserva creada por el cliente'),
(31, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '10:15:00'), 4, 'Reserva aprobada'),
(31, 'APROBADA', 'EN_CURSO', TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '07:45:00'), 4, 'Equipo despachado. Alquiler en curso'),
(32, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '09:30:00'), 38, 'Solicitud de reserva creada por el cliente'),
(32, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:15:00'), 3, 'Reserva aprobada'),
(33, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '09:30:00'), 9, 'Solicitud de reserva creada por el cliente'),
(33, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE(), '10:15:00'), 4, 'Reserva aprobada'),
(34, NULL, 'SOLICITADA', TIMESTAMP(CURDATE(), '09:30:00'), 11, 'Solicitud de reserva creada por el cliente'),
(34, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '10:15:00'), 7, 'Reserva aprobada'),
(35, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '09:30:00'), 20, 'Solicitud de reserva creada por el cliente'),
(36, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '09:30:00'), 10, 'Solicitud de reserva creada por el cliente'),
(36, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE(), '10:15:00'), 4, 'Reserva aprobada'),
(37, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '09:30:00'), 34, 'Solicitud de reserva creada por el cliente'),
(38, NULL, 'SOLICITADA', TIMESTAMP(CURDATE(), '09:30:00'), 19, 'Solicitud de reserva creada por el cliente'),
(39, NULL, 'SOLICITADA', TIMESTAMP(CURDATE(), '09:30:00'), 9, 'Solicitud de reserva creada por el cliente'),
(40, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '09:30:00'), 36, 'Solicitud de reserva creada por el cliente'),
(40, 'SOLICITADA', 'APROBADA', TIMESTAMP(CURDATE() + INTERVAL 2 DAY, '10:15:00'), 6, 'Reserva aprobada'),
(41, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() + INTERVAL 6 DAY, '09:30:00'), 15, 'Solicitud de reserva creada por el cliente'),
(42, NULL, 'SOLICITADA', TIMESTAMP(CURDATE() + INTERVAL 7 DAY, '09:30:00'), 13, 'Solicitud de reserva creada por el cliente');

-- pagos (39 registros). Todos aprobados por la pasarela simulada.
INSERT INTO pagos (id_pago, numero_transaccion, id_reserva, id_metodo_pago, monto, tipo_pago, estado_pago, fecha_pago, referencia_pasarela) VALUES
(1, 'TRX-2026-00001', 1, 2, 600000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 152 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-618128'),
(2, 'TRX-2026-00002', 1, 2, 180000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 152 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-987130'),
(3, 'TRX-2026-00003', 2, 9, 100000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 137 DAY, '10:40:00'), 'AUTH-NEQUI-361595'),
(4, 'TRX-2026-00004', 3, 2, 200000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 113 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-608652'),
(5, 'TRX-2026-00005', 4, 18, 650000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 101 DAY, '10:40:00'), 'AUTH-PAGOS_WOMPI_QR-849769'),
(6, 'TRX-2026-00006', 4, 18, 195000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 101 DAY, '10:40:00'), 'AUTH-PAGOS_WOMPI_QR-688770'),
(7, 'TRX-2026-00007', 5, 6, 300000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 99 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_VISA-505101'),
(8, 'TRX-2026-00008', 6, 6, 475000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 86 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_VISA-494983'),
(9, 'TRX-2026-00009', 7, 11, 1000000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 84 DAY, '10:40:00'), 'AUTH-TRANSFERENCIA_BANCARIA_DIRECTA-830954'),
(10, 'TRX-2026-00010', 7, 1, 300000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 84 DAY, '10:40:00'), 'AUTH-PSE_BANCOLOMBIA-962936'),
(11, 'TRX-2026-00011', 8, 2, 900000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 80 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-571718'),
(12, 'TRX-2026-00012', 9, 1, 880000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 76 DAY, '10:40:00'), 'AUTH-PSE_BANCOLOMBIA-184004'),
(13, 'TRX-2026-00013', 10, 6, 240000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_VISA-704031'),
(14, 'TRX-2026-00014', 10, 18, 72000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '10:40:00'), 'AUTH-PAGOS_WOMPI_QR-845513'),
(15, 'TRX-2026-00015', 11, 7, 870000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 67 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_MASTERCARD-292369'),
(16, 'TRX-2026-00016', 13, 1, 330000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '10:40:00'), 'AUTH-PSE_BANCOLOMBIA-828010'),
(17, 'TRX-2026-00017', 13, 7, 99000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_MASTERCARD-897162'),
(18, 'TRX-2026-00018', 12, 10, 225000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '10:40:00'), 'AUTH-DAVIPLATA-102361'),
(19, 'TRX-2026-00019', 14, 10, 1260000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '10:40:00'), 'AUTH-DAVIPLATA-327765'),
(20, 'TRX-2026-00020', 15, 9, 90000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 58 DAY, '10:40:00'), 'AUTH-NEQUI-771610'),
(21, 'TRX-2026-00021', 16, 6, 450000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_VISA-207770'),
(22, 'TRX-2026-00022', 16, 1, 135000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '10:40:00'), 'AUTH-PSE_BANCOLOMBIA-841427'),
(23, 'TRX-2026-00023', 17, 1, 110000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 49 DAY, '10:40:00'), 'AUTH-PSE_BANCOLOMBIA-131818'),
(24, 'TRX-2026-00024', 18, 7, 580000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 42 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_MASTERCARD-629332'),
(25, 'TRX-2026-00025', 19, 7, 320000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 39 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_MASTERCARD-986963'),
(26, 'TRX-2026-00026', 19, 1, 96000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 39 DAY, '10:40:00'), 'AUTH-PSE_BANCOLOMBIA-969840'),
(27, 'TRX-2026-00027', 21, 2, 585000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-805557'),
(28, 'TRX-2026-00028', 22, 10, 520000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 30 DAY, '10:40:00'), 'AUTH-DAVIPLATA-207115'),
(29, 'TRX-2026-00029', 23, 18, 70000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '10:40:00'), 'AUTH-PAGOS_WOMPI_QR-438381'),
(30, 'TRX-2026-00030', 23, 6, 21000.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '10:40:00'), 'AUTH-TARJETA_CREDITO_VISA-110600'),
(31, 'TRX-2026-00031', 24, 2, 90000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-982895'),
(32, 'TRX-2026-00032', 25, 2, 390000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-704297'),
(33, 'TRX-2026-00033', 29, 11, 665000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '10:40:00'), 'AUTH-TRANSFERENCIA_BANCARIA_DIRECTA-164074'),
(34, 'TRX-2026-00034', 30, 11, 1500000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '10:40:00'), 'AUTH-TRANSFERENCIA_BANCARIA_DIRECTA-252885'),
(35, 'TRX-2026-00035', 31, 10, 275000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '10:40:00'), 'AUTH-DAVIPLATA-706251'),
(36, 'TRX-2026-00036', 32, 18, 225000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:40:00'), 'AUTH-PAGOS_WOMPI_QR-925097'),
(37, 'TRX-2026-00037', 32, 11, 67500.00, 'DEPOSITO_GARANTIA', 'APROBADO', TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:40:00'), 'AUTH-TRANSFERENCIA_BANCARIA_DIRECTA-558303'),
(38, 'TRX-2026-00038', 36, 10, 220000.00, 'ANTICIPO', 'APROBADO', TIMESTAMP(CURDATE(), '10:40:00'), 'AUTH-DAVIPLATA-354242'),
(39, 'TRX-2026-00039', 34, 2, 660000.00, 'TOTALIDAD', 'APROBADO', TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '10:40:00'), 'AUTH-PSE_DAVIVIENDA-510175');

-- facturas (39 registros). Subtotal = total / 1.19 ; IVA = total - subtotal
INSERT INTO facturas (id_factura, numero_factura, id_pago, id_cliente, fecha_emision, subtotal, iva, total, estado_factura, url_comprobante_pdf) VALUES
(1, 'FAC-2026-0001', 1, 36, TIMESTAMP(CURDATE() - INTERVAL 152 DAY, '10:41:00'), 504201.68, 95798.32, 600000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0001/descargar'),
(2, 'FAC-2026-0002', 2, 36, TIMESTAMP(CURDATE() - INTERVAL 152 DAY, '10:41:00'), 151260.50, 28739.50, 180000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0002/descargar'),
(3, 'FAC-2026-0003', 3, 18, TIMESTAMP(CURDATE() - INTERVAL 137 DAY, '10:41:00'), 84033.61, 15966.39, 100000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0003/descargar'),
(4, 'FAC-2026-0004', 4, 18, TIMESTAMP(CURDATE() - INTERVAL 113 DAY, '10:41:00'), 168067.23, 31932.77, 200000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0004/descargar'),
(5, 'FAC-2026-0005', 5, 15, TIMESTAMP(CURDATE() - INTERVAL 101 DAY, '10:41:00'), 546218.49, 103781.51, 650000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0005/descargar'),
(6, 'FAC-2026-0006', 6, 15, TIMESTAMP(CURDATE() - INTERVAL 101 DAY, '10:41:00'), 163865.55, 31134.45, 195000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0006/descargar'),
(7, 'FAC-2026-0007', 7, 37, TIMESTAMP(CURDATE() - INTERVAL 99 DAY, '10:41:00'), 252100.84, 47899.16, 300000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0007/descargar'),
(8, 'FAC-2026-0008', 8, 35, TIMESTAMP(CURDATE() - INTERVAL 86 DAY, '10:41:00'), 399159.66, 75840.34, 475000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0008/descargar'),
(9, 'FAC-2026-0009', 9, 8, TIMESTAMP(CURDATE() - INTERVAL 84 DAY, '10:41:00'), 840336.13, 159663.87, 1000000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0009/descargar'),
(10, 'FAC-2026-0010', 10, 8, TIMESTAMP(CURDATE() - INTERVAL 84 DAY, '10:41:00'), 252100.84, 47899.16, 300000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0010/descargar'),
(11, 'FAC-2026-0011', 11, 42, TIMESTAMP(CURDATE() - INTERVAL 80 DAY, '10:41:00'), 756302.52, 143697.48, 900000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0011/descargar'),
(12, 'FAC-2026-0012', 12, 37, TIMESTAMP(CURDATE() - INTERVAL 76 DAY, '10:41:00'), 739495.80, 140504.20, 880000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0012/descargar'),
(13, 'FAC-2026-0013', 13, 11, TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '10:41:00'), 201680.67, 38319.33, 240000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0013/descargar'),
(14, 'FAC-2026-0014', 14, 11, TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '10:41:00'), 60504.20, 11495.80, 72000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0014/descargar'),
(15, 'FAC-2026-0015', 15, 11, TIMESTAMP(CURDATE() - INTERVAL 67 DAY, '10:41:00'), 731092.44, 138907.56, 870000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0015/descargar'),
(16, 'FAC-2026-0016', 16, 19, TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '10:41:00'), 277310.92, 52689.08, 330000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0016/descargar'),
(17, 'FAC-2026-0017', 17, 19, TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '10:41:00'), 83193.28, 15806.72, 99000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0017/descargar'),
(18, 'FAC-2026-0018', 18, 9, TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '10:41:00'), 189075.63, 35924.37, 225000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0018/descargar'),
(19, 'FAC-2026-0019', 19, 37, TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '10:41:00'), 1058823.53, 201176.47, 1260000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0019/descargar'),
(20, 'FAC-2026-0020', 20, 19, TIMESTAMP(CURDATE() - INTERVAL 58 DAY, '10:41:00'), 75630.25, 14369.75, 90000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0020/descargar'),
(21, 'FAC-2026-0021', 21, 14, TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '10:41:00'), 378151.26, 71848.74, 450000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0021/descargar'),
(22, 'FAC-2026-0022', 22, 14, TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '10:41:00'), 113445.38, 21554.62, 135000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0022/descargar'),
(23, 'FAC-2026-0023', 23, 38, TIMESTAMP(CURDATE() - INTERVAL 49 DAY, '10:41:00'), 92436.97, 17563.03, 110000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0023/descargar'),
(24, 'FAC-2026-0024', 24, 9, TIMESTAMP(CURDATE() - INTERVAL 42 DAY, '10:41:00'), 487394.96, 92605.04, 580000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0024/descargar'),
(25, 'FAC-2026-0025', 25, 37, TIMESTAMP(CURDATE() - INTERVAL 39 DAY, '10:41:00'), 268907.56, 51092.44, 320000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0025/descargar'),
(26, 'FAC-2026-0026', 26, 37, TIMESTAMP(CURDATE() - INTERVAL 39 DAY, '10:41:00'), 80672.27, 15327.73, 96000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0026/descargar'),
(27, 'FAC-2026-0027', 27, 34, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '10:41:00'), 491596.64, 93403.36, 585000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0027/descargar'),
(28, 'FAC-2026-0028', 28, 12, TIMESTAMP(CURDATE() - INTERVAL 30 DAY, '10:41:00'), 436974.79, 83025.21, 520000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0028/descargar'),
(29, 'FAC-2026-0029', 29, 14, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '10:41:00'), 58823.53, 11176.47, 70000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0029/descargar'),
(30, 'FAC-2026-0030', 30, 14, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '10:41:00'), 17647.06, 3352.94, 21000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0030/descargar'),
(31, 'FAC-2026-0031', 31, 35, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '10:41:00'), 75630.25, 14369.75, 90000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0031/descargar'),
(32, 'FAC-2026-0032', 32, 9, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '10:41:00'), 327731.09, 62268.91, 390000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0032/descargar'),
(33, 'FAC-2026-0033', 33, 12, TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '10:41:00'), 558823.53, 106176.47, 665000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0033/descargar'),
(34, 'FAC-2026-0034', 34, 14, TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '10:41:00'), 1260504.20, 239495.80, 1500000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0034/descargar'),
(35, 'FAC-2026-0035', 35, 9, TIMESTAMP(CURDATE() - INTERVAL 5 DAY, '10:41:00'), 231092.44, 43907.56, 275000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0035/descargar'),
(36, 'FAC-2026-0036', 36, 38, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:41:00'), 189075.63, 35924.37, 225000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0036/descargar'),
(37, 'FAC-2026-0037', 37, 38, TIMESTAMP(CURDATE() - INTERVAL 2 DAY, '10:41:00'), 56722.69, 10777.31, 67500.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0037/descargar'),
(38, 'FAC-2026-0038', 38, 10, TIMESTAMP(CURDATE(), '10:41:00'), 184873.95, 35126.05, 220000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0038/descargar'),
(39, 'FAC-2026-0039', 39, 11, TIMESTAMP(CURDATE() + INTERVAL 1 DAY, '10:41:00'), 554621.85, 105378.15, 660000.00, 'PAGADA', '/api/v1/facturas/FAC-2026-0039/descargar');

-- detalles_factura (39 registros)
INSERT INTO detalles_factura (id_detalle_factura, id_factura, descripcion_item, cantidad, precio_unitario, subtotal_linea) VALUES
(1, 1, 'Alquiler de equipos de construccion - Reserva RES-2026-0001', 1, 504201.68, 504201.68),
(2, 2, 'Deposito de garantia reembolsable - Reserva RES-2026-0001', 1, 151260.50, 151260.50),
(3, 3, 'Alquiler de equipos de construccion - Reserva RES-2026-0002', 1, 84033.61, 84033.61),
(4, 4, 'Alquiler de equipos de construccion - Reserva RES-2026-0003', 1, 168067.23, 168067.23),
(5, 5, 'Alquiler de equipos de construccion - Reserva RES-2026-0004', 1, 546218.49, 546218.49),
(6, 6, 'Deposito de garantia reembolsable - Reserva RES-2026-0004', 1, 163865.55, 163865.55),
(7, 7, 'Alquiler de equipos de construccion - Reserva RES-2026-0005', 1, 252100.84, 252100.84),
(8, 8, 'Alquiler de equipos de construccion - Reserva RES-2026-0006', 1, 399159.66, 399159.66),
(9, 9, 'Alquiler de equipos de construccion - Reserva RES-2026-0007', 1, 840336.13, 840336.13),
(10, 10, 'Deposito de garantia reembolsable - Reserva RES-2026-0007', 1, 252100.84, 252100.84),
(11, 11, 'Alquiler de equipos de construccion - Reserva RES-2026-0008', 1, 756302.52, 756302.52),
(12, 12, 'Alquiler de equipos de construccion - Reserva RES-2026-0009', 1, 739495.80, 739495.80),
(13, 13, 'Alquiler de equipos de construccion - Reserva RES-2026-0010', 1, 201680.67, 201680.67),
(14, 14, 'Deposito de garantia reembolsable - Reserva RES-2026-0010', 1, 60504.20, 60504.20),
(15, 15, 'Alquiler de equipos de construccion - Reserva RES-2026-0011', 1, 731092.44, 731092.44),
(16, 16, 'Alquiler de equipos de construccion - Reserva RES-2026-0013', 1, 277310.92, 277310.92),
(17, 17, 'Deposito de garantia reembolsable - Reserva RES-2026-0013', 1, 83193.28, 83193.28),
(18, 18, 'Alquiler de equipos de construccion - Reserva RES-2026-0012', 1, 189075.63, 189075.63),
(19, 19, 'Alquiler de equipos de construccion - Reserva RES-2026-0014', 1, 1058823.53, 1058823.53),
(20, 20, 'Alquiler de equipos de construccion - Reserva RES-2026-0015', 1, 75630.25, 75630.25),
(21, 21, 'Alquiler de equipos de construccion - Reserva RES-2026-0016', 1, 378151.26, 378151.26),
(22, 22, 'Deposito de garantia reembolsable - Reserva RES-2026-0016', 1, 113445.38, 113445.38),
(23, 23, 'Alquiler de equipos de construccion - Reserva RES-2026-0017', 1, 92436.97, 92436.97),
(24, 24, 'Alquiler de equipos de construccion - Reserva RES-2026-0018', 1, 487394.96, 487394.96),
(25, 25, 'Alquiler de equipos de construccion - Reserva RES-2026-0019', 1, 268907.56, 268907.56),
(26, 26, 'Deposito de garantia reembolsable - Reserva RES-2026-0019', 1, 80672.27, 80672.27),
(27, 27, 'Alquiler de equipos de construccion - Reserva RES-2026-0021', 1, 491596.64, 491596.64),
(28, 28, 'Alquiler de equipos de construccion - Reserva RES-2026-0022', 1, 436974.79, 436974.79),
(29, 29, 'Alquiler de equipos de construccion - Reserva RES-2026-0023', 1, 58823.53, 58823.53),
(30, 30, 'Deposito de garantia reembolsable - Reserva RES-2026-0023', 1, 17647.06, 17647.06),
(31, 31, 'Alquiler de equipos de construccion - Reserva RES-2026-0024', 1, 75630.25, 75630.25),
(32, 32, 'Alquiler de equipos de construccion - Reserva RES-2026-0025', 1, 327731.09, 327731.09),
(33, 33, 'Alquiler de equipos de construccion - Reserva RES-2026-0029', 1, 558823.53, 558823.53),
(34, 34, 'Alquiler de equipos de construccion - Reserva RES-2026-0030', 1, 1260504.20, 1260504.20),
(35, 35, 'Alquiler de equipos de construccion - Reserva RES-2026-0031', 1, 231092.44, 231092.44),
(36, 36, 'Alquiler de equipos de construccion - Reserva RES-2026-0032', 1, 189075.63, 189075.63),
(37, 37, 'Deposito de garantia reembolsable - Reserva RES-2026-0032', 1, 56722.69, 56722.69),
(38, 38, 'Anticipo de alquiler - Reserva RES-2026-0036', 1, 184873.95, 184873.95),
(39, 39, 'Alquiler de equipos de construccion - Reserva RES-2026-0034', 1, 554621.85, 554621.85);

-- devoluciones (24 registros): una por cada reserva FINALIZADA
INSERT INTO devoluciones (id_devolucion, id_reserva, fecha_devolucion_pactada, fecha_devolucion_real, recibido_por, estado_equipo_general, dias_retraso, observaciones) VALUES
(1, 1, CURDATE() - INTERVAL 142 DAY, CURDATE() - INTERVAL 142 DAY, 6, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(2, 2, CURDATE() - INTERVAL 131 DAY, CURDATE() - INTERVAL 131 DAY, 4, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(3, 3, CURDATE() - INTERVAL 107 DAY, CURDATE() - INTERVAL 106 DAY, 5, 'DANO_LEVE', 1, 'Se registraron novedades en la inspeccion de entrega. Entregado con 1 dia(s) de retraso'),
(4, 4, CURDATE() - INTERVAL 93 DAY, CURDATE() - INTERVAL 93 DAY, 5, 'DANO_GRAVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(5, 5, CURDATE() - INTERVAL 90 DAY, CURDATE() - INTERVAL 90 DAY, 6, 'BUEN_ESTADO', 0, 'Equipo entregado limpio y en buen funcionamiento'),
(6, 6, CURDATE() - INTERVAL 78 DAY, CURDATE() - INTERVAL 78 DAY, 6, 'DANO_GRAVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(7, 7, CURDATE() - INTERVAL 77 DAY, CURDATE() - INTERVAL 75 DAY, 4, 'DANO_GRAVE', 2, 'Se registraron novedades en la inspeccion de entrega. Entregado con 2 dia(s) de retraso'),
(8, 8, CURDATE() - INTERVAL 69 DAY, CURDATE() - INTERVAL 69 DAY, 6, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(9, 9, CURDATE() - INTERVAL 69 DAY, CURDATE() - INTERVAL 69 DAY, 7, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(10, 10, CURDATE() - INTERVAL 64 DAY, CURDATE() - INTERVAL 64 DAY, 3, 'BUEN_ESTADO', 0, 'Funcionamiento del motor optimo, sin novedades'),
(11, 11, CURDATE() - INTERVAL 63 DAY, CURDATE() - INTERVAL 62 DAY, 7, 'DANO_LEVE', 1, 'Se registraron novedades en la inspeccion de entrega. Entregado con 1 dia(s) de retraso'),
(12, 12, CURDATE() - INTERVAL 57 DAY, CURDATE() - INTERVAL 57 DAY, 3, 'DANO_GRAVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(13, 13, CURDATE() - INTERVAL 53 DAY, CURDATE() - INTERVAL 53 DAY, 4, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(14, 14, CURDATE() - INTERVAL 52 DAY, CURDATE() - INTERVAL 52 DAY, 6, 'DANO_GRAVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(15, 15, CURDATE() - INTERVAL 54 DAY, CURDATE() - INTERVAL 51 DAY, 7, 'BUEN_ESTADO', 3, 'Accesorios completos y niveles correctos. Entregado con 3 dia(s) de retraso'),
(16, 16, CURDATE() - INTERVAL 45 DAY, CURDATE() - INTERVAL 45 DAY, 7, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(17, 17, CURDATE() - INTERVAL 44 DAY, CURDATE() - INTERVAL 44 DAY, 4, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(18, 18, CURDATE() - INTERVAL 36 DAY, CURDATE() - INTERVAL 36 DAY, 4, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(19, 19, CURDATE() - INTERVAL 34 DAY, CURDATE() - INTERVAL 33 DAY, 7, 'DANO_LEVE', 1, 'Se registraron novedades en la inspeccion de entrega. Entregado con 1 dia(s) de retraso'),
(20, 21, CURDATE() - INTERVAL 25 DAY, CURDATE() - INTERVAL 25 DAY, 3, 'BUEN_ESTADO', 0, 'Accesorios completos y niveles correctos'),
(21, 22, CURDATE() - INTERVAL 22 DAY, CURDATE() - INTERVAL 22 DAY, 5, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(22, 23, CURDATE() - INTERVAL 23 DAY, CURDATE() - INTERVAL 23 DAY, 3, 'DANO_GRAVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(23, 24, CURDATE() - INTERVAL 21 DAY, CURDATE() - INTERVAL 21 DAY, 3, 'DANO_GRAVE', 0, 'Se registraron novedades en la inspeccion de entrega'),
(24, 25, CURDATE() - INTERVAL 17 DAY, CURDATE() - INTERVAL 17 DAY, 5, 'DANO_LEVE', 0, 'Se registraron novedades en la inspeccion de entrega');

-- reportes_dano (23 registros)
INSERT INTO reportes_dano (id_reporte_dano, id_devolucion, id_herramienta, tipo_dano, descripcion_dano, costo_estimado_reparacion, responsable_asume, fecha_reporte) VALUES
(1, 1, 10, 'MECANICO', 'Filtro de aire saturado de polvo de concreto', 30000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 142 DAY, '17:10:00')),
(2, 2, 8, 'ELECTRICO', 'Cable de alimentacion con corte superficial', 45000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 131 DAY, '17:10:00')),
(3, 3, 5, 'FALTANTE_PIEZA', 'No se devolvio una de las llaves de ajuste', 25000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 106 DAY, '17:10:00')),
(4, 4, 5, 'MECANICO', 'Correa de transmision agrietada por fatiga del material', 60000.00, 'POLIZA_GARANTIA', TIMESTAMP(CURDATE() - INTERVAL 93 DAY, '17:10:00')),
(5, 6, 10, 'MECANICO', 'Acumulacion de mortero seco en piezas moviles', 50000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 78 DAY, '17:10:00')),
(6, 6, 20, 'ELECTRICO', 'Interruptor de encendido con falso contacto', 55000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 78 DAY, '17:10:00')),
(7, 7, 3, 'ELECTRICO', 'Interruptor de encendido con falso contacto', 55000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 75 DAY, '17:10:00')),
(8, 8, 9, 'ESTETICO', 'Rayones en la carcasa por transporte sin proteccion', 35000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 69 DAY, '17:10:00')),
(9, 9, 12, 'MECANICO', 'Filtro de aire saturado de polvo de concreto', 30000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 69 DAY, '17:10:00')),
(10, 11, 12, 'FALTANTE_PIEZA', 'No se devolvio una de las llaves de ajuste', 25000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '17:10:00')),
(11, 12, 1, 'MECANICO', 'Correa de transmision agrietada por fatiga del material', 60000.00, 'POLIZA_GARANTIA', TIMESTAMP(CURDATE() - INTERVAL 57 DAY, '17:10:00')),
(12, 13, 4, 'ESTETICO', 'Manija de transporte abollada', 20000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 53 DAY, '17:10:00')),
(13, 14, 16, 'MECANICO', 'Acumulacion de mortero seco en piezas moviles', 50000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 52 DAY, '17:10:00')),
(14, 14, 20, 'ELECTRICO', 'Interruptor de encendido con falso contacto', 55000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 52 DAY, '17:10:00')),
(15, 16, 11, 'ESTETICO', 'Rayones en la carcasa por transporte sin proteccion', 35000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '17:10:00')),
(16, 17, 3, 'MECANICO', 'Filtro de aire saturado de polvo de concreto', 30000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '17:10:00')),
(17, 18, 3, 'ELECTRICO', 'Cable de alimentacion con corte superficial', 45000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '17:10:00')),
(18, 18, 20, 'FALTANTE_PIEZA', 'No se devolvio una de las llaves de ajuste', 25000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '17:10:00')),
(19, 19, 17, 'FALTANTE_PIEZA', 'No se devolvio una de las llaves de ajuste', 25000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '17:10:00')),
(20, 21, 5, 'ESTETICO', 'Manija de transporte abollada', 20000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '17:10:00')),
(21, 22, 13, 'MECANICO', 'Acumulacion de mortero seco en piezas moviles', 50000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '17:10:00')),
(22, 23, 7, 'ELECTRICO', 'Interruptor de encendido con falso contacto', 55000.00, 'PROVEEDOR', TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '17:10:00')),
(23, 24, 5, 'ESTETICO', 'Rayones en la carcasa por transporte sin proteccion', 35000.00, 'CLIENTE', TIMESTAMP(CURDATE() - INTERVAL 17 DAY, '17:10:00'));

-- evidencias_dano (34 registros)
INSERT INTO evidencias_dano (id_evidencia, id_reporte_dano, url_foto, descripcion_foto) VALUES
(1, 1, '/evidencias/danos/reporte_01_general.jpg', 'Vista general del dano: filtro de aire saturado de polvo de concreto'),
(2, 2, '/evidencias/danos/reporte_02_general.jpg', 'Vista general del dano: cable de alimentacion con corte superficial'),
(3, 2, '/evidencias/danos/reporte_02_detalle.jpg', 'Acercamiento a la zona afectada'),
(4, 3, '/evidencias/danos/reporte_03_general.jpg', 'Vista general del dano: no se devolvio una de las llaves de ajuste'),
(5, 4, '/evidencias/danos/reporte_04_general.jpg', 'Vista general del dano: correa de transmision agrietada por fatiga del material'),
(6, 4, '/evidencias/danos/reporte_04_detalle.jpg', 'Acercamiento a la zona afectada'),
(7, 5, '/evidencias/danos/reporte_05_general.jpg', 'Vista general del dano: acumulacion de mortero seco en piezas moviles'),
(8, 6, '/evidencias/danos/reporte_06_general.jpg', 'Vista general del dano: interruptor de encendido con falso contacto'),
(9, 6, '/evidencias/danos/reporte_06_detalle.jpg', 'Acercamiento a la zona afectada'),
(10, 7, '/evidencias/danos/reporte_07_general.jpg', 'Vista general del dano: interruptor de encendido con falso contacto'),
(11, 8, '/evidencias/danos/reporte_08_general.jpg', 'Vista general del dano: rayones en la carcasa por transporte sin proteccion'),
(12, 8, '/evidencias/danos/reporte_08_detalle.jpg', 'Acercamiento a la zona afectada'),
(13, 9, '/evidencias/danos/reporte_09_general.jpg', 'Vista general del dano: filtro de aire saturado de polvo de concreto'),
(14, 10, '/evidencias/danos/reporte_10_general.jpg', 'Vista general del dano: no se devolvio una de las llaves de ajuste'),
(15, 10, '/evidencias/danos/reporte_10_detalle.jpg', 'Acercamiento a la zona afectada'),
(16, 11, '/evidencias/danos/reporte_11_general.jpg', 'Vista general del dano: correa de transmision agrietada por fatiga del material'),
(17, 12, '/evidencias/danos/reporte_12_general.jpg', 'Vista general del dano: manija de transporte abollada'),
(18, 12, '/evidencias/danos/reporte_12_detalle.jpg', 'Acercamiento a la zona afectada'),
(19, 13, '/evidencias/danos/reporte_13_general.jpg', 'Vista general del dano: acumulacion de mortero seco en piezas moviles'),
(20, 14, '/evidencias/danos/reporte_14_general.jpg', 'Vista general del dano: interruptor de encendido con falso contacto'),
(21, 14, '/evidencias/danos/reporte_14_detalle.jpg', 'Acercamiento a la zona afectada'),
(22, 15, '/evidencias/danos/reporte_15_general.jpg', 'Vista general del dano: rayones en la carcasa por transporte sin proteccion'),
(23, 16, '/evidencias/danos/reporte_16_general.jpg', 'Vista general del dano: filtro de aire saturado de polvo de concreto'),
(24, 16, '/evidencias/danos/reporte_16_detalle.jpg', 'Acercamiento a la zona afectada'),
(25, 17, '/evidencias/danos/reporte_17_general.jpg', 'Vista general del dano: cable de alimentacion con corte superficial'),
(26, 18, '/evidencias/danos/reporte_18_general.jpg', 'Vista general del dano: no se devolvio una de las llaves de ajuste'),
(27, 18, '/evidencias/danos/reporte_18_detalle.jpg', 'Acercamiento a la zona afectada'),
(28, 19, '/evidencias/danos/reporte_19_general.jpg', 'Vista general del dano: no se devolvio una de las llaves de ajuste'),
(29, 20, '/evidencias/danos/reporte_20_general.jpg', 'Vista general del dano: manija de transporte abollada'),
(30, 20, '/evidencias/danos/reporte_20_detalle.jpg', 'Acercamiento a la zona afectada'),
(31, 21, '/evidencias/danos/reporte_21_general.jpg', 'Vista general del dano: acumulacion de mortero seco en piezas moviles'),
(32, 22, '/evidencias/danos/reporte_22_general.jpg', 'Vista general del dano: interruptor de encendido con falso contacto'),
(33, 22, '/evidencias/danos/reporte_22_detalle.jpg', 'Acercamiento a la zona afectada'),
(34, 23, '/evidencias/danos/reporte_23_general.jpg', 'Vista general del dano: rayones en la carcasa por transporte sin proteccion');

-- cargos_adicionales (23 registros). Mora = 25.000 por dia de retraso
INSERT INTO cargos_adicionales (id_cargo, id_devolucion, tipo_cargo, monto, pagado, fecha_cargo, descripcion) VALUES
(1, 2, 'REPARACION_DANO', 45000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 131 DAY, '17:20:00'), 'Cargo por dano (ELECTRICO) en herramienta ID: 8'),
(2, 3, 'MORA_RETRASO', 25000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 106 DAY, '17:20:00'), 'Cargo por mora: 1 dias de retraso en la entrega'),
(3, 3, 'REPARACION_DANO', 25000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 106 DAY, '17:20:00'), 'Cargo por dano (FALTANTE_PIEZA) en herramienta ID: 5'),
(4, 4, 'LIMPIEZA_PROFUNDA', 30000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 93 DAY, '17:20:00'), 'Limpieza profunda por residuos de concreto y lodo'),
(5, 6, 'REPARACION_DANO', 50000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 78 DAY, '17:20:00'), 'Cargo por dano (MECANICO) en herramienta ID: 10'),
(6, 7, 'MORA_RETRASO', 50000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 75 DAY, '17:20:00'), 'Cargo por mora: 2 dias de retraso en la entrega'),
(7, 8, 'REPARACION_DANO', 35000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 69 DAY, '17:20:00'), 'Cargo por dano (ESTETICO) en herramienta ID: 9'),
(8, 8, 'LIMPIEZA_PROFUNDA', 30000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 69 DAY, '17:20:00'), 'Limpieza profunda por residuos de concreto y lodo'),
(9, 11, 'MORA_RETRASO', 25000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '17:20:00'), 'Cargo por mora: 1 dias de retraso en la entrega'),
(10, 11, 'REPARACION_DANO', 25000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 62 DAY, '17:20:00'), 'Cargo por dano (FALTANTE_PIEZA) en herramienta ID: 12'),
(11, 12, 'LIMPIEZA_PROFUNDA', 30000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 57 DAY, '17:20:00'), 'Limpieza profunda por residuos de concreto y lodo'),
(12, 14, 'REPARACION_DANO', 50000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 52 DAY, '17:20:00'), 'Cargo por dano (MECANICO) en herramienta ID: 16'),
(13, 15, 'MORA_RETRASO', 75000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '17:20:00'), 'Cargo por mora: 3 dias de retraso en la entrega'),
(14, 16, 'REPARACION_DANO', 35000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '17:20:00'), 'Cargo por dano (ESTETICO) en herramienta ID: 11'),
(15, 16, 'LIMPIEZA_PROFUNDA', 30000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '17:20:00'), 'Limpieza profunda por residuos de concreto y lodo'),
(16, 18, 'REPARACION_DANO', 45000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '17:20:00'), 'Cargo por dano (ELECTRICO) en herramienta ID: 3'),
(17, 18, 'REPARACION_DANO', 25000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '17:20:00'), 'Cargo por dano (FALTANTE_PIEZA) en herramienta ID: 20'),
(18, 19, 'MORA_RETRASO', 25000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '17:20:00'), 'Cargo por mora: 1 dias de retraso en la entrega'),
(19, 19, 'REPARACION_DANO', 25000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 33 DAY, '17:20:00'), 'Cargo por dano (FALTANTE_PIEZA) en herramienta ID: 17'),
(20, 20, 'LIMPIEZA_PROFUNDA', 30000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '17:20:00'), 'Limpieza profunda por residuos de concreto y lodo'),
(21, 22, 'REPARACION_DANO', 50000.00, FALSE, TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '17:20:00'), 'Cargo por dano (MECANICO) en herramienta ID: 13'),
(22, 24, 'REPARACION_DANO', 35000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 17 DAY, '17:20:00'), 'Cargo por dano (ESTETICO) en herramienta ID: 5'),
(23, 24, 'LIMPIEZA_PROFUNDA', 30000.00, TRUE, TIMESTAMP(CURDATE() - INTERVAL 17 DAY, '17:20:00'), 'Limpieza profunda por residuos de concreto y lodo');

-- resenas_herramienta (29 registros). Solo de alquileres FINALIZADOS.
INSERT INTO resenas_herramienta (id_resena, id_herramienta, id_cliente, id_reserva, calificacion, comentario, fecha_resena) VALUES
(1, 10, 36, 1, 4, 'Buen equipo, aunque llego con poco combustible', TIMESTAMP(CURDATE() - INTERVAL 141 DAY, '19:05:00')),
(2, 19, 36, 1, 5, 'Potente y facil de operar, lo volveria a alquilar', TIMESTAMP(CURDATE() - INTERVAL 141 DAY, '19:05:00')),
(3, 8, 18, 2, 5, 'Impecable, cumplio con todo lo que necesitabamos', TIMESTAMP(CURDATE() - INTERVAL 130 DAY, '19:05:00')),
(4, 5, 18, 3, 5, 'Muy buena atencion del proveedor y entrega puntual', TIMESTAMP(CURDATE() - INTERVAL 105 DAY, '19:05:00')),
(5, 13, 18, 3, 4, 'Buena relacion entre precio y rendimiento', TIMESTAMP(CURDATE() - INTERVAL 105 DAY, '19:05:00')),
(6, 5, 15, 4, 4, 'Buena relacion entre precio y rendimiento', TIMESTAMP(CURDATE() - INTERVAL 92 DAY, '19:05:00')),
(7, 10, 37, 5, 4, 'Funciono bien, el despacho se demoro un poco', TIMESTAMP(CURDATE() - INTERVAL 89 DAY, '19:05:00')),
(8, 10, 35, 6, 5, 'Impecable, cumplio con todo lo que necesitabamos', TIMESTAMP(CURDATE() - INTERVAL 77 DAY, '19:05:00')),
(9, 20, 35, 6, 4, 'Funciono bien, el despacho se demoro un poco', TIMESTAMP(CURDATE() - INTERVAL 77 DAY, '19:05:00')),
(10, 3, 8, 7, 4, 'Funciono bien, el despacho se demoro un poco', TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '19:05:00')),
(11, 11, 8, 7, 5, 'Muy buena atencion del proveedor y entrega puntual', TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '19:05:00')),
(12, 9, 42, 8, 2, 'Se recalento varias veces durante la jornada', TIMESTAMP(CURDATE() - INTERVAL 68 DAY, '19:05:00')),
(13, 12, 37, 9, 5, 'Potente y facil de operar, lo volveria a alquilar', TIMESTAMP(CURDATE() - INTERVAL 68 DAY, '19:05:00')),
(14, 19, 11, 10, 4, 'Buena relacion entre precio y rendimiento', TIMESTAMP(CURDATE() - INTERVAL 63 DAY, '19:05:00')),
(15, 12, 11, 11, 3, 'Aceptable, tuvimos que limpiar el filtro a mitad de obra', TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '19:05:00')),
(16, 13, 11, 11, 5, 'Muy buena atencion del proveedor y entrega puntual', TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '19:05:00')),
(17, 1, 9, 12, 4, 'Funciono bien, el despacho se demoro un poco', TIMESTAMP(CURDATE() - INTERVAL 56 DAY, '19:05:00')),
(18, 4, 19, 13, 4, 'Buen equipo, aunque llego con poco combustible', TIMESTAMP(CURDATE() - INTERVAL 52 DAY, '19:05:00')),
(19, 16, 37, 14, 4, 'Buena relacion entre precio y rendimiento', TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '19:05:00')),
(20, 20, 37, 14, 3, 'El equipo sirvio pero mostraba desgaste', TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '19:05:00')),
(21, 11, 19, 15, 5, 'Impecable, cumplio con todo lo que necesitabamos', TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '19:05:00')),
(22, 11, 14, 16, 5, 'Impecable, cumplio con todo lo que necesitabamos', TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '19:05:00')),
(23, 3, 38, 17, 3, 'El equipo sirvio pero mostraba desgaste', TIMESTAMP(CURDATE() - INTERVAL 43 DAY, '19:05:00')),
(24, 17, 37, 19, 5, 'Muy buena atencion del proveedor y entrega puntual', TIMESTAMP(CURDATE() - INTERVAL 32 DAY, '19:05:00')),
(25, 2, 34, 21, 2, 'Se recalento varias veces durante la jornada', TIMESTAMP(CURDATE() - INTERVAL 24 DAY, '19:05:00')),
(26, 3, 34, 21, 4, 'Buen equipo, aunque llego con poco combustible', TIMESTAMP(CURDATE() - INTERVAL 24 DAY, '19:05:00')),
(27, 5, 12, 22, 3, 'El equipo sirvio pero mostraba desgaste', TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '19:05:00')),
(28, 13, 14, 23, 3, 'Aceptable, tuvimos que limpiar el filtro a mitad de obra', TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '19:05:00')),
(29, 7, 35, 24, 5, 'Impecable, cumplio con todo lo que necesitabamos', TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '19:05:00'));

-- mantenimientos_herramienta (42 registros). La pulidora (18) sigue en el taller.
INSERT INTO mantenimientos_herramienta (id_mantenimiento, id_herramienta, tipo, descripcion, fecha_inicio, fecha_fin, costo, estado, registrado_por, observaciones_cierre) VALUES
(1, 6, 'REVISION', 'Inspeccion general de 250 horas de uso', TIMESTAMP(CURDATE() - INTERVAL 165 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 164 DAY, '16:00:00'), 120000.00, 'FINALIZADO', 5, 'Mantenimiento programado completado sin novedades'),
(2, 4, 'PREVENTIVO', 'Inspeccion general de 250 horas de uso', TIMESTAMP(CURDATE() - INTERVAL 163 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 162 DAY, '16:00:00'), 80000.00, 'FINALIZADO', 4, 'Mantenimiento programado completado sin novedades'),
(3, 14, 'PREVENTIVO', 'Revision de carbones y limpieza del motor', TIMESTAMP(CURDATE() - INTERVAL 155 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 154 DAY, '16:00:00'), 80000.00, 'FINALIZADO', 5, 'Mantenimiento programado completado sin novedades'),
(4, 19, 'PREVENTIVO', 'Calibracion y verificacion de seguridad', TIMESTAMP(CURDATE() - INTERVAL 151 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 150 DAY, '16:00:00'), 60000.00, 'FINALIZADO', 3, 'Mantenimiento programado completado sin novedades'),
(5, 15, 'REVISION', 'Revision de carbones y limpieza del motor', TIMESTAMP(CURDATE() - INTERVAL 149 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 148 DAY, '16:00:00'), 120000.00, 'FINALIZADO', 4, 'Mantenimiento programado completado sin novedades'),
(6, 1, 'PREVENTIVO', 'Cambio de aceite y filtros', TIMESTAMP(CURDATE() - INTERVAL 146 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 145 DAY, '16:00:00'), 80000.00, 'FINALIZADO', 3, 'Mantenimiento programado completado sin novedades'),
(7, 10, 'CORRECTIVO', 'Reparacion tras devolucion: filtro de aire saturado de polvo de concreto', TIMESTAMP(CURDATE() - INTERVAL 141 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 140 DAY, '16:00:00'), 30000.00, 'FINALIZADO', 6, 'Equipo probado y devuelto al catalogo'),
(8, 17, 'PREVENTIVO', 'Inspeccion general de 250 horas de uso', TIMESTAMP(CURDATE() - INTERVAL 141 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 140 DAY, '16:00:00'), 80000.00, 'FINALIZADO', 7, 'Mantenimiento programado completado sin novedades'),
(9, 12, 'REVISION', 'Calibracion y verificacion de seguridad', TIMESTAMP(CURDATE() - INTERVAL 138 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 137 DAY, '16:00:00'), 45000.00, 'FINALIZADO', 7, 'Mantenimiento programado completado sin novedades'),
(10, 8, 'CORRECTIVO', 'Reparacion tras devolucion: cable de alimentacion con corte superficial', TIMESTAMP(CURDATE() - INTERVAL 130 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 129 DAY, '16:00:00'), 45000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(11, 3, 'REVISION', 'Cambio de aceite y filtros', TIMESTAMP(CURDATE() - INTERVAL 127 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 126 DAY, '16:00:00'), 45000.00, 'FINALIZADO', 4, 'Mantenimiento programado completado sin novedades'),
(12, 5, 'PREVENTIVO', 'Calibracion y verificacion de seguridad', TIMESTAMP(CURDATE() - INTERVAL 126 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 125 DAY, '16:00:00'), 60000.00, 'FINALIZADO', 5, 'Mantenimiento programado completado sin novedades'),
(13, 16, 'PREVENTIVO', 'Calibracion y verificacion de seguridad', TIMESTAMP(CURDATE() - INTERVAL 112 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 111 DAY, '16:00:00'), 45000.00, 'FINALIZADO', 6, 'Mantenimiento programado completado sin novedades'),
(14, 5, 'CORRECTIVO', 'Reparacion tras devolucion: no se devolvio una de las llaves de ajuste', TIMESTAMP(CURDATE() - INTERVAL 105 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 104 DAY, '16:00:00'), 25000.00, 'FINALIZADO', 5, 'Equipo probado y devuelto al catalogo'),
(15, 13, 'PREVENTIVO', 'Calibracion y verificacion de seguridad', TIMESTAMP(CURDATE() - INTERVAL 97 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 96 DAY, '16:00:00'), 45000.00, 'FINALIZADO', 3, 'Mantenimiento programado completado sin novedades'),
(16, 5, 'CORRECTIVO', 'Reparacion tras devolucion: correa de transmision agrietada por fatiga del material', TIMESTAMP(CURDATE() - INTERVAL 92 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 91 DAY, '16:00:00'), 60000.00, 'FINALIZADO', 5, 'Equipo probado y devuelto al catalogo'),
(17, 9, 'REVISION', 'Calibracion y verificacion de seguridad', TIMESTAMP(CURDATE() - INTERVAL 90 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 89 DAY, '16:00:00'), 45000.00, 'FINALIZADO', 6, 'Mantenimiento programado completado sin novedades'),
(18, 10, 'CORRECTIVO', 'Reparacion tras devolucion: acumulacion de mortero seco en piezas moviles', TIMESTAMP(CURDATE() - INTERVAL 77 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 76 DAY, '16:00:00'), 50000.00, 'FINALIZADO', 6, 'Equipo probado y devuelto al catalogo'),
(19, 20, 'CORRECTIVO', 'Reparacion tras devolucion: interruptor de encendido con falso contacto', TIMESTAMP(CURDATE() - INTERVAL 77 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 76 DAY, '16:00:00'), 55000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(20, 3, 'CORRECTIVO', 'Reparacion tras devolucion: interruptor de encendido con falso contacto', TIMESTAMP(CURDATE() - INTERVAL 74 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 73 DAY, '16:00:00'), 55000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(21, 9, 'CORRECTIVO', 'Reparacion tras devolucion: rayones en la carcasa por transporte sin proteccion', TIMESTAMP(CURDATE() - INTERVAL 68 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 67 DAY, '16:00:00'), 35000.00, 'FINALIZADO', 6, 'Equipo probado y devuelto al catalogo'),
(22, 12, 'CORRECTIVO', 'Reparacion tras devolucion: filtro de aire saturado de polvo de concreto', TIMESTAMP(CURDATE() - INTERVAL 68 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 67 DAY, '16:00:00'), 30000.00, 'FINALIZADO', 7, 'Equipo probado y devuelto al catalogo'),
(23, 12, 'CORRECTIVO', 'Reparacion tras devolucion: no se devolvio una de las llaves de ajuste', TIMESTAMP(CURDATE() - INTERVAL 61 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 60 DAY, '16:00:00'), 25000.00, 'FINALIZADO', 7, 'Equipo probado y devuelto al catalogo'),
(24, 2, 'PREVENTIVO', 'Revision de carbones y limpieza del motor', TIMESTAMP(CURDATE() - INTERVAL 57 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 56 DAY, '16:00:00'), 120000.00, 'FINALIZADO', 3, 'Mantenimiento programado completado sin novedades'),
(25, 1, 'CORRECTIVO', 'Reparacion tras devolucion: correa de transmision agrietada por fatiga del material', TIMESTAMP(CURDATE() - INTERVAL 56 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 55 DAY, '16:00:00'), 60000.00, 'FINALIZADO', 3, 'Equipo probado y devuelto al catalogo'),
(26, 4, 'CORRECTIVO', 'Reparacion tras devolucion: manija de transporte abollada', TIMESTAMP(CURDATE() - INTERVAL 52 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '16:00:00'), 20000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(27, 16, 'CORRECTIVO', 'Reparacion tras devolucion: acumulacion de mortero seco en piezas moviles', TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '16:00:00'), 50000.00, 'FINALIZADO', 6, 'Equipo probado y devuelto al catalogo'),
(28, 20, 'CORRECTIVO', 'Reparacion tras devolucion: interruptor de encendido con falso contacto', TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 50 DAY, '16:00:00'), 55000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(29, 7, 'PREVENTIVO', 'Revision de carbones y limpieza del motor', TIMESTAMP(CURDATE() - INTERVAL 48 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 47 DAY, '16:00:00'), 80000.00, 'FINALIZADO', 3, 'Mantenimiento programado completado sin novedades'),
(30, 11, 'CORRECTIVO', 'Reparacion tras devolucion: rayones en la carcasa por transporte sin proteccion', TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 43 DAY, '16:00:00'), 35000.00, 'FINALIZADO', 7, 'Equipo probado y devuelto al catalogo'),
(31, 10, 'PREVENTIVO', 'Revision de carbones y limpieza del motor', TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 43 DAY, '16:00:00'), 60000.00, 'FINALIZADO', 6, 'Mantenimiento programado completado sin novedades'),
(32, 3, 'CORRECTIVO', 'Reparacion tras devolucion: filtro de aire saturado de polvo de concreto', TIMESTAMP(CURDATE() - INTERVAL 43 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 42 DAY, '16:00:00'), 30000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(33, 3, 'CORRECTIVO', 'Reparacion tras devolucion: cable de alimentacion con corte superficial', TIMESTAMP(CURDATE() - INTERVAL 35 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '16:00:00'), 45000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(34, 20, 'CORRECTIVO', 'Reparacion tras devolucion: no se devolvio una de las llaves de ajuste', TIMESTAMP(CURDATE() - INTERVAL 35 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 34 DAY, '16:00:00'), 25000.00, 'FINALIZADO', 4, 'Equipo probado y devuelto al catalogo'),
(35, 17, 'CORRECTIVO', 'Reparacion tras devolucion: no se devolvio una de las llaves de ajuste', TIMESTAMP(CURDATE() - INTERVAL 32 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 31 DAY, '16:00:00'), 25000.00, 'FINALIZADO', 7, 'Equipo probado y devuelto al catalogo'),
(36, 8, 'PREVENTIVO', 'Cambio de aceite y filtros', TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 26 DAY, '16:00:00'), 80000.00, 'FINALIZADO', 4, 'Mantenimiento programado completado sin novedades'),
(37, 13, 'CORRECTIVO', 'Reparacion tras devolucion: acumulacion de mortero seco en piezas moviles', TIMESTAMP(CURDATE() - INTERVAL 22 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '16:00:00'), 50000.00, 'FINALIZADO', 3, 'Equipo probado y devuelto al catalogo'),
(38, 7, 'CORRECTIVO', 'Reparacion tras devolucion: interruptor de encendido con falso contacto', TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 19 DAY, '16:00:00'), 55000.00, 'FINALIZADO', 3, 'Equipo probado y devuelto al catalogo'),
(39, 11, 'PREVENTIVO', 'Revision de carbones y limpieza del motor', TIMESTAMP(CURDATE() - INTERVAL 20 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 19 DAY, '16:00:00'), 120000.00, 'FINALIZADO', 7, 'Mantenimiento programado completado sin novedades'),
(40, 20, 'PREVENTIVO', 'Inspeccion general de 250 horas de uso', TIMESTAMP(CURDATE() - INTERVAL 19 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 18 DAY, '16:00:00'), 60000.00, 'FINALIZADO', 4, 'Mantenimiento programado completado sin novedades'),
(41, 5, 'CORRECTIVO', 'Reparacion tras devolucion: rayones en la carcasa por transporte sin proteccion', TIMESTAMP(CURDATE() - INTERVAL 16 DAY, '08:00:00'), TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '16:00:00'), 35000.00, 'FINALIZADO', 5, 'Equipo probado y devuelto al catalogo'),
(42, 18, 'CORRECTIVO', 'Cambio de rodamientos: ruido anormal y vibracion en el cabezal', TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '08:00:00'), NULL, NULL, 'EN_PROCESO', 5, NULL);

-- favoritos (30 registros)
INSERT INTO favoritos (id_favorito, id_usuario, id_herramienta, fecha_agregado) VALUES
(1, 8, 16, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '12:00:00')),
(2, 9, 7, TIMESTAMP(CURDATE() - INTERVAL 53 DAY, '12:00:00')),
(3, 9, 9, TIMESTAMP(CURDATE() - INTERVAL 47 DAY, '12:00:00')),
(4, 9, 12, TIMESTAMP(CURDATE() - INTERVAL 1 DAY, '12:00:00')),
(5, 9, 16, TIMESTAMP(CURDATE() - INTERVAL 21 DAY, '12:00:00')),
(6, 10, 2, TIMESTAMP(CURDATE() - INTERVAL 52 DAY, '12:00:00')),
(7, 11, 20, TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '12:00:00')),
(8, 12, 19, TIMESTAMP(CURDATE() - INTERVAL 28 DAY, '12:00:00')),
(9, 13, 4, TIMESTAMP(CURDATE() - INTERVAL 27 DAY, '12:00:00')),
(10, 14, 9, TIMESTAMP(CURDATE() - INTERVAL 15 DAY, '12:00:00')),
(11, 15, 9, TIMESTAMP(CURDATE() - INTERVAL 45 DAY, '12:00:00')),
(12, 15, 11, TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '12:00:00')),
(13, 18, 19, TIMESTAMP(CURDATE() - INTERVAL 48 DAY, '12:00:00')),
(14, 18, 20, TIMESTAMP(CURDATE() - INTERVAL 36 DAY, '12:00:00')),
(15, 19, 11, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '12:00:00')),
(16, 19, 20, TIMESTAMP(CURDATE() - INTERVAL 35 DAY, '12:00:00')),
(17, 34, 8, TIMESTAMP(CURDATE() - INTERVAL 44 DAY, '12:00:00')),
(18, 35, 7, TIMESTAMP(CURDATE() - INTERVAL 59 DAY, '12:00:00')),
(19, 35, 17, TIMESTAMP(CURDATE() - INTERVAL 49 DAY, '12:00:00')),
(20, 36, 2, TIMESTAMP(CURDATE() - INTERVAL 6 DAY, '12:00:00')),
(21, 36, 6, TIMESTAMP(CURDATE() - INTERVAL 3 DAY, '12:00:00')),
(22, 36, 14, TIMESTAMP(CURDATE() - INTERVAL 35 DAY, '12:00:00')),
(23, 37, 9, TIMESTAMP(CURDATE() - INTERVAL 23 DAY, '12:00:00')),
(24, 37, 11, TIMESTAMP(CURDATE() - INTERVAL 51 DAY, '12:00:00')),
(25, 37, 19, TIMESTAMP(CURDATE() - INTERVAL 32 DAY, '12:00:00')),
(26, 38, 10, TIMESTAMP(CURDATE() - INTERVAL 35 DAY, '12:00:00')),
(27, 38, 14, TIMESTAMP(CURDATE() - INTERVAL 40 DAY, '12:00:00')),
(28, 40, 10, TIMESTAMP(CURDATE() - INTERVAL 60 DAY, '12:00:00')),
(29, 41, 8, TIMESTAMP(CURDATE() - INTERVAL 28 DAY, '12:00:00')),
(30, 42, 2, TIMESTAMP(CURDATE() - INTERVAL 25 DAY, '12:00:00'));

-- ----------------------------------------------------------------------------
-- Verificacion: cada entidad queda con al menos 20 registros
-- ----------------------------------------------------------------------------
SELECT 'reservas' AS entidad, COUNT(*) AS registros FROM reservas
UNION ALL SELECT 'detalles_reserva', COUNT(*) FROM detalles_reserva
UNION ALL SELECT 'auditoria_estados_reserva', COUNT(*) FROM auditoria_estados_reserva
UNION ALL SELECT 'pagos', COUNT(*) FROM pagos
UNION ALL SELECT 'facturas', COUNT(*) FROM facturas
UNION ALL SELECT 'detalles_factura', COUNT(*) FROM detalles_factura
UNION ALL SELECT 'devoluciones', COUNT(*) FROM devoluciones
UNION ALL SELECT 'reportes_dano', COUNT(*) FROM reportes_dano
UNION ALL SELECT 'evidencias_dano', COUNT(*) FROM evidencias_dano
UNION ALL SELECT 'cargos_adicionales', COUNT(*) FROM cargos_adicionales
UNION ALL SELECT 'resenas_herramienta', COUNT(*) FROM resenas_herramienta
UNION ALL SELECT 'mantenimientos_herramienta', COUNT(*) FROM mantenimientos_herramienta
UNION ALL SELECT 'favoritos', COUNT(*) FROM favoritos
;

-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> 07_vistas_indices.sql <<<<<<<<<<<<<<<<<<<<<<<<<<<<
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

-- Las reservas ya finalizadas se consideran devueltas sin novedades
UPDATE reservas SET estado_devolucion = 'DEVUELTO_OK' WHERE id_reserva > 0 AND estado = 'FINALIZADA';
