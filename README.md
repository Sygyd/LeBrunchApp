# Le Brunch App - Proyecto Portátil

Este repositorio contiene la aplicación completa Le Brunch, que incluye:
- Aplicación móvil Flutter
- Servidor backend Node.js
- Base de datos PostgreSQL

## Requisitos Previos

Para ejecutar este proyecto, necesitas tener instalado:

- [Docker](https://www.docker.com/products/docker-desktop/)
- [Docker Compose](https://docs.docker.com/compose/install/) (incluido en Docker Desktop para Windows/Mac)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (para desarrollo de la aplicación móvil)

## Configuración y Ejecución

### 1. Clonar el Repositorio

```bash
git clone <url-del-repositorio>
cd le_brunch_app
```

### 2. Ejecutar el Backend con Docker Compose

```bash
docker-compose up -d
```

Este comando iniciará:
- Servidor Node.js en el puerto 3000
- Base de datos PostgreSQL en el puerto 5432
- Panel de administración PgAdmin en el puerto 5050

### 3. Verificar que los Servicios Estén Funcionando

```bash
docker-compose ps
```

### 4. Acceder al Panel de Administración de PostgreSQL

- URL: http://localhost:5050
- Email: admin@lebrunch.com
- Contraseña: admin

### 5. Configurar la Aplicación Flutter

Asegúrate de que la URL del servidor esté correctamente configurada en la aplicación Flutter:

1. Abre el archivo `lib/Api_services/gemini_service.dart`
2. Verifica que la URL del servidor apunte a tu IP local o `10.0.2.2` para emuladores Android:

```dart
final String baseUrl = 'http://10.0.2.2:3000'; // Para emulador Android
// final String baseUrl = 'http://localhost:3000'; // Para iOS
```

### 6. Ejecutar la Aplicación Flutter

```bash
flutter pub get
flutter run
```

## Estructura del Proyecto

- `/lib`: Código fuente de la aplicación Flutter
- `/sevidor`: Código fuente del servidor Node.js
- `/init-scripts`: Scripts de inicialización para la base de datos
- `docker-compose.yml`: Configuración de Docker para el backend

## Acceso y Credenciales

### Backend y Base de Datos
- URL del servidor: http://localhost:3000
- Usuario PostgreSQL: postgres
- Contraseña PostgreSQL: postgres
- Base de datos: le_brunch

### Aplicación (Usuario Administrador)
- Usuario: admin
- Contraseña: admin

## Notas para Desarrollo

- Los cambios en el código del servidor se aplicarán automáticamente gracias al volumen montado en Docker
- Para reconstruir los contenedores con cambios en la configuración: `docker-compose up -d --build`
- Para ver los logs del servidor: `docker-compose logs -f server`

## Migrar a Otra Computadora

Para migrar este proyecto a otra computadora:

1. Clona el repositorio o copia todos los archivos del proyecto
2. Asegúrate de tener Docker y Docker Compose instalados en el nuevo equipo
3. Ejecuta `docker-compose up -d` en el directorio del proyecto
4. Configura la aplicación Flutter apuntando al servidor en la nueva IP

La base de datos será inicializada automáticamente con los scripts en la carpeta `init-scripts`.

## Depuración

Si encuentras problemas:

1. Verifica que todos los contenedores estén funcionando: `docker-compose ps`
2. Revisa los logs del servidor: `docker-compose logs -f server`
3. Comprueba la conexión a la base de datos accediendo a PgAdmin
4. Asegúrate de que la IP configurada en la app Flutter sea accesible
