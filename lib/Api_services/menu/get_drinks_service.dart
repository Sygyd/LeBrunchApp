import 'dart:convert';
import 'package:http/http.dart' as http;
import '../network_config_service.dart';

class GetDrinksService {
  final NetworkConfigService _networkConfig = NetworkConfigService();

  Future<List<Map<String, dynamic>>> getDrinks() async {
    try {
      // Usar el endpoint con URLs corregidas dinámicamente
      final baseUrl = _networkConfig.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl/menu-with-corrected-urls'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        // Filtrar sólo bebidas (tipo = 'bebida')
        final List<Map<String, dynamic>> allItems =
            List<Map<String, dynamic>>.from(data);
        final List<Map<String, dynamic>> drinks =
            allItems.where((item) {
              String tipo = item['tipo']?.toString().toLowerCase() ?? '';
              String categoria =
                  item['categoria']?.toString().toLowerCase() ?? '';

              // Priorizar el campo 'tipo' si está disponible
              if (tipo.isNotEmpty) {
                return tipo == 'bebida';
              }

              // Fallback a filtro por categoría
              return categoria == 'expresos' ||
                  categoria == 'frapuccinos' ||
                  categoria == 'cold brew' ||
                  categoria == 'jugos';
            }).toList();

        print('🥤 GetDrinksService: ${drinks.length} bebidas obtenidas');
        return drinks;
      } else {
        throw Exception('Error al obtener bebidas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
