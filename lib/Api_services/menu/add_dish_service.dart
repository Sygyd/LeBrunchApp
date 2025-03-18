import 'dart:io';
import 'package:http/http.dart' as http;

class MenuService {
  Future<bool> submitDish({
    required String nombre,
    required String categoria,
    required String precio,
    required String disponibilidad,
    required String ingredientes,
    required File? imagenFile,
  }) async {
    try {
      // Crear una solicitud multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.121:3000/menu'),
      );

      // Agregar campos del formulario
      request.fields['nombre'] = nombre;
      request.fields['categoria'] = categoria;
      request.fields['precio'] = precio;
      request.fields['disponibilidad'] = disponibilidad;
      request.fields['ingredientes'] = ingredientes;

      // Agregar la imagen si existe
      if (imagenFile != null) {
        var file = await http.MultipartFile.fromPath(
          'imagen', // Nombre del campo en el backend
          imagenFile.path, // Ruta del archivo
        );
        request.files.add(file);
      }

      // Enviar la solicitud
      var response = await request.send();

      // Verificar la respuesta
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
