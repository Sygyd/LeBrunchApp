import 'dart:convert';
import 'package:http/http.dart' as http;
import '../network_config_service.dart';

class GetDrinksService {
  Future<List<Map<String, dynamic>>> getDrinks() async {
    try {
      final response = await http.get(
        Uri.parse('${NetworkConfigService().baseUrl}/menu'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        // Filtrar solo bebidas
        final List<Map<String, dynamic>> allItems =
            List<Map<String, dynamic>>.from(data);
        final List<Map<String, dynamic>> drinks =
            allItems.where((item) {
              String categoria =
                  item['categoria']?.toString().toLowerCase() ?? '';
              return categoria == 'expresos' ||
                  categoria == 'frapuccinos' ||
                  categoria == 'cold brew' ||
                  categoria == 'jugos';
            }).toList();
        return drinks;
      } else {
        throw Exception('Error al obtener bebidas');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
