import 'dart:convert';
import 'package:http/http.dart' as http;
import 'network_config_service.dart';

class PasswordResetService {
  static final String baseUrl = NetworkConfigService().baseUrl;

  /// Verificar credenciales del usuario (email + cédula)
  static Future<Map<String, dynamic>> verifyCredentials({
    required String email,
    required String cedula,
  }) async {
    try {
      print('🔍 Verificando credenciales para: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/verify-reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'cedula': cedula.trim()}),
      );

      print('📡 Respuesta del servidor: ${response.statusCode}');
      print('📄 Cuerpo de respuesta: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'userId': data['userId'],
          'message':
              data['message'] ?? 'Credenciales verificadas correctamente',
        };
      } else {
        return {
          'success': false,
          'message':
              data['message'] ?? 'No se encontró una cuenta con esos datos',
        };
      }
    } catch (e) {
      print('❌ Error en verificación de credenciales: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Cambiar la contraseña del usuario
  static Future<Map<String, dynamic>> resetPassword({
    required int userId,
    required String newPassword,
  }) async {
    try {
      print('🔐 Cambiando contraseña para usuario ID: $userId');

      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'newPassword': newPassword}),
      );

      print('📡 Respuesta del servidor: ${response.statusCode}');
      print('📄 Cuerpo de respuesta: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Contraseña actualizada exitosamente',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Error al actualizar la contraseña',
        };
      }
    } catch (e) {
      print('❌ Error al cambiar contraseña: $e');
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Validar formato de email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Validar formato de cédula
  static bool isValidCedula(String cedula) {
    return cedula.length >= 5 &&
        cedula.length <= 10 &&
        RegExp(r'^\d+$').hasMatch(cedula);
  }

  /// Validar formato de contraseña
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}
