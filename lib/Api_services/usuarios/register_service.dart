import 'dart:convert';
import 'package:http/http.dart' as http;
import '/models/user.dart';

class ApiService {
  static const String apiUrl =
      "http://192.168.1.121:3000"; // Cambia la IP según tu servidor

  // Registrar usuario
  static Future<bool> registerUser(
    User user, {
    required String contrasena,
  }) async {
    final response = await http.post(
      Uri.parse("$apiUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({...user.toJson(), 'contrasena': contrasena}),
    );
    print("Código de respuesta: ${response.statusCode}");
    print("Respuesta del servidor: ${response.body}");
    if (response.statusCode == 201) {
      return true; // Registro exitoso
    } else {
      throw Exception("Error en el registro: ${response.body}");
    }
  }
}
