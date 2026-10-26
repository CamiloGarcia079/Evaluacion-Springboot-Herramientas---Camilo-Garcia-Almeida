# ============================================================================
# Arranque completo en Windows (PowerShell):  .\iniciar.ps1
#   Opcional: .\iniciar.ps1 -ReiniciarBD   (borra y vuelve a cargar los datos)
# Hace lo mismo que iniciar.sh: MySQL en Docker, carga de datos si hace falta,
# deteccion de un backend ya abierto y arranque en un puerto libre.
# ============================================================================
param([switch]$ReiniciarBD)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$Clave = if ($env:DB_ROOT_PASSWORD) { $env:DB_ROOT_PASSWORD } else { "rootpassword" }
$Contenedor = "renta-mysql-2"

function Ocupado($puerto) {
    try { $c = New-Object Net.Sockets.TcpClient; $c.Connect("127.0.0.1", $puerto); $c.Close(); return $true } catch { return $false }
}

Write-Host "==> Levantando MySQL en Docker..."
docker compose up -d mysql
if ($LASTEXITCODE -ne 0) { Write-Host "No se pudo iniciar Docker. Abra Docker Desktop y vuelva a intentar."; exit 1 }

Write-Host -NoNewline "==> Esperando a MySQL"
$listo = $false
for ($i = 0; $i -lt 60; $i++) {
    docker exec $Contenedor mysql -h127.0.0.1 -uroot "-p$Clave" -e "SELECT 1" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $listo = $true; break }
    Write-Host -NoNewline "."; Start-Sleep -Seconds 2
}
if (-not $listo) { Write-Host "`nMySQL no respondio. Revise: docker logs $Contenedor"; exit 1 }
Write-Host " listo"

$tablas = docker exec $Contenedor mysql -h127.0.0.1 -uroot "-p$Clave" -N -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='renta_herramientas_db' AND TABLE_NAME IN ('favoritos','resenas_herramienta','mantenimientos_herramienta','reporte_dano')" 2>$null
if ($ReiniciarBD -or "$tablas".Trim() -ne "4") {
    Write-Host "==> Cargando la base de datos completa (database\instalar_todo.sql)..."
    Get-Content -Raw -Encoding UTF8 database\instalar_todo.sql | docker exec -i $Contenedor mysql -h127.0.0.1 -uroot "-p$Clave" --default-character-set=utf8mb4 | Out-Null
    Write-Host "    Base de datos cargada."
}

foreach ($p in 8080, 8081, 8082, 8083) {
    try {
        $r = Invoke-RestMethod -Uri "http://localhost:$p/api/v1/categorias" -TimeoutSec 2
        if ($r.success) {
            Write-Host "==> El backend YA esta corriendo en el puerto $p"
            Write-Host "    Aplicacion: http://localhost:$p/api/v1/index.html"
            Write-Host "    Swagger:    http://localhost:$p/api/v1/swagger-ui.html"
            exit 0
        }
    } catch { }
}

$Puerto = $null
foreach ($p in 8080, 8081, 8082, 8083) { if (-not (Ocupado $p)) { $Puerto = $p; break } }
if (-not $Puerto) { Write-Host "Los puertos 8080 a 8083 estan ocupados."; exit 1 }

$env:DB_URL = "jdbc:mysql://localhost:3308/renta_herramientas_db?useSSL=false&serverTimezone=America/Bogota&allowPublicKeyRetrieval=true"
$env:DB_USERNAME = "root"; $env:DB_PASSWORD = $Clave; $env:SERVER_PORT = "$Puerto"

Write-Host "==> Arrancando Spring Boot en el puerto $Puerto"
Write-Host "    Cuando aparezca 'Started RentaHerramientasApplication' abra:"
Write-Host "    Aplicacion: http://localhost:$Puerto/api/v1/index.html"
Write-Host "    Swagger:    http://localhost:$Puerto/api/v1/swagger-ui.html"
.\mvnw.cmd spring-boot:run
