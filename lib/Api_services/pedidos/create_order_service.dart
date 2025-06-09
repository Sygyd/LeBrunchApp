import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/cart_item.dart';
import '../network_config_service.dart';

class CreateOrderService {
  final String baseUrl = NetworkConfigService().baseUrl;

  /// Crear un nuevo pedido en la base de datos
  Future<Map<String, dynamic>> createOrder(List<CartItem> items) async {
    try {
      // Obtener el ID del usuario desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      print('🔍 Creando pedido para usuario ID: $userId');
      print('🔍 Número de items en el carrito: ${items.length}');

      // Preparar los datos del pedido
      final orderData = {
        'idpersona': userId,
        'estado': 'pendiente',
        'items':
            items.map((item) {
              // Manejar IDs únicos que pueden tener formato "ID_HASH" para items con notas
              int itemId;
              String originalId = item.id;

              // Si el ID contiene un guión bajo, extraer solo la parte antes del guión
              if (originalId.contains('_')) {
                originalId = originalId.split('_')[0];
                print(
                  '🔧 ID único detectado: ${item.id} -> ID original: $originalId',
                );
              }

              try {
                itemId = int.parse(originalId);
                print('✅ ID de plato procesado exitosamente: $itemId');
              } catch (e) {
                print(
                  '❌ Error al convertir ID de plato: $originalId (ID completo: ${item.id}). Error: $e',
                );
                // Usar un valor alternativo o reportar el error
                throw Exception(
                  'ID de plato inválido: $originalId (original: ${item.id})',
                );
              }

              return {
                'idplato': itemId,
                'cantidad': item.quantity,
                'notas': item.notes ?? '',
              };
            }).toList(),
      };

      print('🔍 URL de la petición: $baseUrl/pedidos');
      print('🔍 Datos a enviar: ${json.encode(orderData)}');

      // Enviar la solicitud al servidor
      final response = await http.post(
        Uri.parse('$baseUrl/pedidos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );

      print('🔍 Código de estado de respuesta: ${response.statusCode}');
      print('🔍 Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 201) {
        // El pedido se creó correctamente
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Pedido creado con éxito',
          'orderData': data,
        };
      } else if (response.statusCode == 400) {
        // Error de validación
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Error al crear el pedido',
        };
      } else if (response.statusCode == 404) {
        // Si la ruta no se encuentra, intentar con la ruta directa
        print(
          '⚠️ La ruta /pedidos no fue encontrada. Intentando con /pedidos-direct...',
        );
        final directResponse = await http.post(
          Uri.parse('$baseUrl/pedidos-direct'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(orderData),
        );

        print(
          '🔍 Código de estado de respuesta directa: ${directResponse.statusCode}',
        );
        print('🔍 Cuerpo de respuesta directa: ${directResponse.body}');

        if (directResponse.statusCode == 201) {
          // El pedido se creó correctamente
          final data = json.decode(directResponse.body);
          return {
            'success': true,
            'message': 'Pedido creado con éxito (ruta directa)',
            'orderData': data,
          };
        } else {
          // Si tampoco funciona la ruta directa, usar el fallback
          return await _createOrderFallback(items);
        }
      } else {
        // Error del servidor
        return {
          'success': false,
          'message': 'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error al crear pedido: $e');

      // Intentar método alternativo de creación de pedido directo a la BD
      return await _createOrderFallback(items);
    }
  }

  /// Método alternativo para crear un pedido directamente en la BD
  Future<Map<String, dynamic>> _createOrderFallback(
    List<CartItem> items,
  ) async {
    try {
      // Obtener el ID del usuario desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        throw Exception('Usuario no autenticado');
      }

      print('🔍 FALLBACK: Creando pedido para usuario ID: $userId');
      print('🔍 FALLBACK: Usando endpoint directo /pedidos-direct...');

      // Preparar los datos del pedido igual que en el método principal
      final orderData = {
        'idpersona': userId,
        'estado': 'pendiente',
        'items':
            items.map((item) {
              // Manejar IDs únicos que pueden tener formato "ID_HASH" para items con notas
              int itemId;
              String originalId = item.id;

              // Si el ID contiene un guión bajo, extraer solo la parte antes del guión
              if (originalId.contains('_')) {
                originalId = originalId.split('_')[0];
                print(
                  '🔧 ID único detectado: ${item.id} -> ID original: $originalId',
                );
              }

              try {
                itemId = int.parse(originalId);
                print('✅ ID de plato procesado exitosamente: $itemId');
              } catch (e) {
                print(
                  '❌ FALLBACK: Error al convertir ID de plato: $originalId (ID completo: ${item.id}). Error: $e',
                );
                // Usar un valor alternativo o reportar el error
                throw Exception(
                  'ID de plato inválido: $originalId (original: ${item.id})',
                );
              }

              return {
                'idplato': itemId,
                'cantidad': item.quantity,
                'notas': item.notes ?? '',
              };
            }).toList(),
      };

      print('🔍 FALLBACK: URL de la petición: $baseUrl/pedidos-direct');
      print('🔍 FALLBACK: Datos a enviar: ${json.encode(orderData)}');

      // Enviar la solicitud al endpoint directo
      final response = await http.post(
        Uri.parse('$baseUrl/pedidos-direct'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderData),
      );

      print(
        '🔍 FALLBACK: Código de estado de respuesta: ${response.statusCode}',
      );
      print('🔍 FALLBACK: Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 201) {
        // El pedido se creó correctamente
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': 'Pedido creado con éxito (método fallback)',
          'orderData': data,
        };
      } else {
        return {
          'success': false,
          'message':
              'Error en fallback: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      print('❌ FALLBACK: Error al crear pedido: $e');
      return {
        'success': false,
        'message': 'Error al crear el pedido (fallback): $e',
      };
    }
  }
}
