@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo     INICIANDO LE BRUNCH APP CON DOCKER
echo ===============================================
echo.

REM Verificar si Docker está instalado
where docker >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ⚠️ Error: Docker no está instalado. Por favor, instale Docker primero.
    pause
    exit /b 1
)

REM Definir el comando de Docker Compose
set COMPOSE_CMD=docker compose

REM Verificar si hay contenedores en ejecución y detenerlos
echo Deteniendo contenedores previos si existen...
%COMPOSE_CMD% down

REM Crear la carpeta uploads si no existe
if not exist "uploads" mkdir uploads

REM Iniciar los contenedores
echo.
echo Iniciando los contenedores de Docker...
echo.

set /p dev_mode="¿Iniciar en modo desarrollo (solo base de datos y servidor)? (s/n): "

if /i "!dev_mode!"=="s" (
    echo Iniciando en modo desarrollo (solo base de datos y servidor)...
    %COMPOSE_CMD% up -d db server
) else (
    echo Iniciando todos los servicios...
    %COMPOSE_CMD% up -d
)

REM Mostrar estado de los contenedores
echo.
echo Contenedores en ejecución:
docker ps

echo.
echo ===============================================
echo Para detener los contenedores, ejecuta:
echo %COMPOSE_CMD% down
echo ===============================================

echo.
echo Presiona cualquier tecla para salir...
pause

endlocal 