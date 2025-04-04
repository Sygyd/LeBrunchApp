# Le Brunch App

Aplicación móvil para gestión de restaurante Le Brunch, desarrollada con Flutter.

## Estado Actual del Proyecto

El proyecto se encuentra actualmente en proceso de migración desde la estructura original hacia una arquitectura más mantenible basada en Clean Architecture. El objetivo es mejorar la organización del código, facilitar el testing y permitir un desarrollo más escalable.

### Arquitectura en Migración

La aplicación está siendo migrada hacia la siguiente estructura:

```
lib/
├── src/
│   ├── app.dart                <- Configuración inicial de la app
│   ├── core/                   <- Funcionalidad central compartida
│   │   ├── api/                <- Cliente API base y utilidades
│   │   ├── models/             <- Modelos de datos centrales
│   │   └── theme/              <- Definición de tema
│   ├── features/               <- Características/Módulos organizados
│   │   ├── auth/               <- Módulo de autenticación
│   │   ├── menu/               <- Módulo de gestión de menú
│   │   ├── orders/             <- Módulo de pedidos
│   │   └── ...                 <- Otros módulos
│   └── shared/                 <- Componentes compartidos
│       ├── utils/              <- Utilidades comunes
│       ├── widgets/            <- Widgets reutilizables
│       └── routes.dart         <- Definición de rutas
└── main.dart                   <- Punto de entrada simplificado
```

### Progreso de la Migración

- **Completado**:
  - Nueva estructura de directorios
  - Sistema de tema centralizado
  - Componentes UI reutilizables (botones, campos de texto)
  - Cliente API base
  - Sistema de navegación con rutas nombradas

- **En progreso**:
  - Migración del módulo de autenticación
  - Implementación de la gestión de estado

Para ver el estado detallado de la migración, consulta el archivo `MIGRATION_GUIDE.md`.

## Componentes Técnicos

- **Frontend**: Flutter (Dart)
- **Backend**: Node.js con Express
- **Base de datos**: PostgreSQL
- **Autenticación**: JWT
- **Almacenamiento**: SharedPreferences, Flutter Secure Storage

## Funcionalidades Principales

- Autenticación de usuarios con roles diferenciados (cliente, administrador, cocinero, barista)
- Visualización y gestión del menú
- Realización de pedidos
- Panel de administración
- Notificaciones a cocina y bar

## Configuración del Proyecto

### Requisitos Previos

- Flutter SDK 3.7.0 o superior
- Dart SDK 3.0.0 o superior
- Android Studio / VS Code
- Emulador o dispositivo físico

### Configuración de Desarrollo

1. Clona el repositorio:

   ```
   git clone [URL_DEL_REPOSITORIO]
   ```

2. Instala las dependencias:

   ```
   flutter pub get
   ```

3. Ejecuta la aplicación:

   ```
   flutter run
   ```

## Notas Importantes

- Durante la migración, algunos archivos antiguos coexistirán con la nueva estructura hasta completar el proceso.
- Se recomienda seguir las pautas establecidas en `MIGRATION_GUIDE.md` al contribuir al proyecto durante esta fase.

## Contacto

Para más información sobre el proyecto, contactar a los desarrolladores:
