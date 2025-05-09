import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async'; // Importar dart:async para TimeoutException

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

  // Constructor con inicialización de URL base
  OrdersService([this.baseUrl]) {
    _cachedBaseUrl = _initBaseUrl();
  }

  // Inicializa y cachea la URL base para reducir llamadas a SharedPreferences
  Future<String> _initBaseUrl() async {
    if (baseUrl != null) return baseUrl!;

    final prefs = await SharedPreferences.getInstance();
    final serverIp =
        prefs.getString('serverIp') ??
        dotenv.env['NODE_SERVER_IP'] ??
        '192.168.1.121';
    final serverPort = dotenv.env['NODE_SERVER_PORT'] ?? '3000';
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
                pd.precio_unitario,
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
                pd.precio_unitario, 
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
    String? period, // 'day', 'week', 'month', 'year', 'all'
    String? customStartDate,
    String? customEndDate,
  }) async {
    try {
      print('📊 Solicitando resumen de pedidos. Periodo: ${period ?? 'all'}');

      // Si period es null o 'all', vamos a obtener todos los datos sin filtros de fecha
      final bool obtenerTodo = period == null || period == 'all';

      // Construir parámetros de consulta
      final queryParams = <String, String>{};
      if (!obtenerTodo) queryParams['period'] = period!;
      if (customStartDate != null) queryParams['startDate'] = customStartDate;
      if (customEndDate != null) queryParams['endDate'] = customEndDate;

      try {
        // Intentar obtener datos desde el endpoint específico
        final response = await _get(
          'pedidos/resumen',
          queryParams: queryParams,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('✅ Datos de resumen obtenidos correctamente de la API');

          // Verificar y completar la estructura del objeto
          if (data is Map) {
            // Convertir Map<dynamic, dynamic> a Map<String, dynamic>
            final Map<String, dynamic> typedData = Map<String, dynamic>.from(
              data,
            );
            _completarDatosFaltantes(typedData);
            _imprimirDetallesResumen(typedData);
            return typedData;
          }
        }

        print(
          '⚠️ Error o respuesta vacía del endpoint de resumen, utilizando consulta directa',
        );
      } catch (e) {
        print('⚠️ Error al obtener resumen desde API: $e');
      }

      // Si falla el endpoint, generar datos directamente con SQL
      return await _fetchSummaryUsingDirectSQL(
        obtenerTodo ? 'all' : period!,
        customStartDate,
        customEndDate,
      );
    } catch (e) {
      print('⚠️ Error global al obtener resumen: $e');
      return <String, dynamic>{
        'totalPedidos': 0,
        'totalVentas': 0.0,
        'ticketPromedio': 0.0,
        'error': e.toString(),
      };
    }
  }

  // Completar datos faltantes en el resumen
  void _completarDatosFaltantes(Map<String, dynamic> data) {
    final validKeys = ['totalPedidos', 'totalVentas', 'ticketPromedio'];
    for (var key in validKeys) {
      if (!data.containsKey(key)) {
        print('⚠️ Falta la clave $key en la respuesta');
        data[key] = 0;
      }
    }
  }

  // Imprimir detalles del resumen para debugging
  void _imprimirDetallesResumen(Map<String, dynamic> data) {
    print('📊 Total de pedidos: ${data['totalPedidos']}');
    print('📊 Total de ventas: ${data['totalVentas']}');
    print('📊 Ticket promedio: ${data['ticketPromedio']}');

    // Datos de distribución
    if (data.containsKey('horasPico'))
      print('⏰ Horas pico: ${data['horasPico']}');
    if (data.containsKey('diasPico'))
      print('📅 Días pico: ${data['diasPico']}');
    if (data.containsKey('semanasPico'))
      print('🗓️ Semanas pico: ${data['semanasPico']}');
    if (data.containsKey('mesesPico'))
      print('📆 Meses pico: ${data['mesesPico']}');
  }

  // Método para generar resumen usando SQL directo
  Future<Map<String, dynamic>> _fetchSummaryUsingDirectSQL(
    String period,
    String? customStartDate,
    String? customEndDate,
  ) async {
    print('🔍 Generando resumen usando SQL directo, periodo: $period');

    try {
      // Determinar la cláusula WHERE basada en el período o fechas personalizadas
      String whereClause = _generarClausulaWherePorPeriodo(
        period,
        customStartDate,
        customEndDate,
      );

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

      final result = await _executeQuery(sql);
      final rows = _extractQueryResults(result);

      if (rows.isNotEmpty) {
        final row = rows[0];

        // Convertir datos a tipos adecuados
        int totalPedidos = int.tryParse(row['total_pedidos'].toString()) ?? 0;
        double totalVentas =
            double.tryParse(row['total_ventas'].toString()) ?? 0.0;
        double ticketPromedio =
            totalPedidos > 0 ? totalVentas / totalPedidos : 0.0;

        // Preparar el resumen
        final summary = {
          'totalPedidos': totalPedidos,
          'totalVentas': totalVentas,
          'ticketPromedio': ticketPromedio,
        };

        // Agregar datos de distribución según el período
        if (period != 'all') {
          await _addDistributionData(summary, period, whereClause);
        } else {
          // Para 'all', obtener datos generales de distribución por meses
          await _addAllTimeDistribution(summary);
        }

        print('✅ Resumen generado exitosamente mediante SQL directo');
        return summary;
      }

      print('❌ Error al generar resumen usando SQL directo');
      return {'totalPedidos': 0, 'totalVentas': 0.0, 'ticketPromedio': 0.0};
    } catch (e) {
      print('❌ Error al generar resumen usando SQL directo: $e');
      return {'totalPedidos': 0, 'totalVentas': 0.0, 'ticketPromedio': 0.0};
    }
  }

  // Generar cláusula WHERE según el período seleccionado
  String _generarClausulaWherePorPeriodo(
    String period,
    String? customStartDate,
    String? customEndDate,
  ) {
    if (customStartDate != null && customEndDate != null) {
      // Usar fechas personalizadas
      print('📅 Usando rango personalizado: $customStartDate a $customEndDate');
      return "p.fecha >= '$customStartDate'::date AND p.fecha <= '$customEndDate'::date + interval '1 day'";
    } else if (period == 'all') {
      // No aplicar filtro de fechas para obtener todo
      print('📅 Obteniendo TODOS los datos sin filtro de fechas');
      return "1=1"; // Condición siempre verdadera
    } else {
      // Calcular cláusula where basada en período
      switch (period) {
        case 'day':
          return "p.fecha >= CURRENT_DATE AND p.fecha < CURRENT_DATE + interval '1 day'";
        case 'week':
          return "p.fecha >= CURRENT_DATE - INTERVAL '7 days' AND p.fecha < CURRENT_TIMESTAMP";
        case 'month':
          return "p.fecha >= DATE_TRUNC('month', CURRENT_DATE) AND p.fecha < CURRENT_TIMESTAMP";
        case 'year':
          return "p.fecha >= DATE_TRUNC('year', CURRENT_DATE) AND p.fecha < CURRENT_TIMESTAMP";
        default:
          return "p.fecha >= CURRENT_DATE AND p.fecha < CURRENT_DATE + interval '1 day'";
      }
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

      // Determinar la consulta SQL según el período
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
          return; // No agregar distribución para períodos no reconocidos
      }

      // Ejecutar la consulta
      final data = await _executeQuery(distributionSQL);
      final result = _extractQueryResults(data);

      if (result.isNotEmpty) {
        summary[resultKey] = result;
        print('✅ Datos de distribución agregados: ${result.length} registros');
      }
    } catch (e) {
      print('⚠️ Error al obtener datos de distribución: $e');
    }
  }

  // Método para agregar distribución de "all"
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

      final data = await _executeQuery(sql);
      final result = _extractQueryResults(data);

      if (result.isNotEmpty) {
        summary['periodosPico'] = result;
        print(
          '✅ Datos de distribución general agregados: ${result.length} registros',
        );
      }
    } catch (e) {
      print('⚠️ Error al obtener datos de distribución general: $e');
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
      print('🔄 Actualizando estado del pedido #$orderId a "$newStatus"');

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
          return true;
        } else {
          print(
            '⚠️ Verificación: El estado del pedido #$orderId sigue siendo "$estadoActual" en lugar de "$newStatus"',
          );
          // Intentar método alternativo
          return await _updateOrderStatusAlternative(orderId, newStatus);
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
  Future<bool> updateItemStatus(
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
        return false;
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
        return false;
      }

      print('✅ Ítem actualizado correctamente');

      // Si se está marcando como completado, verificar si todo el pedido está listo
      if (completado) {
        await checkAndUpdateOrderCompletion(pedidoId);
      }

      return true;
    } catch (e) {
      print('❌ Error al actualizar estado del ítem: $e');
      return false;
    }
  }

  // Verificar y actualizar estado de pedido basado en ítems completados
  Future<bool> checkAndUpdateOrderCompletion(int pedidoId) async {
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
          return false;
        }

        final estadoActual =
            (estadoRows[0]['estado'] ?? '').toString().toLowerCase();

        // Solo actualizar si el estado actual es 'pendiente'
        if (estadoActual == 'pendiente') {
          print(
            '✅ Todos los ítems del pedido #$pedidoId están completados. Actualizando estado a completado.',
          );
          return await updateOrderStatus(pedidoId, 'completado');
        } else {
          print(
            'ℹ️ Pedido #$pedidoId ya no está pendiente, su estado actual es: $estadoActual',
          );
          return false;
        }
      } else {
        print(
          'ℹ️ El pedido #$pedidoId aún no cumple las condiciones para ser completado',
        );
        return false;
      }
    } catch (e) {
      print('❌ Error al verificar y actualizar estado de pedido: $e');
      return false;
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

      final baseUrl = await getBaseUrl;

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
          pd.precio_unitario,
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
}
