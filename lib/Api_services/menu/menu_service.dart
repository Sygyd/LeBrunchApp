import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
        throw Exception('Error al obtener platos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<bool> submitDish({
    required String nombre,
    required String categoria,
    required String precio,
    required String disponibilidad,
    required String ingredientes,
    required File? imagenFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.121:3000/menu'),
      );

      request.fields['nombre'] = nombre;
      request.fields['categoria'] = categoria;
      request.fields['precio'] = precio;
      request.fields['disponibilidad'] = disponibilidad;
      request.fields['ingredientes'] = ingredientes;

      if (imagenFile != null) {
        var file = await http.MultipartFile.fromPath('imagen', imagenFile.path);
        request.files.add(file);
      }

      var response = await request.send();

      if (response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          'Error al agregar plato: ${await response.stream.bytesToString()}',
        );
      }
    } catch (e) {
      throw Exception('Error al agregar plato: $e');
    }
  }
}
