import 'dart:convert';
import 'package:http/http.dart' as http;

class MenuService {
  Future<List<Map<String, dynamic>>> getDishes() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.121:3000/menu'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Error al obtener platos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
