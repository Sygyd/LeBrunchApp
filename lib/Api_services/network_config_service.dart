import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config.dart'; // 👈 NUEVA LÍNEA: Usar configuración simple

class NetworkConfigService {
  static final NetworkConfigService _instance =
      NetworkConfigService._internal();
  factory NetworkConfigService() => _instance;
  NetworkConfigService._internal();

  // 👈 CONFIGURACIÓN PRINCIPAL: Usar config.dart como fuente primaria
  String get serverIp => AppConfig.serverIp;
  String get baseUrl => AppConfig.serverUrl;

  // Auto-discovery como respaldo (solo si es necesario)
  String? _discoveredIp;
  bool _isInitialized = false;

  // ✅ INICIALIZACIÓN SIMPLE
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🔧 Inicializando NetworkConfigService...');
    print('📍 IP configurada: ${AppConfig.serverIp}');
    print('🌐 URL configurada: ${AppConfig.serverUrl}');

    // Probar conexión con la IP configurada
    final isConfiguredIpWorking = await _testConnection(AppConfig.serverIp);

    if (isConfiguredIpWorking) {
      print('✅ IP configurada funciona correctamente');
      _isInitialized = true;
      return;
    }

    print('⚠️ IP configurada no responde, intentando auto-discovery...');

    // Solo hacer auto-discovery si la IP configurada no funciona
    await _performQuickDiscovery();
    _isInitialized = true;
  }

  // 🧪 PROBAR CONEXIÓN RÁPIDA
  Future<bool> _testConnection(String ip) async {
    try {
      final response = await http
          .get(Uri.parse('http://$ip:3000/status'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 🔍 AUTO-DISCOVERY RÁPIDO (solo como fallback)
  Future<void> _performQuickDiscovery() async {
    try {
      print('🚀 Iniciando auto-discovery rápido...');

      // Obtener rango de IP local del dispositivo
      final localIp = await _getDeviceLocalIp();
      if (localIp == null) {
        print('❌ No se pudo detectar IP local del dispositivo');
        return;
      }

      final range = localIp.substring(0, localIp.lastIndexOf('.'));
      print('📱 Rango local detectado: $range (desde $localIp)');

      // Probar IPs comunes primero
      final commonIps = [
        '$range.1',
        '$range.100',
        '$range.101',
        '$range.121',
        '$range.136',
      ];

      for (String ip in commonIps) {
        if (await _testConnection(ip)) {
          print('✅ Servidor encontrado en: $ip');
          _discoveredIp = ip;
          return;
        }
      }

      print('❌ No se encontró servidor en auto-discovery');
    } catch (e) {
      print('❌ Error en auto-discovery: $e');
    }
  }

  // 📱 OBTENER IP LOCAL DEL DISPOSITIVO
  Future<String?> _getDeviceLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (NetworkInterface interface in interfaces) {
        for (InternetAddress addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            if (addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.') ||
                (addr.address.startsWith('172.') &&
                    int.parse(addr.address.split('.')[1]) >= 16 &&
                    int.parse(addr.address.split('.')[1]) <= 31)) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error obteniendo IP local: $e');
    }
    return null;
  }

  // 📡 OBTENER IP EFECTIVA (configurada o descubierta)
  String getEffectiveIp() {
    // Si hay una IP descubierta que funciona, usarla
    if (_discoveredIp != null) {
      print('🔄 Usando IP descubierta: $_discoveredIp');
      return _discoveredIp!;
    }

    // Sino, usar la configurada
    return AppConfig.serverIp;
  }

  // 🌐 OBTENER URL EFECTIVA
  String getEffectiveUrl() {
    final effectiveIp = getEffectiveIp();
    return 'http://$effectiveIp:3000';
  }

  // 🔄 REDESCUBRIR SERVIDOR (para forzar nuevo discovery)
  Future<bool> forceRediscovery() async {
    print('🔄 Forzando redescubrimiento de servidor...');
    _discoveredIp = null;
    _isInitialized = false;

    await initialize();

    final effectiveIp = getEffectiveIp();
    final isWorking = await _testConnection(effectiveIp);

    if (isWorking) {
      print('✅ Redescubrimiento exitoso: $effectiveIp');
      return true;
    } else {
      print('❌ Redescubrimiento falló');
      return false;
    }
  }

  // 📊 OBTENER ESTADO DEL SERVICIO
  Map<String, dynamic> getStatus() {
    return {
      'configuredIp': AppConfig.serverIp,
      'discoveredIp': _discoveredIp,
      'effectiveIp': getEffectiveIp(),
      'effectiveUrl': getEffectiveUrl(),
      'isInitialized': _isInitialized,
    };
  }

  String? _serverIp;
  String? _serverPort;
  bool _isConfigured = false;
  Map<String, dynamic>? _serverInfo;
  DateTime? _lastDiscovery;

  String get serverPort => _serverPort ?? '3000';
  bool get isConfigured => _isConfigured;
  Map<String, dynamic>? get serverInfo => _serverInfo;

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('network_server_ip');
      final savedPort = prefs.getString('network_server_port');
      final lastUpdatedStr = prefs.getString('network_last_updated');
      final serverInfoStr = prefs.getString('network_server_info');

      if (savedIp != null && savedPort != null) {
        // Verificar si el cache no es muy antiguo (menos de 24 horas)
        if (lastUpdatedStr != null) {
          final lastUpdated = DateTime.parse(lastUpdatedStr);
          final cacheAge = DateTime.now().difference(lastUpdated);

          if (cacheAge.inHours > 24) {
            print('⏰ Cache muy antiguo (${cacheAge.inHours}h), refrescando...');
            await _clearSavedConfig();
            return false;
          }
        }

        // Verificar que el servidor aún responde
        if (await _testConnection(savedIp)) {
          _serverIp = savedIp;
          _serverPort = savedPort;
          _isConfigured = true;

          // Cargar info adicional del servidor si existe
          if (serverInfoStr != null) {
            try {
              _serverInfo = jsonDecode(serverInfoStr);
            } catch (e) {
              print('⚠️ Error decodificando info del servidor: $e');
            }
          }

          return true;
        } else {
          print('⚠️ Configuración guardada no responde, limpiando...');
          await _clearSavedConfig();
        }
      }
    } catch (e) {
      print('❌ Error cargando desde cache: $e');
    }
    return false;
  }

  Future<bool> _loadFromEnv() async {
    try {
      String envIp = dotenv.get('SERVER_HOST', fallback: '');
      if (envIp.isEmpty) {
        envIp = dotenv.get('NODE_SERVER_IP', fallback: '');
      }

      String envPort = dotenv.get('PORT', fallback: '');
      if (envPort.isEmpty) {
        envPort = dotenv.get('NODE_SERVER_PORT', fallback: '');
      }

      if (envIp.isNotEmpty && envPort.isNotEmpty) {
        print('🔍 Probando configuración desde .env: $envIp:$envPort');
        if (await _testDiscoveryEndpoint(envIp, envPort)) {
          _serverIp = envIp;
          _serverPort = envPort;
          _isConfigured = true;
          return true;
        }
      }
    } catch (e) {
      print('❌ Error cargando desde .env: $e');
    }
    return false;
  }

  /// OPTIMIZADO: Auto-discovery RÁPIDO y dirigido
  Future<bool> _autoDetectServerUniversal() async {
    print('🚀 Iniciando búsqueda RÁPIDA de servidor...');

    try {
      // 1. Obtener el rango de red local primero (más probable)
      final localRange = await _getLocalIpRange();
      final portsToCheck = ['3000', '8000']; // Solo puertos más comunes

      // 2. PRIORIDAD ALTA: Buscar en el rango local primero
      if (localRange != null) {
        print('🎯 Buscando PRIMERO en rango local: $localRange');
        final found = await _searchInRangeFast(localRange, portsToCheck);
        if (found) {
          print('✅ ¡Servidor encontrado en rango local!');
          return true;
        }
      }

      // 3. PRIORIDAD MEDIA: Buscar en rangos comunes de hotspot/router
      final commonRanges = ['192.168.1', '192.168.0', '192.168.43', '10.0.0'];

      for (final range in commonRanges) {
        if (range != localRange) {
          // Evitar duplicados
          print('🔍 Buscando en rango común: $range');
          final found = await _searchInRangeFast(range, portsToCheck);
          if (found) {
            print('✅ ¡Servidor encontrado en rango común!');
            return true;
          }
        }
      }

      // 4. PRIORIDAD BAJA: Solo si no encontramos nada, buscar en otros rangos
      final otherRanges = ['172.20.10', '192.168.2', '10.42.0'];

      for (final range in otherRanges) {
        print('🔍 Buscando en rango adicional: $range');
        final found = await _searchInRangeFast(range, portsToCheck);
        if (found) {
          print('✅ ¡Servidor encontrado en rango adicional!');
          return true;
        }
      }

      print('❌ No se encontró servidor después de búsqueda dirigida');
      return false;
    } catch (e) {
      print('❌ Error en auto-discovery rápido: $e');
      return false;
    }
  }

  /// NUEVO: Detecta automáticamente TODOS los rangos de red activos en el dispositivo
  Future<List<String>> _detectAllActiveNetworkRanges() async {
    final ranges = <String>{};

    try {
      print('🔍 Detectando todas las interfaces de red activas...');
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        print('📡 Analizando interfaz: ${interface.name}');

        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            final range = _extractNetworkRange(ip);

            if (range != null) {
              ranges.add(range);
              print('   ✅ Rango detectado: $range (desde $ip)');
            }
          }
        }
      }

      // Agregar rangos comunes adicionales que podrían no estar en las interfaces
      // pero que son usados frecuentemente por hotspots y redes compartidas
      final commonHotspotRanges = [
        '192.168.43', // Android hotspot común
        '192.168.137', // Windows hotspot
        '172.20.10', // iPhone hotspot
        '10.42.0', // Linux hotspot
        '192.168.0', // Router común
        '192.168.1', // Router común
        '192.168.2', // Router común
        '10.0.0', // Redes corporativas
        '172.16.0', // Redes privadas
      ];

      for (final range in commonHotspotRanges) {
        ranges.add(range);
      }

      final sortedRanges = ranges.toList()..sort(_prioritizeRanges);
      print('🌐 Total de rangos únicos detectados: ${sortedRanges.length}');

      return sortedRanges;
    } catch (e) {
      print('❌ Error detectando rangos de red: $e');
      // Fallback a rangos comunes
      return [
        '192.168.1',
        '192.168.0',
        '192.168.43',
        '172.20.10',
        '10.0.0',
        '192.168.2',
        '192.168.137',
      ];
    }
  }

  /// NUEVO: Extrae el rango de red de una IP (ej: 192.168.43.123 -> 192.168.43)
  String? _extractNetworkRange(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length >= 3) {
        final range = '${parts[0]}.${parts[1]}.${parts[2]}';

        // Verificar que sea un rango privado válido
        if (_isPrivateIpRange(range)) {
          return range;
        }
      }
    } catch (e) {
      print('⚠️ Error extrayendo rango de $ip: $e');
    }
    return null;
  }

  /// NUEVO: Verifica si un rango es una IP privada válida
  bool _isPrivateIpRange(String range) {
    final parts = range.split('.');
    if (parts.length != 3) return false;

    try {
      final first = int.parse(parts[0]);
      final second = int.parse(parts[1]);
      final third = int.parse(parts[2]);

      // Rangos privados RFC 1918
      if (first == 10) return true;
      if (first == 172 && second >= 16 && second <= 31) return true;
      if (first == 192 && second == 168) return true;

      // Rangos de link-local y otros comunes
      if (first == 169 && second == 254) return true; // Link-local

      return false;
    } catch (e) {
      return false;
    }
  }

  /// NUEVO: Prioriza rangos por probabilidad de contener el servidor
  int _prioritizeRanges(String a, String b) {
    // Primero los rangos de hotspot móvil (más comunes cuando se comparte WiFi)
    final mobileHotspotRanges = ['192.168.43', '172.20.10', '192.168.137'];
    final commonRouterRanges = ['192.168.1', '192.168.0', '10.0.0'];

    final aPriority = _getRangePriority(
      a,
      mobileHotspotRanges,
      commonRouterRanges,
    );
    final bPriority = _getRangePriority(
      b,
      mobileHotspotRanges,
      commonRouterRanges,
    );

    return aPriority.compareTo(bPriority);
  }

  int _getRangePriority(
    String range,
    List<String> mobile,
    List<String> router,
  ) {
    if (mobile.contains(range)) return 1; // Máxima prioridad para hotspots
    if (router.contains(range))
      return 2; // Segunda prioridad para routers comunes
    if (range.startsWith('192.168.')) return 3; // Otros rangos 192.168.x
    if (range.startsWith('10.')) return 4; // Rangos 10.x
    if (range.startsWith('172.')) return 5; // Rangos 172.x
    return 6; // Otros rangos
  }

  /// NUEVO: Genera IPs candidatas de TODOS los rangos detectados de forma inteligente
  Future<List<String>> _generateUniversalCandidateIps(
    List<String> activeRanges,
  ) async {
    final candidates = <String>[];

    print(
      '🎯 Generando candidatos universales para ${activeRanges.length} rangos...',
    );

    for (final range in activeRanges) {
      // IPs más probables primero (routers, servidores comunes)
      final priorityEndings = [
        1, // Gateway común
        2, // Primer dispositivo
        100, // Rango de dispositivos común
        101, // Servidor común
        240, // IP específica que conocemos
        136, // IP específica que conocemos
        121, // IP específica que conocemos
        43, // Común en hotspots
        254, // Último dispositivo posible
        200, // Rango alto común
        50, // Rango medio
        10, // Rango bajo
        20, // Rango bajo-medio
        110, // Servidor alternativo
        111, // Servidor alternativo
      ];

      // Añadir IPs prioritarias
      for (final ending in priorityEndings) {
        if (ending <= 254) {
          candidates.add('$range.$ending');
        }
      }

      // Luego un barrido más completo pero optimizado
      // Solo barrer rangos que no hemos cubierto ya
      for (int i = 3; i <= 254; i++) {
        if (!priorityEndings.contains(i)) {
          candidates.add('$range.$i');
        }
      }
    }

    print('📊 Total de candidatos generados: ${candidates.length}');
    return candidates;
  }

  Future<bool> _autoDetectServerParallel() async {
    print('🔄 Redirigiendo a auto-discovery universal...');
    return await _autoDetectServerUniversal();
  }

  Future<List<String>> _generateCandidateIps() async {
    // DEPRECATED: Este método ahora redirige al nuevo sistema universal
    final activeRanges = await _detectAllActiveNetworkRanges();
    return await _generateUniversalCandidateIps(activeRanges);
  }

  Future<String?> _getLocalIpRange() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi') ||
            interface.name.toLowerCase().contains('ethernet') ||
            interface.name.toLowerCase().contains('en0') ||
            interface.name.toLowerCase().contains('wlp')) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              final ip = addr.address;
              final range = _extractNetworkRange(ip);
              if (range != null) {
                print('📱 Rango local detectado: $range (desde $ip)');
                return range;
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error obteniendo IP local: $e');
    }
    return null;
  }

  bool _isPrivateClassB(String ip) {
    final parts = ip.split('.');
    if (parts.length >= 2) {
      final secondOctet = int.tryParse(parts[1]) ?? 0;
      return secondOctet >= 16 && secondOctet <= 31;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _testConnectionAsync(
    String ip,
    String port,
  ) async {
    try {
      // Primero probar el endpoint de descubrimiento mejorado
      if (await _testDiscoveryEndpoint(ip, port)) {
        return {'ip': ip, 'port': port, 'serverInfo': _serverInfo};
      }

      // Fallback al endpoint de status básico
      if (await _testConnection(ip)) {
        return {'ip': ip, 'port': port, 'serverInfo': null};
      }
    } catch (e) {
      // Silenciar errores de conexión individuales
    }
    return null;
  }

  Future<bool> _testDiscoveryEndpoint(String ip, String port) async {
    try {
      final response = await http
          .get(
            Uri.parse('http://$ip:$port/discover'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 1)); // Timeout más rápido

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          // Verificar que sea realmente nuestro servidor
          if (data['server']?['type'] == 'brunch-app-server') {
            _serverInfo = data;
            print('✅ Servidor Le Brunch verificado: $ip:$port');
            return true;
          }
        } catch (e) {
          print('⚠️ Respuesta de descubrimiento inválida: $e');
        }
      }
    } catch (e) {
      // Error silencioso para no spam en logs
    }
    return false;
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('network_server_ip', _serverIp!);
      await prefs.setString('network_server_port', _serverPort!);
      await prefs.setString(
        'network_last_updated',
        DateTime.now().toIso8601String(),
      );

      if (_serverInfo != null) {
        await prefs.setString('network_server_info', jsonEncode(_serverInfo!));
      }

      print('💾 Configuración de red guardada con timestamp');
    } catch (e) {
      print('❌ Error guardando configuración: $e');
    }
  }

  Future<void> _clearSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('server_ip');
      await prefs.remove('server_url');
      await prefs.remove('last_discovery');
      await prefs.remove('server_info');
      _serverInfo = null;
      _lastDiscovery = null;
      print('🧹 Configuración guardada limpiada');
    } catch (e) {
      print('⚠️ Error limpiando configuración: $e');
    }
  }

  Future<bool> updateServerConfig(String ip, String port) async {
    print('🔄 Actualizando configuración manualmente: $ip:$port');

    if (await _testDiscoveryEndpoint(ip, port) || await _testConnection(ip)) {
      _serverIp = ip;
      _serverPort = port;
      _isConfigured = true;
      _lastDiscovery = DateTime.now();
      await _saveToCache();
      print('✅ Configuración actualizada exitosamente');
      return true;
    } else {
      print('❌ No se pudo conectar con la nueva configuración');
      return false;
    }
  }

  Future<bool> refreshConfiguration() async {
    print('🔄 Refrescando configuración de red...');
    _serverInfo = null;
    _lastDiscovery = null;
    await initialize();
    return true;
  }

  // OPTIMIZADO: Auto-discovery rápido en segundo plano
  Future<void> _backgroundDiscovery() async {
    try {
      print('🔍 Auto-discovery en segundo plano...');

      final success = await _autoDetectServerUniversal();
      if (success) {
        await _saveToCache();
        print('✅ Servidor actualizado en segundo plano: $baseUrl');
      }
    } catch (e) {
      print('⚠️ Error en auto-discovery de segundo plano: $e');
    }
  }

  String getEndpointUrl(String endpoint) {
    if (!endpoint.startsWith('/')) {
      endpoint = '/$endpoint';
    }
    return '$baseUrl$endpoint';
  }

  Map<String, dynamic> getDiagnosticInfo() {
    return {
      'serverIp': _serverIp,
      'serverPort': _serverPort,
      'baseUrl': baseUrl,
      'isConfigured': _isConfigured,
      'lastDiscovery': _lastDiscovery?.toIso8601String(),
      'serverInfo': _serverInfo,
      'cacheAge':
          _lastDiscovery != null
              ? DateTime.now().difference(_lastDiscovery!).inMinutes
              : null,
    };
  }

  Future<Map<String, dynamic>> checkServerStatus() async {
    final startTime = DateTime.now();

    try {
      // Intentar primero el endpoint de descubrimiento
      var response = await http
          .get(
            Uri.parse('$baseUrl/discover'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      var responseTime = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return {
            'status': 'connected',
            'responseTime': responseTime,
            'serverType': 'le-brunch-server',
            'serverInfo': data,
            'endpoint': '/discover',
            'lastChecked': DateTime.now().toIso8601String(),
          };
        } catch (e) {
          // Si falla el parse, intentar endpoint básico
        }
      }

      // Fallback al endpoint básico
      response = await http
          .get(
            Uri.parse('$baseUrl/status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      responseTime = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        return {
          'status': 'connected',
          'responseTime': responseTime,
          'serverType': 'basic',
          'serverResponse': response.body,
          'endpoint': '/status',
          'lastChecked': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'status': 'error',
          'statusCode': response.statusCode,
          'responseTime': responseTime,
          'lastChecked': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'status': 'disconnected',
        'error': e.toString(),
        'lastChecked': DateTime.now().toIso8601String(),
      };
    }
  }

  // NUEVO: Verificar si el servidor actual sigue siendo válido
  Future<bool> validateCurrentServer() async {
    if (!_isConfigured || _serverIp == null || _serverPort == null) {
      return false;
    }

    return await _testDiscoveryEndpoint(_serverIp!, _serverPort!) ||
        await _testConnection(_serverIp!);
  }

  // NUEVO: Sistema inteligente de recuperación automática mejorado
  Future<bool> smartRecovery() async {
    print('🧠 Iniciando recuperación inteligente de red...');

    // 1. Verificar si el servidor actual sigue funcionando
    if (await validateCurrentServer()) {
      print('✅ Servidor actual sigue funcionando');
      return true;
    }

    print('❌ Servidor actual no responde, iniciando búsqueda...');

    // 2. Intentar búsqueda inteligente completa
    print('🔍 Iniciando búsqueda completa inteligente...');
    return await _autoDetectServerUniversal();
  }

  // OPTIMIZADO: Búsqueda rápida y dirigida en un rango específico
  Future<bool> _searchInRangeFast(String range, List<String> ports) async {
    print('🎯 Búsqueda rápida en $range con puertos: ${ports.join(', ')}');

    // IPs más probables en orden de prioridad
    final priorityIps = [
      1, // Gateway común
      100, // IP del servidor conocida
      101, // Servidor alternativo
      121, // IP específica conocida
      136, // IP específica conocida
      240, // IP específica conocida
      2, // Segunda IP
      254, // Última IP
      43, // Común en hotspots
      200, // Rango alto
    ];

    // Probar IPs prioritarias con timeout corto
    for (final ip in priorityIps) {
      for (final port in ports) {
        final fullIp = '$range.$ip';

        try {
          if (await _testDiscoveryEndpoint(fullIp, port)) {
            _serverIp = fullIp;
            _serverPort = port;
            _isConfigured = true;
            _lastDiscovery = DateTime.now();
            print('🎯 ¡Servidor encontrado! $fullIp:$port');
            return true;
          }
        } catch (e) {
          // Continuar con la siguiente IP
        }
      }
    }

    return false;
  }

  // LEGACY: Búsqueda en rango (mantenida para compatibilidad)
  Future<bool> _searchInRange(String range) async {
    final portsToCheck = ['3000', '8000'];
    return await _searchInRangeFast(range, portsToCheck);
  }

  // NUEVO: Verificar conexión con reintentos inteligentes
  Future<bool> checkConnectionWithRetry({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      print('🔄 Intento de conexión $attempt/$maxRetries...');

      final status = await checkServerStatus();

      if (status['status'] == 'connected') {
        print('✅ Conexión exitosa en intento $attempt');
        return true;
      }

      if (attempt < maxRetries) {
        print('⏳ Esperando antes del siguiente intento...');
        await Future.delayed(
          Duration(seconds: attempt * 2),
        ); // Back-off exponencial

        // Intentar recuperación inteligente en el último intento
        if (attempt == maxRetries - 1) {
          print('🧠 Último intento: activando recuperación inteligente...');
          if (await smartRecovery()) {
            return true;
          }
        }
      }
    }

    print('❌ Falló conexión después de $maxRetries intentos');
    return false;
  }

  // NUEVO: Limpiar configuraciones obsoletas que puedan estar hardcodeadas
  Future<void> clearObsoleteConfigurations() async {
    try {
      print('🧹 Limpiando configuraciones obsoletas...');
      final prefs = await SharedPreferences.getInstance();

      // Lista de IPs conocidas que debemos limpiar por ser hardcodeadas
      const obsoleteIPs = ['192.168.1.121', '192.168.1.136'];

      final currentServerIp = prefs.getString('serverIp');

      if (currentServerIp != null && obsoleteIPs.contains(currentServerIp)) {
        print('🧹 Limpiando IP obsoleta guardada: $currentServerIp');
        await prefs.remove('serverIp');
        await prefs.remove('serverPort');
        await prefs.remove('lastDiscoveryCheck');
        await prefs.remove('lastSuccessfulConnect');

        // También limpiar cualquier configuración global que use la IP obsoleta
        final globalServerIp = prefs.getString('global_server_ip');
        if (globalServerIp != null && obsoleteIPs.contains(globalServerIp)) {
          print('🧹 Limpiando configuración global obsoleta: $globalServerIp');
          await prefs.remove('global_server_ip');
        }

        print(
          '✅ Configuraciones obsoletas limpiadas, se activará auto-discovery universal',
        );

        // Resetear estado interno para forzar nueva inicialización
        _serverIp = null;
        _serverPort = null;
        _isConfigured = false;
        _serverInfo = null;
      } else {
        print('✅ No se encontraron configuraciones obsoletas');
      }
    } catch (error) {
      print('⚠️ Error al limpiar configuraciones obsoletas: $error');
    }
  }
}
