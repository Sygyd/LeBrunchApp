-- =====================================================
-- MIGRACIÓN: ELIMINACIÓN DE DUPLICIDAD DE PRECIOS
-- =====================================================
-- Fecha: 2024-12-19
-- Descripción: Elimina el campo precio_unitario de pedido_detalle
--              para usar únicamente menu.precio como fuente de verdad
-- Autor: Sistema de Migración Automática
-- =====================================================

-- Configurar zona horaria
SET timezone = 'America/Caracas';

-- Mostrar información inicial
\echo '🔄 INICIANDO MIGRACIÓN: Eliminación de duplicidad de precios'
\echo '📅 Fecha y hora:' 
SELECT NOW() as fecha_migracion;

-- =====================================================
-- PASO 1: ANÁLISIS PRE-MIGRACIÓN
-- =====================================================
\echo ''
\echo '📊 PASO 1: Análisis de datos existentes'

-- Verificar si existen diferencias entre precios
\echo '🔍 Verificando diferencias entre precio_unitario y menu.precio...'
SELECT 
    COUNT(*) as total_registros,
    COUNT(CASE WHEN pd.precio_unitario != m.precio THEN 1 END) as diferencias_precio,
    ROUND(AVG(pd.precio_unitario), 2) as precio_promedio_pedidos,
    ROUND(AVG(m.precio), 2) as precio_promedio_menu
FROM pedido_detalle pd
INNER JOIN menu m ON pd.idplato = m.idplato;

-- Mostrar ejemplos de diferencias si existen
\echo '📋 Ejemplos de diferencias (si existen):'
SELECT 
    pd.idpedido,
    m.nombre as plato,
    pd.precio_unitario as precio_en_pedido,
    m.precio as precio_en_menu,
    (pd.precio_unitario - m.precio) as diferencia
FROM pedido_detalle pd
INNER JOIN menu m ON pd.idplato = m.idplato
WHERE pd.precio_unitario != m.precio
LIMIT 5;

-- =====================================================
-- PASO 2: CREAR BACKUP AUTOMÁTICO
-- =====================================================
\echo ''
\echo '💾 PASO 2: Creando backup de seguridad'

-- Crear tabla de backup con timestamp
DO $$
DECLARE
    backup_table_name TEXT;
BEGIN
    backup_table_name := 'pedido_detalle_backup_' || to_char(NOW(), 'YYYY_MM_DD_HH24_MI_SS');
    
    EXECUTE format('CREATE TABLE %I AS SELECT * FROM pedido_detalle', backup_table_name);
    
    RAISE NOTICE '✅ Backup creado: %', backup_table_name;
    RAISE NOTICE '📊 Registros respaldados: %', (SELECT COUNT(*) FROM pedido_detalle);
END $$;

-- =====================================================
-- PASO 3: CREAR VISTA DE COMPATIBILIDAD TEMPORAL
-- =====================================================
\echo ''
\echo '🔗 PASO 3: Creando vista de compatibilidad temporal'

-- Crear vista que simula la estructura anterior
CREATE OR REPLACE VIEW pedido_detalle_with_price AS
SELECT 
    pd.idpedido,
    pd.idplato,
    pd.cantidad,
    m.precio as precio_unitario,  -- Precio obtenido desde menu
    pd.notas,
    pd.completado_cocinero,
    pd.completado_barista,
    pd.fecha_completado_cocinero,
    pd.fecha_completado_barista
FROM pedido_detalle pd
INNER JOIN menu m ON pd.idplato = m.idplato;

\echo '✅ Vista de compatibilidad creada: pedido_detalle_with_price'

-- =====================================================
-- PASO 4: VERIFICAR ESTRUCTURA ACTUAL
-- =====================================================
\echo ''
\echo '🔍 PASO 4: Verificando estructura actual de pedido_detalle'

-- Verificar si el campo precio_unitario existe
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pedido_detalle' 
        AND column_name = 'precio_unitario'
    ) THEN
        RAISE NOTICE '✅ Campo precio_unitario encontrado - Procediendo con la eliminación';
    ELSE
        RAISE NOTICE '⚠️ Campo precio_unitario no encontrado - La migración ya fue aplicada';
        RAISE EXCEPTION 'La migración ya fue aplicada anteriormente';
    END IF;
END $$;

-- =====================================================
-- PASO 5: ELIMINAR CAMPO PRECIO_UNITARIO
-- =====================================================
\echo ''
\echo '🗑️ PASO 5: Eliminando campo precio_unitario'

-- Eliminar el campo precio_unitario
ALTER TABLE pedido_detalle DROP COLUMN IF EXISTS precio_unitario;

\echo '✅ Campo precio_unitario eliminado exitosamente'

-- =====================================================
-- PASO 6: VERIFICACIONES POST-MIGRACIÓN
-- =====================================================
\echo ''
\echo '✅ PASO 6: Verificaciones post-migración'

-- Verificar que el campo fue eliminado
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pedido_detalle' 
        AND column_name = 'precio_unitario'
    ) THEN
        RAISE NOTICE '✅ Verificación exitosa: Campo precio_unitario eliminado';
    ELSE
        RAISE EXCEPTION '❌ Error: Campo precio_unitario aún existe';
    END IF;
END $$;

-- Verificar que la vista funciona correctamente
\echo '🔍 Verificando funcionamiento de la vista de compatibilidad:'
SELECT COUNT(*) as registros_en_vista FROM pedido_detalle_with_price LIMIT 1;

-- Mostrar estructura final de la tabla
\echo '📋 Estructura final de pedido_detalle:'
\d pedido_detalle

-- =====================================================
-- PASO 7: ESTADÍSTICAS FINALES
-- =====================================================
\echo ''
\echo '📊 PASO 7: Estadísticas finales'

SELECT 
    'pedido_detalle' as tabla,
    COUNT(*) as total_registros,
    'Campo precio_unitario eliminado' as estado
FROM pedido_detalle

UNION ALL

SELECT 
    'pedido_detalle_with_price (vista)' as tabla,
    COUNT(*) as total_registros,
    'Vista de compatibilidad activa' as estado
FROM pedido_detalle_with_price;

-- =====================================================
-- INFORMACIÓN IMPORTANTE PARA EL DESARROLLADOR
-- =====================================================
\echo ''
\echo '📝 INFORMACIÓN IMPORTANTE:'
\echo '1. ✅ Campo precio_unitario eliminado de pedido_detalle'
\echo '2. 💾 Backup automático creado con timestamp'
\echo '3. 🔗 Vista pedido_detalle_with_price disponible para compatibilidad'
\echo '4. 🔄 Actualizar consultas en backend para usar JOIN con menu'
\echo '5. 📱 Actualizar frontend para no enviar precio_unitario'
\echo ''
\echo '🚨 PRÓXIMOS PASOS REQUERIDOS:'
\echo '   - Actualizar todas las consultas SQL en el backend'
\echo '   - Modificar servicios en Flutter'
\echo '   - Probar funcionalidad de creación de pedidos'
\echo '   - Verificar cálculos de totales'
\echo ''
\echo '✅ MIGRACIÓN COMPLETADA EXITOSAMENTE'

-- Mostrar hora de finalización
SELECT NOW() as fecha_finalizacion; 