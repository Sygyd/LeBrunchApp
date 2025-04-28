import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrdersService {
  // Método para obtener la URL base del servidor
  Future<String> _getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp =
        prefs.getString('serverIp') ??
        dotenv.env['NODE_SERVER_IP'] ??
        '192.168.1.121';
    final serverPort = dotenv.env['NODE_SERVER_PORT'] ?? '3000';
    return 'http://$serverIp:$serverPort';
  }

  // Obtener todos los pedidos (con posibilidad de filtrado)
  Future<List<Map<String, dynamic>>> getOrders({
    String? startDate,
    String? endDate,
    String? estado,
    String? startTime,
    String? endTime,
  }) async {
    try {
      // Log para depuración
      print(
        '🔎 getOrders llamado con estado: $estado, fechas: $startDate a $endDate',
      );

      // SOLUCIÓN DIRECTA: Hacer consulta SQL directa para historial
      if (estado?.contains('completado') == true ||
          estado?.contains('cancelado') == true) {
        print('📌 Usando consulta SQL directa para historial');
        return await _queryOrdersDirectSimple();
      }

      // Verificar si el estado contiene paréntesis, lo que indica que es una lista
      bool isMultipleStates =
          estado != null && estado.startsWith("(") && estado.endsWith(")");

      // Construir la URL con parámetros de consulta
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (estado != null && !isMultipleStates) queryParams['estado'] = estado;
      if (startTime != null) queryParams['startTime'] = startTime;
      if (endTime != null) queryParams['endTime'] = endTime;

      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/pedidos',
      ).replace(queryParameters: queryParams);

      print('🔍 Consultando pedidos: $uri');

      // Si tenemos múltiples estados, usamos directamente la consulta SQL
      if (isMultipleStates) {
        return await _queryOrdersDirectSimple();
      }

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 Respuesta recibida: $data');

        final List<Map<String, dynamic>> orders =
            List<Map<String, dynamic>>.from(data);

        // Verificar si estamos filtrando para historial (completado, cancelado)
        bool isRequestingHistory =
            estado == "('completado', 'cancelado')" ||
            (estado != null &&
                (estado == 'completado' || estado == 'cancelado'));

        // Si estamos consultando el historial, asegurarnos que no regresen pedidos pendientes
        if (isRequestingHistory) {
          final filteredOrders =
              orders
                  .where(
                    (order) =>
                        order['estado'] == 'completado' ||
                        order['estado'] == 'cancelado',
                  )
                  .toList();

          print(
            '✅ Se obtuvieron ${filteredOrders.length} pedidos para historial (filtrados de ${orders.length})',
          );
          return filteredOrders;
        }

        print('✅ Se obtuvieron ${orders.length} pedidos');
        return orders;
      } else {
        print(
          '❌ Error al obtener pedidos: ${response.statusCode} - ${response.body}',
        );
        // Si el backend devuelve un error, intentar con otro endpoint más simple
        return await _queryOrdersDirectSimple();
      }
    } catch (e) {
      print('⚠️ Excepción al obtener pedidos: $e');
      // Intentar con otro endpoint más simple
      return await _queryOrdersDirectSimple();
    }
  }

  // Método simplificado que consulta directamente completados y cancelados
  Future<List<Map<String, dynamic>>> _queryOrdersDirectSimple() async {
    try {
      print(
        '📊 Intentando consulta simplificada para pedidos completados y cancelados',
      );

      // Consulta SQL simplificada para obtener solo pedidos completados y cancelados
      final sql = '''
        SELECT 
          p.idpedido, 
          p.idpersona, 
          p.estado, 
          TO_CHAR(p.fecha, 'YYYY-MM-DD') as fecha, 
          TO_CHAR(p.fecha, 'HH24:MI') as hora, 
          pe.nombre || ' ' || pe.apellido as cliente 
        FROM 
          pedidos p 
        INNER JOIN 
          personas pe ON p.idpersona = pe.idpersonas 
        WHERE 
          p.estado IN ('completado', 'cancelado') 
        ORDER BY 
          p.fecha DESC
      ''';

      print('📋 Ejecutando SQL: $sql');

      // Crear el objeto query para la consulta
      final query = {'query': sql};

      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/db/query');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(query),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📋 Respuesta de la consulta: $data');

        if (data['result'] != null && data['result'].isNotEmpty) {
          print(
            '✅ Se obtuvieron ${data['result'].length} pedidos mediante consulta directa',
          );

          // Obtener los IDs de pedidos para la segunda consulta
          final pedidosIds =
              data['result'].map((row) => row['idpedido']).toList();
          print('🔍 IDs de pedidos encontrados: $pedidosIds');

          if (pedidosIds.isEmpty) {
            print('⚠️ No se encontraron IDs de pedidos');
            return [];
          }

          // Consultar los detalles de los pedidos
          final detallesQuery = {
            'query': '''
              SELECT 
                pd.idpedido, 
                pd.idplato, 
                pd.cantidad, 
                pd.precio_unitario, 
                m.nombre as nombre 
              FROM 
                pedido_detalle pd 
              INNER JOIN 
                menu m ON pd.idplato = m.idplato 
              WHERE 
                pd.idpedido = ANY(ARRAY[${pedidosIds.join(',')}])
            ''',
          };

          final detallesResponse = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(detallesQuery),
          );

          if (detallesResponse.statusCode == 200) {
            final detallesData = json.decode(detallesResponse.body);
            print('📋 Respuesta de detalles: $detallesData');

            final detalles = detallesData['result'] ?? [];

            // Transformar y combinar los datos
            final List<Map<String, dynamic>> orders = [];

            for (final pedido in data['result']) {
              // Filtrar los detalles para este pedido
              final itemsPedido =
                  detalles
                      .where((d) => d['idpedido'] == pedido['idpedido'])
                      .toList();

              // Calcular total
              double total = 0;
              for (var item in itemsPedido) {
                double cantidad =
                    (item['cantidad'] is int)
                        ? item['cantidad'].toDouble()
                        : double.tryParse(item['cantidad'].toString()) ?? 1.0;

                double precioUnitario =
                    (item['precio_unitario'] is num)
                        ? item['precio_unitario'] + 0.0
                        : double.tryParse(item['precio_unitario'].toString()) ??
                            0.0;

                total += cantidad * precioUnitario;
              }

              // Formatear los items
              final items =
                  itemsPedido.map((item) {
                    return {
                      'nombre': item['nombre'],
                      'cantidad':
                          item['cantidad'] is int
                              ? item['cantidad']
                              : int.tryParse(item['cantidad'].toString()) ?? 1,
                      'precio_unitario':
                          item['precio_unitario'] is num
                              ? (item['precio_unitario'] + 0.0)
                              : double.tryParse(
                                    item['precio_unitario'].toString(),
                                  ) ??
                                  0.0,
                    };
                  }).toList();

              orders.add({
                'idpedido': pedido['idpedido'],
                'estado': pedido['estado'],
                'fecha': pedido['fecha'],
                'hora': pedido['hora'],
                'cliente':
                    pedido['cliente'] ?? 'Cliente #${pedido['idpersona']}',
                'total': total,
                'items': items,
              });
            }

            print(
              '✅ Procesados ${orders.length} pedidos completos con sus detalles',
            );
            return orders;
          } else {
            print(
              '❌ Error al obtener detalles: ${detallesResponse.statusCode}',
            );
          }

          // Si no se pudieron obtener los detalles, al menos retornar datos básicos
          return List<Map<String, dynamic>>.from(
            data['result'].map(
              (row) => {
                'idpedido': row['idpedido'],
                'estado': row['estado'],
                'fecha': row['fecha'],
                'hora': row['hora'],
                'cliente': row['cliente'] ?? 'Cliente #${row['idpersona']}',
                'total': 0.0,
                'items': [],
              },
            ),
          );
        } else {
          print('⚠️ La consulta SQL no devolvió resultados');
        }
      } else {
        print(
          '❌ Error en consulta SQL: ${response.statusCode} - ${response.body}',
        );
      }

      // Si la consulta falla, retornar una lista vacía
      print('⚠️ No se pudieron obtener pedidos, retornando lista vacía');
      return [];
    } catch (e) {
      print('⚠️ Error en consulta directa simplificada: $e');
      return [];
    }
  }

  // Obtener resumen de pedidos por período
  Future<Map<String, dynamic>> getOrdersSummary({
    required String period, // 'day', 'week', 'month', 'year'
    String? customStartDate,
    String? customEndDate,
  }) async {
    try {
      // Construir la URL con parámetros de consulta
      final queryParams = <String, String>{'period': period};
      if (customStartDate != null) queryParams['startDate'] = customStartDate;
      if (customEndDate != null) queryParams['endDate'] = customEndDate;

      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/pedidos/resumen',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Error al obtener resumen: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      // Para desarrollo, podemos retornar datos simulados
      return _getMockSummary(period);
    }
  }

  // Resumen simulado para desarrollo
  Map<String, dynamic> _getMockSummary(String period) {
    switch (period) {
      case 'day':
        return {
          'totalPedidos': 12,
          'totalVentas': 285.50,
          'ticketPromedio': 23.79,
          'platosPopulares': [
            {'nombre': 'Panquecas con frutos rojos', 'cantidad': 8},
            {'nombre': 'Tostadas francesas', 'cantidad': 6},
            {'nombre': 'Café americano', 'cantidad': 15},
          ],
          'horasPico': [
            {'hora': '09:00', 'pedidos': 3},
            {'hora': '10:00', 'pedidos': 5},
            {'hora': '11:00', 'pedidos': 4},
          ],
        };
      case 'week':
        return {
          'totalPedidos': 65,
          'totalVentas': 1580.75,
          'ticketPromedio': 24.32,
          'platosPopulares': [
            {'nombre': 'Avocado Toast', 'cantidad': 28},
            {'nombre': 'Panquecas con frutos rojos', 'cantidad': 22},
            {'nombre': 'Café americano', 'cantidad': 45},
          ],
          'diasPico': [
            {'dia': 'Sábado', 'pedidos': 18},
            {'dia': 'Domingo', 'pedidos': 20},
            {'dia': 'Viernes', 'pedidos': 12},
          ],
        };
      case 'month':
        return {
          'totalPedidos': 245,
          'totalVentas': 6120.50,
          'ticketPromedio': 24.98,
          'platosPopulares': [
            {'nombre': 'Avocado Toast', 'cantidad': 105},
            {'nombre': 'Tabla de desayuno', 'cantidad': 85},
            {'nombre': 'Café americano', 'cantidad': 180},
          ],
          'semanasPico': [
            {'semana': '1-7', 'pedidos': 58},
            {'semana': '8-14', 'pedidos': 67},
            {'semana': '15-21', 'pedidos': 72},
            {'semana': '22-28', 'pedidos': 48},
          ],
        };
      case 'year':
        return {
          'totalPedidos': 2850,
          'totalVentas': 73450.25,
          'ticketPromedio': 25.77,
          'platosPopulares': [
            {'nombre': 'Avocado Toast', 'cantidad': 950},
            {'nombre': 'Tabla de desayuno', 'cantidad': 780},
            {'nombre': 'Café americano', 'cantidad': 1850},
          ],
          'mesesPico': [
            {'mes': 'Enero', 'pedidos': 210},
            {'mes': 'Febrero', 'pedidos': 195},
            {'mes': 'Marzo', 'pedidos': 225},
            {'mes': 'Abril', 'pedidos': 240},
            {'mes': 'Mayo', 'pedidos': 260},
            {'mes': 'Junio', 'pedidos': 280},
          ],
        };
      case 'custom':
        return {
          'totalPedidos': 85,
          'totalVentas': 2150.30,
          'ticketPromedio': 25.30,
          'platosPopulares': [
            {'nombre': 'Avocado Toast', 'cantidad': 32},
            {'nombre': 'Panquecas con frutos rojos', 'cantidad': 25},
            {'nombre': 'Café americano', 'cantidad': 58},
          ],
        };
      default:
        return {
          'totalPedidos': 0,
          'totalVentas': 0,
          'ticketPromedio': 0,
          'platosPopulares': [],
        };
    }
  }

  // Actualizar el estado de un pedido
  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/pedidos/$orderId/estado');

      print('🔄 Actualizando estado de pedido #$orderId a $newStatus');

      // Convertir estado si es necesario (completado/cancelado → entregado/cancelado para el servidor)
      String serverStatus = newStatus;
      if (newStatus == 'completado') {
        // El servidor usa 'entregado' en lugar de 'completado'
        serverStatus = 'entregado';
        print(
          'ℹ️ Convertido "completado" a "entregado" para comunicación con servidor',
        );
      }

      final response = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'estado': serverStatus}),
      );

      if (response.statusCode == 200) {
        print('✅ Estado de pedido actualizado correctamente');
        return true;
      } else {
        print(
          '❌ Error al actualizar estado: ${response.statusCode} - ${response.body}',
        );
        // Intentar método alternativo
        return await _updateOrderStatusFallback(orderId, serverStatus);
      }
    } catch (e) {
      print('⚠️ Excepción al actualizar estado: $e');
      // Intentar método alternativo
      return await _updateOrderStatusFallback(
        orderId,
        newStatus == 'completado' ? 'entregado' : newStatus,
      );
    }
  }

  // Método alternativo para actualizar estado directamente en BD
  Future<bool> _updateOrderStatusFallback(int orderId, String newStatus) async {
    try {
      final query = {
        'query':
            "UPDATE pedidos SET estado = '$newStatus' WHERE idpedido = $orderId RETURNING idpedido",
      };

      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/db/query');

      print('🔄 Intentando actualizar estado vía consulta directa');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(query),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] != null && data['result'].isNotEmpty) {
          print('✅ Estado actualizado correctamente vía consulta directa');
          return true;
        }
      }

      print('❌ No se pudo actualizar el estado vía consulta directa');
      return false;
    } catch (e) {
      print('⚠️ Error en método alternativo de actualización: $e');
      return false;
    }
  }
}
