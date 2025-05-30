import 'dart:convert';
import 'package:http/http.dart' as http;

class RecommendationsService {
  static const String baseUrl = 'http://192.168.1.121:3000';

  // Obtener historial de pedidos del cliente
  static Future<Map<String, dynamic>> getClientHistory(
    int clientId, {
    int limit = 20,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/pedidos/cliente/$clientId/historial?limit=$limit',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error':
              errorData['error'] ?? 'Error al obtener historial del cliente',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Obtener recomendaciones personalizadas
  static Future<Map<String, dynamic>> getPersonalizedRecommendations(
    int clientId, {
    int limit = 5,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/pedidos/cliente/$clientId/recomendaciones?limit=$limit',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Error al obtener recomendaciones',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Obtener estadísticas del cliente
  static Future<Map<String, dynamic>> getClientStatistics(int clientId) async {
    try {
      final url = Uri.parse('$baseUrl/pedidos/cliente/$clientId/estadisticas');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error':
              errorData['error'] ?? 'Error al obtener estadísticas del cliente',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Obtener platos populares generales (usando el endpoint existente)
  static Future<Map<String, dynamic>> getPopularDishes({
    int limit = 5,
    String? categoria,
  }) async {
    try {
      String url = '$baseUrl/pedidos/stats/mas-vendidos?limit=$limit';
      if (categoria != null && categoria.isNotEmpty) {
        url += '&categoria=$categoria';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Error al obtener platos populares',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Obtener recomendaciones mixtas (populares + personalizadas)
  static Future<Map<String, dynamic>> getMixedRecommendations(
    int clientId, {
    int limit = 5,
  }) async {
    try {
      // Obtener tanto las recomendaciones personalizadas como las populares
      final futures = await Future.wait([
        getPersonalizedRecommendations(clientId, limit: limit),
        getPopularDishes(limit: limit),
      ]);

      final personalizedResult = futures[0];
      final popularResult = futures[1];

      if (!personalizedResult['success'] && !popularResult['success']) {
        return {
          'success': false,
          'error': 'Error al obtener recomendaciones mixtas',
        };
      }

      Map<String, dynamic> mixedData = {
        'clienteId': clientId,
        'personalizadas':
            personalizedResult['success'] ? personalizedResult['data'] : null,
        'populares': popularResult['success'] ? popularResult['data'] : null,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Si el cliente es nuevo y no tiene historial, priorizar platos populares
      if (personalizedResult['success'] &&
          personalizedResult['data']['recomendaciones_unificadas'].isEmpty) {
        mixedData['recomendacion_tipo'] = 'nuevo_cliente';
        mixedData['mensaje'] =
            '¡Bienvenido! Te recomendamos estos platos populares para empezar:';
      } else if (personalizedResult['success']) {
        mixedData['recomendacion_tipo'] = 'cliente_recurrente';
        mixedData['mensaje'] = 'Basado en tus gustos, te recomendamos:';
      } else {
        mixedData['recomendacion_tipo'] = 'solo_populares';
        mixedData['mensaje'] = 'Estos son nuestros platos más populares:';
      }

      return {'success': true, 'data': mixedData};
    } catch (e) {
      return {
        'success': false,
        'error': 'Error al obtener recomendaciones mixtas: $e',
      };
    }
  }
}
