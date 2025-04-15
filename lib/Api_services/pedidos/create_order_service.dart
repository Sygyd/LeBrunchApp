import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/cart_item.dart';

class CreateOrderService {
  final String baseUrl = 'http://192.168.1.121:3000';

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
              // Manejar caso donde id no sea un entero válido
              int itemId;
              try {
                itemId = int.parse(item.id);
              } catch (e) {
                print(
                  '❌ Error al convertir ID de plato: ${item.id}. Error: $e',
                );
                // Usar un valor alternativo o reportar el error
                throw Exception('ID de plato inválido: ${item.id}');
              }

              return {
                'idplato': itemId,
                'cantidad': item.quantity,
                'precio_unitario': item.price,
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
      print('🔍 FALLBACK: Intentando método alternativo...');

      // 1. Crear el pedido principal
      final orderQuery = {
        'query':
            "INSERT INTO pedidos (idpersona, estado, fecha) VALUES ($userId, 'pendiente', NOW()) RETURNING idpedido",
      };

      print(
        '🔍 FALLBACK: Consulta SQL para crear pedido: ${orderQuery['query']}',
      );
      print('🔍 FALLBACK: URL para consulta SQL: $baseUrl/db/query');

      final orderResponse = await http.post(
        Uri.parse('$baseUrl/db/query'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(orderQuery),
      );

      print(
        '🔍 FALLBACK: Código de estado de respuesta: ${orderResponse.statusCode}',
      );
      print('🔍 FALLBACK: Cuerpo de respuesta: ${orderResponse.body}');

      if (orderResponse.statusCode != 200) {
        return {
          'success': false,
          'message':
              'Error al crear el pedido en la base de datos: status ${orderResponse.statusCode}',
        };
      }

      final orderData = json.decode(orderResponse.body);
      if (orderData['result'] == null || orderData['result'].isEmpty) {
        return {
          'success': false,
          'message': 'No se pudo obtener el ID del pedido creado',
        };
      }

      final orderId = orderData['result'][0]['idpedido'];
      print('🔍 FALLBACK: Pedido creado con ID: $orderId');

      // 2. Insertar los detalles del pedido
      print('🔍 FALLBACK: Insertando ${items.length} items...');

      for (var item in items) {
        int itemId;
        try {
          itemId = int.parse(item.id);
        } catch (e) {
          print(
            '❌ FALLBACK: Error al convertir ID de plato: ${item.id}. Error: $e',
          );
          continue; // Saltar este item si hay error con el ID
        }

        final detailQuery = {
          'query':
              "INSERT INTO pedido_detalle (idpedido, idplato, cantidad, precio_unitario, notas) VALUES ($orderId, $itemId, ${item.quantity}, ${item.price}, '${item.notes ?? ''}')",
        };

        print(
          '🔍 FALLBACK: Consulta SQL para insertar item: ${detailQuery['query']}',
        );

        final detailResponse = await http.post(
          Uri.parse('$baseUrl/db/query'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(detailQuery),
        );

        if (detailResponse.statusCode != 200) {
          print(
            '❌ FALLBACK: Error al insertar detalle: ${detailResponse.body}',
          );
          // Continuar con otros items aunque haya error
        } else {
          print('✅ FALLBACK: Item insertado correctamente');
        }
      }

      print('✅ FALLBACK: Pedido creado exitosamente con ID: $orderId');
      return {
        'success': true,
        'message': 'Pedido creado con éxito (método alternativo)',
        'orderData': {'idpedido': orderId},
      };
    } catch (e) {
      print('❌ FALLBACK: Error en fallback de creación de pedido: $e');
      return {'success': false, 'message': 'Error al crear el pedido: $e'};
    }
  }
}
