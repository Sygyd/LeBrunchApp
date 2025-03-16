import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';


class MenuService {
    
      Future<List<Map<String, dynamic>>> getDishes() async {
    try {
      final response = await http.get(
        Uri.parse('https://panda-central-hyena.ngrok-free.app/menu'),
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

        Future<String> updateDish({
  required String id,
  required String nombre,
  required String categoria,
  required String precio,
  required String disponibilidad,
  required String ingredientes,
  required File? imagenFile, // Si la imagen es un archivo
}) async {
  // Aquí puedes realizar la lógica de actualización de tu plato
  // Ejemplo de cómo podrías enviar estos datos a tu API

  // Prepara los datos para enviar
  

  // Llama a tu API para actualizar el plato con los datos
  // Ejemplo de solicitud HTTP:
  try {
    
  } catch (e) {
    print('Error: $e');
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
      // Crear una solicitud multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          'https://panda-central-hyena.ngrok-free.app/menu',
        ), // Usa la IP correcta
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
