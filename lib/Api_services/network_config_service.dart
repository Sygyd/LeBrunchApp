import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NetworkConfigService {
  static final NetworkConfigService _instance =
      NetworkConfigService._internal();
  factory NetworkConfigService() => _instance;
  NetworkConfigService._internal();

  String? _serverIp;
  String? _serverPort;
  bool _isConfigured = false;

  String get serverIp => _serverIp ?? '192.168.1.121';
  String get serverPort => _serverPort ?? '3000';
  String get baseUrl => 'http://$serverIp:$serverPort';
  bool get isConfigured => _isConfigured;

  Future<bool> initialize() async {
    print('🌐 NetworkConfigService: Iniciando configuración de red...');

    if (await _loadFromPreferences()) {
      print('✅ Configuración cargada desde preferencias: $baseUrl');
      return true;
    }

    if (await _loadFromEnv()) {
      print('✅ Configuración cargada desde .env: $baseUrl');
      await _saveToPreferences();
      return true;
    }

    if (await _autoDetectServer()) {
      print('✅ Servidor auto-detectado: $baseUrl');
      await _saveToPreferences();
      return true;
    }

    _serverIp = '192.168.1.121';
    _serverPort = '3000';
    _isConfigured = false;
    print('⚠️ Usando configuración por defecto: $baseUrl');
    return false;
  }

  Future<bool> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('network_server_ip');
      final savedPort = prefs.getString('network_server_port');

      if (savedIp != null && savedPort != null) {
        if (await _testConnection(savedIp, savedPort)) {
          _serverIp = savedIp;
          _serverPort = savedPort;
          _isConfigured = true;
          return true;
        } else {
          print('⚠️ Configuración guardada no responde, limpiando...');
          await _clearSavedConfig();
        }
      }
    } catch (e) {
      print('❌ Error cargando desde preferencias: $e');
    }
    return false;
  }

  Future<bool> _loadFromEnv() async {
    try {
      final envIp = dotenv.get('NODE_SERVER_IP', fallback: '');
      final envPort = dotenv.get('NODE_SERVER_PORT', fallback: '');

      if (envIp.isNotEmpty && envPort.isNotEmpty) {
        if (await _testConnection(envIp, envPort)) {
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

  Future<bool> _autoDetectServer() async {
    print('🔍 Buscando servidor en la red local...');

    final localIpRange = await _getLocalIpRange();
    if (localIpRange == null) {
      print('❌ No se pudo determinar el rango de IP local');
      return false;
    }

    print('🔍 Buscando en rango: $localIpRange');

    final portsToCheck = ['3000', '8000', '5000'];
    final commonIps = _generateCommonIps(localIpRange);

    for (final port in portsToCheck) {
      for (final ip in commonIps) {
        if (await _testConnection(ip, port)) {
          _serverIp = ip;
          _serverPort = port;
          _isConfigured = true;
          print('🎯 Servidor encontrado en: $ip:$port');
          return true;
        }
      }
    }

    return false;
  }

  Future<String?> _getLocalIpRange() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;
            if (ip.startsWith('192.168.') ||
                ip.startsWith('10.') ||
                ip.startsWith('172.')) {
              final parts = ip.split('.');
              if (parts.length >= 3) {
                return '${parts[0]}.${parts[1]}.${parts[2]}';
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

  List<String> _generateCommonIps(String baseRange) {
    final commonIps = <String>[];
    final commonEndings = [1, 100, 101, 102, 110, 111, 121, 200, 201, 250];

    for (final ending in commonEndings) {
      commonIps.add('$baseRange.$ending');
    }

    return commonIps;
  }

  Future<bool> _testConnection(String ip, String port) async {
    try {
      print('🔍 Probando conexión: $ip:$port');

      final response = await http
          .get(
            Uri.parse('http://$ip:$port/status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 2));

      final isValid = response.statusCode == 200;
      if (isValid) {
        print('✅ Conexión exitosa: $ip:$port');
      }
      return isValid;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('network_server_ip', _serverIp!);
      await prefs.setString('network_server_port', _serverPort!);
      await prefs.setString(
        'network_last_updated',
        DateTime.now().toIso8601String(),
      );
      print('💾 Configuración de red guardada');
    } catch (e) {
      print('❌ Error guardando configuración: $e');
    }
  }

  Future<void> _clearSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('network_server_ip');
      await prefs.remove('network_server_port');
      await prefs.remove('network_last_updated');
    } catch (e) {
      print('❌ Error limpiando configuración: $e');
    }
  }

  Future<bool> updateServerConfig(String ip, String port) async {
    print('🔄 Actualizando configuración manualmente: $ip:$port');

    if (await _testConnection(ip, port)) {
      _serverIp = ip;
      _serverPort = port;
      _isConfigured = true;
      await _saveToPreferences();
      print('✅ Configuración actualizada exitosamente');
      return true;
    } else {
      print('❌ No se pudo conectar con la nueva configuración');
      return false;
    }
  }

  Future<bool> refreshConfiguration() async {
    print('🔄 Refrescando configuración de red...');
    await _clearSavedConfig();
    return await initialize();
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
      'lastChecked': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> checkServerStatus() async {
    final startTime = DateTime.now();

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        return {
          'status': 'connected',
          'responseTime': responseTime,
          'serverResponse': response.body,
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
}
