@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo     SINCRONIZACIÓN DE BASE DE DATOS
echo ===============================================
echo.

REM Verificar qué versión de Docker Compose está disponible (V2 o V1)
echo Verificando Docker Compose...

set "COMPOSE_CMD=docker compose"
docker compose version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Detectado: Docker Compose V2 (integrado con Docker CLI)
    goto compose_found
)

set "COMPOSE_CMD=docker-compose"
docker-compose --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Detectado: Docker Compose V1 (comando separado)
    goto compose_found
)

echo ⚠️ Error: No se pudo detectar Docker Compose.
echo Debes instalar Docker Compose o Docker Desktop.
pause
exit /b 1

:compose_found

REM Verificar si pg_dump está instalado
echo Verificando si pg_dump está instalado...

REM Definir rutas conocidas para pg_dump
set "PG_DUMP_PATH1=C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"
set "PG_DUMP_PATH2=C:\Program Files\PostgreSQL\17\pgAdmin 4\runtime\pg_dump.exe"

REM Verificar si alguna de las rutas conocidas existe
if exist "!PG_DUMP_PATH1!" (
    echo ✅ pg_dump encontrado en: !PG_DUMP_PATH1!
    set "PG_DUMP_PATH=!PG_DUMP_PATH1!"
    goto pgdump_found
) else if exist "!PG_DUMP_PATH2!" (
    echo ✅ pg_dump encontrado en: !PG_DUMP_PATH2!
    set "PG_DUMP_PATH=!PG_DUMP_PATH2!"
    goto pgdump_found
)

REM Primero intentar con pg_dump directamente en el PATH
where pg_dump >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ pg_dump encontrado en el PATH.
    for /f "tokens=*" %%a in ('where pg_dump') do set "PG_DUMP_PATH=%%a"
    goto pgdump_found
)

REM Intentar buscar en ubicaciones comunes de PostgreSQL
set "PGDUMP_PATHS=C:\Program Files\PostgreSQL"
echo pg_dump no encontrado en el PATH. Buscando en instalaciones comunes...

for /d %%G in ("%PGDUMP_PATHS%\*") do (
    if exist "%%G\bin\pg_dump.exe" (
        echo ✅ pg_dump encontrado en: %%G\bin
        set "PG_DUMP_PATH=%%G\bin\pg_dump.exe"
        goto pgdump_found
    )
)

REM Preguntar al usuario por la ruta
echo.
echo ⚠️ No se pudo encontrar pg_dump automáticamente.
echo.
echo Opciones:
echo 1. Instalar PostgreSQL (https://www.postgresql.org/download/windows/)
echo 2. Especificar la ruta a pg_dump manualmente
echo 3. Usar la opción de respaldo manual (docker sin exportar desde local)
echo.
set /p pgdump_option="Selecciona una opción (1/2/3): "

if "%pgdump_option%"=="1" (
    echo Instala PostgreSQL y vuelve a ejecutar este script.
    pause
    exit /b 1
) else if "%pgdump_option%"=="2" (
    set /p pg_dump_path="Ruta completa a pg_dump.exe (incluyendo el nombre del archivo): "
    if not exist "!pg_dump_path!" (
        echo ⚠️ Error: La ruta especificada no existe: !pg_dump_path!
        pause
        exit /b 1
    )
    set "PG_DUMP_PATH=!pg_dump_path!"
    goto pgdump_found
) else if "%pgdump_option%"=="3" (
    goto manual_backup
) else (
    echo ⚠️ Opción no válida.
    pause
    exit /b 1
)

:pgdump_found
REM Verificar si el contenedor está en ejecución
echo.
echo Verificando si el contenedor de PostgreSQL está en ejecución...

docker ps | findstr "lebrunch_postgres" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ El contenedor lebrunch_postgres está en ejecución.
) else (
    echo ⚠️ El contenedor lebrunch_postgres no está en ejecución.
    echo Iniciando el contenedor...
    %COMPOSE_CMD% up -d db
    if %ERRORLEVEL% NEQ 0 (
        echo ⚠️ Error al iniciar el contenedor. Verifica si Docker está funcionando correctamente.
        pause
        exit /b 1
    )
    
    echo Esperando 10 segundos para que el contenedor esté listo...
    timeout /t 10 /nobreak >nul
)

REM 1. Obtener credenciales locales
echo.
echo ===============================================
echo       CONFIGURACIÓN DE BASE DE DATOS LOCAL
echo ===============================================
echo.
echo Introduce los datos de conexión a tu base de datos PostgreSQL local:
echo.
set /p LOCAL_HOST="Host PostgreSQL local [localhost]: " || set LOCAL_HOST=localhost
set /p LOCAL_PORT="Puerto PostgreSQL local [5432]: " || set LOCAL_PORT=5432
set /p LOCAL_DB="Nombre de base de datos local [postgres]: " || set LOCAL_DB=postgres
set /p LOCAL_USER="Usuario PostgreSQL local [postgres]: " || set LOCAL_USER=postgres
set /p LOCAL_PASS="Contraseña PostgreSQL local: "

REM Crear directorio db_init si no existe
if not exist "db_init" mkdir db_init

REM 2. Exportar desde la base de datos local
echo.
echo ===============================================
echo       EXPORTANDO BASE DE DATOS LOCAL
echo ===============================================
echo.
echo Exportando datos desde %LOCAL_HOST%:%LOCAL_PORT%/%LOCAL_DB%...
echo Este proceso puede tardar unos segundos...
echo Usando pg_dump desde: !PG_DUMP_PATH!

set PGPASSWORD=%LOCAL_PASS%

"!PG_DUMP_PATH!" -h %LOCAL_HOST% -p %LOCAL_PORT% -U %LOCAL_USER% -d %LOCAL_DB% -f db_init\backup.sql

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️ Error al exportar la base de datos.
    echo Posibles causas:
    echo - Contraseña incorrecta
    echo - Base de datos "%LOCAL_DB%" no existe
    echo - PostgreSQL no está en ejecución
    echo - Error de conexión a la base de datos
    echo.
    echo ¿Deseas intentar la opción de respaldo manual? (s/n)
    set /p retry_manual="Tu respuesta: "
    if /i "!retry_manual!"=="s" goto manual_backup
    pause
    exit /b 1
)

echo ✅ Base de datos exportada correctamente a db_init\backup.sql

goto import_to_docker

:manual_backup
echo.
echo ===============================================
echo       RESPALDO MANUAL
echo ===============================================
echo.
echo Esta opción usará el archivo db_init\init.sql para inicializar
echo la base de datos Docker en lugar de exportar datos desde tu PostgreSQL local.
echo.
echo ¿Estás seguro de continuar? Este proceso:
echo 1. NO exportará datos desde tu base local
echo 2. Usará el esquema básico en db_init\init.sql
echo 3. Creará un entorno limpio en el contenedor Docker
echo.
set /p confirm_manual="Confirmar (s/n): "
if /i not "!confirm_manual!"=="s" (
    echo Operación cancelada por el usuario.
    pause
    exit /b 0
)

echo.
echo Usando configuración manual con init.sql...

REM Verificar si existe init.sql
if not exist "db_init\init.sql" (
    echo ⚠️ Error: No se encontró el archivo db_init\init.sql
    echo Este archivo es necesario para la inicialización manual.
    echo Copia un archivo SQL válido a esta ubicación e intenta de nuevo.
    pause
    exit /b 1
)

:import_to_docker
echo.
echo ===============================================
echo       IMPORTANDO DATOS A DOCKER
echo ===============================================
echo.
echo Copiando archivo SQL al contenedor...

REM Determinar qué archivo usar (backup.sql o init.sql)
set SQL_FILE=db_init\backup.sql
if "%pgdump_option%"=="3" set SQL_FILE=db_init\init.sql

if not exist "%SQL_FILE%" (
    echo ⚠️ Error: No se encontró el archivo %SQL_FILE%
    pause
    exit /b 1
)

REM Copiar el archivo al contenedor
docker cp %SQL_FILE% lebrunch_postgres:/tmp/import.sql
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Error al copiar el archivo al contenedor.
    echo Verifica que el contenedor esté en ejecución.
    pause
    exit /b 1
)

echo ✅ Archivo copiado correctamente

REM Resetear el esquema de la base de datos
echo.
echo Reseteando esquema en la base de datos del contenedor...
docker exec lebrunch_postgres psql -U postgres -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Error al resetear el esquema.
    echo Verifique que la base de datos esté funcionando correctamente.
    pause
    exit /b 1
)

echo ✅ Esquema reseteado correctamente

REM Importar datos
echo.
echo Importando datos al contenedor Docker...
echo Este proceso puede tardar unos segundos...

docker exec lebrunch_postgres psql -U postgres -f /tmp/import.sql
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Error al importar datos.
    echo Verificar si el archivo SQL es válido.
    pause
    exit /b 1
)

echo.
echo ===============================================
echo       ¡SINCRONIZACIÓN COMPLETADA!
echo ===============================================
echo.
echo ✅ Los datos han sido importados correctamente al contenedor Docker.
echo.
echo Información de conexión:
echo - Host: localhost
echo - Puerto: 5432
echo - Base de datos: postgres
echo - Usuario: postgres
echo - Contraseña: monito
echo.
echo Ya puedes acceder a los datos desde la aplicación.
echo.
pause
exit /b 0

endlocal 