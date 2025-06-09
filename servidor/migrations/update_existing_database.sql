-- =====================================================
-- MIGRACIÓN PARA ACTUALIZAR BASE DE DATOS EXISTENTE
-- De versión 1.0 a versión 2.0 (con Soft Delete)
-- Fecha: Enero 2025
-- =====================================================

-- IMPORTANTE: Ejecutar este script solo si ya tienes una base de datos existente
-- Si es una instalación nueva, usar complete_database_schema.sql

BEGIN;

-- =====================================================
-- 1. AGREGAR CAMPOS DE SOFT DELETE A TABLA PERSONAS
-- =====================================================

-- Verificar si los campos ya existen antes de agregarlos
DO $$ 
BEGIN
    -- Agregar campo isDelete si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'personas' AND column_name = 'isdelete') THEN
        ALTER TABLE personas ADD COLUMN isDelete BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Campo isDelete agregado a tabla personas';
    ELSE
        RAISE NOTICE 'Campo isDelete ya existe en tabla personas';
    END IF;

    -- Agregar campo deleted_at si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'personas' AND column_name = 'deleted_at') THEN
        ALTER TABLE personas ADD COLUMN deleted_at TIMESTAMP NULL;
        RAISE NOTICE 'Campo deleted_at agregado a tabla personas';
    ELSE
        RAISE NOTICE 'Campo deleted_at ya existe en tabla personas';
    END IF;

    -- Agregar campo deleted_by si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'personas' AND column_name = 'deleted_by') THEN
        ALTER TABLE personas ADD COLUMN deleted_by INTEGER REFERENCES personas(idpersonas);
        RAISE NOTICE 'Campo deleted_by agregado a tabla personas';
    ELSE
        RAISE NOTICE 'Campo deleted_by ya existe en tabla personas';
    END IF;
END $$;

-- =====================================================
-- 2. AGREGAR CAMPOS DE SOFT DELETE A TABLA MENU
-- =====================================================

DO $$ 
BEGIN
    -- Agregar campo isDelete si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'menu' AND column_name = 'isdelete') THEN
        ALTER TABLE menu ADD COLUMN isDelete BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Campo isDelete agregado a tabla menu';
    ELSE
        RAISE NOTICE 'Campo isDelete ya existe en tabla menu';
    END IF;

    -- Agregar campo deleted_at si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'menu' AND column_name = 'deleted_at') THEN
        ALTER TABLE menu ADD COLUMN deleted_at TIMESTAMP NULL;
        RAISE NOTICE 'Campo deleted_at agregado a tabla menu';
    ELSE
        RAISE NOTICE 'Campo deleted_at ya existe en tabla menu';
    END IF;

    -- Agregar campo deleted_by si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'menu' AND column_name = 'deleted_by') THEN
        ALTER TABLE menu ADD COLUMN deleted_by INTEGER REFERENCES personas(idpersonas);
        RAISE NOTICE 'Campo deleted_by agregado a tabla menu';
    ELSE
        RAISE NOTICE 'Campo deleted_by ya existe en tabla menu';
    END IF;
END $$;

-- =====================================================
-- 3. AGREGAR CAMPO TIPO A TABLA MENU (SI NO EXISTE)
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'menu' AND column_name = 'tipo') THEN
        ALTER TABLE menu ADD COLUMN tipo VARCHAR(50);
        RAISE NOTICE 'Campo tipo agregado a tabla menu';
        
        -- Actualizar valores existentes basándose en la categoría
        UPDATE menu SET tipo = 'comida' 
        WHERE LOWER(categoria) IN ('tablas', 'panquecas', 'tostadas francesas', 'gofres', 'omelettes');
        
        UPDATE menu SET tipo = 'bebida' 
        WHERE categoria IN ('Expresos', 'Frapuccinos', 'Cold Brew', 'Jugos');
        
        RAISE NOTICE 'Valores de tipo actualizados basándose en categorías existentes';
    ELSE
        RAISE NOTICE 'Campo tipo ya existe en tabla menu';
    END IF;
END $$;

-- =====================================================
-- 4. AGREGAR CAMPOS DE SEGUIMIENTO A PEDIDO_DETALLE
-- =====================================================

DO $$ 
BEGIN
    -- Agregar completado_cocinero si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'pedido_detalle' AND column_name = 'completado_cocinero') THEN
        ALTER TABLE pedido_detalle ADD COLUMN completado_cocinero BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Campo completado_cocinero agregado a tabla pedido_detalle';
    ELSE
        RAISE NOTICE 'Campo completado_cocinero ya existe en tabla pedido_detalle';
    END IF;

    -- Agregar completado_barista si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'pedido_detalle' AND column_name = 'completado_barista') THEN
        ALTER TABLE pedido_detalle ADD COLUMN completado_barista BOOLEAN DEFAULT FALSE;
        RAISE NOTICE 'Campo completado_barista agregado a tabla pedido_detalle';
    ELSE
        RAISE NOTICE 'Campo completado_barista ya existe en tabla pedido_detalle';
    END IF;

    -- Agregar fecha_completado_cocinero si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'pedido_detalle' AND column_name = 'fecha_completado_cocinero') THEN
        ALTER TABLE pedido_detalle ADD COLUMN fecha_completado_cocinero TIMESTAMP;
        RAISE NOTICE 'Campo fecha_completado_cocinero agregado a tabla pedido_detalle';
    ELSE
        RAISE NOTICE 'Campo fecha_completado_cocinero ya existe en tabla pedido_detalle';
    END IF;

    -- Agregar fecha_completado_barista si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'pedido_detalle' AND column_name = 'fecha_completado_barista') THEN
        ALTER TABLE pedido_detalle ADD COLUMN fecha_completado_barista TIMESTAMP;
        RAISE NOTICE 'Campo fecha_completado_barista agregado a tabla pedido_detalle';
    ELSE
        RAISE NOTICE 'Campo fecha_completado_barista ya existe en tabla pedido_detalle';
    END IF;
END $$;

-- =====================================================
-- 5. AGREGAR CAMPO TIEMPO_PROCESAMIENTO A PEDIDOS
-- =====================================================

DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'pedidos' AND column_name = 'tiempo_procesamiento') THEN
        ALTER TABLE pedidos ADD COLUMN tiempo_procesamiento INTERVAL;
        RAISE NOTICE 'Campo tiempo_procesamiento agregado a tabla pedidos';
    ELSE
        RAISE NOTICE 'Campo tiempo_procesamiento ya existe en tabla pedidos';
    END IF;
END $$;

-- =====================================================
-- 6. CREAR ÍNDICES PARA OPTIMIZACIÓN (SI NO EXISTEN)
-- =====================================================

-- Índices para personas
CREATE INDEX IF NOT EXISTS idx_personas_email ON personas(email);
CREATE INDEX IF NOT EXISTS idx_personas_cedula ON personas(cedula);
CREATE INDEX IF NOT EXISTS idx_personas_soft_delete ON personas(isDelete, deleted_at);

-- Índices para usuario
CREATE INDEX IF NOT EXISTS idx_usuario_rol ON usuario(rol);

-- Índices para menu
CREATE INDEX IF NOT EXISTS idx_menu_categoria ON menu(categoria);
CREATE INDEX IF NOT EXISTS idx_menu_tipo ON menu(tipo);
CREATE INDEX IF NOT EXISTS idx_menu_disponibilidad ON menu(disponibilidad);
CREATE INDEX IF NOT EXISTS idx_menu_soft_delete ON menu(isDelete, deleted_at);

-- Índices para pedidos
CREATE INDEX IF NOT EXISTS idx_pedidos_persona ON pedidos(idpersona);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado ON pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha ON pedidos(fecha);

-- Índices para pedido_detalle
CREATE INDEX IF NOT EXISTS idx_pedido_detalle_pedido ON pedido_detalle(idpedido);
CREATE INDEX IF NOT EXISTS idx_pedido_detalle_plato ON pedido_detalle(idplato);
CREATE INDEX IF NOT EXISTS idx_pedido_detalle_completado ON pedido_detalle(completado_cocinero, completado_barista);

-- =====================================================
-- 7. ACTUALIZAR DATOS EXISTENTES
-- =====================================================

-- Asegurar que todos los registros existentes tengan isDelete = FALSE
UPDATE personas SET isDelete = FALSE WHERE isDelete IS NULL;
UPDATE menu SET isDelete = FALSE WHERE isDelete IS NULL;

-- Asegurar que todos los pedido_detalle existentes tengan valores por defecto
UPDATE pedido_detalle SET completado_cocinero = FALSE WHERE completado_cocinero IS NULL;
UPDATE pedido_detalle SET completado_barista = FALSE WHERE completado_barista IS NULL;

-- NOTA: Si quieres eliminar la duplicidad de precio_unitario, ejecuta por separado:
-- sevidor/migrations/remove_price_duplication.sql

-- =====================================================
-- 8. VERIFICACIÓN FINAL
-- =====================================================

-- Mostrar resumen de la migración
DO $$ 
DECLARE
    personas_count INTEGER;
    menu_count INTEGER;
    pedidos_count INTEGER;
    detalle_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO personas_count FROM personas;
    SELECT COUNT(*) INTO menu_count FROM menu;
    SELECT COUNT(*) INTO pedidos_count FROM pedidos;
    SELECT COUNT(*) INTO detalle_count FROM pedido_detalle;
    
    RAISE NOTICE '=== RESUMEN DE MIGRACIÓN ===';
    RAISE NOTICE 'Registros en personas: %', personas_count;
    RAISE NOTICE 'Registros en menu: %', menu_count;
    RAISE NOTICE 'Registros en pedidos: %', pedidos_count;
    RAISE NOTICE 'Registros en pedido_detalle: %', detalle_count;
    RAISE NOTICE '=== MIGRACIÓN COMPLETADA ===';
END $$;

-- Verificar estructura de tablas
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name IN ('personas', 'usuario', 'menu', 'pedidos', 'pedido_detalle')
ORDER BY table_name, ordinal_position;

COMMIT;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
DESPUÉS DE EJECUTAR ESTA MIGRACIÓN:

1. Verificar que el backend esté actualizado con los nuevos campos
2. Asegurar que las consultas incluyan WHERE isDelete = FALSE
3. Probar las funcionalidades de soft delete
4. Verificar que los índices mejoren el rendimiento
5. Actualizar la aplicación Flutter si es necesario

ROLLBACK (solo si es necesario):
Si necesitas revertir los cambios, puedes ejecutar:

-- CUIDADO: Esto eliminará los nuevos campos y datos
ALTER TABLE personas DROP COLUMN IF EXISTS isDelete;
ALTER TABLE personas DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE personas DROP COLUMN IF EXISTS deleted_by;

ALTER TABLE menu DROP COLUMN IF EXISTS isDelete;
ALTER TABLE menu DROP COLUMN IF EXISTS deleted_at;
ALTER TABLE menu DROP COLUMN IF EXISTS deleted_by;
ALTER TABLE menu DROP COLUMN IF EXISTS tipo;

ALTER TABLE pedido_detalle DROP COLUMN IF EXISTS completado_cocinero;
ALTER TABLE pedido_detalle DROP COLUMN IF EXISTS completado_barista;
ALTER TABLE pedido_detalle DROP COLUMN IF EXISTS fecha_completado_cocinero;
ALTER TABLE pedido_detalle DROP COLUMN IF EXISTS fecha_completado_barista;

ALTER TABLE pedidos DROP COLUMN IF EXISTS tiempo_procesamiento;
*/ 