# 🌐 Sistema de Auto-Descubrimiento de Red - Le Brunch App

## 📋 Descripción

El sistema de auto-descubrimiento permite que la aplicación Le Brunch encuentre automáticamente el servidor en la red local sin necesidad de configuración manual de IP.

## 🚀 Características Nuevas

### 1. **Auto-Detección Inteligente**
- ✅ Búsqueda paralela en la red local
- ✅ Detección automática del rango de IP del dispositivo
- ✅ Cache inteligente con validación temporal (24 horas)
- ✅ Verificación específica del servidor Le Brunch

### 2. **Endpoint de Descubrimiento Mejorado**
- **Nuevo endpoint**: `/discover` en el servidor
- **Información completa**: Tipo de servidor, versión, capacidades
- **Validación**: Identifica específicamente servidores Le Brunch

### 3. **Herramientas de Diagnóstico**
- **Widget de diagnóstico**: Pantalla completa para debugging
- **Información detallada**: Estado de conexión, configuración, etc.
- **Acciones**: Re-descubrimiento forzado, sincronización

## 🔧 Cómo Funciona

### Proceso de Inicialización

1. **Cache Válido** → Usar configuración guardada (si < 24h)
2. **Variables .env** → Probar configuración desde archivo
3. **Auto-Descubrimiento** → Búsqueda paralela en red local
4. **Fallback** → Usar IP por defecto (192.168.1.121:3000)

### Búsqueda Inteligente

```
🔍 Detectar rango local del dispositivo (ej: 192.168.1.x)
🎯 Priorizar IPs comunes (.1, .100, .101, .121, etc.)
⚡ Búsqueda paralela en chunks de 10 conexiones
🎪 Probar puertos: 3000, 8000, 5000, 4000
✅ Verificar que sea servidor Le Brunch (/discover)
```

### Endpoints del Servidor

#### `/discover` (NUEVO)
```json
{
  "server": {
    "name": "Le Brunch Server",
    "type": "brunch-app-server",
    "version": "1.4.1",
    "ip": "192.168.1.121",
    "capabilities": ["chat", "menu-management", "order-management"]
  },
  "status": {
    "online": true,
    "healthy": true,
    "uptime": 12345
  }
}
```

#### `/status` (Existente)
```json
{
  "status": "ok",
  "message": "Servidor en línea"
}
```

## 📱 Uso en la Aplicación

### Para Administradores

1. **Abrir Chat de Admin**
2. **Clic en ⚙️ Configuración**
3. **Botón "Diagnóstico"** → Abre pantalla completa
4. **Opciones disponibles**:
   - 🔄 **Re-descubrir**: Busca servidor en toda la red
   - 🔄 **Refrescar**: Actualiza configuración actual
   - 📋 **Copiar IPs**: Toca URLs para copiar al portapapeles

### Para Desarrolladores

#### Auto-Detección Programática

```dart
final networkService = NetworkConfigService();
final isConfigured = await networkService.initialize();

if (isConfigured) {
  print('✅ Servidor encontrado: ${networkService.baseUrl}');
} else {
  print('❌ Servidor no encontrado, usando fallback');
}
```

#### Forzar Re-Descubrimiento

```dart
final success = await networkService.forceRediscovery();
if (success) {
  print('✅ Nuevo servidor encontrado');
}
```

#### Validar Servidor Actual

```dart
final isValid = await networkService.validateCurrentServer();
if (!isValid) {
  // Servidor cambió o no responde
  await networkService.forceRediscovery();
}
```

## 🔧 Configuración del Servidor

### Variables de Entorno (.env)

```env
# IP del servidor (auto-detectada si no se especifica)
SERVER_HOST=192.168.1.121

# Puerto del servidor
PORT=3000

# Claves de Gemini API
GEMINI_API_KEY_1=tu_clave_aqui
GEMINI_API_KEY_2=tu_clave_aqui_2
GEMINI_API_KEY_3=tu_clave_aqui_3
```

### Configuración Automática

El servidor auto-detecta su IP local y la expone en los endpoints. No necesitas configurar manualmente la IP en la mayoría de casos.

## 🐛 Solución de Problemas

### Problema: App no encuentra el servidor

**Soluciones**:
1. ✅ Verificar que el servidor esté ejecutándose
2. ✅ Ambos dispositivos en la misma red WiFi
3. ✅ Firewall/antivirus no bloquee el puerto 3000
4. ✅ Usar diagnóstico de red para debug

### Problema: IP cambia frecuentemente

**Soluciones**:
1. ✅ Configurar IP estática en el router
2. ✅ Usar el re-descubrimiento automático
3. ✅ El cache se invalida automáticamente tras 24h

### Problema: Múltiples servidores en la red

**Soluciones**:
1. ✅ El sistema verifica que sea servidor Le Brunch específicamente
2. ✅ Usa el endpoint `/discover` para validación
3. ✅ Configuración manual disponible en diagnóstico

## 📊 Información Técnica

### Rangos de IP Soportados

- **Clase A**: 10.0.0.0/8
- **Clase B**: 172.16.0.0/12
- **Clase C**: 192.168.0.0/16

### Timeouts y Reintentos

- **Timeout conexión**: 3 segundos
- **Reintento en chunks**: 100ms entre chunks
- **Cache válido**: 24 horas
- **Validación**: Al iniciar app

### Optimizaciones

- **Búsqueda paralela**: Máximo 10 conexiones simultáneas
- **Priorización inteligente**: IPs más comunes primero
- **Cache persistente**: Evita re-escaneo innecesario
- **Validación específica**: Solo servidores Le Brunch

## 🎯 Próximas Mejoras

- [ ] **Broadcast UDP**: Descubrimiento más rápido
- [ ] **mDNS/Bonjour**: Descubrimiento por nombre
- [ ] **QR Code**: Configuración rápida por código
- [ ] **Historial de servidores**: Recordar servidores anteriores
- [ ] **Notificaciones**: Alertar cuando servidor cambie

---

## 🤝 Uso Durante el Desarrollo

Durante tu mes de tesis, este sistema te permitirá:

1. **Desarrollo flexible**: Cambiar IPs sin reconfigurar
2. **Pruebas rápidas**: Auto-conexión en cualquier red
3. **Debug fácil**: Herramientas integradas de diagnóstico
4. **Experiencia fluida**: Usuarios no necesitan configuración técnica

¡El sistema está listo para hacer tu desarrollo más eficiente! 🚀 