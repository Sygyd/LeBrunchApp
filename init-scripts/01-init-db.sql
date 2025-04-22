-- Script de inicialización para la base de datos Le Brunch
-- Este script se ejecuta automáticamente cuando el contenedor PostgreSQL inicia por primera vez

-- Crear las tablas necesarias para Le Brunch

-- Tabla de personas
CREATE TABLE IF NOT EXISTS personas (
    idpersonas SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(20)
);

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS usuario (
    idpersona INTEGER PRIMARY KEY REFERENCES personas(idpersonas) ON DELETE CASCADE,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(100) NOT NULL,
    rol INTEGER NOT NULL DEFAULT 3, -- 1=admin, 2=staff, 3=cliente
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de menú
CREATE TABLE IF NOT EXISTS menu (
    idplato SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    ingredientes TEXT,
    categoria VARCHAR(50) NOT NULL,
    disponibilidad BOOLEAN DEFAULT TRUE,
    imagen_url TEXT
);

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos (
    idpedido SERIAL PRIMARY KEY,
    idpersona INTEGER REFERENCES personas(idpersonas),
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente', -- pendiente, completado, cancelado
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de detalles de pedido
CREATE TABLE IF NOT EXISTS pedido_detalle (
    iddetalle SERIAL PRIMARY KEY,
    idpedido INTEGER REFERENCES pedidos(idpedido) ON DELETE CASCADE,
    idplato INTEGER REFERENCES menu(idplato),
    cantidad INTEGER NOT NULL,
    precio_unitario DECIMAL(10, 2) NOT NULL,
    notas TEXT
);

-- Insertar algunos datos de ejemplo

-- Insertar administrador por defecto
INSERT INTO personas (nombre, apellido, correo, telefono)
VALUES ('Admin', 'Le Brunch', 'admin@lebrunch.com', '12345678')
ON CONFLICT (correo) DO NOTHING;

-- Obtener el ID de la persona admin
DO $$
DECLARE
    admin_id INTEGER;
BEGIN
    SELECT idpersonas INTO admin_id FROM personas WHERE correo = 'admin@lebrunch.com';
    
    -- Insertar usuario administrador
    INSERT INTO usuario (idpersona, username, password, rol)
    VALUES (admin_id, 'admin', '$2a$10$XYZ123ENCRYPTED.PASSWORD.HASH', 1)
    ON CONFLICT (idpersona) DO NOTHING;
END $$;

-- Insertar algunos platos de ejemplo en el menú
INSERT INTO menu (nombre, precio, ingredientes, categoria, disponibilidad, imagen_url)
VALUES 
    ('Tostada Francesa', 12.99, 'Pan, huevo, canela, azúcar, miel', 'Desayunos', TRUE, 'https://example.com/tostada.jpg'),
    ('Omelette Clásico', 14.99, 'Huevos, queso, jamón, pimientos, cebolla', 'Desayunos', TRUE, 'https://example.com/omelette.jpg'),
    ('Panquecas de Avena', 10.99, 'Avena, plátano, canela, miel', 'Desayunos', TRUE, 'https://example.com/panquecas.jpg'),
    ('Gofres Belgas', 13.99, 'Harina, huevo, azúcar, fresas, arándanos, crema batida', 'Desayunos', TRUE, 'https://example.com/gofres.jpg'),
    ('Café Americano', 3.99, 'Café de especialidad', 'Bebidas', TRUE, 'https://example.com/cafe.jpg'),
    ('Jugo Natural de Naranja', 4.99, 'Naranja fresca', 'Bebidas', TRUE, 'https://example.com/jugo.jpg')
ON CONFLICT DO NOTHING;

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_pedidos_persona ON pedidos(idpersona);
CREATE INDEX IF NOT EXISTS idx_pedido_detalle_pedido ON pedido_detalle(idpedido);
CREATE INDEX IF NOT EXISTS idx_menu_categoria ON menu(categoria);

-- Otorgar permisos
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO postgres;