#!/bin/bash

# Script para iniciar los contenedores Docker de Le Brunch App

# Colores para mensajes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Iniciando Le Brunch App con Docker ===${NC}"

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado. Por favor, instale Docker primero.${NC}"
    exit 1
fi

# Intentar determinar qué versión de Docker Compose está disponible
COMPOSE_CMD="docker-compose"
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    echo -e "${GREEN}Usando Docker Compose V2 (integrado con Docker CLI)${NC}"
elif ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose no está instalado. Por favor, instale Docker Compose primero.${NC}"
    exit 1
else
    echo -e "${YELLOW}Usando Docker Compose V1 (comando independiente)${NC}"
fi

# Verificar si el archivo .env existe
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Advertencia: No se encontró el archivo .env.${NC}"
    echo -e "${YELLOW}Se usarán los valores predeterminados para la configuración.${NC}"
    
    # Preguntar si se desea crear un archivo .env de ejemplo
    read -p "¿Desea crear un archivo .env de ejemplo? (s/n): " crear_env
    if [[ $crear_env == "s" || $crear_env == "S" ]]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            echo -e "${GREEN}Archivo .env creado a partir de .env.example. Por favor, edite los valores según sea necesario.${NC}"
        else
            echo -e "${BLUE}=== Creando .env con valores predeterminados ===${NC}"
            cat > .env << EOL
# Configuración del servidor
SERVER_IP=192.168.1.121
SERVER_PORT=3000

# Configuración de la base de datos
DB_HOST=db
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=monito
DB_NAME=postgres

# Configuración de Gemini
GEMINI_API_KEY=your_gemini_api_key_here

# Otras configuraciones
DEBUG_MODE=true
EOL
            echo -e "${GREEN}Archivo .env creado con valores predeterminados. Por favor, edite los valores según sea necesario.${NC}"
        fi
    fi
fi

# Crear la carpeta uploads si no existe
mkdir -p uploads
chmod 777 uploads

# Comprobar si hay contenedores en ejecución
if $COMPOSE_CMD ps &> /dev/null; then
    echo "Los contenedores están en ejecución. ¿Desea reiniciarlos?"
    read -p "Reiniciar contenedores (s/n): " restart
    if [[ $restart == "s" || $restart == "S" ]]; then
        echo "Deteniendo los contenedores actuales..."
        $COMPOSE_CMD down
    fi
fi

# Iniciar los contenedores
echo -e "${BLUE}Iniciando los contenedores de Docker...${NC}"

# Verificar si se quiere iniciar en modo desarrollo o producción
read -p "¿Iniciar en modo desarrollo (solo base de datos y servidor)? (s/n): " dev_mode
if [[ $dev_mode == "s" || $dev_mode == "S" ]]; then
    echo -e "${GREEN}Iniciando en modo desarrollo (solo base de datos y servidor)...${NC}"
    $COMPOSE_CMD up -d db server
else
    echo -e "${GREEN}Iniciando todos los servicios...${NC}"
    $COMPOSE_CMD up -d
fi

if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error al iniciar los contenedores. Intente:${NC}"
    echo "1. Verificar que Docker esté en ejecución"
    echo "2. Ejecutar manualmente: docker compose up -d"
    exit 1
fi

# Sincronización de base de datos
read -p "¿Desea sincronizar la base de datos local con el contenedor? (s/n): " sync_db
if [[ $sync_db == "s" || $sync_db == "S" ]]; then
    echo
    echo -e "${BLUE}=== Iniciando sincronización de base de datos ===${NC}"
    bash ./db_sync.sh
fi

# Verificar el estado de los contenedores
echo -e "\n${BLUE}=== Estado de los contenedores ===${NC}"
$COMPOSE_CMD ps

# Mostrar enlaces útiles si todos los servicios están en ejecución
if [[ $dev_mode != "s" && $dev_mode != "S" ]]; then
    echo -e "\n${GREEN}=== Aplicación iniciada correctamente ===${NC}"
    echo -e "Aplicación web: ${BLUE}http://localhost:8080${NC}"
    echo -e "API Backend: ${BLUE}http://localhost:3000${NC}"
    echo -e "Base de datos: ${BLUE}localhost:5432${NC}"
else
    echo -e "\n${GREEN}=== Servicios de desarrollo iniciados correctamente ===${NC}"
    echo -e "API Backend: ${BLUE}http://localhost:3000${NC}"
    echo -e "Base de datos: ${BLUE}localhost:5432${NC}"
    echo -e "\nPara iniciar la aplicación Flutter en modo desarrollo, ejecuta:"
    echo -e "${YELLOW}flutter run -d chrome${NC} (para web)"
    echo -e "o"
    echo -e "${YELLOW}flutter run -d <device-id>${NC} (para dispositivo móvil)"
fi

echo -e "\n${BLUE}=== Para detener los contenedores, ejecuta: ===${NC}"
echo -e "${YELLOW}$COMPOSE_CMD down${NC}" 