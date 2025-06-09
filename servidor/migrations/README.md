# 🗄️ Migraciones de Base de Datos

Esta carpeta contiene todas las migraciones SQL para la base de datos PostgreSQL del proyecto Le Brunch.

## 📋 Migraciones Disponibles

### 🗑️ Soft Delete System
- **`migration_soft_delete.sql`**: Implementación del sistema de eliminación lógica
  - Agrega campos `isDelete`, `deleted_at`, `deleted_by` a tablas `menu` y `personas`
  - Crea índices optimizados para consultas
  - Establece foreign keys para integridad referencial
  - Incluye comentarios en columnas para documentación

## 🚀 Cómo Aplicar Migraciones

### Opción 1: Desde psql
```bash
psql -U postgres -d postgres -f migration_soft_delete.sql
```

### Opción 2: Desde pgAdmin
1. Abrir pgAdmin
2. Conectar a la base de datos `postgres`
3. Abrir Query Tool
4. Cargar y ejecutar el archivo SQL

### Opción 3: Desde línea de comandos
```bash
# Conectar a PostgreSQL y ejecutar
cat migration_soft_delete.sql | psql -U postgres -d postgres
```

## ⚠️ Importante

- **Siempre hacer backup** de la base de datos antes de aplicar migraciones
- Las migraciones están diseñadas para ser **idempotentes** (se pueden ejecutar múltiples veces)
- Verificar que la migración se aplicó correctamente revisando las tablas

## 📊 Verificación Post-Migración

Después de aplicar una migración, verificar:
```sql
-- Verificar que las columnas se agregaron
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('menu', 'personas') 
AND column_name IN ('isdelete', 'deleted_at', 'deleted_by');

-- Verificar estadísticas
SELECT 'menu' as tabla, COUNT(*) as total FROM menu
UNION ALL
SELECT 'personas' as tabla, COUNT(*) as total FROM personas;
``` 