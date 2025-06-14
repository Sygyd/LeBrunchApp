import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

// ✅ VERSIÓN SUPER SIMPLIFICADA
class GlobalConfigService {
  static final GlobalConfigService _instance = GlobalConfigService._internal();
  factory GlobalConfigService() => _instance;
  GlobalConfigService._internal();

  // 👈 CONFIGURACIÓN SIMPLIFICADA: Todo viene de config.dart
  String get serverIp => AppConfig.serverIp;
  String get serverUrl => AppConfig.serverUrl;

  // Solo configuración esencial de la app
  String _currentModel = "gemini-2.0-flash";
  bool _enableReports = true;
  bool _enablePopularDishes = true;
  bool _enableMenuManagement = true;
  bool _showSystemMessages = true;
  bool _debugMode = false;

  // Getters
  String get currentModel => _currentModel;
  bool get enableReports => _enableReports;
  bool get enablePopularDishes => _enablePopularDishes;
  bool get enableMenuManagement => _enableMenuManagement;
  bool get showSystemMessages => _showSystemMessages;
  bool get debugMode => _debugMode;

  // 🔧 CARGAR CONFIGURACIÓN SIMPLE
  Future<void> loadConfig() async {
    try {
      print('🔧 Cargando configuración simple...');
      print('📍 IP del servidor: ${AppConfig.serverIp}');
      print('🌐 URL del servidor: ${AppConfig.serverUrl}');

      final prefs = await SharedPreferences.getInstance();

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

      print('✅ Configuración simple cargada - Modelo: $_currentModel');
    } catch (e) {
      print('❌ Error al cargar configuración: $e');
    }
  }

  // 💾 GUARDAR CONFIGURACIÓN
  Future<void> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('global_gemini_model', _currentModel);
      await prefs.setBool('global_enable_reports', _enableReports);
      await prefs.setBool('global_enable_popular_dishes', _enablePopularDishes);
      await prefs.setBool(
        'global_enable_menu_management',
        _enableMenuManagement,
      );
      await prefs.setBool('global_show_system_messages', _showSystemMessages);
      await prefs.setBool('global_debug_mode', _debugMode);
      print('✅ Configuración guardada');
    } catch (e) {
      print('❌ Error al guardar configuración: $e');
    }
  }

  // 🔄 SETTERS PARA ACTUALIZAR CONFIGURACIÓN
  Future<void> updateModel(String model) async {
    _currentModel = model;
    await saveConfig();
  }

  Future<void> updateReports(bool enabled) async {
    _enableReports = enabled;
    await saveConfig();
  }

  Future<void> updatePopularDishes(bool enabled) async {
    _enablePopularDishes = enabled;
    await saveConfig();
  }

  Future<void> updateMenuManagement(bool enabled) async {
    _enableMenuManagement = enabled;
    await saveConfig();
  }

  Future<void> updateSystemMessages(bool enabled) async {
    _showSystemMessages = enabled;
    await saveConfig();
  }

  Future<void> updateDebugMode(bool enabled) async {
    _debugMode = enabled;
    await saveConfig();
  }

  // 🧪 PROBAR CONEXIÓN CON EL SERVIDOR
  Future<bool> testConnection() async {
    try {
      print('🔍 Probando conexión con ${AppConfig.serverUrl}...');
      final response = await http
          .get(Uri.parse('${AppConfig.serverUrl}/status'))
          .timeout(const Duration(seconds: 3));

      final isConnected = response.statusCode == 200;
      print(isConnected ? '✅ Servidor conectado' : '❌ Servidor no responde');
      return isConnected;
    } catch (e) {
      print('❌ Error de conexión: $e');
      return false;
    }
  }

  // 📊 OBTENER CONFIGURACIÓN DEL SERVIDOR
  Future<Map<String, dynamic>?> getServerConfig() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.serverUrl}/config'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('⚠️ No se pudo obtener configuración del servidor: $e');
    }
    return null;
  }

  // ✅ MÉTODOS FALTANTES AGREGADOS

  // 📊 OBTENER ESTADO DEL SERVIDOR
  Future<Map<String, dynamic>?> getServerStatus() async {
    try {
      // Usar el endpoint /mcp/status que incluye información de la base de datos
      final response = await http
          .get(Uri.parse('${AppConfig.serverUrl}/mcp/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'status': data['status'] ?? 'unknown',
          'message': 'Sistema MCP activo',
          'version': data['version'] ?? 'unknown',
          'database': data['database'] ?? {'connected': false},
          'geminiModel': data['geminiModel'] ?? {},
          'keyRotation': data['keyRotation'] ?? {},
          'timestamp': data['timestamp'] ?? DateTime.now().toIso8601String(),
          'connected': true,
        };
      }
    } catch (e) {
      print('⚠️ Error al obtener estado del servidor MCP: $e');
    }
    return {
      'status': 'error',
      'message': 'No se pudo conectar al servidor',
      'timestamp': DateTime.now().toIso8601String(),
      'connected': false,
      'database': {'connected': false},
    };
  }

  // 🔧 ACTUALIZAR CONFIGURACIÓN DEL SERVIDOR
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
      // Actualizar configuración local
      if (model != null) _currentModel = model;
      if (enableReports != null) _enableReports = enableReports;
      if (enablePopularDishes != null)
        _enablePopularDishes = enablePopularDishes;
      if (enableMenuManagement != null)
        _enableMenuManagement = enableMenuManagement;
      if (showSystemMessages != null) _showSystemMessages = showSystemMessages;
      if (debugMode != null) _debugMode = debugMode;

      // Guardar cambios localmente
      await saveConfig();

      // Intentar sincronizar con el servidor si está disponible
      try {
        final response = await http
            .post(
              Uri.parse('${AppConfig.serverUrl}/config/global'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                if (serverIp != null) 'serverIp': serverIp,
                if (model != null) 'model': model,
                if (enableReports != null) 'enableReports': enableReports,
                if (enablePopularDishes != null)
                  'enablePopularDishes': enablePopularDishes,
                if (enableMenuManagement != null)
                  'enableMenuManagement': enableMenuManagement,
                if (showSystemMessages != null)
                  'showSystemMessages': showSystemMessages,
                if (debugMode != null) 'debugMode': debugMode,
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          print('✅ Configuración sincronizada con el servidor');
          return true;
        }
      } catch (e) {
        print(
          '⚠️ No se pudo sincronizar con el servidor, cambios guardados localmente: $e',
        );
      }

      return true; // Éxito local aunque falle la sincronización
    } catch (e) {
      print('❌ Error al actualizar configuración: $e');
      return false;
    }
  }

  // 🔍 PROBAR CONEXIÓN CON DETALLES
  Future<Map<String, dynamic>> testConnectionWithDetails(String ip) async {
    try {
      final testUrl = 'http://$ip:3000';
      print('🔍 Probando conexión detallada con $testUrl...');

      final response = await http
          .get(Uri.parse('$testUrl/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Conexión exitosa',
          'serverUrl': testUrl,
          'status': data['status'] ?? 'ok',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'success': false,
          'message': 'Servidor respondió con código ${response.statusCode}',
          'serverUrl': testUrl,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: $e',
        'serverUrl': 'http://$ip:3000',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // 📥 CARGAR CONFIGURACIÓN DESDE EL SERVIDOR
  Future<bool> loadConfigFromServer() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.serverUrl}/config/global'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final config = data['config'] ?? {};

        // Actualizar configuración local con datos del servidor
        _currentModel = config['model'] ?? _currentModel;
        _enableReports = config['enableReports'] ?? _enableReports;
        _enablePopularDishes =
            config['enablePopularDishes'] ?? _enablePopularDishes;
        _enableMenuManagement =
            config['enableMenuManagement'] ?? _enableMenuManagement;
        _showSystemMessages =
            config['showSystemMessages'] ?? _showSystemMessages;
        _debugMode = config['debugMode'] ?? _debugMode;

        await saveConfig();
        print('✅ Configuración cargada desde el servidor');
        return true;
      }
    } catch (e) {
      print('⚠️ No se pudo cargar configuración del servidor: $e');
    }
    return false;
  }

  // 🔄 FORZAR SINCRONIZACIÓN CON EL SERVIDOR
  Future<bool> forceSyncWithServer() async {
    try {
      // Primero cargar configuración del servidor
      await loadConfigFromServer();

      // Luego enviar nuestra configuración actual
      final success = await updateServerConfig(
        model: _currentModel,
        enableReports: _enableReports,
        enablePopularDishes: _enablePopularDishes,
        enableMenuManagement: _enableMenuManagement,
        showSystemMessages: _showSystemMessages,
        debugMode: _debugMode,
      );

      if (success) {
        print('✅ Sincronización forzada completada');
        return true;
      }
    } catch (e) {
      print('❌ Error en sincronización forzada: $e');
    }
    return false;
  }

  // 📊 OBTENER ESTADO DE SINCRONIZACIÓN
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final serverStatus = await getServerStatus();
      final isConnected = serverStatus?['connected'] ?? false;

      return {
        'synchronized': isConnected,
        'lastSync': DateTime.now().toIso8601String(),
        'serverConnected': isConnected,
        'localConfig': toMap(),
      };
    } catch (e) {
      return {
        'synchronized': false,
        'lastSync': null,
        'serverConnected': false,
        'error': e.toString(),
      };
    }
  }

  // 🗺️ CONVERTIR A MAPA
  Map<String, dynamic> toMap() {
    return {
      'serverIp': serverIp,
      'serverUrl': serverUrl,
      'currentModel': _currentModel,
      'enableReports': _enableReports,
      'enablePopularDishes': _enablePopularDishes,
      'enableMenuManagement': _enableMenuManagement,
      'showSystemMessages': _showSystemMessages,
      'debugMode': _debugMode,
    };
  }
}
