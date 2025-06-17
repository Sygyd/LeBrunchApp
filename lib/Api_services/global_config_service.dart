import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

// ✅ VERSIÓN MEJORADA CON SINCRONIZACIÓN REAL DE IP Y MODELO ACTUALIZADO
class GlobalConfigService {
  static final GlobalConfigService _instance = GlobalConfigService._internal();
  factory GlobalConfigService() => _instance;
  GlobalConfigService._internal();

  // 👈 CONFIGURACIÓN ACTUALIZADA: Usar AppConfig dinámico
  String get serverIp => AppConfig.serverIp;
  String get serverUrl => AppConfig.serverUrl;

  // Configuración esencial de la app - MODELO ACTUALIZADO SEGÚN REQUERIMIENTO
  String _currentModel =
      "gemini-2.5-flash-preview-05-20"; // 🔥 MODELO ACTUALIZADO
  bool _enableReports = true;
  bool _enablePopularDishes = true;
  bool _showSystemMessages = true;
  bool _debugMode = false;

  // Getters
  String get currentModel => _currentModel;
  bool get enableReports => _enableReports;
  bool get enablePopularDishes => _enablePopularDishes;
  bool get showSystemMessages => _showSystemMessages;
  bool get debugMode => _debugMode;

  // 🔧 CARGAR CONFIGURACIÓN MEJORADA
  Future<void> loadConfig() async {
    try {
      print('🔧 Cargando configuración mejorada...');

      final prefs = await SharedPreferences.getInstance();

      // Cargar IP guardada y actualizar AppConfig
      final savedIp = prefs.getString('global_server_ip');
      if (savedIp != null && savedIp.isNotEmpty) {
        AppConfig.updateServerIp(savedIp);
        print('🔄 IP cargada desde SharedPreferences: $savedIp');
      }

      print('📍 IP del servidor: ${AppConfig.serverIp}');
      print('🌐 URL del servidor: ${AppConfig.serverUrl}');

      // Cargar configuraciones del asistente con migración automática
      _currentModel =
          prefs.getString('global_gemini_model') ??
          "gemini-2.5-flash-preview-05-20";

      // 🔥 MIGRACIÓN AUTOMÁTICA: Actualizar modelos obsoletos
      if (_currentModel == "gemini-2.0-flash" ||
          _currentModel == "gemini-1.5-flash") {
        final oldModel = _currentModel;
        _currentModel = "gemini-2.5-flash-preview-05-20";
        // Guardar el modelo actualizado inmediatamente
        await prefs.setString('global_gemini_model', _currentModel);
        print(
          '🔄 Modelo migrado automáticamente de "$oldModel" a "$_currentModel"',
        );
      }

      _enableReports = prefs.getBool('global_enable_reports') ?? true;
      _enablePopularDishes =
          prefs.getBool('global_enable_popular_dishes') ?? true;
      _showSystemMessages =
          prefs.getBool('global_show_system_messages') ?? true;
      _debugMode = prefs.getBool('global_debug_mode') ?? false;

      print('✅ Configuración mejorada cargada - Modelo: $_currentModel');
    } catch (e) {
      print('❌ Error al cargar configuración: $e');
    }
  }

  // 💾 GUARDAR CONFIGURACIÓN MEJORADA
  Future<void> saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Guardar IP actual de AppConfig
      await prefs.setString('global_server_ip', AppConfig.serverIp);

      // Guardar configuraciones del asistente
      await prefs.setString('global_gemini_model', _currentModel);
      await prefs.setBool('global_enable_reports', _enableReports);
      await prefs.setBool('global_enable_popular_dishes', _enablePopularDishes);
      await prefs.setBool('global_show_system_messages', _showSystemMessages);
      await prefs.setBool('global_debug_mode', _debugMode);

      print(
        '✅ Configuración guardada - IP: ${AppConfig.serverIp}, Modelo: $_currentModel',
      );
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

  Future<void> updateSystemMessages(bool enabled) async {
    _showSystemMessages = enabled;
    await saveConfig();
  }

  Future<void> updateDebugMode(bool enabled) async {
    _debugMode = enabled;
    await saveConfig();
  }

  // 🔄 MÉTODO MEJORADO PARA ACTUALIZAR IP DEL SERVIDOR
  Future<void> updateServerIp(String newIp) async {
    try {
      // Actualizar AppConfig directamente
      AppConfig.updateServerIp(newIp);

      // Guardar en SharedPreferences
      await saveConfig();

      print('✅ IP del servidor actualizada: $newIp → ${AppConfig.serverUrl}');
    } catch (e) {
      print('❌ Error al actualizar IP del servidor: $e');
    }
  }

  // 🧪 PROBAR CONEXIÓN CON LA IP ACTUAL
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.serverUrl}/status'))
          .timeout(const Duration(seconds: 3));

      final isConnected = response.statusCode == 200;
      print(
        '🔌 Test de conexión a ${AppConfig.serverUrl}: ${isConnected ? "✅ ÉXITO" : "❌ FALLO"}',
      );
      return isConnected;
    } catch (e) {
      print('❌ Error en test de conexión: $e');
      return false;
    }
  }

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
          'currentServerUrl': AppConfig.serverUrl, // Agregar URL actual
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
      'currentServerUrl': AppConfig.serverUrl,
    };
  }

  // 🔧 ACTUALIZAR CONFIGURACIÓN DEL SERVIDOR - VERSIÓN MEJORADA
  Future<bool> updateServerConfig({
    String? serverIp,
    String? model,
    bool? enableReports,
    bool? enablePopularDishes,
    bool? showSystemMessages,
    bool? debugMode,
  }) async {
    try {
      // 1. Actualizar IP PRIMERO si se proporciona
      if (serverIp != null && serverIp.isNotEmpty) {
        await updateServerIp(serverIp);
        print('🔄 IP actualizada en AppConfig: ${AppConfig.serverIp}');
      }

      // 2. Actualizar configuración local
      if (model != null) _currentModel = model;
      if (enableReports != null) _enableReports = enableReports;
      if (enablePopularDishes != null)
        _enablePopularDishes = enablePopularDishes;
      if (showSystemMessages != null) _showSystemMessages = showSystemMessages;
      if (debugMode != null) _debugMode = debugMode;

      // 3. Guardar cambios localmente
      await saveConfig();

      // 4. Intentar sincronizar con el servidor usando la URL actualizada
      try {
        print('🔄 Sincronizando con servidor en: ${AppConfig.serverUrl}');

        final requestBody = <String, dynamic>{};
        if (serverIp != null) requestBody['serverIp'] = serverIp;
        if (model != null) requestBody['model'] = model;
        if (enableReports != null) requestBody['enableReports'] = enableReports;
        if (enablePopularDishes != null)
          requestBody['enablePopularDishes'] = enablePopularDishes;
        if (showSystemMessages != null)
          requestBody['showSystemMessages'] = showSystemMessages;
        if (debugMode != null) requestBody['debugMode'] = debugMode;

        final response = await http
            .post(
              Uri.parse('${AppConfig.serverUrl}/config/global'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(requestBody),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          print('✅ Configuración sincronizada con el servidor exitosamente');
          return true;
        } else {
          print('⚠️ Servidor respondió con código: ${response.statusCode}');
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

  // 📋 OBTENER MAPA DE CONFIGURACIÓN COMPLETA
  Map<String, dynamic> toMap() {
    return {
      'serverIp': AppConfig.serverIp,
      'serverUrl': AppConfig.serverUrl,
      'currentModel': _currentModel,
      'enableReports': _enableReports,
      'enablePopularDishes': _enablePopularDishes,
      'showSystemMessages': _showSystemMessages,
      'debugMode': _debugMode,
      'configInfo': AppConfig.getConfigInfo(),
    };
  }
}
