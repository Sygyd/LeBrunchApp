import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Importar dart:async para TimeoutException

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
    String? period, // 'day', 'week', 'month', 'year', 'all'
    String? customStartDate,
    String? customEndDate,
  }) async {
    try {
      // Si period es null o 'all', vamos a obtener todos los datos sin filtros de fecha
      final bool obtenerTodo = period == null || period == 'all';

      // Construir la URL con parámetros de consulta
      final queryParams = <String, String>{};

      if (!obtenerTodo) {
        // Solo agregar el periodo si no estamos buscando todos los datos
        queryParams['period'] = period!;
      }

      if (customStartDate != null) queryParams['startDate'] = customStartDate;
      if (customEndDate != null) queryParams['endDate'] = customEndDate;

      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse(
        '$baseUrl/pedidos/resumen',
      ).replace(queryParameters: queryParams);

      print('📊 Solicitando resumen de pedidos: $uri');

      // Intentar obtener datos reales del servidor
      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              print('⚠️ Timeout al conectar con el servidor');
              throw TimeoutException('No se pudo conectar con el servidor');
            },
          );

      print('📊 Código de respuesta: ${response.statusCode}');
      print('📊 Cuerpo de respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Datos de resumen obtenidos correctamente de la base de datos');

        // Verificar la estructura del objeto
        if (data is Map) {
          // Asegurar que todas las claves necesarias existan
          final validKeys = ['totalPedidos', 'totalVentas', 'ticketPromedio'];
          for (var key in validKeys) {
            if (!data.containsKey(key)) {
              print('⚠️ Falta la clave $key en la respuesta');
              data[key] = 0;
            }
          }

          // Realizar verificaciones adicionales
          print('📊 Total de pedidos: ${data['totalPedidos']}');
          print('📊 Total de ventas: ${data['totalVentas']}');
          print('📊 Ticket promedio: ${data['ticketPromedio']}');

          // Para debuggear datos de distribución
          if (data.containsKey('horasPico')) {
            print('⏰ Horas pico: ${data['horasPico']}');
          }
          if (data.containsKey('diasPico')) {
            print('📅 Días pico: ${data['diasPico']}');
          }
          if (data.containsKey('semanasPico')) {
            print('🗓️ Semanas pico: ${data['semanasPico']}');
          }
          if (data.containsKey('mesesPico')) {
            print('📆 Meses pico: ${data['mesesPico']}');
          }
        }

        return data;
      } else {
        print(
          '❌ Error al obtener resumen: ${response.statusCode} - ${response.body}',
        );
        // En caso de error, intentar generar datos directamente de la base de datos
        return await _fetchSummaryUsingDirectSQL(
          obtenerTodo ? 'all' : period!,
          customStartDate,
          customEndDate,
        );
      }
    } catch (e) {
      print('⚠️ Excepción al obtener resumen: $e');
      // Intentar generar datos directamente de la base de datos
      return await _fetchSummaryUsingDirectSQL(
        period ?? 'all',
        customStartDate,
        customEndDate,
      );
    }
  }

  // Método para generar resumen usando SQL directo cuando falla el endpoint principal
  Future<Map<String, dynamic>> _fetchSummaryUsingDirectSQL(
    String period,
    String? customStartDate,
    String? customEndDate,
  ) async {
    print('🔍 Generando resumen usando SQL directo, periodo: $period');
    try {
      // Determinar rango de fechas basado en el período
      String whereClause;

      if (customStartDate != null && customEndDate != null) {
        // Usar fechas personalizadas
        whereClause =
            "p.fecha >= '$customStartDate'::date AND p.fecha <= '$customEndDate'::date + interval '1 day'";
        print(
          '📅 Usando rango personalizado: $customStartDate a $customEndDate',
        );
      } else if (period == 'all') {
        // No aplicar filtro de fechas para obtener todo
        whereClause = "1=1"; // Condición siempre verdadera
        print('📅 Obteniendo TODOS los datos sin filtro de fechas');
      } else {
        // Calcular cláusula where basada en período
        switch (period) {
          case 'day':
            whereClause =
                "p.fecha >= CURRENT_DATE AND p.fecha < CURRENT_DATE + interval '1 day'";
            break;
          case 'week':
            whereClause =
                "p.fecha >= CURRENT_DATE - INTERVAL '7 days' AND p.fecha < CURRENT_TIMESTAMP";
            break;
          case 'month':
            whereClause =
                "p.fecha >= DATE_TRUNC('month', CURRENT_DATE) AND p.fecha < CURRENT_TIMESTAMP";
            break;
          case 'year':
            whereClause =
                "p.fecha >= DATE_TRUNC('year', CURRENT_DATE) AND p.fecha < CURRENT_TIMESTAMP";
            break;
          default:
            whereClause =
                "p.fecha >= CURRENT_DATE AND p.fecha < CURRENT_DATE + interval '1 day'";
        }
        print('📅 Usando período predeterminado: $period');
      }

      // Consulta SQL para obtener resumen básico
      String sql = '''
        SELECT 
          COUNT(DISTINCT p.idpedido) as total_pedidos,
          COALESCE(SUM(pd.cantidad * pd.precio_unitario), 0) as total_ventas
        FROM 
          pedidos p
        LEFT JOIN 
          pedido_detalle pd ON p.idpedido = pd.idpedido
        WHERE 
          $whereClause
          AND p.estado = 'completado'
      ''';

      print('🔍 Ejecutando SQL: $sql');

      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/db/query');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': sql}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Respuesta de la consulta: $data');

        if (data['result'] != null && data['result'].isNotEmpty) {
          final result = data['result'][0];

          // Convertir datos a tipos adecuados
          int totalPedidos =
              int.tryParse(result['total_pedidos'].toString()) ?? 0;
          double totalVentas =
              double.tryParse(result['total_ventas'].toString()) ?? 0.0;
          double ticketPromedio =
              totalPedidos > 0 ? totalVentas / totalPedidos : 0.0;

          // Preparar el resumen
          final summary = {
            'totalPedidos': totalPedidos,
            'totalVentas': totalVentas,
            'ticketPromedio': ticketPromedio,
          };

          // Para 'all', no intentamos agregar datos de distribución específicos
          if (period != 'all') {
            // Consultar datos de distribución según el período
            await _addDistributionData(summary, period, whereClause);
          } else {
            // Para 'all', obtener datos generales de distribución por meses
            await _addAllTimeDistribution(summary);
          }

          print('✅ Resumen generado exitosamente mediante SQL directo');
          return summary;
        }
      }

      print('❌ Error al generar resumen usando SQL directo');
      return {'totalPedidos': 0, 'totalVentas': 0.0, 'ticketPromedio': 0.0};
    } catch (e) {
      print('❌ Error al generar resumen usando SQL directo: $e');
      return {'totalPedidos': 0, 'totalVentas': 0.0, 'ticketPromedio': 0.0};
    }
  }

  // Método para agregar datos de distribución al resumen
  Future<void> _addDistributionData(
    Map<String, dynamic> summary,
    String period,
    String whereClause,
  ) async {
    try {
      String distributionSQL;
      String resultKey;

      // Consulta diferente según el período
      switch (period) {
        case 'day':
          distributionSQL = '''
            SELECT 
              TO_CHAR(p.fecha, 'HH24:MI') as hora,
              COUNT(DISTINCT p.idpedido) as pedidos
            FROM 
              pedidos p
            WHERE 
              $whereClause
              AND p.estado = 'completado'
            GROUP BY 
              TO_CHAR(p.fecha, 'HH24:MI')
            ORDER BY 
              pedidos DESC
            LIMIT 10
          ''';
          resultKey = 'horasPico';
          break;

        case 'week':
          distributionSQL = '''
            SELECT 
              TO_CHAR(p.fecha, 'Day') as dia,
              COUNT(DISTINCT p.idpedido) as pedidos
            FROM 
              pedidos p
            WHERE 
              $whereClause
              AND p.estado = 'completado'
            GROUP BY 
              TO_CHAR(p.fecha, 'Day')
            ORDER BY 
              pedidos DESC
          ''';
          resultKey = 'diasPico';
          break;

        case 'month':
          distributionSQL = '''
            SELECT 
              CONCAT('Semana ', TO_CHAR(p.fecha, 'W')) as semana,
              COUNT(DISTINCT p.idpedido) as pedidos
            FROM 
              pedidos p
            WHERE 
              $whereClause
              AND p.estado = 'completado'
            GROUP BY 
              TO_CHAR(p.fecha, 'W')
            ORDER BY 
              TO_CHAR(p.fecha, 'W')::integer
          ''';
          resultKey = 'semanasPico';
          break;

        case 'year':
          distributionSQL = '''
            SELECT 
              TO_CHAR(p.fecha, 'Month') as mes,
              COUNT(DISTINCT p.idpedido) as pedidos
            FROM 
              pedidos p
            WHERE 
              $whereClause
              AND p.estado = 'completado'
            GROUP BY 
              TO_CHAR(p.fecha, 'Month')
            ORDER BY 
              MIN(DATE_TRUNC('month', p.fecha))
          ''';
          resultKey = 'mesesPico';
          break;

        default:
          return; // No agregar distribución
      }

      print('🔍 Ejecutando consulta de distribución para $period');

      // Ejecutar la consulta
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/db/query');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': distributionSQL}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] != null && data['result'].isNotEmpty) {
          summary[resultKey] = data['result'];
          print(
            '✅ Datos de distribución agregados: ${data['result'].length} registros',
          );
        }
      }
    } catch (e) {
      print('⚠️ Error al obtener datos de distribución: $e');
    }
  }

  // Método para agregar distribución para "all"
  Future<void> _addAllTimeDistribution(Map<String, dynamic> summary) async {
    try {
      // Obtener distribución por meses de todo el tiempo
      String sql = '''
        SELECT 
          TO_CHAR(p.fecha, 'YYYY-MM') as periodo,
          COUNT(DISTINCT p.idpedido) as pedidos
        FROM 
          pedidos p
        WHERE 
          p.estado = 'completado'
        GROUP BY 
          TO_CHAR(p.fecha, 'YYYY-MM')
        ORDER BY 
          periodo DESC
        LIMIT 12
      ''';

      print('🔍 Ejecutando consulta de distribución para todo el tiempo');

      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/db/query');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': sql}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] != null && data['result'].isNotEmpty) {
          summary['periodosPico'] = data['result'];
          print(
            '✅ Datos de distribución general agregados: ${data['result'].length} registros',
          );
        }
      }
    } catch (e) {
      print('⚠️ Error al obtener datos de distribución general: $e');
    }
  }

  // Actualizar el estado de un pedido
  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/pedidos/$orderId/estado');

      print('🔄 Actualizando estado de pedido #$orderId a $newStatus');

      final response = await http.patch(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'estado': newStatus}),
      );

      if (response.statusCode == 200) {
        print('✅ Estado de pedido actualizado correctamente');
        return true;
      } else {
        print(
          '❌ Error al actualizar estado: ${response.statusCode} - ${response.body}',
        );
        // Intentar método alternativo
        return await _updateOrderStatusFallback(orderId, newStatus);
      }
    } catch (e) {
      print('⚠️ Excepción al actualizar estado: $e');
      // Intentar método alternativo
      return await _updateOrderStatusFallback(orderId, newStatus);
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

  // Obtener el tiempo de procesamiento de un pedido
  Future<Map<String, dynamic>?> getOrderProcessingTime(int orderId) async {
    try {
      print('⏱️ Obteniendo tiempo de procesamiento para pedido #$orderId');

      final baseUrl = await _getBaseUrl();
      final query = {
        'query': '''
          SELECT 
            pt.idpedido,
            pt.estado_inicial,
            pt.estado_final, 
            pt.timestamp_inicial,
            pt.timestamp_final,
            EXTRACT(EPOCH FROM pt.tiempo_procesamiento) as tiempo_segundos
          FROM 
            pedido_tiempos pt
          WHERE 
            pt.idpedido = $orderId
          LIMIT 1
        ''',
      };

      final uri = Uri.parse('$baseUrl/db/query');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(query),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] != null && data['result'].isNotEmpty) {
          final processingData = data['result'][0];
          print('⏱️ Datos de tiempo obtenidos: $processingData');

          // Formatear el tiempo en formato legible
          final tiempoSegundos =
              (processingData['tiempo_segundos'] is num)
                  ? processingData['tiempo_segundos']
                  : double.tryParse(
                        processingData['tiempo_segundos'].toString(),
                      ) ??
                      0.0;

          final minutos = (tiempoSegundos / 60).floor();
          final segundos = (tiempoSegundos % 60).round();

          return {
            'idpedido': processingData['idpedido'],
            'estado_inicial': processingData['estado_inicial'],
            'estado_final': processingData['estado_final'],
            'timestamp_inicial': processingData['timestamp_inicial'],
            'timestamp_final': processingData['timestamp_final'],
            'tiempo_segundos': tiempoSegundos,
            'tiempo_formato': '$minutos min $segundos seg',
          };
        } else {
          print(
            '⏱️ No se encontraron datos de tiempo para el pedido #$orderId',
          );
          return null;
        }
      } else {
        print(
          '❌ Error al obtener tiempo de procesamiento: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('⚠️ Error al obtener tiempo de procesamiento: $e');
      return null;
    }
  }
}
