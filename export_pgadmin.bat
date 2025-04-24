@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo    Exportación de base de datos desde pgAdmin 4
echo ===============================================
echo.

REM Detectar la instalación de PostgreSQL
echo Buscando instalación de PostgreSQL...
set "PG_DUMP_PATH="

REM Verificar la ruta de PostgreSQL 17 (visible en pgAdmin)
if exist "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" (
    set "PG_DUMP_PATH=C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"
    echo Encontrado pg_dump en PostgreSQL 17
)

REM Si no se encuentra, buscar en otras versiones comunes
if "!PG_DUMP_PATH!"=="" (
    for %%v in (16 15 14 13 12 11 10) do (
        if exist "C:\Program Files\PostgreSQL\%%v\bin\pg_dump.exe" (
            set "PG_DUMP_PATH=C:\Program Files\PostgreSQL\%%v\bin\pg_dump.exe"
            echo Encontrado pg_dump en PostgreSQL %%v
        )
    )
)

REM Si aún no se encuentra, preguntar al usuario
if "!PG_DUMP_PATH!"=="" (
    echo No se encontró automáticamente la instalación de PostgreSQL.
    set /p PG_DUMP_PATH="Ruta completa a pg_dump.exe: "
    
    if not exist "!PG_DUMP_PATH!" (
        echo Error: La ruta especificada no existe.
        pause
        exit /b 1
    )
)

echo.
echo Usando pg_dump: !PG_DUMP_PATH!
echo.

REM Obtener datos de conexión con valores predeterminados basados en pgAdmin
echo Según la captura de pgAdmin, parece que estás usando:
echo - Host: localhost
echo - Usuario: postgres
echo - Base de datos: postgres@rasa

set /p PG_HOST="Host de PostgreSQL [localhost]: " || set PG_HOST=localhost
set /p PG_PORT="Puerto de PostgreSQL [5432]: " || set PG_PORT=5432
set /p PG_USER="Usuario de PostgreSQL [postgres]: " || set PG_USER=postgres
set /p PG_PASS="Contraseña de PostgreSQL: "
set /p PG_DB="Nombre de la base de datos [postgres]: " || set PG_DB=postgres

echo.
echo Configuración a utilizar:
echo Host: %PG_HOST%
echo Puerto: %PG_PORT%
echo Base de datos: %PG_DB%
echo Usuario: %PG_USER%
echo.

REM Crear directorio db_init si no existe
if not exist "db_init" (
    echo Creando directorio db_init...
    mkdir db_init
)

echo.
echo Exportando la base de datos %PG_DB%...
echo Por favor espera, esto puede tomar unos segundos...

REM Configurar variable de entorno para la contraseña
set PGPASSWORD=%PG_PASS%

REM Exportar la estructura y datos
"%PG_DUMP_PATH%" -h %PG_HOST% -p %PG_PORT% -U %PG_USER% -d %PG_DB% -f db_init\backup.sql

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ===============================================
    echo ERROR: No se pudo exportar la base de datos
    echo ===============================================
    echo.
    echo Posibles causas:
    echo 1. Contraseña incorrecta
    echo 2. La base de datos "%PG_DB%" no existe
    echo 3. PostgreSQL no está en ejecución
    echo 4. Problema de permisos
    echo.
    pause
    exit /b 1
)

echo.
echo ===============================================
echo         Exportación completada con éxito
echo ===============================================
echo.
echo La base de datos ha sido exportada a: db_init\backup.sql
echo.
echo Este archivo será usado para importar los datos a Docker.
echo.

REM Mostrar mensaje acerca del siguiente paso
echo Siguiente paso: El sistema importará este archivo a Docker.
echo.
pause
endlocal 