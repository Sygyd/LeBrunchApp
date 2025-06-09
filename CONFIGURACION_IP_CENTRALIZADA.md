# Configuración IP Centralizada - Le Brunch App

## 🎯 Problema Solucionado

Anteriormente, la aplicación tenía IPs hardcodeadas en múltiples archivos:
- `lib/Api_services/cart_service.dart`
- `lib/Api_services/gemini_api_client.dart`
- `lib/Api_services/mcp_service.dart`
- `lib/UI_Screens/Auth_Screens/auth_modals.dart`
- Y 20+ archivos más...

Esto creaba un problema: **cada vez que movías el proyecto a otra computadora/red, tenías que cambiar la IP en docenas de lugares**.

## ✅ Solución Implementada

### 1. Servicio Centralizado: `NetworkConfigService`

Se creó un servicio singleton (`lib/Api_services/network_config_service.dart`) que:

- **🔍 Auto-detecta** el servidor en la red local
- **💾 Guarda** la configuración en SharedPreferences
- **⚙️ Fallback** a valores del .env y por defecto
- **🔄 Actualiza** dinámicamente la configuración

### 2. Detección Inteligente

El servicio busca el servidor en este orden:

1. **Configuración guardada** (de sesiones anteriores)
2. **Archivo .env** (si existe)
3. **Auto-detección en red local** (escanea IPs comunes)
4. **Configuración por defecto** (192.168.1.121:3000)

### 3. Configuración del Servidor

En tu servidor Node.js (`servidor/servidor.js`), solo necesitas cambiar una línea:

```javascript
// Cambiar SOLO esta línea con tu IP actual
const PORT = process.env.PORT || 3000;
const HOST = 'TU_IP_AQUI'; // Ej: '192.168.1.100'

app.listen(PORT, HOST, () => {
  console.log(`🚀 Servidor corriendo en http://${HOST}:${PORT}`);
});
```

## 🚀 Cómo Usar

### Para Desarrolladores

1. **Cambiar IP en servidor**: Solo modifica la IP en `servidor.js`
2. **Auto-detección**: La app Flutter detectará automáticamente la nueva IP
3. **Configuración manual**: Si falla, usa el modal de configuración en la app

### Para Usuarios Finales

1. La app intentará conectarse automáticamente
2. Si no encuentra el servidor, mostrará opciones de configuración
3. Una vez configurada, recordará la IP para futuras sesiones

## 🔧 Archivos Actualizados

### Nuevos Archivos
- `lib/Api_services/network_config_service.dart` - Servicio principal
- `CONFIGURACION_IP_CENTRALIZADA.md` - Esta documentación

### Archivos Modificados
- `lib/main.dart` - Inicializa NetworkConfigService
- `lib/Api_services/gemini_api_client.dart` - Usa NetworkConfigService
- `lib/Api_services/mcp_service.dart` - Usa NetworkConfigService
- (Próximamente: todos los demás servicios)

## 📝 Implementación por Fases

### ✅ Fase 1: Infraestructura
- [x] Crear NetworkConfigService
- [x] Integrar en main.dart
- [x] Actualizar servicios principales

### 🔄 Fase 2: Migración de Servicios
- [ ] CartService
- [ ] AuthModals
- [ ] UserService
- [ ] MenuServices
- [ ] OrderServices

### 🎯 Fase 3: UI y UX
- [ ] Modal de configuración IP
- [ ] Indicador de estado de conexión
- [ ] Botón de re-detección

## 🛠️ API del NetworkConfigService

```dart
final networkConfig = NetworkConfigService();

// Inicializar (auto-detecta)
await networkConfig.initialize();

// Obtener URL base
String baseUrl = networkConfig.baseUrl; // "http://192.168.1.100:3000"

// Obtener URL de endpoint
String menuUrl = networkConfig.getEndpointUrl('/menu');

// Actualizar manualmente
bool success = await networkConfig.updateServerConfig('192.168.1.200', '3000');

// Verificar estado
Map<String, dynamic> status = await networkConfig.checkServerStatus();

// Re-detectar servidor
bool found = await networkConfig.refreshConfiguration();
```

## 🎉 Beneficios

1. **🔄 Cambio único**: Solo cambias IP en `servidor.js`
2. **🤖 Auto-detección**: La app encuentra el servidor automáticamente
3. **💾 Persistencia**: Recuerda la configuración entre sesiones
4. **🛠️ Debugging**: Información detallada de diagnóstico
5. **🔧 Flexibilidad**: Configuración manual si es necesaria

## 🧪 Pruebas

Para probar el sistema:

1. Cambia la IP en `servidor.js`
2. Reinicia el servidor Node.js
3. Abre la app Flutter
4. Verifica en logs que detecte la nueva IP automáticamente

```
🌐 NetworkConfigService: Iniciando configuración de red...
🔍 Buscando servidor en la red local...
🔍 Buscando en rango: 192.168.1
🎯 Servidor encontrado en: 192.168.1.200:3000
✅ Servidor auto-detectado: http://192.168.1.200:3000
💾 Configuración de red guardada
🌐 Red configurada: http://192.168.1.200:3000
```

## 📋 Próximos Pasos

1. **Migrar todos los servicios** para usar NetworkConfigService
2. **Crear UI de configuración** para usuarios avanzados
3. **Agregar notificaciones** cuando cambie la IP del servidor
4. **Implementar heartbeat** para detectar cambios automáticamente

## 💡 Notas Técnicas

- El servicio es **singleton** - una sola instancia en toda la app
- **Thread-safe** - puede usarse desde cualquier parte sin problemas
- **Fallback inteligente** - siempre tiene una IP funcional
- **Caché en memoria** - evita múltiples consultas innecesarias 