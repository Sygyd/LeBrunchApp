# Sincronización de Base de Datos - Le Brunch App

Este documento explica cómo mantener sincronizada tu base de datos local con el contenedor Docker de PostgreSQL en Le Brunch App.

## Métodos de sincronización

Hay dos métodos principales para sincronizar tus datos:

### 1. Inicialización automática (al crear el contenedor por primera vez)

Los archivos SQL en la carpeta `db_init/` se ejecutan automáticamente cuando el contenedor de PostgreSQL se inicia por primera vez. 

- `init.sql` - Contiene la estructura de las tablas (se ejecuta primero)
- `backup.sql` - Contiene un respaldo completo de la base de datos (opcional)

### 2. Sincronización manual (contenedor ya creado)

Para sincronizar manualmente la base de datos local con el contenedor, puedes usar:

#### En Windows:
```
db_sync.bat
```

#### En Linux/Mac:
```
chmod +x db_sync.sh  # Primera vez para hacerlo ejecutable
./db_sync.sh
```

Estos scripts te guiarán en el proceso para:
1. Exportar la base de datos local a un archivo
2. Copiar ese archivo al contenedor Docker
3. Importar los datos al contenedor
4. Reiniciar el servidor para que los cambios surtan efecto

## Sincronización durante el inicio

También puedes sincronizar tu base de datos al iniciar el entorno Docker. Los scripts `start-docker.bat` y `start-docker.sh` te preguntarán si deseas sincronizar la base de datos después de iniciar los contenedores.

## ¿Cuándo usar cada método?

- **Inicialización automática**: Ideal cuando quieres empezar desde cero o reconstruir completamente los contenedores.
- **Sincronización manual**: Perfecto para actualizar datos sin reiniciar completamente el entorno.

## Requisitos

Para que la sincronización funcione correctamente, necesitas:

1. PostgreSQL instalado localmente (para tener disponible `pg_dump`)
2. Docker y Docker Compose funcionando
3. Los contenedores de Le Brunch App en ejecución

## Problemas comunes

- **Error "pg_dump no está disponible"**: Asegúrate de tener PostgreSQL instalado y en tu PATH.
- **Error al conectar a la base de datos local**: Verifica las credenciales y que el servidor PostgreSQL esté en ejecución.
- **Error al copiar al contenedor**: Verifica que el contenedor `lebrunch_postgres` esté en ejecución. 