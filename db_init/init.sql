-- Crear tabla de personas
CREATE TABLE IF NOT EXISTS personas (
    idpersonas SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    cedula VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL
);

-- Crear tabla de usuarios
CREATE TABLE IF NOT EXISTS usuario (
    idpersona INT PRIMARY KEY REFERENCES personas(idpersonas),
    contrasena VARCHAR(255) NOT NULL,
    rol VARCHAR(50) NOT NULL
);

-- Crear tabla de menú
CREATE TABLE IF NOT EXISTS menu (
    idplato SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(50) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    disponibilidad BOOLEAN NOT NULL DEFAULT TRUE,
    ingredientes TEXT NOT NULL,
    imagen_url TEXT
);

-- Crear tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos (
    idpedido SERIAL PRIMARY KEY,
    idpersona INT NOT NULL REFERENCES personas(idpersonas),
    estado VARCHAR(20) DEFAULT 'pendiente',
    fecha TIMESTAMP DEFAULT NOW()
);

-- Crear tabla de detalles de pedido
CREATE TABLE IF NOT EXISTS pedido_detalle (
    idpedido_detalle SERIAL PRIMARY KEY,
    idplato INT NOT NULL REFERENCES menu(idplato),
    idpedido INT NOT NULL REFERENCES pedidos(idpedido),
    cantidad INT DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    notas TEXT
);

-- Insertar usuario administrador inicial
INSERT INTO personas (nombre, apellido, cedula, email)
VALUES ('Admin', 'Sistema', '00000000', 'admin@lebrunch.com')
ON CONFLICT (email) DO NOTHING;

-- Insertar usuario (contraseña: admin123)
INSERT INTO usuario (idpersona, contrasena, rol)
SELECT idpersonas, '$2b$10$DjCxgMR.gZIJ3I9UDerTau5Z.GB0d7UEgBbH8KHDk1dHbEOtamUuy', '0'
FROM personas WHERE email = 'admin@lebrunch.com'
ON CONFLICT (idpersona) DO NOTHING;

-- Insertar algunos platos de muestra en el menú
INSERT INTO menu (nombre, categoria, precio, disponibilidad, ingredientes, imagen_url)
VALUES 
('Pancakes Clásicos', 'Desayunos', 8.50, TRUE, 'Harina, huevos, leche, mantequilla, jarabe de maple', 'http://server:3000/uploads/pancakes.jpg'),
('Omelette de Jamón y Queso', 'Desayunos', 10.25, TRUE, 'Huevos, jamón, queso, cebolla, pimientos', 'http://server:3000/uploads/omelette.jpg'),
('Café Americano', 'Bebidas', 3.50, TRUE, 'Café 100% arábica', 'http://server:3000/uploads/cafe.jpg')
ON CONFLICT (idplato) DO NOTHING; 