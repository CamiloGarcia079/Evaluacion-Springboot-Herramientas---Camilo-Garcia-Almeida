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
