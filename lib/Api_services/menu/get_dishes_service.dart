import 'dart:convert';
import 'package:http/http.dart' as http;
import '../network_config_service.dart';

class GetDishesService {
  Future<List<Map<String, dynamic>>> getDishes() async {
    try {
      final response = await http.get(
        Uri.parse('${NetworkConfigService().baseUrl}/menu'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        // Filtrar sólo platos, excluyendo bebidas
        final List<Map<String, dynamic>> allItems =
            List<Map<String, dynamic>>.from(data);
        final List<Map<String, dynamic>> dishes =
            allItems.where((item) {
              String categoria =
                  item['categoria']?.toString().toLowerCase() ?? '';
              // Excluir categorías de bebidas
              return categoria != 'expresos' &&
                  categoria != 'frapuccinos' &&
                  categoria != 'cold brew' &&
                  categoria != 'jugos';
            }).toList();
        return dishes;
      } else {
        throw Exception('Error al obtener platos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
