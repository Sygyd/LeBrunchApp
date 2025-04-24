@echo off
setlocal enabledelayedexpansion

:menu
cls
echo ===============================================
echo       Le Brunch App - Menú de Inicio
echo ===============================================
echo.
echo Selecciona una opción:
echo.
echo 1. Iniciar todo (docker + servidor + app web)
echo 2. Iniciar en modo desarrollo (docker + servidor)
echo 3. Sincronizar base de datos
echo 4. Ver estado de los contenedores
echo 5. Detener todos los servicios
echo 6. Ejecutar comandos Docker directamente
echo 7. Exportar desde pgAdmin e importar a Docker
echo.
echo 0. Salir
echo.

set /p opcion="Ingresa el número de la opción: "

if "%opcion%"=="1" (
    call :iniciar_completo
) else if "%opcion%"=="2" (
    call :iniciar_desarrollo
) else if "%opcion%"=="3" (
    call :sincronizar_bd
) else if "%opcion%"=="4" (
    call :ver_estado
) else if "%opcion%"=="5" (
    call :detener_servicios
) else if "%opcion%"=="6" (
    call :ejecutar_docker
) else if "%opcion%"=="7" (
    call :exportar_pgadmin
) else if "%opcion%"=="0" (
    exit /b 0
) else (
    echo.
    echo ⚠️ Opción no válida. Intenta de nuevo.
    timeout /t 3 >nul
    goto menu
)

goto menu

:iniciar_completo
cls
echo ===============================================
echo       INICIANDO TODOS LOS SERVICIOS
echo ===============================================
echo.
echo Este proceso iniciará:
echo - Contenedor de base de datos PostgreSQL
echo - Servidor Node.js para API
echo - Aplicación web
echo.
echo Por favor espera mientras se inician los servicios...
echo.
echo Presiona cualquier tecla para continuar o CTRL+C para cancelar...
pause >nul

set "MODO_DEV="
start /WAIT cmd /c start-docker.bat

echo.
echo ===============================================
echo       ¡Servicios iniciados correctamente!
echo ===============================================
echo.
echo Los servicios están en ejecución. Puedes acceder a:
echo - API Backend: http://localhost:3000
echo - Base de datos: localhost:5432
echo - Aplicación web: http://localhost:8080
echo.
pause
goto menu

:iniciar_desarrollo
cls
echo ===============================================
echo       INICIANDO EN MODO DESARROLLO
echo ===============================================
echo.
echo Este proceso iniciará:
echo - Contenedor de base de datos PostgreSQL
echo - Servidor Node.js para API
echo.
echo No se iniciará la aplicación web Flutter. Deberás
echo iniciarla manualmente con 'flutter run'.
echo.
echo Presiona cualquier tecla para continuar o CTRL+C para cancelar...
pause >nul

set "MODO_DEV=s"
start /WAIT cmd /c start-docker.bat

echo.
echo ===============================================
echo     ¡Servicios de desarrollo iniciados!
echo ===============================================
echo.
echo Los servicios básicos están en ejecución:
echo - API Backend: http://localhost:3000
echo - Base de datos: localhost:5432
echo.
echo Para iniciar la aplicación Flutter:
echo flutter run -d chrome (para web)
echo flutter run -d ^<device-id^> (para móvil)
echo.
pause
goto menu

:sincronizar_bd
cls
echo ===============================================
echo      SINCRONIZACIÓN DE BASE DE DATOS
echo ===============================================
echo.
echo Este proceso:
echo 1. Exportará datos de tu PostgreSQL local
echo 2. Los importará al contenedor Docker
echo.
echo Es útil cuando ya tienes datos en pgAdmin y 
echo quieres transferirlos al entorno Docker.
echo.
echo Presiona cualquier tecla para continuar o CTRL+C para cancelar...
pause >nul

cmd /c db_sync.bat
echo.
echo Presiona cualquier tecla para volver al menú principal...
pause >nul
goto menu

:ver_estado
cls
echo ===============================================
echo        ESTADO DE LOS CONTENEDORES
echo ===============================================
echo.
echo Consultando el estado actual de los contenedores...
echo.

docker ps
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️ Error al obtener el estado de los contenedores.
    echo Asegúrate de que Docker esté en ejecución.
    echo.
    pause
    goto menu
)

echo.
echo Si los contenedores están en ejecución, las aplicaciones
echo deberían estar disponibles en:
echo.
echo - API Backend: http://localhost:3000
echo - Base de datos: localhost:5432
echo - Aplicación web: http://localhost:8080
echo.
pause
goto menu

:detener_servicios
cls
echo ===============================================
echo       DETENIENDO TODOS LOS SERVICIOS
echo ===============================================
echo.
echo Deteniendo los contenedores Docker...
echo.

REM Intentar con docker compose V2 primero
docker compose down 2>nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Servicios detenidos correctamente con Docker Compose V2.
    echo.
    pause
    goto menu
)

REM Si falló, intentar con docker-compose V1
docker-compose down 2>nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Servicios detenidos correctamente con Docker Compose V1.
    echo.
    pause
    goto menu
)

echo.
echo ⚠️ No se pudieron detener los servicios.
echo Verifica que Docker esté funcionando correctamente.
echo.
pause
goto menu

:ejecutar_docker
cls
echo ===============================================
echo     EJECUCIÓN DIRECTA DE COMANDOS DOCKER
echo ===============================================
echo.
echo Opciones rápidas:
echo.
echo 1. docker compose up -d (iniciar todos los servicios)
echo 2. docker compose up -d db server (iniciar DB y servidor)
echo 3. docker compose down (detener todos los servicios)
echo 4. docker compose restart server (reiniciar el servidor)
echo 5. docker compose logs server (ver logs del servidor)
echo 6. Comando personalizado
echo.
set /p docker_option="Selecciona una opción (1-6): "

cls
echo ===============================================
echo          EJECUTANDO COMANDO DOCKER
echo ===============================================
echo.

if "%docker_option%"=="1" (
    echo Ejecutando: docker compose up -d
    echo.
    docker compose up -d
) else if "%docker_option%"=="2" (
    echo Ejecutando: docker compose up -d db server
    echo.
    docker compose up -d db server
) else if "%docker_option%"=="3" (
    echo Ejecutando: docker compose down
    echo.
    docker compose down
) else if "%docker_option%"=="4" (
    echo Ejecutando: docker compose restart server
    echo.
    docker compose restart server
) else if "%docker_option%"=="5" (
    echo Ejecutando: docker compose logs server
    echo.
    docker compose logs server
) else if "%docker_option%"=="6" (
    set /p custom_cmd="Ingresa el comando Docker a ejecutar: "
    echo.
    echo Ejecutando: !custom_cmd!
    echo.
    !custom_cmd!
) else (
    echo ⚠️ Opción no válida.
)

echo.
echo Comando ejecutado. Revisa los resultados anteriores.
echo.
pause
goto menu

:exportar_pgadmin
cls
echo ===============================================
echo   EXPORTACIÓN DESDE PGADMIN E IMPORTACIÓN
echo ===============================================
echo.
echo Este proceso completo incluye tres pasos:
echo.
echo 1. Exportar la base de datos desde pgAdmin 
echo 2. Iniciar el contenedor Docker de PostgreSQL
echo 3. Importar el archivo SQL al contenedor
echo.
echo Al final, tendrás todos tus datos de pgAdmin
echo disponibles en el contenedor Docker.
echo.
set /p continuar="¿Quieres continuar? (s/n): "
if /i not "!continuar!"=="s" goto menu

cls
echo ===============================================
echo   PASO 1: EXPORTAR DESDE PGADMIN
echo ===============================================
echo.
call export_pgadmin.bat
if %ERRORLEVEL% NEQ 0 goto menu

cls
echo ===============================================
echo   PASO 2: INICIAR CONTENEDOR POSTGRESQL
echo ===============================================
echo.
echo Verificando si el contenedor ya está en ejecución...

docker ps | findstr "lebrunch_postgres" >nul
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ El contenedor PostgreSQL ya está en ejecución.
    echo.
) else (
    echo.
    echo Iniciando contenedor PostgreSQL...
    echo.
    docker compose up -d db
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo ⚠️ Error al iniciar el contenedor PostgreSQL.
        echo Verifica que Docker esté funcionando correctamente.
        echo.
        pause
        goto menu
    )
    echo.
    echo Contenedor iniciado. Esperando 10 segundos para que esté listo...
    timeout /t 10 /nobreak >nul
)

cls
echo ===============================================
echo   PASO 3: IMPORTAR AL CONTENEDOR DOCKER
echo ===============================================
echo.

if not exist "db_init\backup.sql" (
    echo ⚠️ Error: No se encontró el archivo de respaldo db_init\backup.sql
    echo.
    echo Es posible que la exportación desde pgAdmin haya fallado.
    echo Vuelve a intentarlo desde el principio.
    echo.
    pause
    goto menu
)

echo Copiando archivo de respaldo al contenedor...
docker cp db_init\backup.sql lebrunch_postgres:/tmp/backup.sql
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️ Error al copiar el archivo al contenedor.
    echo Verifica que el contenedor esté en ejecución.
    echo.
    pause
    goto menu
)

echo.
echo Reseteando esquema actual en Docker...
docker exec -i lebrunch_postgres psql -U postgres -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️ Error al resetear el esquema en el contenedor.
    echo.
    pause
    goto menu
)

echo.
echo Importando datos... (esto puede tardar unos segundos)
docker exec -i lebrunch_postgres psql -U postgres -f /tmp/backup.sql
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️ Error al importar los datos.
    echo.
    pause
    goto menu
)

echo.
echo ¿Quieres iniciar también el servidor Node.js? (s/n): 
set /p iniciar_server=""
if /i "!iniciar_server!"=="s" (
    echo.
    echo Iniciando servidor Node.js...
    docker compose up -d server
    echo.
    echo ✅ Servidor iniciado correctamente.
)

cls
echo ===============================================
echo   ¡PROCESO COMPLETADO CON ÉXITO!
echo ===============================================
echo.
echo ✅ La base de datos ha sido importada al contenedor Docker.
echo.
echo Ahora puedes utilizar la aplicación con los datos de
echo pgAdmin disponibles en el entorno Docker.
echo.
echo Si iniciaste el servidor, estará disponible en:
echo http://localhost:3000
echo.
echo Si deseas iniciar toda la aplicación, usa la opción 1
echo del menú principal.
echo.
pause
goto menu

endlocal 