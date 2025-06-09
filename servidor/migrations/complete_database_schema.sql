-- =====================================================
-- ESQUEMA COMPLETO DE BASE DE DATOS - LE BRUNCH APP
-- Versión: 2.0 (con Soft Delete)
-- Fecha: Enero 2025
-- =====================================================

-- Configurar zona horaria para Venezuela (GMT-4)
SET timezone = "America/Caracas";

-- =====================================================
-- TABLA: personas
-- Almacena información personal de todos los usuarios
-- =====================================================
CREATE TABLE personas (
    idpersonas SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    
    -- Campos para Soft Delete
    isDelete BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    deleted_by INTEGER REFERENCES personas(idpersonas)
);

-- Índices para optimización de consultas
CREATE INDEX idx_personas_email ON personas(email);
CREATE INDEX idx_personas_cedula ON personas(cedula);
CREATE INDEX idx_personas_soft_delete ON personas(isDelete, deleted_at);

-- =====================================================
-- TABLA: usuario
-- Maneja autenticación y roles de usuarios
-- =====================================================
CREATE TABLE usuario (
    idpersona INTEGER PRIMARY KEY REFERENCES personas(idpersonas),
    contrasena VARCHAR(255) NOT NULL,
    rol VARCHAR(50) NOT NULL
);

-- Índice para optimización de consultas por rol
CREATE INDEX idx_usuario_rol ON usuario(rol);

-- =====================================================
-- TABLA: menu
-- Contiene todos los platos y bebidas disponibles
-- =====================================================
CREATE TABLE menu (
    idplato SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponibilidad BOOLEAN NOT NULL,
    ingredientes TEXT NOT NULL,
    imagen_url TEXT NOT NULL,
    tipo VARCHAR(50),
    
    -- Campos para Soft Delete
    isDelete BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP NULL,
    deleted_by INTEGER REFERENCES personas(idpersonas)
);

-- Índices para optimización
CREATE INDEX idx_menu_categoria ON menu(categoria);
CREATE INDEX idx_menu_tipo ON menu(tipo);
CREATE INDEX idx_menu_disponibilidad ON menu(disponibilidad);
CREATE INDEX idx_menu_soft_delete ON menu(isDelete, deleted_at);

-- =====================================================
-- TABLA: pedidos
-- Registra los pedidos realizados por los clientes
-- =====================================================
CREATE TABLE pedidos (
    idpedido SERIAL PRIMARY KEY,
    idpersona INTEGER NOT NULL REFERENCES personas(idpersonas),
    estado VARCHAR(20) DEFAULT 'pendiente',
    fecha TIMESTAMP DEFAULT NOW(),
    tiempo_procesamiento INTERVAL
);

-- Índices para optimización
CREATE INDEX idx_pedidos_persona ON pedidos(idpersona);
CREATE INDEX idx_pedidos_estado ON pedidos(estado);
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha);

-- =====================================================
-- TABLA: pedido_detalle
-- Detalla los items específicos de cada pedido
-- =====================================================
CREATE TABLE pedido_detalle (
    idpedido_detalle SERIAL PRIMARY KEY,
    idplato INTEGER NOT NULL REFERENCES menu(idplato),
    idpedido INTEGER NOT NULL REFERENCES pedidos(idpedido),
    cantidad INTEGER DEFAULT 1,
    notas TEXT,
    
    -- Campos para seguimiento por rol
    completado_cocinero BOOLEAN DEFAULT FALSE,
    completado_barista BOOLEAN DEFAULT FALSE,
    fecha_completado_cocinero TIMESTAMP,
    fecha_completado_barista TIMESTAMP
);

-- Índices para optimización
CREATE INDEX idx_pedido_detalle_pedido ON pedido_detalle(idpedido);
CREATE INDEX idx_pedido_detalle_plato ON pedido_detalle(idplato);
CREATE INDEX idx_pedido_detalle_completado ON pedido_detalle(completado_cocinero, completado_barista);

-- =====================================================
-- DATOS DE EJEMPLO (OPCIONAL)
-- =====================================================

-- Insertar usuario administrador por defecto
INSERT INTO personas (nombre, apellido, cedula, email, isDelete) 
VALUES ('Admin', 'Sistema', '00000000', 'admin@lebrunch.com', FALSE);

INSERT INTO usuario (idpersona, contrasena, rol) 
VALUES (1, '$2b$10$example.hash.here', '0');

-- Insertar algunas categorías de ejemplo en el menú
INSERT INTO menu (nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, tipo, isDelete) VALUES
('Tabla LB Mix', 'Tablas', 15.50, TRUE, 'Pan tostado, jamón, queso, tomate, lechuga', 'http://192.168.1.121:3000/uploads/tabla-mix.jpg', 'comida', FALSE),
('Panquecas Clásicas', 'Panquecas', 12.00, TRUE, 'Harina, huevos, leche, mantequilla, miel', 'http://192.168.1.121:3000/uploads/panquecas.jpg', 'comida', FALSE),
('Americano', 'Expresos', 3.50, TRUE, 'Café espresso, agua caliente', 'http://192.168.1.121:3000/uploads/americano.jpg', 'bebida', FALSE),
('Jugo de Naranja', 'Jugos', 4.00, TRUE, 'Naranja natural, sin azúcar añadida', 'http://192.168.1.121:3000/uploads/jugo-naranja.jpg', 'bebida', FALSE);

-- =====================================================
-- COMENTARIOS SOBRE EL ESQUEMA
-- =====================================================

/*
ROLES DEL SISTEMA:
- 0: Administrador (acceso completo)
- 1: Cliente (realizar pedidos, ver menú)
- 2: Cocinero (gestionar preparación de comidas)
- 3: Barista (gestionar preparación de bebidas)

ESTADOS DE PEDIDO:
- pendiente: Recién creado, esperando preparación
- preparando: En proceso de preparación
- listo: Terminado, listo para entrega
- completado: Entregado al cliente
- cancelado: Cancelado por alguna razón

TIPOS DE MENU:
- comida: Platos principales (tablas, panquecas, etc.)
- bebida: Bebidas (cafés, jugos, etc.)

CATEGORÍAS DE COMIDA:
- Tablas, Panquecas, Tostadas Francesas, Gofres, Omelettes

CATEGORÍAS DE BEBIDA:
- Expresos, Frapuccinos, Cold Brew, Jugos

SOFT DELETE:
- Las tablas 'personas' y 'menu' implementan soft delete
- Los registros no se eliminan físicamente, solo se marcan como eliminados
- Permite mantener historial completo para auditoría
- Campos: isDelete, deleted_at, deleted_by

OPTIMIZACIONES:
- Índices en campos frecuentemente consultados
- Claves foráneas para integridad referencial
- Zona horaria configurada para Venezuela (GMT-4)
- Tipos de datos optimizados para el uso específico
*/

-- =====================================================
-- VERIFICACIÓN DEL ESQUEMA
-- =====================================================

-- Verificar que todas las tablas se crearon correctamente
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Verificar índices creados
SELECT indexname, tablename 
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;

-- Mostrar estructura de cada tabla
\d personas;
\d usuario;
\d menu;
\d pedidos;
\d pedido_detalle; 