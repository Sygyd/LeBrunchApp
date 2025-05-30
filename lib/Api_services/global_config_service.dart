import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GlobalConfigService {
  static final GlobalConfigService _instance = GlobalConfigService._internal();
  factory GlobalConfigService() => _instance;
  GlobalConfigService._internal();

  // Configuración por defecto
  String _serverIp = "192.168.1.121";
  String _currentModel = "gemini-2.0-flash";
  bool _enableReports = true;
  bool _enablePopularDishes = true;
  bool _enableMenuManagement = true;
  bool _showSystemMessages = true;
  bool _debugMode = false;

  // Getters
  String get serverIp => _serverIp;
  String get currentModel => _currentModel;
  bool get enableReports => _enableReports;
  bool get enablePopularDishes => _enablePopularDishes;
  bool get enableMenuManagement => _enableMenuManagement;
  bool get showSystemMessages => _showSystemMessages;
  bool get debugMode => _debugMode;

  // Cargar configuración desde SharedPreferences
  Future<void> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _serverIp = prefs.getString('global_server_ip') ?? "192.168.1.121";
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
        '🔧 GlobalConfig: Configuración cargada - IP: $_serverIp, Modelo: $_currentModel',
      );
    } catch (e) {
      print('❌ Error al cargar configuración global: $e');
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
      final url = Uri.parse('http://$_serverIp:3000/mcp/status');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('❌ Error al obtener estado del servidor: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener estado: $e');
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
    try {
      final ipToTest = testIp ?? _serverIp;
      final url = Uri.parse('http://$ipToTest:3000/status');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error al probar conexión: $e');
      return false;
    }
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
}
