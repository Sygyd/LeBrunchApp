import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MCPService {
  static final MCPService _instance = MCPService._internal();
  factory MCPService() => _instance;
  MCPService._internal();

  final String _baseUrl =
      'http://${dotenv.get('NODE_SERVER_IP', fallback: '192.168.1.121')}:${dotenv.get('NODE_SERVER_PORT', fallback: '3000')}';

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
