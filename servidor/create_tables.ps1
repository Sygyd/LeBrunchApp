# Script para crear las tablas de Le Brunch App
Write-Host "🔧 Creando tablas de la base de datos..." -ForegroundColor Cyan

# Verificar si PostgreSQL está disponible
try {
    $testConnection = psql -U postgres -h localhost -p 5432 -d postgres -c "SELECT 1;"
    Write-Host "✅ Conexión a PostgreSQL exitosa" -ForegroundColor Green
} catch {
    Write-Host "❌ Error conectando a PostgreSQL" -ForegroundColor Red
    exit 1
}

# Crear tablas
Write-Host "📋 Creando tabla personas..." -ForegroundColor Yellow
psql -U postgres -h localhost -p 5432 -d postgres -c "
CREATE TABLE IF NOT EXISTS personas (
    idpersonas SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    isDelete BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    deleted_by INTEGER
);
"

Write-Host "👤 Creando tabla usuario..." -ForegroundColor Yellow
psql -U postgres -h localhost -p 5432 -d postgres -c "
CREATE TABLE IF NOT EXISTS usuario (
    idpersona INTEGER PRIMARY KEY REFERENCES personas(idpersonas),
    contrasena VARCHAR(255) NOT NULL,
    rol VARCHAR(50) NOT NULL
);
"

Write-Host "🍽️ Creando tabla menu..." -ForegroundColor Yellow
psql -U postgres -h localhost -p 5432 -d postgres -c "
CREATE TABLE IF NOT EXISTS menu (
    idplato SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponibilidad BOOLEAN NOT NULL,
    ingredientes TEXT NOT NULL,
    imagen_url TEXT NOT NULL,
    tipo VARCHAR(50),
    isDelete BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    deleted_by INTEGER
);
"

Write-Host "📦 Creando tabla pedidos..." -ForegroundColor Yellow
psql -U postgres -h localhost -p 5432 -d postgres -c "
CREATE TABLE IF NOT EXISTS pedidos (
    idpedido SERIAL PRIMARY KEY,
    idpersona INTEGER NOT NULL REFERENCES personas(idpersonas),
    estado VARCHAR(20) DEFAULT 'pendiente',
    fecha TIMESTAMP DEFAULT NOW(),
    tiempo_procesamiento INTERVAL
);
"

Write-Host "📝 Creando tabla pedido_detalle..." -ForegroundColor Yellow
psql -U postgres -h localhost -p 5432 -d postgres -c "
CREATE TABLE IF NOT EXISTS pedido_detalle (
    idpedido_detalle SERIAL PRIMARY KEY,
    idplato INTEGER NOT NULL REFERENCES menu(idplato),
    idpedido INTEGER NOT NULL REFERENCES pedidos(idpedido),
    cantidad INTEGER DEFAULT 1,
    notas TEXT,
    completado_cocinero BOOLEAN DEFAULT FALSE,
    completado_barista BOOLEAN DEFAULT FALSE,
    fecha_completado_cocinero TIMESTAMP,
    fecha_completado_barista TIMESTAMP
);
"

Write-Host "📊 Verificando tablas creadas..." -ForegroundColor Yellow
psql -U postgres -h localhost -p 5432 -d postgres -c "\dt"

Write-Host "✅ ¡Base de datos creada exitosamente!" -ForegroundColor Green
Write-Host "🚀 Ahora puedes reiniciar el servidor Node.js" -ForegroundColor Cyan 