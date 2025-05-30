# 📊 Estructura de Base de Datos - Le Brunch App

## 🗂️ Esquema General

La base de datos de Le Brunch App utiliza **PostgreSQL** y está diseñada para manejar un sistema completo de ecommerce de comida con roles de usuario, gestión de menú, pedidos y sistema de soft delete.

---

## 📋 Tablas y Estructura

### 1. 👥 **Tabla: `personas`**
Almacena la información personal de todos los usuarios del sistema.

```sql
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

-- Índices para optimización
CREATE INDEX idx_personas_email ON personas(email);
CREATE INDEX idx_personas_cedula ON personas(cedula);
CREATE INDEX idx_personas_soft_delete ON personas(isDelete, deleted_at);
```

**Campos:**
- `idpersonas`: Clave primaria autoincremental
- `nombre`: Nombre del usuario (máx. 100 caracteres)
- `apellido`: Apellido del usuario (máx. 100 caracteres)
- `cedula`: Número de cédula único (máx. 20 caracteres)
- `email`: Correo electrónico único (máx. 150 caracteres)
- `isDelete`: Indica si el registro está eliminado lógicamente
- `deleted_at`: Fecha y hora de eliminación
- `deleted_by`: ID del usuario que realizó la eliminación

---

### 2. 🔐 **Tabla: `usuario`**
Maneja la autenticación y roles de los usuarios.

```sql
CREATE TABLE usuario (
    idpersona INTEGER PRIMARY KEY REFERENCES personas(idpersonas),
    contrasena VARCHAR(255) NOT NULL,
    rol VARCHAR(50) NOT NULL
);

-- Índice para optimización de consultas por rol
CREATE INDEX idx_usuario_rol ON usuario(rol);
```

**Campos:**
- `idpersona`: Clave foránea hacia `personas`
- `contrasena`: Contraseña hasheada con bcrypt
- `rol`: Rol del usuario (0=Admin, 1=Cliente, 2=Cocinero, 3=Barista)

**Roles del Sistema:**
- `0` - **Administrador**: Acceso completo al sistema
- `1` - **Cliente**: Puede realizar pedidos y ver menú
- `2` - **Cocinero**: Gestiona preparación de comidas
- `3` - **Barista**: Gestiona preparación de bebidas

---

### 3. 🍽️ **Tabla: `menu`**
Contiene todos los platos y bebidas disponibles.

```sql
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
```

**Campos:**
- `idplato`: Clave primaria autoincremental
- `nombre`: Nombre del plato/bebida (máx. 150 caracteres)
- `categoria`: Categoría específica (ej: "Panquecas", "Expresos")
- `precio`: Precio en formato decimal (10,2)
- `disponibilidad`: Si está disponible para pedidos
- `ingredientes`: Descripción de ingredientes
- `imagen_url`: URL de la imagen del plato
- `tipo`: Tipo general ("comida" o "bebida")
- `isDelete`: Indica si está eliminado lógicamente
- `deleted_at`: Fecha y hora de eliminación
- `deleted_by`: ID del usuario que realizó la eliminación

**Categorías por Tipo:**
- **Comida**: Tablas, Panquecas, Tostadas Francesas, Gofres, Omelettes
- **Bebida**: Expresos, Frapuccinos, Cold Brew, Jugos

---

### 4. 📦 **Tabla: `pedidos`**
Registra los pedidos realizados por los clientes.

```sql
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
```

**Campos:**
- `idpedido`: Clave primaria autoincremental
- `idpersona`: Clave foránea hacia `personas` (cliente que hizo el pedido)
- `estado`: Estado actual del pedido
- `fecha`: Fecha y hora de creación del pedido
- `tiempo_procesamiento`: Tiempo que tomó procesar el pedido

**Estados de Pedido:**
- `pendiente`: Recién creado, esperando preparación
- `preparando`: En proceso de preparación
- `listo`: Terminado, listo para entrega
- `completado`: Entregado al cliente
- `cancelado`: Cancelado por alguna razón

---

### 5. 📋 **Tabla: `pedido_detalle`**
Detalla los items específicos de cada pedido.

```sql
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
```

**Campos:**
- `idpedido_detalle`: Clave primaria autoincremental
- `idplato`: Clave foránea hacia `menu` (incluye referencia al precio)
- `idpedido`: Clave foránea hacia `pedidos`
- `cantidad`: Cantidad del item pedido
- `notas`: Notas especiales del cliente (ej: "sin cebolla")
- `completado_cocinero`: Si el cocinero terminó este item
- `completado_barista`: Si el barista terminó este item
- `fecha_completado_cocinero`: Cuándo el cocinero completó el item
- `fecha_completado_barista`: Cuándo el barista completó el item

**Nota:** El precio se obtiene mediante JOIN con la tabla `menu` para evitar duplicidad de datos.

---

## 🔄 Sistema de Soft Delete

### Implementación
El sistema permite "eliminar" registros sin borrarlos físicamente de la base de datos, manteniendo un historial completo para auditoría.

### Tablas con Soft Delete
- ✅ `personas`
- ✅ `menu`

### Campos Estándar
```sql
isDelete BOOLEAN DEFAULT FALSE,
deleted_at TIMESTAMP NULL,
deleted_by INTEGER REFERENCES personas(idpersonas)
```

### Consultas Típicas
```sql
-- Obtener solo registros activos
SELECT * FROM personas WHERE isDelete = FALSE;

-- Obtener solo registros eliminados
SELECT * FROM personas WHERE isDelete = TRUE;

-- Eliminar lógicamente un registro
UPDATE personas 
SET isDelete = TRUE, deleted_at = NOW(), deleted_by = [user_id] 
WHERE idpersonas = [id];

-- Restaurar un registro
UPDATE personas 
SET isDelete = FALSE, deleted_at = NULL, deleted_by = NULL 
WHERE idpersonas = [id];
```

---

## 📊 Relaciones entre Tablas

```
personas (1) ←→ (1) usuario
    ↓
    (1) ←→ (N) pedidos
              ↓
              (1) ←→ (N) pedido_detalle ←→ (N) ←→ (1) menu
```

### Descripción de Relaciones:
1. **personas ↔ usuario**: Relación 1:1 (una persona = un usuario)
2. **personas ↔ pedidos**: Relación 1:N (una persona puede tener muchos pedidos)
3. **pedidos ↔ pedido_detalle**: Relación 1:N (un pedido puede tener muchos items)
4. **menu ↔ pedido_detalle**: Relación 1:N (un plato puede estar en muchos pedidos)

---

## 🛠️ Configuración de Zona Horaria

La base de datos está configurada para usar la zona horaria de Venezuela:

```sql
SET timezone = "America/Caracas";
```

Esto asegura que todas las fechas y horas se manejen correctamente en GMT-4.

---

## 📈 Optimizaciones Implementadas

### Índices Creados:
- **Búsquedas por email y cédula** en `personas`
- **Filtros por disponibilidad y categoría** en `menu`
- **Consultas por estado y fecha** en `pedidos`
- **Joins optimizados** en `pedido_detalle`
- **Soft delete queries** en tablas aplicables

### Beneficios:
- ⚡ Consultas más rápidas
- 🔍 Búsquedas optimizadas
- 📊 Reportes eficientes
- 🗂️ Gestión de datos mejorada

---

## 🔐 Consideraciones de Seguridad

1. **Contraseñas**: Hasheadas con bcrypt (factor 10)
2. **Soft Delete**: Preserva datos para auditoría
3. **Claves foráneas**: Mantienen integridad referencial
4. **Índices únicos**: Previenen duplicados en email y cédula
5. **Validaciones**: A nivel de aplicación y base de datos

---

*Última actualización: Enero 2025*
*Versión de la base de datos: 2.0 (con Soft Delete)* 