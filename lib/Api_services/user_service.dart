import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String> _getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();

    // Usar siempre esta IP fija
    const String fixedIp = '192.168.1.121';

    // Guardar en ambas claves para futura consistencia
    await prefs.setString('server_ip', fixedIp);
    await prefs.setString('serverIp', fixedIp);

    print('🌐 URL base de API: http://$fixedIp:3000');
    return 'http://$fixedIp:3000';
  }

  // Obtener todos los usuarios desde la base de datos
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final baseUrl = await _getApiBaseUrl();
      print('🔌 Intentando conexión a: $baseUrl/users');

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

        // Asegurar que el rol mantenga su formato original como string
        final result = List<Map<String, dynamic>>.from(
          data.map((user) {
            // MANTENER el rol como string para preservar "00" vs "0"
            var originalRol = user['rol'];

            // Asegurar que el rol sea string
            if (user['rol'] is! String) {
              user['rol'] = user['rol'].toString();
            }

            print(
              '🧩 Usuario: ${user['nombre']} ${user['apellido']}, rol: "${user['rol']}" (mantenido como string)',
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

        // Si el código no es 200, intentar el método alternativo
        print('🔄 Intentando método alternativo para obtener usuarios...');
        final backupUsers = await _getUsersFromLogin();
        if (backupUsers.isNotEmpty) {
          print('✅ Método alternativo exitoso: ${backupUsers.length} usuarios');
          return backupUsers;
        }

        // Si todo falla, retornar una lista vacía
        return [];
      }
    } catch (e) {
      print('❌ Error al obtener usuarios: $e');

      // En caso de error, intentar el método alternativo
      print('🔄 Intentando método alternativo para obtener usuarios...');
      try {
        final backupUsers = await _getUsersFromLogin();
        if (backupUsers.isNotEmpty) {
          print('✅ Método alternativo exitoso: ${backupUsers.length} usuarios');
          return backupUsers;
        }
      } catch (backupError) {
        print('❌ Error en método alternativo: $backupError');
      }

      // Si todo falla, retornar una lista vacía
      return [];
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
      print('🔄 Usando método alternativo para obtener usuarios...');

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
        print('✅ Login exitoso para admin@lebrunch.com');
        final adminData = json.decode(adminResponse.body);
        print('🔑 Datos del admin: ${adminData.toString()}');
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
          print('🔄 Intentando obtener usuario cocinero...');
          final cookResponse = await http
              .post(
                Uri.parse('$baseUrl/login'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({"email": "cook", "contrasena": "cook123"}),
              )
              .timeout(const Duration(seconds: 3));

          print('📝 Respuesta para cocinero: ${cookResponse.statusCode}');
          if (cookResponse.statusCode == 200) {
            final cookData = json.decode(cookResponse.body);
            print('🔑 Datos del cocinero: ${cookData.toString()}');
            int cookRol =
                cookData['rol'] is String
                    ? _getRolFromString(cookData['rol'])
                    : (cookData['rol'] ?? 2);

            users.add({
              'id': cookData['id'],
              'nombre': cookData['nombre'],
              'apellido': cookData['apellido'],
              'cedula': cookData['cedula'],
              'email': "cook",
              'rol': cookRol,
            });
            print('✅ Usuario cocinero agregado correctamente');
          } else {
            print(
              '❌ No se pudo obtener usuario cocinero: ${cookResponse.body}',
            );
          }
        } catch (e) {
          print('❌ Error al obtener cocinero: $e');
        }

        try {
          print('🔄 Intentando obtener usuario barista...');
          final baristaResponse = await http
              .post(
                Uri.parse('$baseUrl/login'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  "email": "barista",
                  "contrasena": "barista123",
                }),
              )
              .timeout(const Duration(seconds: 3));

          print('📝 Respuesta para barista: ${baristaResponse.statusCode}');
          if (baristaResponse.statusCode == 200) {
            final baristaData = json.decode(baristaResponse.body);
            print('🔑 Datos del barista: ${baristaData.toString()}');
            int baristaRol =
                baristaData['rol'] is String
                    ? _getRolFromString(baristaData['rol'])
                    : (baristaData['rol'] ?? 3);

            users.add({
              'id': baristaData['id'],
              'nombre': baristaData['nombre'],
              'apellido': baristaData['apellido'],
              'cedula': baristaData['cedula'],
              'email': "barista",
              'rol': baristaRol,
            });
            print('✅ Usuario barista agregado correctamente');
          } else {
            print(
              '❌ No se pudo obtener usuario barista: ${baristaResponse.body}',
            );
          }
        } catch (e) {
          print('❌ Error al obtener barista: $e');
        }

        print(
          '📋 Total usuarios obtenidos por método alternativo: ${users.length}',
        );
        return users;
      } else {
        print('❌ No se pudo obtener usuario admin: ${adminResponse.body}');
        // Si no podemos obtener información del servidor, devolver lista vacía
        return [];
      }
    } catch (e) {
      print('Error en método alternativo de obtención de usuarios: $e');
      // Si todo falla, devolver lista vacía
      return [];
    }
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

      // Obtener el token de autenticación desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      print('🔑 Verificando token de autenticación para actualización...');
      print(
        '🔑 Token encontrado: ${token != null ? "Sí (${token.length > 20 ? token.substring(0, 20) + '...' : token})" : "No"}',
      );

      if (token == null) {
        // Intentar obtener información adicional para debug
        final allKeys = prefs.getKeys();
        print('🔍 Claves disponibles en SharedPreferences: $allKeys');
        throw Exception('No hay token de autenticación disponible');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Incluir el token en la solicitud
        },
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
          '✅ Usuario actualizado con éxito: ${data['success'] ? 'Éxito' : 'Respuesta inesperada'}',
        );
        return {'success': true, 'message': 'Usuario actualizado exitosamente'};
      } else {
        final error = json.decode(response.body);
        throw Exception(
          error['message'] ?? error['error'] ?? 'Error al actualizar usuario',
        );
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

      // Obtener el token de autenticación desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('auth_token');

      print('🔑 Verificando token de autenticación...');
      print(
        '🔑 Token encontrado: ${token != null ? "Sí (${token.length > 20 ? token.substring(0, 20) + '...' : token})" : "No"}',
      );

      if (token == null) {
        // Intentar obtener información adicional para debug
        final allKeys = prefs.getKeys();
        print('🔍 Claves disponibles en SharedPreferences: $allKeys');
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
