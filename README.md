# Renta de Herramientas

API REST y aplicación web para alquilar herramientas y maquinaria de construcción. Un proveedor publica sus equipos, un cliente los reserva por fechas y paga, y al final el proveedor registra la devolución, con mora si llegó tarde y con reporte de daños si volvió averiada.

Backend en Java 21 con Spring Boot 3.4, seguridad con JWT, base de datos MySQL 8 y un frontend en HTML, CSS y JavaScript sin frameworks.

Este repositorio es mi entrega individual de la evaluación de Spring Boot. Parte del proyecto que hicimos en pareja con Daniel Osorio ([repositorio del equipo](https://github.com/santiagoosorio0708e-wq/Proyecto_RentaHerramientas_OsorioDaniel_GarciaCamilo)); lo que pedía el examen era el registro de devolución y el reporte de daños, y las evidencias están en [`docs/evidencias-examen`](docs/evidencias-examen).

## Qué problema resuelve

En un alquiler de maquinaria los problemas casi siempre aparecen al final: dos clientes con la misma herramienta para las mismas fechas, cobros calculados a mano, equipos que vuelven tarde o dañados y nadie sabe quién lo reportó ni cuándo. La plataforma cubre ese ciclo completo y deja registro de cada paso.

## Tecnologías

| Parte | Qué se usó |
|---|---|
| Lenguaje | Java 21 |
| Framework | Spring Boot 3.4.1 (Web, Data JPA, Validation, Security) |
| Autenticación | JWT con la librería JJWT 0.12.6 (token de acceso y de refresco) |
| Base de datos | MySQL 8. Para las pruebas, H2 en memoria |
| Documentación de la API | springdoc-openapi (Swagger UI) |
| Frontend | HTML, CSS y JavaScript |
| Pruebas | JUnit 5 y Spring Security Test |
| Contenedores | Dockerfile de dos etapas y docker-compose con MySQL y el backend |

## Roles

- **Administrador:** gestiona usuarios y consulta los reportes generales.
- **Proveedor:** publica herramientas con su tarifa diaria, aprueba o rechaza reservas y registra las devoluciones.
- **Cliente:** busca en el catálogo, reserva por fechas, paga y consulta sus facturas.

Los datos de prueba traen usuarios de cada rol, todos con la contraseña `Password123` (por ejemplo `admin.perez@rentatool.com` como administrador). Están en [`database/04_datos_base.sql`](database/04_datos_base.sql). La lista de endpoints está en [`docs/GUIA_ENDPOINTS.md`](docs/GUIA_ENDPOINTS.md).

## Cómo ejecutarlo

Necesitas Docker y JDK 21. El camino más corto es el script de arranque, que levanta MySQL en Docker (puerto 3308), carga la base si está vacía y arranca Spring Boot en el primer puerto libre entre 8080 y 8083:

```bash
./iniciar.sh          # Linux y macOS
.\iniciar.ps1         # Windows (PowerShell)
```

Si prefieres hacerlo todo con Docker:

```bash
docker compose up --build
```

O a mano, con un MySQL propio:

```bash
mysql -u root -p < database/instalar_todo.sql
./mvnw spring-boot:run
```

La configuración se lee de variables de entorno con valores por defecto (`DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`). Con la aplicación corriendo:

- Aplicación web: http://localhost:8080/api/v1/index.html
- Swagger: http://localhost:8080/api/v1/swagger-ui.html

Para probar la API sin el frontend hay dos colecciones de Postman en [`postman/`](postman).

## Pruebas

```bash
./mvnw test
```

Son 113 pruebas en 15 clases. Cubren sobre todo los servicios de aplicación (reservas, pagos, devoluciones, reseñas, favoritos, mantenimientos, reportes y autenticación), las reglas del dominio como el rango de fechas y el cálculo de la factura, y el manejador global de errores. Corren contra H2, así que no necesitan MySQL.

## Estructura

El código está organizado por módulos de negocio, y cada módulo separa dominio, aplicación e infraestructura:

```text
src/main/java/com/rentaherramientas/
├── common/           configuración de seguridad, CORS, OpenAPI y manejo de errores
└── modules/
    ├── identidad/    usuarios, roles, login y JWT
    ├── inventario/   herramientas, categorías y tarifas
    ├── reservas/     reservas, disponibilidad por fechas y auditoría de estados
    ├── pagos/        pagos y facturas con IVA
    ├── devoluciones/ devolución, mora y reporte de daños
    ├── reportes/     indicadores para el administrador
    ├── resenas/  mantenimientos/  favoritos/
frontend/             páginas del cliente, del proveedor y del administrador
database/             scripts SQL numerados, diccionario de datos y diagrama
docs/                 guía de endpoints, compilación, despliegue y decisiones (adr/)
postman/              colecciones para probar la API
```

## Decisiones técnicas

Las tres más importantes están escritas como ADR en [`docs/adr`](docs/adr):

- **El precio se calcula en el servidor.** Al principio el frontend enviaba el total y el cliente de la reserva. Lo cambié para que el cliente salga del token JWT y el valor se calcule con la tarifa guardada de la herramienta; si no, cualquiera podía mandar el precio que quisiera.
- **El IVA vive en el dominio.** La factura separa base e IVA del 19 % usando `BigDecimal` y redondeo `HALF_UP`, para que no aparezcan diferencias de centavos entre pantallas.
- **Cada cambio de estado de una reserva queda auditado.** Además del estado actual se guarda quién lo cambió, cuándo y por qué, en una tabla aparte.
- **Base de datos en cuarta forma normal.** Las evidencias fotográficas de un daño van en su propia tabla y no mezcladas con el reporte, para evitar filas repetidas.

## Qué aprendí

- A separar una aplicación Spring Boot por contextos de negocio en lugar de por tipo de clase, y a que cada módulo tenga sus propios puertos.
- Que la seguridad no se resuelve en el frontend. En una versión anterior, si el servidor no respondía, el navegador abría una sesión de demostración y dejaba entrar a cualquiera; el registro de esas correcciones está en el [CHANGELOG](CHANGELOG.md).
- A dejar el proyecto listo para que otra persona lo arranque con un solo comando.

## Autor

Camilo Andrés García Almeida · [GitHub](https://github.com/CamiloGarcia079) · [LinkedIn](https://www.linkedin.com/in/camilo-andr%C3%A9s-garc%C3%ADa-almeida-7570693b7/)
