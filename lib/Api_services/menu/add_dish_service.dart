import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../network_config_service.dart';

class AddDishService {
  // Método para agregar un nuevo plato
  Future<bool> submitDish({
    required String nombre,
    required String categoria,
    required String precio,
    required String disponibilidad,
    required String ingredientes,
    required File? imagenFile,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${NetworkConfigService().baseUrl}/menu'),
      );

      // Agregar el token en los headers
      request.headers['Authorization'] = 'Bearer $token';

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

  // Método para editar un plato existente
  Future<bool> updateDish({
    required String id,
    required String nombre,
    required String categoria,
    required String precio,
    required String disponibilidad,
    required String ingredientes,
    required File? imagenFile,
  }) async {
    try {
      var request = http.MultipartRequest(
        'PUT', // Usamos PUT para actualizar
        Uri.parse(
          '${NetworkConfigService().baseUrl}/menu/$id',
        ), // Incluimos el ID del plato
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
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception(
          'Error al actualizar plato: ${await response.stream.bytesToString()}',
        );
      }
    } catch (e) {
      throw Exception('Error al actualizar plato: $e');
    }
  }

  Future<bool> deleteDish(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${NetworkConfigService().baseUrl}/menu/$id'),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Error al eliminar plato: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
