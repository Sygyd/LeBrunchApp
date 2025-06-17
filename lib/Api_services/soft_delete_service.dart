import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config.dart'; // Usar directamente la configuración estática

/// Servicio para manejar operaciones de soft delete
/// Proporciona funcionalidades para restaurar elementos eliminados
/// y obtener listas de elementos eliminados
class SoftDeleteService {
  // Método para obtener la URL base del servidor
  Future<String> _getBaseUrl() async {
    try {
      // Usar la configuración estática como primera opción
      print(
        '🌐 SoftDeleteService - Usando configuración estática: ${AppConfig.serverUrl}',
      );
      return AppConfig.serverUrl;
    } catch (e) {
      print('❌ Error al obtener URL base: $e');
      // Fallback solo en caso de error crítico
      return 'http://192.168.1.85:3000';
    }
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
      print('🌐 SoftDeleteService: URL: $baseUrl/menu/deleted/list');

      final response = await http
          .get(Uri.parse('$baseUrl/menu/deleted/list'), headers: headers)
          .timeout(const Duration(seconds: 10));

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
          '❌ SoftDeleteService: Error del servidor al obtener platos eliminados: ${response.statusCode}',
        );
        print('📝 SoftDeleteService: Respuesta del servidor: ${response.body}');
        throw Exception(
          'Error del servidor (${response.statusCode}): ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print(
        '❌ SoftDeleteService: Error crítico al obtener platos eliminados: $e',
      );

      // Proporcionar un mensaje más específico basado en el tipo de error
      if (e.toString().contains('NotInitializedError')) {
        throw Exception(
          'Servicio no inicializado. Por favor, reinicia la aplicación.',
        );
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Tiempo de espera agotado. Verifica tu conexión a internet.',
        );
      } else if (e.toString().contains('SocketException')) {
        throw Exception(
          'Sin conexión al servidor. Verifica que el servidor esté funcionando.',
        );
      } else {
        throw Exception('Error de conexión: ${e.toString()}');
      }
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
      print('🌐 SoftDeleteService: URL: $baseUrl/users/deleted/list');

      final response = await http
          .get(Uri.parse('$baseUrl/users/deleted/list'), headers: headers)
          .timeout(const Duration(seconds: 10));

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
          '❌ SoftDeleteService: Error del servidor al obtener usuarios eliminados: ${response.statusCode}',
        );
        print('📝 SoftDeleteService: Respuesta del servidor: ${response.body}');
        throw Exception(
          'Error del servidor (${response.statusCode}): ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print(
        '❌ SoftDeleteService: Error crítico al obtener usuarios eliminados: $e',
      );

      // Proporcionar un mensaje más específico basado en el tipo de error
      if (e.toString().contains('NotInitializedError')) {
        throw Exception(
          'Servicio no inicializado. Por favor, reinicia la aplicación.',
        );
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Tiempo de espera agotado. Verifica tu conexión a internet.',
        );
      } else if (e.toString().contains('SocketException')) {
        throw Exception(
          'Sin conexión al servidor. Verifica que el servidor esté funcionando.',
        );
      } else {
        throw Exception('Error de conexión: ${e.toString()}');
      }
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
        return 'Super Admin';
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

  /// Eliminar usuario permanentemente con todas sus dependencias
  /// ⚠️ CUIDADO: Esta es una eliminación PERMANENTE, no soft delete
  Future<bool> permanentlyDeleteUserWithDependencies(String userId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getAuthHeaders();

      print(
        '🗑️ SoftDeleteService: Eliminación permanente de usuario ID: $userId',
      );
      print(
        '⚠️ ADVERTENCIA: Esta operación eliminará TODOS los datos relacionados',
      );

      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId/permanent-delete'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        print('✅ SoftDeleteService: Usuario $userId eliminado permanentemente');
        return true;
      } else {
        print(
          '❌ SoftDeleteService: Error al eliminar permanentemente: ${response.statusCode}',
        );
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Error al eliminar usuario permanentemente',
        );
      }
    } catch (e) {
      print('❌ SoftDeleteService: Error en eliminación permanente: $e');
      throw Exception('Error al eliminar usuario permanentemente: $e');
    }
  }

  /// Verificar dependencias de un usuario antes de eliminarlo
  Future<Map<String, dynamic>> checkUserDependencies(String userId) async {
    try {
      final baseUrl = await _getBaseUrl();
      final headers = await _getAuthHeaders();

      print(
        '🔍 SoftDeleteService: Verificando dependencias del usuario ID: $userId',
      );

      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/dependencies'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '✅ SoftDeleteService: Dependencias verificadas para usuario $userId',
        );
        return {
          'hasPedidos': data['hasPedidos'] ?? false,
          'pedidosCount': data['pedidosCount'] ?? 0,
          'pedidosIds': data['pedidosIds'] ?? [],
          'canDelete': data['canDelete'] ?? false,
          'warnings': data['warnings'] ?? [],
        };
      } else {
        print(
          '❌ SoftDeleteService: Error al verificar dependencias: ${response.statusCode}',
        );
        return {
          'hasPedidos': false,
          'pedidosCount': 0,
          'pedidosIds': [],
          'canDelete': false,
          'warnings': ['Error al verificar dependencias'],
        };
      }
    } catch (e) {
      print('❌ SoftDeleteService: Error al verificar dependencias: $e');
      return {
        'hasPedidos': false,
        'pedidosCount': 0,
        'pedidosIds': [],
        'canDelete': false,
        'warnings': ['Error de conexión al verificar dependencias'],
      };
    }
  }
}
