# Le Brunch App

Este proyecto consiste en una aplicación de comercio electrónico para un restaurante de tipo Brunch, desarrollada como parte de un proyecto de tesis.

## Estructura del Proyecto

El proyecto se divide en dos partes principales:

1. **Aplicación Cliente (Flutter)**: Una aplicación móvil y web desarrollada con Flutter.
2. **Servidor Backend (Node.js)**: Una API RESTful desarrollada con Node.js, Express y PostgreSQL.

## Requisitos Previos

Para ejecutar este proyecto necesitas:

- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://git-scm.com/downloads)

## Configuración con Docker

El proyecto está configurado para ejecutarse completamente en contenedores Docker, lo que facilita la instalación y ejecución en cualquier entorno.

### Paso 1: Clonar el repositorio

```bash
git clone <URL_DEL_REPOSITORIO>
cd le_brunch_app
```

### Paso 2: Configurar variables de entorno

Crea un archivo `.env` en la raíz del proyecto siguiendo el ejemplo de `.env.example`:

```bash
cp .env.example .env
```

Edita el archivo `.env` con tus configuraciones específicas, especialmente la API key de Gemini si es necesaria.

### Paso 3: Iniciar los contenedores

```bash
docker-compose up -d
```

Este comando iniciará tres servicios:

- **db**: Base de datos PostgreSQL
- **server**: Servidor Node.js
- **app**: Aplicación Flutter compilada para web

### Paso 4: Acceder a la aplicación

- **Aplicación Web**: http://localhost:8080
- **API Backend**: http://localhost:3000

## Desarrollo Local

Para desarrollo local, puedes elegir entre:

### Opción 1: Desarrollo con Docker

```bash
# Iniciar solo la base de datos y el servidor
docker-compose up db server -d

# Ejecutar la aplicación Flutter en modo desarrollo
flutter run -d chrome
```

### Opción 2: Desarrollo completamente local

```bash
# Instalar dependencias del servidor
cd sevidor
npm install
npm run dev

# Instalar dependencias de Flutter y ejecutar
cd ..
flutter pub get
flutter run
```

## Estructura de la Base de Datos

La aplicación utiliza las siguientes tablas:

- **personas**: Información personal de usuarios
- **usuario**: Datos de autenticación y roles
- **menu**: Platos y bebidas disponibles
- **pedidos**: Pedidos realizados por los clientes
- **pedido_detalle**: Detalles de cada pedido

## Roles de Usuario

- **Administrador (0)**: Gestión completa del sistema
- **Cliente (1)**: Realiza pedidos
- **Cocinero (2)**: Gestiona la preparación de platos
- **Barista (3)**: Gestiona la preparación de bebidas

## Licencia

Este proyecto es parte de un trabajo académico y está sujeto a los términos establecidos por la institución educativa correspondiente. 