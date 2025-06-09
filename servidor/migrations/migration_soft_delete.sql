-- Migration para implementar Soft Delete en las tablas menu y personas
-- Fecha: 2024
-- Descripción: Agregar campos para eliminación lógica en lugar de física

-- =====================================================
-- TABLA MENU - Agregar campos de soft delete
-- =====================================================

-- Agregar campo isDelete (boolean, por defecto false)
ALTER TABLE menu 
ADD COLUMN IF NOT EXISTS isDelete BOOLEAN DEFAULT FALSE;

-- Agregar campo deleted_at (timestamp, nullable)
ALTER TABLE menu 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL;

-- Agregar campo deleted_by (referencia al usuario que eliminó, nullable)
ALTER TABLE menu 
ADD COLUMN IF NOT EXISTS deleted_by INTEGER DEFAULT NULL;

-- Agregar foreign key constraint para deleted_by
ALTER TABLE menu 
ADD CONSTRAINT fk_menu_deleted_by 
FOREIGN KEY (deleted_by) REFERENCES personas(idpersonas) ON DELETE SET NULL;

-- =====================================================
-- TABLA PERSONAS - Agregar campos de soft delete
-- =====================================================

-- Agregar campo isDelete (boolean, por defecto false)
ALTER TABLE personas 
ADD COLUMN IF NOT EXISTS isDelete BOOLEAN DEFAULT FALSE;

-- Agregar campo deleted_at (timestamp, nullable)
ALTER TABLE personas 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NULL;

-- Agregar campo deleted_by (referencia al usuario que eliminó, nullable)
ALTER TABLE personas 
ADD COLUMN IF NOT EXISTS deleted_by INTEGER DEFAULT NULL;

-- Agregar foreign key constraint para deleted_by
ALTER TABLE personas 
ADD CONSTRAINT fk_personas_deleted_by 
FOREIGN KEY (deleted_by) REFERENCES personas(idpersonas) ON DELETE SET NULL;

-- =====================================================
-- ÍNDICES PARA OPTIMIZAR CONSULTAS
-- =====================================================

-- Índice para consultas de elementos no eliminados en menu
CREATE INDEX IF NOT EXISTS idx_menu_not_deleted 
ON menu (isDelete) WHERE isDelete = FALSE;

-- Índice para consultas de elementos no eliminados en personas
CREATE INDEX IF NOT EXISTS idx_personas_not_deleted 
ON personas (isDelete) WHERE isDelete = FALSE;

-- Índice compuesto para menu con disponibilidad y no eliminado
CREATE INDEX IF NOT EXISTS idx_menu_available_not_deleted 
ON menu (disponibilidad, isDelete) WHERE isDelete = FALSE;

-- =====================================================
-- COMENTARIOS EN LAS COLUMNAS
-- =====================================================

COMMENT ON COLUMN menu.isDelete IS 'Indica si el plato ha sido eliminado lógicamente (soft delete)';
COMMENT ON COLUMN menu.deleted_at IS 'Fecha y hora cuando el plato fue eliminado lógicamente';
COMMENT ON COLUMN menu.deleted_by IS 'ID del usuario que eliminó el plato lógicamente';

COMMENT ON COLUMN personas.isDelete IS 'Indica si la persona ha sido eliminada lógicamente (soft delete)';
COMMENT ON COLUMN personas.deleted_at IS 'Fecha y hora cuando la persona fue eliminada lógicamente';
COMMENT ON COLUMN personas.deleted_by IS 'ID del usuario que eliminó la persona lógicamente';

-- =====================================================
-- VERIFICACIÓN DE LA MIGRACIÓN
-- =====================================================

-- Verificar que las columnas se agregaron correctamente
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name IN ('menu', 'personas') 
    AND column_name IN ('isdelete', 'deleted_at', 'deleted_by')
ORDER BY table_name, column_name;

-- Mostrar estadísticas de registros
SELECT 
    'menu' as tabla,
    COUNT(*) as total_registros,
    COUNT(*) FILTER (WHERE isDelete = FALSE) as registros_activos,
    COUNT(*) FILTER (WHERE isDelete = TRUE) as registros_eliminados
FROM menu
UNION ALL
SELECT 
    'personas' as tabla,
    COUNT(*) as total_registros,
    COUNT(*) FILTER (WHERE isDelete = FALSE) as registros_activos,
    COUNT(*) FILTER (WHERE isDelete = TRUE) as registros_eliminados
FROM personas; 