import 'dart:convert';
import 'package:http/http.dart' as http;
import '/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterService {
  static const String _baseUrl = 'http://192.168.1.121:3000';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'contrasena': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Guardar información del usuario en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setInt('user_id', data['user']['id']);
        await prefs.setString('user_name', data['user']['nombre']);
        await prefs.setString('user_email', data['user']['email']);
        await prefs.setInt('user_rol', data['user']['rol']);

        // Guardar información de super admin
        final bool isSuperAdmin = data['user']['isSuperAdmin'] == true;
        await prefs.setBool('is_super_admin', isSuperAdmin);

        print('🔑 Login exitoso - Super Admin: $isSuperAdmin');
        print('🔑 Token guardado con clave: auth_token');

        return {
          'success': true,
          'message': 'Login exitoso',
          'user': data['user'],
          'token': data['token'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Error en el login',
        };
      }
    } catch (e) {
      print('❌ Error en login: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<Map<String, dynamic>> register(
    String nombre,
    String apellido,
    String cedula,
    String email,
    String password,
    int rol,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre': nombre,
          'apellido': apellido,
          'cedula': cedula,
          'email': email,
          'contrasena': password,
          'rol': rol,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Usuario registrado exitosamente',
          'user': data['user'],
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['error'] ?? 'Error en el registro',
        };
      }
    } catch (e) {
      print('❌ Error en registro: $e');
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Limpiar todas las preferencias almacenadas
      print('🚪 Logout exitoso - Datos limpiados');
    } catch (e) {
      print('❌ Error en logout: $e');
    }
  }
}
