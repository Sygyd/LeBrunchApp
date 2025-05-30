import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Servicio para manejar operaciones de soft delete
/// Proporciona funcionalidades para restaurar elementos eliminados
/// y obtener listas de elementos eliminados
class SoftDeleteService {
  // Método para obtener la URL base del servidor
  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp =
        prefs.getString('serverIp') ??
        dotenv.env['NODE_SERVER_IP'] ??
        '192.168.1.121';
    final serverPort = dotenv.env['NODE_SERVER_PORT'] ?? '3000';
    final baseUrl = 'http://$serverIp:$serverPort';
    print('🌐 SoftDeleteService - URL base del servidor: $baseUrl');
    return baseUrl;
  }

  // Método para obtener el token de autorización
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Método para obtener headers con autorización
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // =====================================================
  // OPERACIONES PARA MENÚ
  // =====================================================

  /// Obtener lista de platos eliminados
  Future<List<Map<String, dynamic>>> getDeletedDishes() async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getAuthHeaders();

      print('🗑️ SoftDeleteService: Obteniendo platos eliminados...');

      final response = await http.get(
        Uri.parse('$baseUrl/menu/deleted/list'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final deletedItems = List<Map<String, dynamic>>.from(
          data['deletedItems'] ?? [],
        );

        print(
          '✅ SoftDeleteService: ${deletedItems.length} platos eliminados obtenidos',
        );
        return deletedItems;
      } else {
        print(
          '❌ SoftDeleteService: Error al obtener platos eliminados: ${response.statusCode}',
        );
        throw Exception(
          'Error al obtener platos eliminados: ${response.statusCode}',
        );
      }
    } catch (e) {
      print(
        '❌ SoftDeleteService: Error de conexión al obtener platos eliminados: $e',
      );
      throw Exception('Error de conexión: $e');
    }
  }

  /// Restaurar un plato eliminado
  Future<bool> restoreDish(String dishId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getAuthHeaders();

      print('🔄 SoftDeleteService: Restaurando plato ID: $dishId');

      final response = await http.patch(
        Uri.parse('$baseUrl/menu/$dishId/restore'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        print('✅ SoftDeleteService: Plato $dishId restaurado exitosamente');
        return true;
      } else {
        print(
          '❌ SoftDeleteService: Error al restaurar plato: ${response.statusCode}',
        );
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error al restaurar plato');
      }
    } catch (e) {
      print('❌ SoftDeleteService: Error al restaurar plato: $e');
      throw Exception('Error al restaurar plato: $e');
    }
  }

  // =====================================================
  // OPERACIONES PARA USUARIOS
  // =====================================================

  /// Obtener lista de usuarios eliminados
  Future<List<Map<String, dynamic>>> getDeletedUsers() async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getAuthHeaders();

      print('🗑️ SoftDeleteService: Obteniendo usuarios eliminados...');

      final response = await http.get(
        Uri.parse('$baseUrl/users/deleted/list'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final deletedUsers = List<Map<String, dynamic>>.from(
          data['deletedUsers'] ?? [],
        );

        print(
          '✅ SoftDeleteService: ${deletedUsers.length} usuarios eliminados obtenidos',
        );
        return deletedUsers;
      } else {
        print(
          '❌ SoftDeleteService: Error al obtener usuarios eliminados: ${response.statusCode}',
        );
        throw Exception(
          'Error al obtener usuarios eliminados: ${response.statusCode}',
        );
      }
    } catch (e) {
      print(
        '❌ SoftDeleteService: Error de conexión al obtener usuarios eliminados: $e',
      );
      throw Exception('Error de conexión: $e');
    }
  }

  /// Restaurar un usuario eliminado
  Future<bool> restoreUser(String userId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getAuthHeaders();

      print('🔄 SoftDeleteService: Restaurando usuario ID: $userId');

      final response = await http.patch(
        Uri.parse('$baseUrl/users/$userId/restore'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        print('✅ SoftDeleteService: Usuario $userId restaurado exitosamente');
        return true;
      } else {
        print(
          '❌ SoftDeleteService: Error al restaurar usuario: ${response.statusCode}',
        );
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Error al restaurar usuario');
      }
    } catch (e) {
      print('❌ SoftDeleteService: Error al restaurar usuario: $e');
      throw Exception('Error al restaurar usuario: $e');
    }
  }

  // =====================================================
  // MÉTODOS UTILITARIOS
  // =====================================================

  /// Formatear fecha de eliminación para mostrar en UI
  String formatDeletedDate(String? deletedAt) {
    if (deletedAt == null) return 'Fecha no disponible';

    try {
      final date = DateTime.parse(deletedAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'Hace unos momentos';
      }
    } catch (e) {
      print('❌ Error al formatear fecha: $e');
      return 'Fecha inválida';
    }
  }

  /// Obtener nombre del usuario que eliminó el elemento
  String getDeletedByName(Map<String, dynamic> item) {
    final deletedByName = item['deleted_by_name'];
    final deletedByLastname = item['deleted_by_lastname'];

    if (deletedByName != null && deletedByLastname != null) {
      return '$deletedByName $deletedByLastname';
    } else if (deletedByName != null) {
      return deletedByName;
    } else {
      return 'Usuario desconocido';
    }
  }

  /// Obtener el nombre del rol en español
  String getRoleName(int rol) {
    switch (rol) {
      case 0:
        return 'Administrador';
      case 1:
        return 'Cliente';
      case 2:
        return 'Cocinero';
      case 3:
        return 'Barista';
      default:
        return 'Rol desconocido';
    }
  }

  /// Obtener estadísticas de elementos eliminados
  Future<Map<String, int>> getDeletedItemsStats() async {
    try {
      final deletedDishes = await getDeletedDishes();
      final deletedUsers = await getDeletedUsers();

      return {
        'deletedDishes': deletedDishes.length,
        'deletedUsers': deletedUsers.length,
        'total': deletedDishes.length + deletedUsers.length,
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return {'deletedDishes': 0, 'deletedUsers': 0, 'total': 0};
    }
  }
}
