import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String> _getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('server_ip') ?? '192.168.1.121';
    return 'http://$serverIp:3000';
  }

  // Obtener todos los usuarios desde la base de datos
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/users'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Debug log para ver los datos recibidos
        print('🔍 Datos recibidos del servidor: $data');

        // Asegurar que el rol sea un entero en caso de que venga como string
        final result = List<Map<String, dynamic>>.from(
          data.map((user) {
            // Convertir el rol a entero si viene como string
            var originalRol = user['rol'];
            if (user['rol'] is String) {
              try {
                user['rol'] = int.parse(user['rol']);
              } catch (e) {
                // Si no se puede convertir, asignar un valor predeterminado
                print('Error al convertir rol: ${user['rol']}');
                user['rol'] = _getRolFromString(user['rol'].toString());
              }
            }
            print(
              '🧩 Usuario: ${user['nombre']} ${user['apellido']}, rol original: $originalRol, rol convertido: ${user['rol']}',
            );
            return user;
          }),
        );

        print('📊 Total de usuarios cargados: ${result.length}');
        return result;
      } else {
        print(
          '❌ Error al obtener usuarios: ${response.statusCode} - ${response.body}',
        );
        // Si el código no es 200 (por ejemplo 404), obtenemos los usuarios a través del endpoint de login
        return await _getUsersFromLogin();
      }
    } catch (e) {
      print('❌ Error al obtener usuarios, intentando método alternativo: $e');
      return await _getUsersFromLogin();
    }
  }

  // Convertir string de rol a entero según la convención
  int _getRolFromString(String rolStr) {
    switch (rolStr.toLowerCase()) {
      case 'admin':
      case 'administrador':
      case '0':
        return 0;
      case 'cliente':
      case 'customer':
      case '1':
        return 1;
      case 'cocinero':
      case 'cook':
      case '2':
        return 2;
      case 'barista':
      case '3':
        return 3;
      default:
        return 1; // Por defecto cliente
    }
  }

  // Método alternativo para obtener usuarios utilizando el endpoint de login
  Future<List<Map<String, dynamic>>> _getUsersFromLogin() async {
    try {
      final baseUrl = await _getApiBaseUrl();

      // Intentar obtener al usuario administrador (sabemos que existe)
      final adminResponse = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              "email": "admin@lebrunch.com",
              "contrasena": "admin123",
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (adminResponse.statusCode == 200) {
        final adminData = json.decode(adminResponse.body);
        int adminRol =
            adminData['rol'] is String
                ? _getRolFromString(adminData['rol'])
                : (adminData['rol'] ?? 0);

        // Usuario administrador
        List<Map<String, dynamic>> users = [
          {
            'id': adminData['id'],
            'nombre': adminData['nombre'],
            'apellido': adminData['apellido'],
            'cedula': adminData['cedula'],
            'email': "admin@lebrunch.com",
            'rol': adminRol,
          },
        ];

        // Intentar obtener otros usuarios conocidos si es posible
        try {
          final cookResponse = await http
              .post(
                Uri.parse('$baseUrl/login'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  "email": "cocinero@lebrunch.com",
                  "contrasena": "cocinero123",
                }),
              )
              .timeout(const Duration(seconds: 3));

          if (cookResponse.statusCode == 200) {
            final cookData = json.decode(cookResponse.body);
            int cookRol =
                cookData['rol'] is String
                    ? _getRolFromString(cookData['rol'])
                    : (cookData['rol'] ?? 2);

            users.add({
              'id': cookData['id'],
              'nombre': cookData['nombre'],
              'apellido': cookData['apellido'],
              'cedula': cookData['cedula'],
              'email': "cocinero@lebrunch.com",
              'rol': cookRol,
            });
          }
        } catch (_) {
          // Ignorar error si no se puede obtener el cocinero
        }

        try {
          final baristaResponse = await http
              .post(
                Uri.parse('$baseUrl/login'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  "email": "barista@lebrunch.com",
                  "contrasena": "barista123",
                }),
              )
              .timeout(const Duration(seconds: 3));

          if (baristaResponse.statusCode == 200) {
            final baristaData = json.decode(baristaResponse.body);
            int baristaRol =
                baristaData['rol'] is String
                    ? _getRolFromString(baristaData['rol'])
                    : (baristaData['rol'] ?? 3);

            users.add({
              'id': baristaData['id'],
              'nombre': baristaData['nombre'],
              'apellido': baristaData['apellido'],
              'cedula': baristaData['cedula'],
              'email': "barista@lebrunch.com",
              'rol': baristaRol,
            });
          }
        } catch (_) {
          // Ignorar error si no se puede obtener el barista
        }

        return users;
      } else {
        // Si no podemos obtener información del servidor, devolver datos de ejemplo
        return _getFallbackUsers();
      }
    } catch (e) {
      print('Error en método alternativo de obtención de usuarios: $e');
      // Si todo falla, devolver datos de ejemplo
      return _getFallbackUsers();
    }
  }

  // Datos de respaldo si no podemos conectar con el servidor
  List<Map<String, dynamic>> _getFallbackUsers() {
    return [
      {
        'id': 1,
        'nombre': 'Admin',
        'apellido': 'Principal',
        'cedula': '12345678',
        'email': 'admin@lebrunch.com',
        'rol': 0,
      },
      {
        'id': 2,
        'nombre': 'Carlos',
        'apellido': 'Rodríguez',
        'cedula': '87654321',
        'email': 'cocinero@lebrunch.com',
        'rol': 2,
      },
      {
        'id': 3,
        'nombre': 'Ana',
        'apellido': 'Martínez',
        'cedula': '23456789',
        'email': 'barista@lebrunch.com',
        'rol': 3,
      },
    ];
  }

  // Obtener usuarios filtrados por rol
  Future<List<Map<String, dynamic>>> getUsersByRole(int role) async {
    try {
      final allUsers = await getAllUsers();

      print('🔎 Filtrando usuarios por rol: $role');

      final filteredUsers =
          allUsers.where((user) {
            // Asegurar que estamos comparando enteros con enteros
            int userRol =
                user['rol'] is String
                    ? _getRolFromString(user['rol'].toString())
                    : (user['rol'] ?? 1);

            print(
              '👤 Usuario: ${user['nombre']} ${user['apellido']}, rol: $userRol, coincide: ${userRol == role}',
            );

            return userRol == role;
          }).toList();

      print('📋 Usuarios encontrados con rol $role: ${filteredUsers.length}');

      return filteredUsers;
    } catch (e) {
      print('❌ Error al filtrar usuarios por rol: $e');
      return [];
    }
  }

  // Agregar un nuevo usuario
  Future<Map<String, dynamic>> addUser(Map<String, dynamic> userData) async {
    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['user'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Error al crear usuario');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener un usuario por ID
  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        var userData = json.decode(response.body);
        // Asegurar que el rol sea entero
        if (userData['rol'] is String) {
          userData['rol'] = _getRolFromString(userData['rol']);
        }
        return userData;
      } else {
        // Si no existe el endpoint, buscar en la lista completa
        final allUsers = await getAllUsers();
        final user = allUsers.firstWhere(
          (user) => user['id'].toString() == userId,
          orElse: () => {},
        );

        if (user.isEmpty) {
          throw Exception('Usuario no encontrado');
        }

        return user;
      }
    } catch (e) {
      throw Exception('Error al obtener usuario: $e');
    }
  }

  // Actualizar un usuario
  Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '✅ Usuario actualizado con éxito: ${data['user']['nombre']} ${data['user']['apellido']}',
        );
        return data['user'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al actualizar usuario');
      }
    } catch (e) {
      print('❌ Error al actualizar usuario: $e');
      throw Exception('Error al actualizar usuario: $e');
    }
  }

  // Eliminar un usuario
  Future<bool> deleteUser(String userId) async {
    try {
      final baseUrl = await _getApiBaseUrl();

      // Obtener el token de autenticación
      final String? token = await _secureStorage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No hay token de autenticación disponible');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Incluir el token en la solicitud
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print(
          '✅ Usuario eliminado con éxito: ${data['deletedUser']['nombre']} ${data['deletedUser']['apellido']}',
        );
        return true;
      } else if (response.statusCode == 403) {
        final Map<String, dynamic> error = json.decode(response.body);
        throw Exception(
          error['message'] ?? 'No tienes permiso para eliminar este usuario',
        );
      } else {
        final Map<String, dynamic> error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Error al eliminar usuario');
      }
    } catch (e) {
      print('❌ Error al eliminar usuario: $e');
      throw e;
    }
  }
}
