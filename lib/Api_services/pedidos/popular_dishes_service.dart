import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class PopularDishesService {
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

  // Obtener los platos más populares con filtros opcionales
  Future<List<Map<String, dynamic>>> getPopularDishes({
    String? period, // 'day', 'week', 'month', 'year'
    String? startDate,
    String? endDate,
    String? category,
    int limit = 20,
  }) async {
    try {
      // Construir los parámetros de consulta
      final queryParams = <String, String>{'limit': limit.toString()};

      // Agregar parámetros opcionales si están disponibles
      if (period != null && period != 'custom') {
        queryParams['period'] = period;
      }

      if (startDate != null) {
        queryParams['startDate'] = startDate;
      }

      if (endDate != null) {
        queryParams['endDate'] = endDate;
      }

      if (category != null && category.isNotEmpty) {
        queryParams['categoria'] = category;
      }

      // Obtener la URL base del servidor
      final baseUrl = await _getBaseUrl();

      // Construir la URI con los parámetros
      final uri = Uri.parse(
        '$baseUrl/pedidos/stats/mas-vendidos',
      ).replace(queryParameters: queryParams);

      print('🔍 Consultando platos populares: $uri');

      // Realizar la solicitud HTTP
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List) {
          final dishes = List<Map<String, dynamic>>.from(data);
          print('✅ Se obtuvieron ${dishes.length} platos populares');

          // Obtener las categorías para los platos si no tienen
          final dishesWithCategories = await _addCategoriesIfMissing(dishes);
          return dishesWithCategories;
        } else {
          print('❌ Formato de respuesta inesperado');
          return [];
        }
      } else {
        print(
          '❌ Error al obtener platos populares: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('⚠️ Excepción al obtener platos populares: $e');
      return [];
    }
  }

  // Método para agregar información de categoría si falta
  Future<List<Map<String, dynamic>>> _addCategoriesIfMissing(
    List<Map<String, dynamic>> dishes,
  ) async {
    // Verificar si ya tienen categoría
    final dishesNeedingCategory =
        dishes
            .where(
              (dish) => dish['categoria'] == null && dish['idplato'] != null,
            )
            .toList();

    if (dishesNeedingCategory.isEmpty) {
      return dishes;
    }

    try {
      final baseUrl = await _getBaseUrl();

      // Obtener todos los platos del menú
      final response = await http.get(Uri.parse('$baseUrl/menu'));

      if (response.statusCode == 200) {
        final List<dynamic> menuItems = json.decode(response.body);

        // Crear un mapa de id -> categoria
        final Map<int, String> categoriesMap = {};
        for (var item in menuItems) {
          if (item is Map &&
              item['idplato'] != null &&
              item['categoria'] != null) {
            categoriesMap[item['idplato']] = item['categoria'];
          }
        }

        // Actualizar los platos con las categorías
        return dishes.map((dish) {
          if (dish['categoria'] == null && dish['idplato'] != null) {
            final int dishId =
                dish['idplato'] is String
                    ? int.tryParse(dish['idplato']) ?? 0
                    : dish['idplato'];

            if (categoriesMap.containsKey(dishId)) {
              dish['categoria'] = categoriesMap[dishId];
            }
          }
          return dish;
        }).toList();
      }
    } catch (e) {
      print('⚠️ Error al obtener categorías: $e');
    }

    return dishes;
  }

  // Método alternativo para obtener platos populares directamente de la base de datos
  Future<List<Map<String, dynamic>>> getPopularDishesDirect({
    String? period, // 'day', 'week', 'month', 'year'
    String? startDate,
    String? endDate,
    String? category,
    int limit = 20,
  }) async {
    try {
      print(
        'Solicitud de platos populares: periodo=$period, categoría=$category, fechas=$startDate a $endDate',
      );

      // Convertir el período a fechas si no se proporcionaron fechas específicas
      if (startDate == null && endDate == null && period != null) {
        final DateTime now = DateTime.now();
        endDate = DateFormat('yyyy-MM-dd').format(now);

        switch (period) {
          case 'day':
            startDate = endDate; // Mismo día
            break;
          case 'week':
            startDate = DateFormat(
              'yyyy-MM-dd',
            ).format(now.subtract(const Duration(days: 7)));
            break;
          case 'month':
            startDate = DateFormat(
              'yyyy-MM-dd',
            ).format(now.subtract(const Duration(days: 30)));
            break;
          case 'year':
            startDate = DateFormat(
              'yyyy-MM-dd',
            ).format(now.subtract(const Duration(days: 365)));
            break;
        }

        print('Período $period convertido a fechas: $startDate a $endDate');
      }

      // Construir la consulta SQL optimizada para obtener platos populares
      String sql = '''
      WITH ventas_platos AS (
        SELECT 
          pd.idplato,
          SUM(pd.cantidad) as cantidad_vendida,
          AVG(pd.precio_unitario) as precio_promedio
        FROM 
          pedido_detalle pd
        JOIN 
          pedidos p ON pd.idpedido = p.idpedido
        WHERE 
          p.estado = 'completado'
      ''';

      // Añadir filtros de fecha si se proporcionan
      List<String> conditions = [];

      if (startDate != null) {
        conditions.add("DATE(p.fecha) >= '$startDate'::date");
      }

      if (endDate != null) {
        conditions.add("DATE(p.fecha) <= '$endDate'::date");
      }

      if (conditions.isNotEmpty) {
        sql += " AND " + conditions.join(" AND ");
      }

      // Agrupar resultados por plato
      sql += '''
        GROUP BY pd.idplato
      )
      SELECT 
        m.idplato, 
        m.nombre, 
        m.categoria,
        m.precio,
        m.imagen_url,
        COALESCE(vp.cantidad_vendida, 0) as cantidad_vendida,
        COALESCE(vp.precio_promedio, m.precio) as precio_promedio
      FROM 
        menu m
      LEFT JOIN 
        ventas_platos vp ON m.idplato = vp.idplato
      ''';

      // Añadir filtro de categoría si se proporciona
      if (category != null &&
          category.isNotEmpty &&
          category.toLowerCase() != 'todas') {
        sql += " WHERE LOWER(m.categoria) = LOWER('$category')";
      }

      // Ordenar y limitar resultados
      sql += '''
      ORDER BY cantidad_vendida DESC, m.nombre ASC
      LIMIT $limit
      ''';

      print('Consulta SQL optimizada: $sql');

      // Crear el objeto query para la consulta
      final query = {'query': sql};

      // Ejecutar la consulta directa
      final baseUrl = await _getBaseUrl();
      final uri = Uri.parse('$baseUrl/db/query');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(query),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['result'] != null && data['result'].isNotEmpty) {
          final List<Map<String, dynamic>> dishes =
              List<Map<String, dynamic>>.from(data['result']);

          print('Platos obtenidos directamente de BD: ${dishes.length}');

          // Formatear los resultados y asegurar que todos los campos estén presentes
          final formattedDishes =
              dishes
                  .map(
                    (dish) => {
                      'idplato': dish['idplato'],
                      'nombre': dish['nombre'] ?? 'Plato sin nombre',
                      'categoria': dish['categoria'] ?? 'Sin categoría',
                      'imagen_url': dish['imagen_url'] ?? '',
                      'precio': _parseDoubleSafely(dish['precio']),
                      'cantidad_vendida': _parseIntSafely(
                        dish['cantidad_vendida'],
                      ),
                      'precio_promedio': _parseDoubleSafely(
                        dish['precio_promedio'],
                      ),
                    },
                  )
                  .toList();

          // Filtrar: mostrar solo platos que tienen ventas mayores a cero
          final dishesWithSales =
              formattedDishes
                  .where((dish) => dish['cantidad_vendida'] > 0)
                  .toList();

          // Si no hay platos con ventas en el período seleccionado
          if (dishesWithSales.isEmpty) {
            print(
              'No se encontraron platos con ventas en el período seleccionado',
            );

            // Verificar si se aplicaron filtros específicos
            if (category != null || startDate != null || endDate != null) {
              // Mostrar mensaje de que no hay ventas con esos filtros
              return [];
            } else {
              // Para la vista general (sin filtros), mostrar algunos platos del menú
              return await _getTopMenuItems(limit);
            }
          }

          return dishesWithSales;
        } else {
          print('No se encontraron platos populares en la consulta directa');
          return await _getTopMenuItems(limit);
        }
      } else {
        print(
          'Error en consulta directa: ${response.statusCode} - ${response.body}',
        );
        return await _getTopMenuItems(limit);
      }
    } catch (e) {
      print('⚠️ Error en consulta directa de platos populares: $e');
      return await _getTopMenuItems(limit);
    }
  }

  // Método para obtener los platos más vendidos sin aplicar filtros (fallback)
  Future<List<Map<String, dynamic>>> _getTopDishesWithoutFilters(
    int limit,
  ) async {
    // Este método ahora solo se usa como fallback cuando falla la consulta principal
    return await _getTopMenuItems(limit);
  }

  // Método para obtener platos destacados del menú sin considerar ventas
  Future<List<Map<String, dynamic>>> _getTopMenuItems(int limit) async {
    try {
      final baseUrl = await _getBaseUrl();

      // Consulta simple que obtiene los platos destacados del menú (ordenados por nombre)
      final query = {
        'query': '''
          SELECT 
            m.idplato, 
            m.nombre, 
            m.categoria,
            m.precio,
            m.imagen_url,
            0 as cantidad_vendida,
            m.precio as precio_promedio
          FROM 
            menu m
          WHERE 
            m.disponibilidad = true
          ORDER BY 
            m.nombre ASC
          LIMIT $limit
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
          final List<Map<String, dynamic>> dishes =
              List<Map<String, dynamic>>.from(data['result']);

          print('Mostrando platos destacados del menú: ${dishes.length}');

          return dishes
              .map(
                (dish) => {
                  'idplato': dish['idplato'],
                  'nombre': dish['nombre'] ?? 'Plato sin nombre',
                  'categoria': dish['categoria'] ?? 'Sin categoría',
                  'imagen_url': dish['imagen_url'] ?? '',
                  'precio': _parseDoubleSafely(dish['precio']),
                  'cantidad_vendida': 0,
                  'precio_promedio': _parseDoubleSafely(dish['precio']),
                },
              )
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('⚠️ Error al obtener platos del menú: $e');
      return [];
    }
  }

  // Método para parsear enteros de forma segura
  int _parseIntSafely(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // Método para parsear doubles de forma segura
  double _parseDoubleSafely(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}
