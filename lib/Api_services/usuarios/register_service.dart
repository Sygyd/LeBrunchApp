import 'dart:convert';
import 'package:http/http.dart' as http;
import '/models/user.dart';

class ApiService {
  static const String apiUrl =
      "http://10.0.2.2:3000"; // Cambia la IP según tu servidor

  // Registrar usuario
  static Future<bool> registerUser(User user) async {
    final response = await http.post(
      Uri.parse("$apiUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(user.toJson()),
    );
    print("Código de respuesta: ${response.statusCode}");
    print("Respuesta del servidor: ${response.body}");
    if (response.statusCode == 201) {
      return true; // Registro exitoso
    } else {
      return false; // Error en el registro
    }
  }
}
