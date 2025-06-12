import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'network_config_service.dart';

class MCPService {
  static final MCPService _instance = MCPService._internal();
  factory MCPService() => _instance;
  MCPService._internal();

  // Usar un getter en lugar de variable final para evitar NotInitializedError
  String get _baseUrl => _buildBaseUrl();

  // Método para construir la URL base usando NetworkConfigService
  String _buildBaseUrl() {
    try {
      final networkConfig = NetworkConfigService();
      return networkConfig.baseUrl;
    } catch (e) {
      print('⚠️ Error al acceder a NetworkConfigService en MCPService: $e');
      // Fallback a dotenv y luego a valores por defecto
      try {
        final ip = dotenv.get(
          'NODE_SERVER_IP',
          fallback: NetworkConfigService().serverIp,
        );
        final port = dotenv.get('NODE_SERVER_PORT', fallback: '3000');
        return 'http://$ip:$port';
      } catch (dotenvError) {
        return NetworkConfigService().baseUrl;
      }
    }
  }

  /// Obtiene el estado actual del sistema MCP
  Future<Map<String, dynamic>?> getMCPStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/mcp/status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('❌ Error al obtener estado MCP: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener estado MCP: $e');
      return null;
    }
  }

  /// Valida una respuesta del asistente
  Future<Map<String, dynamic>?> validateResponse(String response) async {
    try {
      final requestBody = jsonEncode({'response': response});

      final httpResponse = await http
          .post(
            Uri.parse('$_baseUrl/mcp/validate'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 10));

      if (httpResponse.statusCode == 200) {
        return jsonDecode(httpResponse.body) as Map<String, dynamic>;
      } else {
        print('❌ Error al validar respuesta: ${httpResponse.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión al validar respuesta: $e');
      return null;
    }
  }

  /// Verifica la conectividad con el servidor
  Future<bool> checkServerConnectivity() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/status'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error de conectividad del servidor: $e');
      return false;
    }
  }

  /// Obtiene métricas administrativas
  Future<Map<String, dynamic>?> getAdminMetrics() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/admin/metrics'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('❌ Error al obtener métricas admin: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener métricas admin: $e');
      return null;
    }
  }
}
