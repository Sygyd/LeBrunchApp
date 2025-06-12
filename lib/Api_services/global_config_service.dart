import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'network_config_service.dart';

class GlobalConfigService {
  static final GlobalConfigService _instance = GlobalConfigService._internal();
  factory GlobalConfigService() => _instance;
  GlobalConfigService._internal();

  // Configuración por defecto
  String _serverIp =
      '192.168.1.240'; // Valor por defecto, se actualizará con auto-discovery
  String _currentModel = "gemini-2.0-flash";
  bool _enableReports = true;
  bool _enablePopularDishes = true;
  bool _enableMenuManagement = true;
  bool _showSystemMessages = true;
  bool _debugMode = false;

  // Variable para asegurar que NetworkConfigService esté listo
  bool _networkServiceReady = false;

  // Getters
  String get serverIp => _serverIp;
  String get currentModel => _currentModel;
  bool get enableReports => _enableReports;
  bool get enablePopularDishes => _enablePopularDishes;
  bool get enableMenuManagement => _enableMenuManagement;
  bool get showSystemMessages => _showSystemMessages;
  bool get debugMode => _debugMode;

  // NUEVO: Asegurar que NetworkConfigService esté listo antes de operaciones críticas
  Future<void> _ensureNetworkServiceReady() async {
    try {
      const maxWaitTime = 2; // Reducido de tiempo de espera
      const checkInterval = 200; // Intervalo más frecuente
      int attempts = 0;
      int maxAttempts = (maxWaitTime * 1000) ~/ checkInterval;

      while (attempts < maxAttempts) {
        final networkService = NetworkConfigService();
        final networkIp = networkService.serverIp;

        // Si ya tenemos una IP válida de NetworkConfigService, usarla
        if (networkIp.isNotEmpty &&
            !['192.168.1.121', '192.168.1.136'].contains(networkIp)) {
          // Solo actualizar si la IP es diferente a la actual
          if (_serverIp != networkIp) {
            print(
              '🔄 GlobalConfig: Actualizando IP desde NetworkConfigService: $_serverIp → $networkIp',
            );
            _serverIp = networkIp;
          }
          return;
        }

        attempts++;
        // Esperar menos tiempo para no bloquear la UI
        await Future.delayed(const Duration(milliseconds: checkInterval));
      }

      print(
        '⏰ GlobalConfig: NetworkConfigService no listo después de ${maxWaitTime}s, continuando con IP actual: $_serverIp',
      );
    } catch (e) {
      print('❌ Error verificando NetworkConfigService: $e');
      // Continuar con la IP actual si hay error
    }
  }

  // Cargar configuración desde SharedPreferences
  Future<void> loadConfig() async {
    try {
      // CRUCIAL: Asegurar que NetworkConfigService esté listo antes de continuar
      await _ensureNetworkServiceReady();

      final prefs = await SharedPreferences.getInstance();

      // CAMBIO IMPORTANTE: Obtener IP actual del NetworkConfigService que ya tiene auto-discovery
      final networkService = NetworkConfigService();
      final currentNetworkIp = networkService.serverIp;

      // Lista de IPs obsoletas que no debemos probar
      const obsoleteIPs = ['192.168.1.121', '192.168.1.136'];

      // Solo usar IP guardada si coincide con la IP detectada actual o si es más nueva
      final savedIp = prefs.getString('global_server_ip');

      // NUEVA LÓGICA OPTIMIZADA: Evitar tests innecesarios
      if (savedIp != null &&
          savedIp.isNotEmpty &&
          savedIp != currentNetworkIp) {
        // CAMBIO CLAVE: Si la IP guardada es obsoleta, limpiarla y usar la actual directamente
        if (obsoleteIPs.contains(savedIp)) {
          print(
            '🧹 GlobalConfig: IP guardada obsoleta detectada ($savedIp), limpiando y usando auto-discovery',
          );
          await prefs.remove('global_server_ip');
          _serverIp = currentNetworkIp;
          await prefs.setString('global_server_ip', currentNetworkIp);
          print(
            '🔄 GlobalConfig: Usando IP detectada por auto-discovery: $currentNetworkIp',
          );
        } else {
          // Solo probar IPs si no son obsoletas
          print(
            '🔍 GlobalConfig: Comparando IP guardada ($savedIp) vs detectada ($currentNetworkIp)',
          );

          // Test rápido en paralelo pero solo para IPs no obsoletas
          final results = await Future.wait([
            _testIpConnection(savedIp),
            _testIpConnection(currentNetworkIp),
          ]);

          final savedIpWorks = results[0];
          final currentIpWorks = results[1];

          // Usar IP guardada solo si funciona y la actual no
          if (savedIpWorks && !currentIpWorks) {
            _serverIp = savedIp;
            print('🔄 GlobalConfig: Usando IP guardada que funciona: $savedIp');
          } else {
            _serverIp = currentNetworkIp;
            print(
              '🔄 GlobalConfig: Usando IP detectada por auto-discovery: $currentNetworkIp',
            );
            // Actualizar IP guardada con la detectada
            await prefs.setString('global_server_ip', currentNetworkIp);
          }
        }
      } else {
        // Usar directamente la IP detectada por auto-discovery
        _serverIp = currentNetworkIp;
        print(
          '🔄 GlobalConfig: Usando IP detectada por auto-discovery: $currentNetworkIp',
        );
        // Guardar la IP detectada
        await prefs.setString('global_server_ip', currentNetworkIp);
      }

      _currentModel =
          prefs.getString('global_gemini_model') ?? "gemini-2.0-flash";
      _enableReports = prefs.getBool('global_enable_reports') ?? true;
      _enablePopularDishes =
          prefs.getBool('global_enable_popular_dishes') ?? true;
      _enableMenuManagement =
          prefs.getBool('global_enable_menu_management') ?? true;
      _showSystemMessages =
          prefs.getBool('global_show_system_messages') ?? true;
      _debugMode = prefs.getBool('global_debug_mode') ?? false;

      print(
        '🔧 GlobalConfig: Configuración local cargada - IP: $_serverIp, Modelo: $_currentModel',
      );

      // NUEVO: Intentar sincronizar con el servidor automáticamente (solo si NetworkService está listo)
      if (_networkServiceReady) {
        await _syncWithServer();
      } else {
        print(
          '⚠️ GlobalConfig: Saltando sincronización automática - NetworkService no está listo',
        );
      }
    } catch (e) {
      print('❌ Error al cargar configuración global: $e');
    }
  }

  // Método optimizado para probar conexión a una IP específica con timeout más corto
  Future<bool> _testIpConnection(String ip) async {
    try {
      final url = Uri.parse('http://$ip:3000/status');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 2)); // Reducido de 3 a 2 segundos
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error al probar conexión: $e');
      return false;
    }
  }

  // NUEVO: Sincronizar configuración con el servidor (OPTIMIZADO)
  Future<void> _syncWithServer() async {
    try {
      print('🔄 Iniciando sincronización automática con servidor...');

      // Lista de IPs obsoletas que no debemos usar para sincronización
      const obsoleteIPs = ['192.168.1.121', '192.168.1.136'];

      // Verificar que tengamos una IP válida antes de intentar conectar
      if (_serverIp.isEmpty || obsoleteIPs.contains(_serverIp)) {
        print(
          '⚠️ GlobalConfig: IP no válida o obsoleta para sincronización ($_serverIp), saltando sincronización',
        );
        return;
      }

      final url = Uri.parse('http://$_serverIp:3000/config/sync');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 3)); // Reducido timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final serverData = data['data'];
          final serverConfig = serverData['serverConfig'];

          // NUEVO: Verificar si el servidor está devolviendo una IP obsoleta y corregirla automáticamente
          if (serverConfig['serverIp'] != null &&
              obsoleteIPs.contains(serverConfig['serverIp'])) {
            print(
              '🔧 GlobalConfig: Servidor devuelve IP obsoleta (${serverConfig['serverIp']}), corrigiendo automáticamente...',
            );

            // Enviar corrección al servidor
            await _updateServerGlobalConfig({'serverIp': _serverIp});
            print('✅ GlobalConfig: IP del servidor corregida a $_serverIp');
          }

          // Comparar y actualizar si hay diferencias
          bool hasChanges = false;

          if (serverConfig['model'] != null &&
              serverConfig['model'] != _currentModel) {
            print(
              '🔄 Sincronizando modelo: $_currentModel → ${serverConfig['model']}',
            );
            _currentModel = serverConfig['model'];
            hasChanges = true;
          }

          if (serverConfig['enableReports'] != null &&
              serverConfig['enableReports'] != _enableReports) {
            _enableReports = serverConfig['enableReports'];
            hasChanges = true;
          }

          if (serverConfig['enablePopularDishes'] != null &&
              serverConfig['enablePopularDishes'] != _enablePopularDishes) {
            _enablePopularDishes = serverConfig['enablePopularDishes'];
            hasChanges = true;
          }

          if (serverConfig['enableMenuManagement'] != null &&
              serverConfig['enableMenuManagement'] != _enableMenuManagement) {
            _enableMenuManagement = serverConfig['enableMenuManagement'];
            hasChanges = true;
          }

          if (serverConfig['showSystemMessages'] != null &&
              serverConfig['showSystemMessages'] != _showSystemMessages) {
            _showSystemMessages = serverConfig['showSystemMessages'];
            hasChanges = true;
          }

          if (serverConfig['debugMode'] != null &&
              serverConfig['debugMode'] != _debugMode) {
            _debugMode = serverConfig['debugMode'];
            hasChanges = true;
          }

          if (hasChanges) {
            await saveConfig();
            print('✅ Configuración sincronizada automáticamente con servidor');
          } else {
            print('✅ Configuración ya está sincronizada con servidor');
          }

          // Mostrar información de sincronización
          final brunchyModel = serverConfig['brunchyModel'];
          final synchronized = serverConfig['synchronized'] ?? false;
          print(
            '🤖 Estado servidor: Modelo global(${serverConfig['model']}) | BrunchyMCP($brunchyModel) | Sync: $synchronized',
          );
        }
      } else {
        print(
          '⚠️ No se pudo sincronizar con servidor (${response.statusCode}), usando configuración local',
        );
      }
    } catch (e) {
      print('⚠️ Error en sincronización automática (usando config local): $e');
      // No lanzar error para no bloquear la app
    }
  }

  // Guardar configuración en SharedPreferences
  Future<void> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('global_server_ip', _serverIp);
      await prefs.setString('global_gemini_model', _currentModel);
      await prefs.setBool('global_enable_reports', _enableReports);
      await prefs.setBool('global_enable_popular_dishes', _enablePopularDishes);
      await prefs.setBool(
        'global_enable_menu_management',
        _enableMenuManagement,
      );
      await prefs.setBool('global_show_system_messages', _showSystemMessages);
      await prefs.setBool('global_debug_mode', _debugMode);

      print('💾 GlobalConfig: Configuración guardada exitosamente');
    } catch (e) {
      print('❌ Error al guardar configuración global: $e');
    }
  }

  // Actualizar configuración del servidor
  Future<bool> updateServerConfig({
    String? serverIp,
    String? model,
    bool? enableReports,
    bool? enablePopularDishes,
    bool? enableMenuManagement,
    bool? showSystemMessages,
    bool? debugMode,
  }) async {
    try {
      // Preparar datos para enviar al servidor
      Map<String, dynamic> configData = {};
      bool hasChanges = false;

      if (serverIp != null && serverIp != _serverIp) {
        configData['serverIp'] = serverIp;
        _serverIp = serverIp;
        hasChanges = true;
      }

      if (model != null && model != _currentModel) {
        configData['model'] = model;
        _currentModel = model;
        hasChanges = true;
      }

      if (enableReports != null) {
        configData['enableReports'] = enableReports;
        _enableReports = enableReports;
        hasChanges = true;
      }

      if (enablePopularDishes != null) {
        configData['enablePopularDishes'] = enablePopularDishes;
        _enablePopularDishes = enablePopularDishes;
        hasChanges = true;
      }

      if (enableMenuManagement != null) {
        configData['enableMenuManagement'] = enableMenuManagement;
        _enableMenuManagement = enableMenuManagement;
        hasChanges = true;
      }

      if (showSystemMessages != null) {
        configData['showSystemMessages'] = showSystemMessages;
        _showSystemMessages = showSystemMessages;
        hasChanges = true;
      }

      if (debugMode != null) {
        configData['debugMode'] = debugMode;
        _debugMode = debugMode;
        hasChanges = true;
      }

      if (hasChanges) {
        // Enviar configuración al servidor
        final success = await _updateServerGlobalConfig(configData);
        if (success) {
          await saveConfig();
          print('✅ GlobalConfig: Configuración actualizada exitosamente');
          return true;
        } else {
          print('❌ No se pudo actualizar la configuración en el servidor');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('❌ Error al actualizar configuración: $e');
      return false;
    }
  }

  // Actualizar configuración global en el servidor
  Future<bool> _updateServerGlobalConfig(
    Map<String, dynamic> configData,
  ) async {
    try {
      print('🔧 Enviando configuración al servidor: $configData');
      final url = Uri.parse('http://$_serverIp:3000/config/global');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(configData),
          )
          .timeout(const Duration(seconds: 10));

      print('📡 Respuesta del servidor: ${response.statusCode}');
      print('📡 Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '✅ Configuración global actualizada en servidor: ${data['message']}',
        );
        return data['success'] ?? false;
      } else {
        print(
          '❌ Error al actualizar configuración global: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('❌ Error de conexión al actualizar configuración global: $e');
      return false;
    }
  }

  // Cargar configuración desde el servidor
  Future<bool> loadConfigFromServer() async {
    try {
      // Asegurar que NetworkConfigService esté listo antes de hacer conexiones
      await _ensureNetworkServiceReady();

      final url = Uri.parse('http://$_serverIp:3000/config/global');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['config'] != null) {
          final serverConfig = data['config'];

          _serverIp = serverConfig['serverIp'] ?? _serverIp;
          _currentModel = serverConfig['model'] ?? _currentModel;
          _enableReports = serverConfig['enableReports'] ?? _enableReports;
          _enablePopularDishes =
              serverConfig['enablePopularDishes'] ?? _enablePopularDishes;
          _enableMenuManagement =
              serverConfig['enableMenuManagement'] ?? _enableMenuManagement;
          _showSystemMessages =
              serverConfig['showSystemMessages'] ?? _showSystemMessages;
          _debugMode = serverConfig['debugMode'] ?? _debugMode;

          await saveConfig();
          print('✅ Configuración cargada desde servidor exitosamente');
          return true;
        }
      } else {
        print(
          '❌ Error al cargar configuración desde servidor: ${response.statusCode}',
        );
      }
      return false;
    } catch (e) {
      print('❌ Error de conexión al cargar configuración desde servidor: $e');
      return false;
    }
  }

  // Cambiar modelo en el servidor
  Future<bool> _changeServerModel(String model) async {
    try {
      // Asegurar que NetworkConfigService esté listo antes de hacer conexiones
      await _ensureNetworkServiceReady();

      final url = Uri.parse('http://$_serverIp:3000/mcp/model');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'model': model}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Modelo cambiado en servidor: ${data['currentModel']}');
        return true;
      } else {
        print('❌ Error al cambiar modelo: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error de conexión al cambiar modelo: $e');
      return false;
    }
  }

  // Obtener estado del servidor
  Future<Map<String, dynamic>?> getServerStatus() async {
    try {
      // Asegurar que NetworkConfigService esté listo antes de hacer conexiones
      await _ensureNetworkServiceReady();

      final url = Uri.parse('http://$_serverIp:3000/mcp/status');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error al obtener estado del servidor: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener estado del servidor: $e');
      return null;
    }
  }

  // Obtener información del modelo actual
  Future<Map<String, dynamic>?> getModelInfo() async {
    try {
      final url = Uri.parse('http://$_serverIp:3000/mcp/model');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error al obtener info del modelo: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener info del modelo: $e');
      return null;
    }
  }

  // Probar conexión con el servidor
  Future<bool> testConnection([String? testIp]) async {
    // Si no se especifica IP de prueba, asegurar que NetworkConfigService esté listo
    if (testIp == null) {
      await _ensureNetworkServiceReady();
    }

    final ipToTest = testIp ?? _serverIp;

    try {
      final url = Uri.parse('http://$ipToTest:3000/status');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 3)); // Reducido de 5 a 3 segundos

      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      print('❌ Error al probar conexión con IP $ipToTest: $e');

      // NUEVO: Si falla y no se especificó IP, intentar con la IP detectada por NetworkConfigService
      if (testIp == null) {
        final networkService = NetworkConfigService();
        final networkIp = networkService.serverIp;

        if (networkIp.isNotEmpty && networkIp != _serverIp) {
          print(
            '🔄 GlobalConfig: Intentando conexión con IP de auto-discovery: $networkIp',
          );
          try {
            final fallbackUrl = Uri.parse('http://$networkIp:3000/status');
            final fallbackResponse = await http
                .get(fallbackUrl)
                .timeout(
                  const Duration(seconds: 2),
                ); // Timeout más corto para fallback

            if (fallbackResponse.statusCode == 200) {
              print(
                '✅ GlobalConfig: Conexión exitosa con IP de auto-discovery, actualizando...',
              );
              _serverIp = networkIp;
              // No bloquear la UI esperando a que se guarde
              saveConfig(); // Sin await
              return true;
            }
          } catch (fallbackError) {
            print('❌ Error con IP de auto-discovery: $fallbackError');
          }
        }
      }
    }

    return false;
  }

  // Probar conexión específica usando el endpoint del servidor
  Future<Map<String, dynamic>> testConnectionWithDetails([
    String? testIp,
  ]) async {
    try {
      final ipToTest = testIp ?? _serverIp;
      final url = Uri.parse('http://$ipToTest:3000/config/test-connection');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'serverIp': ipToTest}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'Conexión exitosa',
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'success': false,
          'message': 'Error de conexión: ${response.statusCode}',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Obtener configuración como Map para enviar al servidor
  Map<String, dynamic> toMap() {
    return {
      'serverIp': _serverIp,
      'currentModel': _currentModel,
      'enableReports': _enableReports,
      'enablePopularDishes': _enablePopularDishes,
      'enableMenuManagement': _enableMenuManagement,
      'showSystemMessages': _showSystemMessages,
      'debugMode': _debugMode,
    };
  }

  // Cargar configuración desde Map
  void fromMap(Map<String, dynamic> config) {
    _serverIp = config['serverIp'] ?? _serverIp;
    _currentModel = config['currentModel'] ?? _currentModel;
    _enableReports = config['enableReports'] ?? _enableReports;
    _enablePopularDishes =
        config['enablePopularDishes'] ?? _enablePopularDishes;
    _enableMenuManagement =
        config['enableMenuManagement'] ?? _enableMenuManagement;
    _showSystemMessages = config['showSystemMessages'] ?? _showSystemMessages;
    _debugMode = config['debugMode'] ?? _debugMode;
  }

  // NUEVO: Forzar sincronización manual (para uso del admin)
  Future<bool> forceSyncWithServer() async {
    try {
      print('🔄 Forzando sincronización manual con servidor...');
      await _syncWithServer();
      return true;
    } catch (e) {
      print('❌ Error en sincronización manual: $e');
      return false;
    }
  }

  // NUEVO: Verificar estado de sincronización
  Future<Map<String, dynamic>?> getSyncStatus() async {
    try {
      final url = Uri.parse('http://$_serverIp:3000/config/sync');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        print(
          '❌ Error al obtener estado de sincronización: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener estado de sincronización: $e');
      return null;
    }
  }
}
