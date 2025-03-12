import 'dart:convert';
import 'package:http/http.dart' as http;

class MenuService {
  Future<bool> submitDish(Map<String, dynamic> dish) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:3000/add-dish'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(dish),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Error al agregar plato: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al agregar plato: $e');
    }
  }
}
