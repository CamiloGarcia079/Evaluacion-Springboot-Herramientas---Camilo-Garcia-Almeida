#!/usr/bin/env bash
# ============================================================================
# Arranque completo en Linux / macOS:  ./iniciar.sh
#   1. Levanta MySQL en Docker (puerto 3308) y espera a que responda.
#   2. Si la base de datos no tiene las tablas nuevas, la carga completa.
#      Para borrarla y cargarla de nuevo:  ./iniciar.sh --reiniciar-bd
#   3. Si el backend ya esta corriendo, solo muestra las direcciones
#      (evita el error "Port already in use" por abrirlo dos veces).
#   4. Si no, busca un puerto libre (8080 a 8083) y arranca Spring Boot.
# ============================================================================
set -e
cd "$(dirname "$0")"
CLAVE="${DB_ROOT_PASSWORD:-rootpassword}"
CONTENEDOR="renta-mysql-2"

ocupado() { (echo > "/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; }

echo "==> Levantando MySQL en Docker..."
docker compose up -d mysql

echo -n "==> Esperando a MySQL"
for i in $(seq 1 60); do
  if docker exec "$CONTENEDOR" mysql -h127.0.0.1 -uroot -p"$CLAVE" -e "SELECT 1" >/dev/null 2>&1; then echo " listo"; break; fi
  echo -n "."; sleep 2
  [ "$i" = 60 ] && { echo; echo "MySQL no respondio. Revise: docker logs $CONTENEDOR"; exit 1; }
done

TABLAS=$(docker exec "$CONTENEDOR" mysql -h127.0.0.1 -uroot -p"$CLAVE" -N -e \
  "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='renta_herramientas_db' AND TABLE_NAME IN ('favoritos','resenas_herramienta','mantenimientos_herramienta','reporte_dano')" 2>/dev/null || echo 0)
if [ "$1" = "--reiniciar-bd" ] || [ "$TABLAS" != "4" ]; then
  echo "==> Cargando la base de datos completa (database/instalar_todo.sql)..."
  docker exec -i "$CONTENEDOR" mysql -h127.0.0.1 -uroot -p"$CLAVE" --default-character-set=utf8mb4 < database/instalar_todo.sql >/dev/null
  echo "    Base de datos cargada."
fi

for p in 8080 8081 8082 8083; do
  if curl -s "http://localhost:$p/api/v1/categorias" 2>/dev/null | grep -q '"success":true'; then
    echo "==> El backend YA esta corriendo en el puerto $p"
    echo "    Aplicacion: http://localhost:$p/api/v1/index.html"
    echo "    Swagger:    http://localhost:$p/api/v1/swagger-ui.html"
    exit 0
  fi
done

PUERTO=""
for p in 8080 8081 8082 8083; do
  if ! ocupado "$p"; then PUERTO=$p; break; fi
done
[ -z "$PUERTO" ] && { echo "Los puertos 8080 a 8083 estan ocupados. Cierre otra aplicacion e intente de nuevo."; exit 1; }

export DB_URL="jdbc:mysql://localhost:3308/renta_herramientas_db?useSSL=false&serverTimezone=America/Bogota&allowPublicKeyRetrieval=true"
export DB_USERNAME=root DB_PASSWORD="$CLAVE" SERVER_PORT=$PUERTO

echo "==> Arrancando Spring Boot en el puerto $PUERTO (la primera vez descarga dependencias)"
echo "    Cuando aparezca 'Started RentaHerramientasApplication' abra:"
echo "    Aplicacion: http://localhost:$PUERTO/api/v1/index.html"
echo "    Swagger:    http://localhost:$PUERTO/api/v1/swagger-ui.html"
chmod +x mvnw 2>/dev/null || true
if [ -x ./mvnw ]; then ./mvnw spring-boot:run; else mvn spring-boot:run; fi
