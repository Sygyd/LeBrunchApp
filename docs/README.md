# 🍽️ Le Brunch App - Sistema de Ecommerce de Comida

## 📋 Descripción del Proyecto

**Le Brunch App** es una aplicación completa de ecommerce especializada en comida tipo brunch, desarrollada como proyecto de tesis. La aplicación permite a los usuarios navegar por el menú, realizar pedidos, y gestionar todo el proceso desde la cocina hasta la entrega.

### 🎯 Características Principales

- **🛒 Sistema de Pedidos Completo**: Carrito de compras, gestión de pedidos en tiempo real
- **👥 Gestión Multi-Rol**: Admin, Cliente, Cocinero, Barista
- **🤖 Asistente Virtual**: "Brunchy" - IA conversacional para tomar pedidos
- **📊 Panel Administrativo**: Reportes, estadísticas, gestión de usuarios y menú
- **🗑️ Sistema Soft Delete**: Eliminación lógica con posibilidad de restauración
- **🔐 Recuperación de Contraseña**: Sistema completo de restablecimiento
- **📱 Interfaz Responsiva**: Diseño moderno y adaptativo

---

## 🏗️ Arquitectura del Sistema

### **Frontend** 
- **Framework**: Flutter (Dart)
- **Estado**: Provider + SharedPreferences
- **UI/UX**: Material Design 3
- **Navegación**: Named Routes

### **Backend**
- **Runtime**: Node.js + Express
- **Base de Datos**: PostgreSQL
- **Autenticación**: JWT + bcrypt
- **IA**: Google Gemini API (con rotación de claves)
- **Archivos**: Multer para imágenes

### **Integración**
- **API REST**: Comunicación HTTP/JSON
- **WebSocket**: Actualizaciones en tiempo real (futuro)
- **Almacenamiento**: Local (SharedPreferences) + Servidor

---

## 📊 Base de Datos

### Estructura Principal

```sql
-- Usuarios y Autenticación
personas (idpersonas, nombre, apellido, cedula, email, isDelete, deleted_at, deleted_by)
usuario (idpersona, contrasena, rol)

-- Menú y Productos
menu (idplato, nombre, categoria, precio, disponibilidad, ingredientes, imagen_url, tipo, isDelete, deleted_at, deleted_by)

-- Pedidos y Transacciones
pedidos (idpedido, idpersona, estado, fecha, tiempo_procesamiento)
pedido_detalle (idpedido_detalle, idplato, idpedido, cantidad, precio_unitario, notas, completado_cocinero, completado_barista, fecha_completado_cocinero, fecha_completado_barista)
```

### Roles del Sistema
- **0** - Administrador: Acceso completo al sistema
- **1** - Cliente: Realizar pedidos, ver menú
- **2** - Cocinero: Gestionar preparación de comidas
- **3** - Barista: Gestionar preparación de bebidas

### Estados de Pedido
- `pendiente` → `preparando` → `listo` → `completado`
- `cancelado` (en cualquier momento)

---

## 🚀 Funcionalidades por Rol

### 👑 **Administrador**
- ✅ Dashboard con métricas en tiempo real
- ✅ Gestión completa de usuarios (CRUD + Soft Delete)
- ✅ Gestión completa de menú (CRUD + Soft Delete)
- ✅ Reportes y estadísticas avanzadas
- ✅ Historial completo de pedidos
- ✅ Restauración de elementos eliminados
- ✅ Platos más populares por categoría

### 👤 **Cliente**
- ✅ Navegación por menú con filtros
- ✅ Carrito de compras persistente
- ✅ Chat con asistente virtual "Brunchy"
- ✅ Historial de pedidos personales
- ✅ Sistema de recuperación de contraseña

### 👨‍🍳 **Cocinero**
- ✅ Vista de pedidos pendientes (solo comidas)
- ✅ Marcar items como completados
- ✅ Historial de pedidos procesados
- ✅ Perfil personal

### ☕ **Barista**
- ✅ Vista de pedidos pendientes (solo bebidas)
- ✅ Marcar items como completados
- ✅ Historial de pedidos procesados
- ✅ Perfil personal

---

## 🤖 Asistente Virtual "Brunchy"

### Características
- **IA Conversacional**: Powered by Google Gemini
- **Especialización**: Solo temas relacionados con Le Brunch
- **Funcionalidades**:
  - Tomar pedidos por chat
  - Añadir items al carrito automáticamente
  - Responder preguntas sobre el menú
  - Información del restaurante

### Restricciones de Seguridad
- ❌ No responde preguntas fuera del contexto del restaurante
- ❌ No añade items que no estén en el menú
- ✅ Solo información verificada del menú actual
- ✅ Validación de nombres exactos de platos

---

## 🔐 Sistema de Seguridad

### Autenticación
- **JWT Tokens**: Expiración de 1 hora
- **Contraseñas**: Hash bcrypt (factor 10)
- **Recuperación**: Verificación por email + cédula

### Soft Delete
- **Tablas Implementadas**: `personas`, `menu`
- **Beneficios**: 
  - Auditoría completa
  - Posibilidad de restauración
  - Integridad referencial mantenida

### Validaciones
- **Frontend**: Validación en tiempo real
- **Backend**: Validación de datos y permisos
- **Base de Datos**: Constraints y claves foráneas

---

## 📱 Interfaz de Usuario

### Diseño
- **Material Design 3**: Componentes modernos
- **Tema Personalizado**: Colores de marca Le Brunch
- **Navegación**: Bottom Navigation + Drawer
- **Modales**: Para autenticación y formularios

### Experiencia de Usuario
- **Onboarding**: Pantalla de bienvenida intuitiva
- **Feedback Visual**: Loading states, confirmaciones
- **Accesibilidad**: Textos legibles, contrastes adecuados
- **Responsive**: Adaptable a diferentes tamaños de pantalla

---

## 📊 Reportes y Estadísticas

### Métricas Disponibles
- **Ventas**: Por día, semana, mes, año
- **Pedidos**: Conteo por estado y período
- **Productos**: Más vendidos por categoría
- **Usuarios**: Distribución por rol
- **Tiempo**: Promedio de procesamiento

### Visualizaciones
- **Gráficos**: Ventas por hora del día
- **Tablas**: Historial detallado de pedidos
- **Cards**: Métricas principales en dashboard
- **Filtros**: Por fecha, estado, categoría

---

## 🛠️ Instalación y Configuración

### Prerrequisitos
```bash
# Backend
Node.js >= 16.x
PostgreSQL >= 13.x
npm o yarn

# Frontend  
Flutter >= 3.x
Dart >= 3.x
Android Studio / VS Code
```

### Configuración del Backend
```bash
cd sevidor/
npm install
cp .env.example .env
# Configurar variables de entorno
npm start
```

### Configuración del Frontend
```bash
flutter pub get
flutter run
```

### Variables de Entorno
```env
# Base de datos
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=tu_password

# API Keys
GEMINI_API_KEY_1=tu_clave_gemini_1
GEMINI_API_KEY_2=tu_clave_gemini_2
GEMINI_API_KEY_3=tu_clave_gemini_3

# JWT
JWT_SECRET=tu_secreto_jwt
```

---

## 📁 Estructura del Proyecto

```
le_brunch_app/
├── lib/                          # Código Flutter
│   ├── Api_services/            # Servicios de API
│   ├── models/                  # Modelos de datos
│   ├── UI_Screens/             # Pantallas de la app
│   ├── services/               # Servicios locales
│   └── theme/                  # Configuración de tema
├── sevidor/                     # Backend Node.js
│   ├── migrations/             # Scripts de base de datos
│   ├── uploads/               # Archivos subidos
│   └── *.js                   # Archivos del servidor
├── docs/                       # Documentación
│   ├── DATABASE_STRUCTURE.md  # Estructura de BD
│   └── README.md              # Este archivo
└── assets/                     # Recursos estáticos
```

---

## 🔄 Flujo de Trabajo

### Proceso de Pedido
1. **Cliente**: Navega menú → Añade al carrito → Confirma pedido
2. **Sistema**: Crea pedido → Notifica cocina/barra
3. **Cocinero/Barista**: Ve pedido → Prepara → Marca completado
4. **Sistema**: Actualiza estado → Notifica cliente
5. **Cliente**: Recibe notificación → Recoge pedido

### Gestión Administrativa
1. **Admin**: Accede dashboard → Ve métricas
2. **Gestión**: CRUD usuarios/menú → Soft delete
3. **Reportes**: Filtra datos → Exporta información
4. **Restauración**: Ve eliminados → Restaura si necesario

---

## 🚧 Estado del Desarrollo

### ✅ Completado
- [x] Sistema de autenticación completo
- [x] CRUD de usuarios con soft delete
- [x] CRUD de menú con soft delete
- [x] Sistema de pedidos funcional
- [x] Asistente virtual "Brunchy"
- [x] Recuperación de contraseña
- [x] Dashboard administrativo
- [x] Reportes y estadísticas
- [x] Interfaz multi-rol

### 🔄 En Desarrollo
- [ ] Notificaciones push
- [ ] Sistema de pagos
- [ ] Geolocalización
- [ ] Modo offline

### 📋 Próximas Funcionalidades
- [ ] WebSocket para tiempo real
- [ ] Sistema de calificaciones
- [ ] Programa de fidelidad
- [ ] Integración con delivery

---

## 👥 Equipo de Desarrollo

**Desarrollador Principal**: [Tu Nombre]
**Proyecto**: Tesis de Grado
**Institución**: [Tu Universidad]
**Año**: 2025

---

## 📄 Licencia

Este proyecto es desarrollado como parte de una tesis de grado y está sujeto a las políticas académicas correspondientes.

---

## 📞 Contacto

Para consultas sobre el proyecto:
- **Email**: [tu-email@universidad.edu]
- **GitHub**: [tu-usuario-github]

---

*Última actualización: Enero 2025*
*Versión: 2.0 (con Sistema Soft Delete y Recuperación de Contraseña)* 