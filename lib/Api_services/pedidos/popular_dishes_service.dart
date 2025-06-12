import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../network_config_service.dart';

class PopularDishesService {
  final NetworkConfigService _networkConfig = NetworkConfigService();

  // Método para obtener la URL base del servidor usando NetworkConfigService
  Future<String> _getBaseUrl() async {
    // Asegurar que la configuración esté inicializada
    if (!_networkConfig.isConfigured) {
      await _networkConfig.initialize();
    }

    final baseUrl = _networkConfig.baseUrl;
    print('🌐 PopularDishesService - URL base del servidor: $baseUrl');
    return baseUrl;
  }

  // Obtener los platos más populares con filtros opcionales - VERSIÓN OPTIMIZADA
  Future<List<Map<String, dynamic>>> getPopularDishes({
    String? period,
    String? startDate,
    String? endDate,
    String? category,
    int limit = 20,
  }) async {
    try {
      // Construir los parámetros de consulta de forma optimizada
      final queryParams = <String, String>{'limit': limit.toString()};

      // ¡OPTIMIZACIÓN! Solo agregar parámetros que realmente se necesitan
      if (period != null && period.isNotEmpty && period != 'null') {
        queryParams['period'] = period;
        print('🔧 [OPTIMIZADO] Agregando período: $period');
      }

      if (startDate != null && startDate.isNotEmpty && startDate != 'null') {
        queryParams['startDate'] = startDate;
        print('🔧 [OPTIMIZADO] Agregando fecha inicio: $startDate');
      }

      if (endDate != null && endDate.isNotEmpty && endDate != 'null') {
        queryParams['endDate'] = endDate;
        print('🔧 [OPTIMIZADO] Agregando fecha fin: $endDate');
      }

      if (category != null &&
          category.isNotEmpty &&
          category != 'null' &&
          category != 'todos') {
        queryParams['categoria'] = category;
        print('🔧 [OPTIMIZADO] Agregando categoría: $category');
      }

      // Obtener la URL base del servidor
      final baseUrl = await _getBaseUrl();

      // Construir la URI con los parámetros optimizados
      final uri = Uri.parse(
        '$baseUrl/pedidos/stats/mas-vendidos',
      ).replace(queryParameters: queryParams);

      print('🌐 [OPTIMIZADO] URL de consulta: $uri');

      // Realizar la solicitud HTTP
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is List) {
          final dishes = List<Map<String, dynamic>>.from(data);
          print('✅ [OPTIMIZADO] Respuesta exitosa: ${dishes.length} platos');

          // Procesar las URLs de las imágenes de forma optimizada
          final dishesWithFullUrls = await _processDishesWithFullUrls(dishes);

          print(
            '🖼️ [OPTIMIZADO] URLs procesadas para ${dishesWithFullUrls.length} platos',
          );
          return dishesWithFullUrls;
        } else {
          print(
            '❌ [OPTIMIZADO] Formato de respuesta inesperado: ${data.runtimeType}',
          );
          return [];
        }
      } else {
        print(
          '❌ [OPTIMIZADO] Error HTTP ${response.statusCode}: ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('❌ [OPTIMIZADO] Error en getPopularDishes: $e');
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

      // Obtener todos los platos del menú con URLs corregidas
      final response = await http.get(
        Uri.parse('$baseUrl/menu-with-corrected-urls'),
      );

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

  // Método para asegurar que la URL de la imagen esté completa
  Future<String> _ensureFullImageUrl(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return '';

    // Si ya es una URL completa, verificar si es de nuestro servidor actual
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      final baseUrl = await _getBaseUrl();

      // Si no es de nuestro servidor actual, corregir la URL
      if (!imageUrl.startsWith(baseUrl)) {
        // Extraer solo el nombre del archivo
        final match = RegExp(r'/uploads/(.+)$').firstMatch(imageUrl);
        if (match != null && match.group(1) != null) {
          final filename = match.group(1)!;
          final correctedUrl = '$baseUrl/uploads/$filename';
          print('🔧 URL corregida: $imageUrl → $correctedUrl');
          return correctedUrl;
        }
      }

      return imageUrl;
    }

    // Si es una URL relativa, convertirla a absoluta
    final baseUrl = await _getBaseUrl();
    final fullUrl =
        imageUrl.startsWith('/') ? '$baseUrl$imageUrl' : '$baseUrl/$imageUrl';

    print('🔗 URL convertida a absoluta: $imageUrl → $fullUrl');
    return fullUrl;
  }

  // Método optimizado para procesar URLs de imágenes
  Future<List<Map<String, dynamic>>> _processDishesWithFullUrls(
    List<Map<String, dynamic>> dishes,
  ) async {
    if (dishes.isEmpty) return dishes;

    final baseUrl = await _getBaseUrl();

    return dishes.map((dish) {
      var processedDish = Map<String, dynamic>.from(dish);
      final originalUrl = dish['imagen_url'];

      if (originalUrl != null && originalUrl.isNotEmpty) {
        if (originalUrl.startsWith('http://') ||
            originalUrl.startsWith('https://')) {
          // Si no es de nuestro servidor actual, corregir la URL
          if (!originalUrl.startsWith(baseUrl)) {
            final match = RegExp(r'/uploads/(.+)$').firstMatch(originalUrl);
            if (match != null && match.group(1) != null) {
              final filename = match.group(1)!;
              processedDish['imagen_url'] = '$baseUrl/uploads/$filename';
              print(
                '🔧 URL procesada: $originalUrl → ${processedDish['imagen_url']}',
              );
            }
          }
        } else {
          // URL relativa, convertir a absoluta
          processedDish['imagen_url'] =
              originalUrl.startsWith('/')
                  ? '$baseUrl$originalUrl'
                  : '$baseUrl/$originalUrl';
        }
      }

      return processedDish;
    }).toList();
  }

  // Método para obtener los platos más vendidos con filtros opcionales - VERSIÓN OPTIMIZADA
  Future<List<Map<String, dynamic>>> getPopularDishesDirect({
    String? period,
    String? startDate,
    String? endDate,
    int limit = 5,
    String? categoria,
  }) async {
    try {
      print('🔄 [OPTIMIZADO] PopularDishesService: Solicitud optimizada');
      print('   📅 Período: ${period ?? 'null'}');
      print('   📅 Fechas: ${startDate ?? 'null'} a ${endDate ?? 'null'}');
      print('   🎯 Categoría: ${categoria ?? 'null'}');
      print('   📊 Límite: $limit');

      // Usar el método estándar optimizado
      final result = await getPopularDishes(
        period: period,
        startDate: startDate,
        endDate: endDate,
        category: categoria,
        limit: limit,
      );

      print(
        '✅ [OPTIMIZADO] PopularDishesService: ${result.length} platos obtenidos',
      );

      if (result.isNotEmpty) {
        print('📊 [OPTIMIZADO] Top 3 resultados:');
        result.take(3).forEach((plato) {
          final nombre = plato['nombre'] ?? 'Sin nombre';
          final vendidos = plato['cantidad_vendida'] ?? 0;
          final categoria = plato['categoria'] ?? 'Sin categoría';
          print('   • $nombre ($categoria): $vendidos vendidos');
        });
      }

      return result;
    } catch (e) {
      print('⚠️ [OPTIMIZADO] PopularDishesService: Error - $e');
      return [];
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
