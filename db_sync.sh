#!/bin/bash

# Colores para mensajes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Script de sincronización de base de datos Le Brunch App ===${NC}"
echo

# Intentar determinar qué versión de Docker Compose está disponible
COMPOSE_CMD="docker-compose"
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: Docker Compose no está instalado.${NC}"
    exit 1
fi

# Verificar si pg_dump está instalado
if ! command -v pg_dump &> /dev/null; then
    echo -e "${RED}Error: pg_dump no está disponible. Asegúrate de tener PostgreSQL instalado.${NC}"
    exit 1
fi

DB_FILE="db_init/backup.sql"

# Verificar que el contenedor esté en ejecución
if ! docker ps | grep "lebrunch_postgres" &> /dev/null; then
    echo -e "${YELLOW}Error: El contenedor lebrunch_postgres no está en ejecución.${NC}"
    echo -e "Iniciando el contenedor..."
    $COMPOSE_CMD up -d db
    
    # Esperar a que el contenedor esté listo
    echo -e "Esperando a que el contenedor de base de datos esté listo..."
    sleep 5
fi

# 1. Obtener credenciales locales
read -p "Host PostgreSQL local [localhost]: " LOCAL_HOST
LOCAL_HOST=${LOCAL_HOST:-localhost}

read -p "Puerto PostgreSQL local [5432]: " LOCAL_PORT
LOCAL_PORT=${LOCAL_PORT:-5432}

read -p "Nombre de base de datos local [postgres]: " LOCAL_DB
LOCAL_DB=${LOCAL_DB:-postgres}

read -p "Usuario PostgreSQL local [postgres]: " LOCAL_USER
LOCAL_USER=${LOCAL_USER:-postgres}

read -p "Contraseña PostgreSQL local []: " LOCAL_PASS

# 2. Exportar desde la base de datos local
echo
echo -e "${BLUE}=== Exportando base de datos local ===${NC}"
echo -e "Exportando desde ${YELLOW}${LOCAL_HOST}:${LOCAL_PORT}/${LOCAL_DB}${NC}..."

export PGPASSWORD="$LOCAL_PASS"
pg_dump -h "$LOCAL_HOST" -p "$LOCAL_PORT" -U "$LOCAL_USER" -d "$LOCAL_DB" -F p -f "$DB_FILE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: No se pudo exportar la base de datos local.${NC}"
    exit 1
fi

echo -e "${GREEN}Base de datos exportada exitosamente a ${DB_FILE}${NC}"

# 3. Importar al contenedor Docker
echo
echo -e "${BLUE}=== Importando al contenedor Docker ===${NC}"

docker cp "$DB_FILE" lebrunch_postgres:/tmp/backup.sql
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: No se pudo copiar el archivo al contenedor.${NC}"
    exit 1
fi

echo -e "Restaurando en el contenedor..."
docker exec -i lebrunch_postgres psql -U postgres -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
docker exec -i lebrunch_postgres psql -U postgres -f /tmp/backup.sql

echo
echo -e "${BLUE}=== Limpiando y reiniciando servicios ===${NC}"
$COMPOSE_CMD restart server

echo
echo -e "${GREEN}=== Sincronización completada ===${NC}"
echo -e "La base de datos ha sido sincronizada exitosamente."
echo -e "Ahora puedes probar la aplicación con los datos actualizados." 