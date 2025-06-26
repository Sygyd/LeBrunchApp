import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Importar dart:async para TimeoutException
import '../../services/order_status_service.dart'; // Importar el servicio de notificación
import '../../config.dart'; // Importar configuración centralizada
import '../table_identification_service.dart'; // 🆕 NUEVO: Importar servicio de mesas real

/// Servicio para la gestión de pedidos (órdenes)
///
/// Este servicio maneja todas las operaciones relacionadas con pedidos en el sistema:
/// - Obtener listado de pedidos con filtros (estado, fecha, etc)
/// - Obtener pedidos por tipo (comida/bebida) para cocineros y baristas
/// - Actualizar estados de pedidos y sus ítems
/// - Calcular estadísticas y resúmenes
/// - Obtener tiempos de procesamiento
///
/// El servicio utiliza tanto endpoints REST como consultas SQL directas
/// para mayor robustez y fallback en caso de errores.
class OrdersService {
  final String? baseUrl;
  late final Future<String> _cachedBaseUrl;
  final Duration _defaultTimeout = const Duration(seconds: 10);
  final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };
  final OrderStatusService _statusService =
      OrderStatusService(); // Instancia del servicio de notificación
  final TableIdentificationService _tableService =
      TableIdentificationService(); // 🆕 NUEVO: Servicio de mesas real

  // Constructor con inicialización de URL base
  OrdersService([this.baseUrl]) {
    _cachedBaseUrl = _initBaseUrl();
  }

  // Inicializa y cachea la URL base para reducir llamadas a SharedPreferences
  Future<String> _initBaseUrl() async {
    if (baseUrl != null) return baseUrl!;

    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('serverIp') ?? AppConfig.serverIp;
    final serverPort = AppConfig.serverPort;
    return 'http://$serverIp:$serverPort';
  }

  // Getter para obtener la URL base previamente cacheada
  Future<String> get getBaseUrl => _cachedBaseUrl;

  // Método para realizar peticiones HTTP GET con manejo de errores integrado
  Future<http.Response> _get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? timeout,
  }) async {
    final baseUrl = await getBaseUrl;
    final uri = Uri.parse(
      '$baseUrl/$endpoint',
    ).replace(queryParameters: queryParams);

    try {
      print('🔍 GET: $uri');
      return await http.get(uri).timeout(timeout ?? _defaultTimeout);
    } on TimeoutException {
      print('⚠️ Timeout al conectar con el servidor: $uri');
      throw TimeoutException('No se pudo conectar con el servidor');
    } catch (e) {
      print('❌ Error en GET $uri: $e');
      rethrow;
    }
  }

  // Método para realizar peticiones HTTP POST con manejo de errores integrado
  Future<http.Response> _post(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final baseUrl = await getBaseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint');

    try {
      print('🔍 POST: $uri');
      print('🔍 Body: $body');
      return await http
          .post(
            uri,
            headers: headers ?? _defaultHeaders,
            body:
                body is String
                    ? body
                    : (body != null ? jsonEncode(body) : null),
          )
          .timeout(timeout ?? _defaultTimeout);
    } on TimeoutException {
      print('⚠️ Timeout al conectar con el servidor: $uri');
      throw TimeoutException('No se pudo conectar con el servidor');
    } catch (e) {
      print('❌ Error en POST $uri: $e');
      rethrow;
    }
  }

  // Método para realizar peticiones HTTP PATCH con manejo de errores integrado
  Future<http.Response> _patch(
    String endpoint, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final baseUrl = await getBaseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint');

    try {
      print('🔍 PATCH: $uri');
      return await http
          .patch(
            uri,
            headers: headers ?? _defaultHeaders,
            body:
                body is String
                    ? body
                    : (body != null ? jsonEncode(body) : null),
          )
          .timeout(timeout ?? _defaultTimeout);
    } on TimeoutException {
      print('⚠️ Timeout al conectar con el servidor: $uri');
      throw TimeoutException('No se pudo conectar con el servidor');
    } catch (e) {
      print('❌ Error en PATCH $uri: $e');
      rethrow;
    }
  }

  // Método para ejecutar consultas SQL directas
  Future<Map<String, dynamic>> _executeQuery(String sql) async {
    try {
      final response = await _post('db/query', body: {'query': sql});

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print(
          '❌ Error en consulta SQL: ${response.statusCode} - ${response.body}',
        );
        return {'result': []};
      }
    } catch (e) {
      print('❌ Error al ejecutar consulta SQL: $e');
      return {'result': []};
    }
  }

  // Método para extraer resultados de una consulta SQL
  List<Map<String, dynamic>> _extractQueryResults(Map<String, dynamic> data) {
    return (data['result'] as List?)
            ?.map(
              (item) =>
                  item is Map<String, dynamic>
                      ? item
                      : Map<String, dynamic>.from(item as Map),
            )
            .toList() ??
        [];
  }

  // Método para obtener todos los pedidos (con filtros opcionales)
  Future<List<Map<String, dynamic>>> getOrders({
    String? startDate,
    String? endDate,
    String? estado,
    String? startTime,
    String? endTime,
  }) async {
    try {
      print(
        '🔍 Obteniendo pedidos: startDate=$startDate, endDate=$endDate, estado=$estado, startTime=$startTime, endTime=$endTime',
      );

      // Detectar si buscamos múltiples estados
      bool isMultipleStates =
          estado != null &&
          (estado.contains(',') ||
              estado.contains('(') ||
              estado.contains(')'));

      // Construir la URL con parámetros de consulta
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (estado != null && !isMultipleStates) queryParams['estado'] = estado;
      if (startTime != null) queryParams['startTime'] = startTime;
      if (endTime != null) queryParams['endTime'] = endTime;

      // Para los pedidos del administrador, siempre usamos consulta directa
      if (estado == 'pendiente') {
        return await _queryPendingOrdersForAdmin();
      }

      final baseUrl = await getBaseUrl;
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

  // Método para obtener los pedidos pendientes para el administrador usando consulta directa
  Future<List<Map<String, dynamic>>> _queryPendingOrdersForAdmin() async {
    try {
      print('📊 Consultando pedidos pendientes para administrador');

      final baseUrl = await getBaseUrl;
      final uri = Uri.parse('$baseUrl/db/query');

      // Consulta para obtener todos los pedidos pendientes
      final query = {
        'query': '''
          SELECT 
            p.idpedido, 
            p.estado, 
            TO_CHAR(p.fecha, 'YYYY-MM-DD') as fecha,
            TO_CHAR(p.fecha, 'HH24:MI') as hora,
            pe.nombre || ' ' || pe.apellido as cliente
          FROM 
            pedidos p
          INNER JOIN 
            personas pe ON p.idpersona = pe.idpersonas
          WHERE 
            p.estado = 'pendiente'
          ORDER BY 
            p.fecha ASC
        ''',
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(query),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📋 Respuesta de la consulta de pedidos pendientes: $data');

        if (data['result'] != null && data['result'].isNotEmpty) {
          final pedidosIds =
              data['result'].map((row) => row['idpedido']).toList();

          // Consultar los detalles de los pedidos - TODOS los ítems sin filtrar por tipo
          final detallesQuery = {
            'query': '''
              SELECT 
                pd.idpedido, 
                pd.idplato, 
                pd.cantidad, 
                m.precio as precio_unitario,
                pd.notas,
                pd.completado_cocinero,
                pd.completado_barista,
                pd.fecha_completado_cocinero,
                pd.fecha_completado_barista,
                m.nombre as nombre,
                m.tipo
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
            final detalles = detallesData['result'] ?? [];

            // Transformar y combinar los datos
            final List<Map<String, dynamic>> orders = [];
            // Lista de pedidos que deben completarse automáticamente
            final List<int> pedidosParaCompletar = [];

            for (final pedido in data['result']) {
              final idPedido = pedido['idpedido'];
              final itemsPedido =
                  detalles.where((d) => d['idpedido'] == idPedido).toList();

              // Verificar si todos los ítems están completados
              bool hayComida = false;
              bool hayBebida = false;
              bool todosItemsComidaCompletados = true;
              bool todosItemsBebidaCompletados = true;

              for (var item in itemsPedido) {
                final tipo = item['tipo']?.toString().toLowerCase() ?? '';

                if (tipo == 'comida') {
                  hayComida = true;
                  final completadoCocinero =
                      item['completado_cocinero'] ?? false;
                  if (!completadoCocinero) {
                    todosItemsComidaCompletados = false;
                  }
                } else if (tipo == 'bebida') {
                  hayBebida = true;
                  final completadoBarista = item['completado_barista'] ?? false;
                  if (!completadoBarista) {
                    todosItemsBebidaCompletados = false;
                  }
                }
              }

              // Determinar si el pedido debe completarse automáticamente
              bool debeCompletarse = false;

              if (hayComida && hayBebida) {
                // Si hay comida y bebida, ambas deben estar completadas
                debeCompletarse =
                    todosItemsComidaCompletados && todosItemsBebidaCompletados;
              } else if (hayComida && !hayBebida) {
                // Si solo hay comida, todos los ítems de comida deben estar completados
                debeCompletarse = todosItemsComidaCompletados;
              } else if (!hayComida && hayBebida) {
                // Si solo hay bebida, todos los ítems de bebida deben estar completados
                debeCompletarse = todosItemsBebidaCompletados;
              }

              if (debeCompletarse) {
                // Marcar para completar automáticamente
                print(
                  '✅ Detectado pedido #$idPedido que debe completarse automáticamente',
                );
                pedidosParaCompletar.add(idPedido);
                // No agregar a la lista de pedidos pendientes
                continue;
              }

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
                      'idplato': item['idplato'],
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
                      'notas': item['notas'],
                      'completado_cocinero':
                          item['completado_cocinero'] ?? false,
                      'completado_barista': item['completado_barista'] ?? false,
                      'fecha_completado_cocinero':
                          item['fecha_completado_cocinero'],
                      'fecha_completado_barista':
                          item['fecha_completado_barista'],
                      'tipo':
                          item['tipo'] ??
                          (item['idplato'] % 2 == 0 ? 'comida' : 'bebida'),
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

            // Completar automáticamente los pedidos que lo necesiten
            for (int idPedido in pedidosParaCompletar) {
              print('🔄 Completando automáticamente el pedido #$idPedido...');
              await updateOrderStatus(idPedido, 'completado');
            }

            return orders;
          }
        }
      }
      return [];
    } catch (e) {
      print('❌ Error al obtener pedidos pendientes para admin: $e');
      return [];
    }
  }

  // Método simplificado que consulta directamente completados y cancelados
  Future<List<Map<String, dynamic>>> _queryOrdersDirectSimple() async {
    try {
      print('📊 Intentando consulta simplificada para todos los pedidos');

      // Consulta SQL simplificada para obtener todos los pedidos
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

      final baseUrl = await getBaseUrl;
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
                m.precio as precio_unitario, 
                pd.notas,
                pd.completado_cocinero,
                pd.completado_barista,
                pd.fecha_completado_cocinero,
                pd.fecha_completado_barista,
                m.nombre as nombre,
                m.tipo
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
                      'idplato': item['idplato'],
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
                      'notas': item['notas'],
                      'completado_cocinero':
                          item['completado_cocinero'] ?? false,
                      'completado_barista': item['completado_barista'] ?? false,
                      'fecha_completado_cocinero':
                          item['fecha_completado_cocinero'],
                      'fecha_completado_barista':
                          item['fecha_completado_barista'],
                      'tipo':
                          item['tipo'] ??
                          (item['idplato'] % 2 == 0
                              ? 'comida'
                              : 'bebida'), // Asignar un tipo por defecto si no está disponible
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
    String? period,
    String? customStartDate,
    String? customEndDate,
    String? categoria,
    String? estado, // 🔄 NUEVO: Filtro por estado de pedido
  }) async {
    try {
      print(
        '📊 Obteniendo resumen de pedidos: period=$period, startDate=$customStartDate, endDate=$customEndDate, categoria=$categoria, estado=$estado',
      );

      final queryParams = <String, String>{};
      if (period != null && period != 'custom') queryParams['period'] = period;
      if (customStartDate != null) queryParams['startDate'] = customStartDate;
      if (customEndDate != null) queryParams['endDate'] = customEndDate;
      if (categoria != null && categoria != 'todos') {
        queryParams['categoria'] = categoria == 'comida' ? 'comida' : 'bebida';
      }
      if (estado != null)
        queryParams['estado'] = estado; // 🔄 NUEVO: Filtro por estado

      final baseUrl = await getBaseUrl;
      final uri = Uri.parse(
        '$baseUrl/pedidos/resumen',
      ).replace(queryParameters: queryParams);
      print('🔍 URL de consulta: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Resumen obtenido: $data');
        return data;
      } else {
        print(
          '❌ Error al obtener resumen: ${response.statusCode} - ${response.body}',
        );
        return {
          'totalPedidos': 0,
          'totalVentas': 0.0,
          'ticketPromedio': 0.0,
          'minPedido': 0.0,
          'maxPedido': 0.0,
          'periodo': {
            'inicio':
                customStartDate ?? DateTime.now().toString().split(' ')[0],
            'fin': customEndDate ?? DateTime.now().toString().split(' ')[0],
            'tipo': period ?? 'custom',
          },
        };
      }
    } catch (e) {
      print('❌ Error al obtener resumen de pedidos: $e');
      return {
        'totalPedidos': 0,
        'totalVentas': 0.0,
        'ticketPromedio': 0.0,
        'minPedido': 0.0,
        'maxPedido': 0.0,
        'periodo': {
          'inicio': customStartDate ?? DateTime.now().toString().split(' ')[0],
          'fin': customEndDate ?? DateTime.now().toString().split(' ')[0],
          'tipo': period ?? 'custom',
        },
      };
    }
  }

  // Obtener el tiempo de procesamiento de un pedido
  Future<Map<String, dynamic>?> getOrderProcessingTime(int orderId) async {
    try {
      print('⏱️ Obteniendo tiempo de procesamiento para pedido #$orderId');

      try {
        // Intentar con el endpoint específico
        final response = await _get('pedidos/tiempo/$orderId');

        if (response.statusCode == 200) {
          final processingData = json.decode(response.body);
          print('⏱️ Datos de tiempo obtenidos vía endpoint: $processingData');
          return processingData;
        }
      } catch (e) {
        print('⚠️ Error en endpoint de tiempo: $e');
      }

      // Si el endpoint falla, intentar obtener directamente de la tabla
      print(
        '⏱️ Intentando consulta directa para obtener tiempo de procesamiento...',
      );

      final query = '''
            SELECT 
              idpedido,
              estado,
              fecha as timestamp_inicial,
              EXTRACT(EPOCH FROM tiempo_procesamiento) as tiempo_segundos
            FROM 
              pedidos
            WHERE 
              idpedido = $orderId AND
              tiempo_procesamiento IS NOT NULL
            LIMIT 1
      ''';

      final data = await _executeQuery(query);
      final result = _extractQueryResults(data);

      if (result.isNotEmpty) {
        final processingData = result[0];
        print('⏱️ Datos de tiempo obtenidos directamente: $processingData');

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
          'estado_inicial': 'pendiente',
          'estado_final': processingData['estado'],
          'timestamp_inicial': processingData['timestamp_inicial'],
          'tiempo_segundos': tiempoSegundos,
          'tiempo_formato': '$minutos min $segundos seg',
        };
      }

      print('⏱️ No se encontraron datos de tiempo para el pedido #$orderId');
      return null;
    } catch (e) {
      print('⚠️ Error al obtener tiempo de procesamiento: $e');
      return null;
    }
  }

  // Obtener el tiempo promedio de procesamiento de pedidos por día
  Future<String?> getAverageProcessingTimeByDay() async {
    try {
      print(
        '⏱️ Obteniendo tiempo promedio de procesamiento para el día actual',
      );

      // Lista de estrategias a intentar
      final strategies = [
        _getAverageTimeFromEndpoint,
        _getAverageTimeOptimizedQuery,
        _getAverageTimeFromIndividualOrders,
        _getAverageTimeApproximated,
      ];

      // Intentar cada estrategia hasta que una funcione
      for (var strategy in strategies) {
        try {
          final result = await strategy();
          if (result != null) {
            return result;
          }
        } catch (e) {
          print('⚠️ Error en estrategia: $e');
          // Continuar con la siguiente estrategia
        }
      }

      print('⏱️ No se pudo calcular tiempo promedio con ninguna estrategia');
      return null;
    } catch (e) {
      print('⚠️ Error global al obtener tiempo promedio: $e');
      return null;
    }
  }

  // Estrategia 1: Usar endpoint específico
  Future<String?> _getAverageTimeFromEndpoint() async {
    final response = await _get('pedidos/tiempo/promedio');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['promedio_minutos'] != null) {
        final min = (data['promedio_minutos'] as num).floor();
        final sec = ((data['promedio_minutos'] as num) * 60 % 60).round();
        print('⏱️ Tiempo promedio (endpoint): $min min $sec seg');
        return '$min min $sec seg';
      }
    }
    return null;
  }

  // Estrategia 2: Consulta optimizada con INTERVAL
  Future<String?> _getAverageTimeOptimizedQuery() async {
    final query = '''
            WITH PedidosCompletadosHoy AS (
              SELECT 
                idpedido,
                tiempo_procesamiento,
                fecha
              FROM 
                pedidos
              WHERE 
                estado = 'completado'
                AND DATE(fecha) = CURRENT_DATE
            )
            SELECT 
              COUNT(*) as count,
              EXTRACT(EPOCH FROM AVG(
                CASE 
                  WHEN tiempo_procesamiento IS NOT NULL THEN tiempo_procesamiento
                  ELSE CURRENT_TIMESTAMP - fecha
                END
              )) as promedio_segundos
            FROM 
              PedidosCompletadosHoy
    ''';

    final data = await _executeQuery(query);
    final rows = _extractQueryResults(data);

    if (rows.isNotEmpty) {
      final count = int.tryParse(rows[0]['count']?.toString() ?? '0') ?? 0;

      if (count > 0) {
        final promedioSegundos =
            double.tryParse(rows[0]['promedio_segundos']?.toString() ?? '0') ??
            0.0;

        if (promedioSegundos > 0) {
          final minutos = (promedioSegundos / 60).floor();
          final segundos = (promedioSegundos % 60).round();
          print(
            '⏱️ Tiempo promedio (consulta optimizada): $minutos min $segundos seg',
          );
          return '$minutos min $segundos seg';
        }
      }
    }
    return null;
  }

  // Estrategia 3: Calcular desde órdenes individuales
  Future<String?> _getAverageTimeFromIndividualOrders() async {
    // Primero obtenemos IDs de pedidos completados hoy
    final pedidosQuery = '''
            SELECT idpedido 
            FROM pedidos 
            WHERE estado = 'completado' 
            AND DATE(fecha) = CURRENT_DATE
    ''';

    final pedidosData = await _executeQuery(pedidosQuery);
    final pedidos = _extractQueryResults(pedidosData);

    if (pedidos.isEmpty) return null;

    print('📊 Encontrados ${pedidos.length} pedidos para cálculo individual');

    // Calculamos manualmente sumando tiempos individuales
    double tiempoTotalSegundos = 0;
    int pedidosValidos = 0;

    for (final pedido in pedidos) {
      final idPedido = pedido['idpedido'];
      final tiempoQuery = '''
                  SELECT EXTRACT(EPOCH FROM tiempo_procesamiento) as segundos
                  FROM pedidos 
                  WHERE idpedido = $idPedido 
                  AND tiempo_procesamiento IS NOT NULL
      ''';

      final tiempoData = await _executeQuery(tiempoQuery);
      final tiempoRows = _extractQueryResults(tiempoData);

      if (tiempoRows.isNotEmpty && tiempoRows[0]['segundos'] != null) {
        final segundos =
            double.tryParse(tiempoRows[0]['segundos'].toString()) ?? 0.0;

        if (segundos > 0) {
          tiempoTotalSegundos += segundos;
          pedidosValidos++;
        }
      }
    }

    if (pedidosValidos > 0) {
      final promedioSegundos = tiempoTotalSegundos / pedidosValidos;
      final minutos = (promedioSegundos / 60).floor();
      final segundos = (promedioSegundos % 60).round();
      print('⏱️ Tiempo promedio (individual): $minutos min $segundos seg');
      return '$minutos min $segundos seg';
    }

    return null;
  }

  // Estrategia 4: Valor aproximado basado en cantidad
  Future<String?> _getAverageTimeApproximated() async {
    final countQuery = '''
            SELECT COUNT(*) as count
            FROM pedidos 
            WHERE estado = 'completado' 
            AND DATE(fecha) = CURRENT_DATE
    ''';

    final countData = await _executeQuery(countQuery);
    final countRows = _extractQueryResults(countData);

    if (countRows.isNotEmpty) {
      final count = int.tryParse(countRows[0]['count']?.toString() ?? '0') ?? 0;

      if (count > 0) {
        // Devolver valor aproximado
        print('⏱️ Tiempo promedio (aproximado): 15 min 0 seg');
        return '15 min 0 seg (aprox.)';
      } else {
        print('⏱️ No hay pedidos completados hoy');
        return 'No hay datos';
      }
    }

    return null;
  }

  // Actualizar el estado de un pedido (completado, cancelado, etc.)
  Future<bool> updateOrderStatus(int orderId, String newStatus) async {
    try {
      // Obtener estado anterior para verificar si es un cambio de pendiente a completado
      final estadoAnteriorQuery =
          'SELECT estado FROM pedidos WHERE idpedido = $orderId';
      final estadoAnteriorResult = await _executeQuery(estadoAnteriorQuery);
      final estadoAnteriorRows = _extractQueryResults(estadoAnteriorResult);
      final estadoAnterior =
          estadoAnteriorRows.isNotEmpty
              ? (estadoAnteriorRows[0]['estado'] ?? '').toString().toLowerCase()
              : 'desconocido';

      print(
        '🔄 Actualizando estado del pedido #$orderId de "$estadoAnterior" a "$newStatus"',
      );

      // Validar el estado
      final estadosValidos = [
        'pendiente',
        'completado',
        'cancelado',
        'en preparación',
      ];
      if (!estadosValidos.contains(newStatus.toLowerCase())) {
        print('❌ Estado inválido: $newStatus');
        return false;
      }

      // Si el estado es 'completado', también actualizar el tiempo de procesamiento
      final tiempoProcesamientoField =
          newStatus.toLowerCase() == 'completado'
              ? ', tiempo_procesamiento = NOW() - fecha::timestamp'
              : '';

      final query = '''
        UPDATE pedidos 
        SET estado = '$newStatus'$tiempoProcesamientoField
        WHERE idpedido = $orderId 
        RETURNING idpedido, estado
      ''';

      final result = await _executeQuery(query);
      final rows = _extractQueryResults(result);

      if (rows.isEmpty) {
        print(
          '⚠️ No se encontró el pedido #$orderId para actualizar su estado',
        );
        return false;
      }

      print(
        '✅ Estado actualizado con éxito a "$newStatus" para pedido #$orderId',
      );

      // Verificar después de 1 segundo si el cambio se aplicó correctamente
      await Future.delayed(const Duration(seconds: 1));

      // Verificar que el cambio se realizó correctamente
      final verificacionQuery =
          'SELECT estado FROM pedidos WHERE idpedido = $orderId';
      final verificacionResult = await _executeQuery(verificacionQuery);
      final verificacionRows = _extractQueryResults(verificacionResult);

      if (verificacionRows.isNotEmpty) {
        final estadoActual =
            (verificacionRows[0]['estado'] ?? '').toString().toLowerCase();

        if (estadoActual == newStatus.toLowerCase()) {
          print(
            '✅ Verificación: El estado del pedido #$orderId es ahora "$estadoActual"',
          );

          // 🔇 REMOVIDO: Notificación aquí causa duplicación
          // La notificación se maneja en checkAndUpdateOrderCompletion con información de mesa
          if (estadoAnterior == 'pendiente' &&
              newStatus.toLowerCase() == 'completado') {
            print(
              '✅ Estado actualizado de pendiente a completado para pedido #$orderId (notificación manejada por checkAndUpdateOrderCompletion)',
            );
          }

          return true;
        } else {
          print(
            '⚠️ Verificación: El estado del pedido #$orderId sigue siendo "$estadoActual" en lugar de "$newStatus"',
          );
          // Intentar método alternativo
          final success = await _updateOrderStatusAlternative(
            orderId,
            newStatus,
          );

          // 🔇 REMOVIDO: Notificación aquí causa duplicación
          // La notificación se maneja en checkAndUpdateOrderCompletion con información de mesa
          if (success &&
              estadoAnterior == 'pendiente' &&
              newStatus.toLowerCase() == 'completado') {
            print(
              '✅ Estado actualizado de pendiente a completado para pedido #$orderId (método alternativo - notificación manejada por checkAndUpdateOrderCompletion)',
            );
          }

          return success;
        }
      }

      return true;
    } catch (e) {
      print('❌ Error al actualizar estado del pedido: $e');
      // Intentar método alternativo en caso de error
      return await _updateOrderStatusAlternative(orderId, newStatus);
    }
  }

  // Método alternativo para actualizar el estado utilizando el endpoint específico
  Future<bool> _updateOrderStatusAlternative(
    int orderId,
    String newStatus,
  ) async {
    try {
      print(
        '🔄 Intentando actualización alternativa para pedido #$orderId a "$newStatus"',
      );

      final response = await _patch(
        'pedidos/$orderId/estado',
        body: {'estado': newStatus},
      );

      if (response.statusCode == 200) {
        print('✅ Estado actualizado con éxito mediante método alternativo');
        return true;
      } else {
        print('❌ Error en actualización alternativa: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error en actualización alternativa: $e');
      return false;
    }
  }

  // Método para actualizar el estado de un ítem específico (completado por cocinero o barista)
  Future<Map<String, dynamic>> updateItemStatus(
    int pedidoId,
    int platoId,
    bool completado,
    String role,
  ) async {
    try {
      print(
        '🔄 Actualizando estado de item: pedido=$pedidoId, plato=$platoId, completado=$completado, role=$role',
      );

      // Validar el rol
      if (role != 'cook' && role != 'barista') {
        print('❌ Rol inválido: $role. Debe ser "cook" o "barista"');
        return {'success': false, 'message': 'Rol inválido'};
      }

      // Determinar campos a actualizar según el rol
      final campoCompletado =
          role == 'cook' ? 'completado_cocinero' : 'completado_barista';
      final campoFecha =
          role == 'cook'
              ? 'fecha_completado_cocinero'
              : 'fecha_completado_barista';

      final query = '''
        UPDATE pedido_detalle 
        SET 
          $campoCompletado = $completado,
          $campoFecha = ${completado ? 'NOW()' : 'NULL'}
          WHERE 
          idpedido = $pedidoId AND idplato = $platoId
        RETURNING *
      ''';

      final result = await _executeQuery(query);
      final rows = _extractQueryResults(result);

      if (rows.isEmpty) {
        print('⚠️ No se encontró el ítem para actualizar');
        return {'success': false, 'message': 'Ítem no encontrado'};
      }

      print('✅ Ítem actualizado correctamente');

      // Si se está marcando como completado, verificar si todo el pedido está listo
      if (completado) {
        final completionResult = await checkAndUpdateOrderCompletion(pedidoId);

        // 🆕 NUEVO: Devolver información adicional si el pedido se completó
        if (completionResult['success'] == true &&
            completionResult['completed'] == true) {
          return {
            'success': true,
            'message': 'Ítem completado',
            'orderCompleted': true,
            'orderCompletionMessage': completionResult['message'],
            'mesa': completionResult['mesa'],
            'pedidoId': pedidoId,
          };
        }
      }

      return {
        'success': true,
        'message':
            completado
                ? 'Ítem marcado como completado'
                : 'Ítem marcado como pendiente',
        'orderCompleted': false,
      };
    } catch (e) {
      print('❌ Error al actualizar estado del ítem: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Verificar y actualizar estado de pedido basado en ítems completados
  Future<Map<String, dynamic>> checkAndUpdateOrderCompletion(
    int pedidoId,
  ) async {
    print('🔄 Verificando si el pedido #$pedidoId está completado...');

    try {
      // Verificar si debe completarse
      bool debeCompletarse = await debeCompletarsePedido(pedidoId);

      if (debeCompletarse) {
        // Verificar el estado actual del pedido
        final estadoQuery =
            'SELECT estado FROM pedidos WHERE idpedido = $pedidoId';
        final estadoResult = await _executeQuery(estadoQuery);
        final estadoRows = _extractQueryResults(estadoResult);

        if (estadoRows.isEmpty) {
          print('⚠️ No se encontró el pedido #$pedidoId');
          return {'success': false, 'message': 'Pedido no encontrado'};
        }

        final estadoActual =
            (estadoRows[0]['estado'] ?? '').toString().toLowerCase();

        // Solo actualizar si el estado actual es 'pendiente'
        if (estadoActual == 'pendiente') {
          print(
            '✅ Todos los ítems del pedido #$pedidoId están completados. Actualizando estado a completado.',
          );

          // 🆕 NUEVO: Obtener información de la mesa antes de completar
          final mesaInfo = await getTableForOrder(pedidoId);

          final success = await updateOrderStatus(pedidoId, 'completado');

          if (success) {
            final message =
                mesaInfo != null
                    ? 'Pedido completado, enviando a $mesaInfo'
                    : 'Pedido completado exitosamente';

            print('🎯 $message');

            // 🆕 NUEVO: Notificar via servidor WebSocket
            await _notifyOrderCompletedViaServer(pedidoId, mesaInfo, message);

            // 🔄 MANTENER: Notificación local para admin en la misma app
            _statusService.notifyOrderCompleted(
              pedidoId,
              mesa: mesaInfo,
              mensaje: message,
            );

            return {
              'success': true,
              'message': message,
              'mesa': mesaInfo,
              'pedidoId': pedidoId,
              'completed': true,
            };
          } else {
            return {
              'success': false,
              'message': 'Error al completar el pedido',
            };
          }
        } else {
          print(
            'ℹ️ Pedido #$pedidoId ya no está pendiente, su estado actual es: $estadoActual',
          );
          return {
            'success': false,
            'message': 'El pedido ya no está pendiente',
            'currentStatus': estadoActual,
          };
        }
      } else {
        print(
          'ℹ️ El pedido #$pedidoId aún no cumple las condiciones para ser completado',
        );
        return {
          'success': false,
          'message': 'El pedido aún no está listo para completar',
          'completed': false,
        };
      }
    } catch (e) {
      print('❌ Error al verificar y actualizar estado de pedido: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Método para determinar si un pedido debe completarse automáticamente
  Future<bool> debeCompletarsePedido(int pedidoId) async {
    try {
      // Obtener todos los ítems del pedido con su tipo
      final query = '''
              SELECT 
                pd.idplato, 
                pd.completado_cocinero,
                pd.completado_barista,
                m.tipo
              FROM 
                pedido_detalle pd 
        JOIN 
                menu m ON pd.idplato = m.idplato 
              WHERE 
          pd.idpedido = $pedidoId
      ''';

      final result = await _executeQuery(query);
      final items = _extractQueryResults(result);

      if (items.isEmpty) {
        print('⚠️ No se encontraron ítems para el pedido #$pedidoId');
        return false;
      }

      // Verificar si hay ítems de comida y/o bebida
      bool hayComida = false;
      bool hayBebida = false;
      bool todosLosItemsComidaCompletados = true;
      bool todosLosItemsBebidaCompletados = true;

      for (var item in items) {
        final tipo = (item['tipo'] ?? '').toString().toLowerCase();

        if (tipo == 'comida') {
          hayComida = true;
          if (!(item['completado_cocinero'] ?? false)) {
            todosLosItemsComidaCompletados = false;
          }
        } else if (tipo == 'bebida') {
          hayBebida = true;
          if (!(item['completado_barista'] ?? false)) {
            todosLosItemsBebidaCompletados = false;
          }
        }
      }

      // Aplicar las reglas para determinar si debe completarse
      return _determinarSiDebeCompletarse(
        hayComida,
        hayBebida,
        todosLosItemsComidaCompletados,
        todosLosItemsBebidaCompletados,
      );
    } catch (e) {
      print('❌ Error al verificar si el pedido debe completarse: $e');
      return false;
    }
  }

  // Método auxiliar para determinar si un pedido debe completarse automáticamente
  bool _determinarSiDebeCompletarse(
    bool hayComida,
    bool hayBebida,
    bool todosItemsComidaCompletados,
    bool todosItemsBebidaCompletados,
  ) {
    if (hayComida && hayBebida) {
      // Si hay comida y bebida, ambas deben estar completadas
      return todosItemsComidaCompletados && todosItemsBebidaCompletados;
    } else if (hayComida && !hayBebida) {
      // Si solo hay comida, todos los ítems de comida deben estar completados
      return todosItemsComidaCompletados;
    } else if (!hayComida && hayBebida) {
      // Si solo hay bebida, todos los ítems de bebida deben estar completados
      return todosItemsBebidaCompletados;
    }
    return false;
  }

  // Método auxiliar para calcular el total de un pedido
  double _calcularTotalPedido(List<Map<String, dynamic>> items) {
    double total = 0;
    for (var item in items) {
      double cantidad =
          (item['cantidad'] is int)
              ? item['cantidad'].toDouble()
              : double.tryParse(item['cantidad'].toString()) ?? 1.0;

      double precioUnitario =
          (item['precio_unitario'] is num)
              ? item['precio_unitario'] + 0.0
              : double.tryParse(item['precio_unitario'].toString()) ?? 0.0;

      total += cantidad * precioUnitario;
    }
    return total;
  }

  // Método auxiliar para formatear la lista de items de un pedido
  List<Map<String, dynamic>> _formatearItems(
    List<Map<String, dynamic>> itemsPedido,
  ) {
    return itemsPedido.map((item) {
      return {
        'idplato': item['idplato'],
        'nombre': item['nombre'],
        'cantidad':
            item['cantidad'] is int
                ? item['cantidad']
                : int.tryParse(item['cantidad'].toString()) ?? 1,
        'precio_unitario':
            item['precio_unitario'] is num
                ? (item['precio_unitario'] + 0.0)
                : double.tryParse(item['precio_unitario'].toString()) ?? 0.0,
        'notas': item['notas'],
        'completado_cocinero': item['completado_cocinero'] ?? false,
        'completado_barista': item['completado_barista'] ?? false,
        'fecha_completado_cocinero': item['fecha_completado_cocinero'],
        'fecha_completado_barista': item['fecha_completado_barista'],
        'tipo':
            item['tipo'] ?? (item['idplato'] % 2 == 0 ? 'comida' : 'bebida'),
      };
    }).toList();
  }

  // Obtener pedidos filtrados por tipo (comida/bebida)
  Future<List<Map<String, dynamic>>> getOrdersByType(String tipo) async {
    try {
      print('🔍 Buscando pedidos de tipo: $tipo');

      // Validar el tipo
      if (tipo.toLowerCase() != 'comida' && tipo.toLowerCase() != 'bebida') {
        print('❌ Tipo inválido: $tipo. Debe ser "comida" o "bebida"');
        return [];
      }

      // Consulta base para obtener todos los pedidos pendientes
      final query = '''
        SELECT 
          p.idpedido, 
          p.estado, 
          TO_CHAR(p.fecha, 'YYYY-MM-DD') as fecha,
          TO_CHAR(p.fecha, 'HH24:MI') as hora,
          pe.nombre || ' ' || pe.apellido as cliente
        FROM 
          pedidos p
        INNER JOIN 
          personas pe ON p.idpersona = pe.idpersonas
        WHERE 
          p.estado = 'pendiente'
        ORDER BY 
          p.fecha ASC
      ''';

      // Ejecutar consulta para obtener pedidos pendientes
      final data = await _executeQuery(query);
      final result = _extractQueryResults(data);

      if (result.isEmpty) {
        print('⚠️ No se encontraron pedidos pendientes');
        return [];
      }

      // Obtener los IDs de los pedidos
      final pedidosIds = result.map((row) => row['idpedido']).toList();

      // Lista para pedidos que deben completarse automáticamente
      final List<int> pedidosParaCompletar = [];

      // Consultar los detalles de los pedidos
      final detallesQuery = '''
        SELECT 
          pd.idpedido, 
          pd.idplato, 
          pd.cantidad, 
          m.precio as precio_unitario,
          pd.notas,
          pd.completado_cocinero,
          pd.completado_barista,
          pd.fecha_completado_cocinero,
          pd.fecha_completado_barista,
          m.nombre as nombre,
          m.tipo
        FROM 
          pedido_detalle pd 
        INNER JOIN 
          menu m ON pd.idplato = m.idplato 
        WHERE 
          pd.idpedido = ANY(ARRAY[${pedidosIds.join(',')}])
      ''';

      final detallesData = await _executeQuery(detallesQuery);
      final detalles = _extractQueryResults(detallesData);

      // Lista para los pedidos filtrados
      final List<Map<String, dynamic>> orders = [];

      // Procesar cada pedido
      for (final pedido in result) {
        final idPedido = pedido['idpedido'];
        final itemsPedido =
            detalles.where((d) => d['idpedido'] == idPedido).toList();

        // Verificar si todos los ítems están completados
        bool hayComida = false;
        bool hayBebida = false;
        bool todosItemsComidaCompletados = true;
        bool todosItemsBebidaCompletados = true;

        for (var item in itemsPedido) {
          final itemTipo = (item['tipo'] ?? '').toString().toLowerCase();

          if (itemTipo == 'comida') {
            hayComida = true;
            if (!(item['completado_cocinero'] ?? false)) {
              todosItemsComidaCompletados = false;
            }
          } else if (itemTipo == 'bebida') {
            hayBebida = true;
            if (!(item['completado_barista'] ?? false)) {
              todosItemsBebidaCompletados = false;
            }
          }
        }

        // Determinar si el pedido debe completarse automáticamente
        bool debeCompletarse = _determinarSiDebeCompletarse(
          hayComida,
          hayBebida,
          todosItemsComidaCompletados,
          todosItemsBebidaCompletados,
        );

        if (debeCompletarse) {
          print(
            '✅ Detectado pedido #$idPedido que debe completarse automáticamente',
          );
          pedidosParaCompletar.add(idPedido);
          continue; // No agregar a la lista de pedidos pendientes
        }

        // Filtrar los pedidos según el rol (cook o barista)
        final tipoItems =
            itemsPedido.where((item) {
              final itemTipo = (item['tipo'] ?? '').toString().toLowerCase();
              final estaCompletado =
                  tipo == 'comida'
                      ? item['completado_cocinero'] ?? false
                      : item['completado_barista'] ?? false;

              // Incluir este pedido si tiene ítems del tipo correcto que NO están completados
              return itemTipo == tipo && !estaCompletado;
            }).toList();

        // Solo incluir pedidos que tienen ítems del tipo correspondiente pendientes
        if (tipoItems.isNotEmpty) {
          // Calcular total
          double total = _calcularTotalPedido(itemsPedido);

          // Preparar los items formateados
          final items = _formatearItems(itemsPedido);

          // Agregar el pedido a la lista
          orders.add({
            'idpedido': pedido['idpedido'],
            'estado': pedido['estado'],
            'fecha': pedido['fecha'],
            'hora': pedido['hora'],
            'cliente': pedido['cliente'] ?? 'Cliente #${pedido['idpersona']}',
            'total': total,
            'items': items,
          });
        }
      }

      // Completar automáticamente los pedidos que lo necesiten
      for (int idPedido in pedidosParaCompletar) {
        print('🔄 Completando automáticamente el pedido #$idPedido...');
        await updateOrderStatus(idPedido, 'completado');
      }

      print('✅ Se encontraron ${orders.length} pedidos para el rol $tipo');
      return orders;
    } catch (e) {
      print('❌ Error al obtener pedidos por tipo: $e');
      return [];
    }
  }

  // 🆕 NUEVO: Método para obtener información de la mesa asociada a un pedido
  Future<String?> getTableForOrder(int orderId) async {
    try {
      print('🔍 Buscando información de mesa REAL para pedido #$orderId');

      // 🆕 PASO 1: Verificar si tenemos información de mesa guardada del momento de creación
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastOrderTable = prefs.getString('last_order_table');
        final lastOrderTimestamp = prefs.getString('last_order_timestamp');

        if (lastOrderTable != null && lastOrderTimestamp != null) {
          // Verificar si esta información es reciente (últimos 30 minutos)
          try {
            final orderTime = DateTime.parse(lastOrderTimestamp);
            final currentTime = DateTime.now();
            final timeDifference = currentTime.difference(orderTime);

            if (timeDifference.inMinutes <= 30) {
              print(
                '✅ Información de mesa reciente (${timeDifference.inMinutes} min), usando: $lastOrderTable',
              );
              return lastOrderTable;
            } else {
              print(
                '⚠️ Información de mesa obsoleta (${timeDifference.inMinutes} min), buscando mesa real',
              );
            }
          } catch (e) {
            print('❌ Error verificando timestamp de mesa: $e');
          }
        }
      } catch (e) {
        print('❌ Error accediendo a SharedPreferences: $e');
      }

      // 🆕 PASO 2: Obtener dispositivos REALMENTE conectados del sistema
      print('📱 Consultando dispositivos realmente conectados al servidor...');
      final connectedDevices =
          await _tableService.getTablesWithConnectionStatus();
      final activeDevices = connectedDevices.where((d) => d.isActive).toList();

      print('📊 Dispositivos encontrados:');
      print('   - Total configurados: ${connectedDevices.length}');
      print('   - Realmente conectados: ${activeDevices.length}');

      for (final device in activeDevices) {
        print('   ✅ Mesa ${device.tableNumber}: ${device.deviceName}');
      }

      if (activeDevices.isEmpty) {
        print('⚠️ No hay dispositivos realmente conectados');
        print('🔄 Usando mesa por defecto: Mesa 12');
        return 'Mesa 12';
      }

      // 🆕 PASO 3: Asignar mesa basada en dispositivos REALES conectados
      // Si solo hay un dispositivo conectado, usar esa mesa
      if (activeDevices.length == 1) {
        final mesaUnica = activeDevices.first.tableNumber;
        print('📱 Solo hay un dispositivo conectado: Mesa $mesaUnica');
        return 'Mesa $mesaUnica';
      }

      // Si hay múltiples dispositivos, usar distribución consistente basada en ID del pedido
      final mesaIndex = orderId % activeDevices.length;
      final mesaAsignada = activeDevices[mesaIndex].tableNumber;

      print(
        '🎯 Distribución entre ${activeDevices.length} dispositivos conectados:',
      );
      print('   - Pedido #$orderId → índice $mesaIndex → Mesa $mesaAsignada');
      print(
        '   - Dispositivos activos: ${activeDevices.map((d) => 'Mesa ${d.tableNumber}').join(', ')}',
      );

      return 'Mesa $mesaAsignada';
    } catch (e) {
      print('❌ Error obteniendo información de mesa para pedido #$orderId: $e');
      print('🔄 Fallback: Usando mesa por defecto Mesa 12');
      return 'Mesa 12';
    }
  }

  // 🆕 NUEVO: Método para enviar notificación vía servidor WebSocket
  Future<void> _notifyOrderCompletedViaServer(
    int orderId,
    String? mesaInfo,
    String message,
  ) async {
    try {
      if (mesaInfo == null || !mesaInfo.startsWith('Mesa ')) {
        print(
          '⚠️ No se puede enviar notificación: información de mesa inválida ($mesaInfo)',
        );
        return;
      }

      // Extraer número de mesa
      final tableNumberMatch = RegExp(r'Mesa (\d+)').firstMatch(mesaInfo);
      if (tableNumberMatch == null) {
        print('⚠️ No se pudo extraer número de mesa de: $mesaInfo');
        return;
      }

      final tableNumber = int.parse(tableNumberMatch.group(1)!);

      print(
        '🔔 Enviando notificación via servidor: Pedido #$orderId → Mesa $tableNumber',
      );

      final baseUrl = await getBaseUrl;
      final response = await _post(
        'notifications/order-completed',
        body: {
          'orderId': orderId,
          'tableNumber': tableNumber,
          'message': message,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Notificación enviada via servidor: ${data['message']}');
        } else {
          print('⚠️ Servidor reportó fallo: ${data['message']}');
        }
      } else {
        print(
          '❌ Error enviando notificación via servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Excepción enviando notificación via servidor: $e');
    }
  }
}

class OrderSummary {
  final int totalPedidos;
  final double totalVentas;
  final double ticketPromedio;
  final double minPedido;
  final double maxPedido;
  final List<VentasPorHora> ventasPorHora;
  final List<VentasPorCategoria> ventasPorCategoria;
  final List<TicketPromedioPorDia> ticketPromedioPorDia;

  OrderSummary({
    required this.totalPedidos,
    required this.totalVentas,
    required this.ticketPromedio,
    required this.minPedido,
    required this.maxPedido,
    required this.ventasPorHora,
    required this.ventasPorCategoria,
    required this.ticketPromedioPorDia,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      totalPedidos: json['totalPedidos'] ?? 0,
      totalVentas: (json['totalVentas'] ?? 0).toDouble(),
      ticketPromedio: (json['ticketPromedio'] ?? 0).toDouble(),
      minPedido: (json['minPedido'] ?? 0).toDouble(),
      maxPedido: (json['maxPedido'] ?? 0).toDouble(),
      ventasPorHora:
          (json['ventasPorHora'] as List<dynamic>?)
              ?.map((x) => VentasPorHora.fromJson(x))
              .toList() ??
          [],
      ventasPorCategoria:
          (json['ventasPorCategoria'] as List<dynamic>?)
              ?.map((x) => VentasPorCategoria.fromJson(x))
              .toList() ??
          [],
      ticketPromedioPorDia:
          (json['ticketPromedioPorDia'] as List<dynamic>?)
              ?.map((x) => TicketPromedioPorDia.fromJson(x))
              .toList() ??
          [],
    );
  }
}

class VentasPorHora {
  final int hora;
  final int totalPedidos;
  final double totalVentas;

  VentasPorHora({
    required this.hora,
    required this.totalPedidos,
    required this.totalVentas,
  });

  factory VentasPorHora.fromJson(Map<String, dynamic> json) {
    return VentasPorHora(
      hora: json['hora'] ?? 0,
      totalPedidos: json['total_pedidos'] ?? 0,
      totalVentas: (json['total_ventas'] ?? 0).toDouble(),
    );
  }
}

class VentasPorCategoria {
  final String categoria;
  final int totalPedidos;
  final double totalVentas;

  VentasPorCategoria({
    required this.categoria,
    required this.totalPedidos,
    required this.totalVentas,
  });

  factory VentasPorCategoria.fromJson(Map<String, dynamic> json) {
    return VentasPorCategoria(
      categoria: json['categoria'] ?? '',
      totalPedidos: json['total_pedidos'] ?? 0,
      totalVentas: (json['total_ventas'] ?? 0).toDouble(),
    );
  }
}

class TicketPromedioPorDia {
  final int diaSemana;
  final int totalPedidos;
  final double totalVentas;
  final double ticketPromedio;

  TicketPromedioPorDia({
    required this.diaSemana,
    required this.totalPedidos,
    required this.totalVentas,
    required this.ticketPromedio,
  });

  factory TicketPromedioPorDia.fromJson(Map<String, dynamic> json) {
    return TicketPromedioPorDia(
      diaSemana: json['dia_semana'] ?? 0,
      totalPedidos: json['total_pedidos'] ?? 0,
      totalVentas: (json['total_ventas'] ?? 0).toDouble(),
      ticketPromedio: (json['ticket_promedio'] ?? 0).toDouble(),
    );
  }
}
