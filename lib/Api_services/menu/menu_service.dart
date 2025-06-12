import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../network_config_service.dart';

class MenuService {
  final NetworkConfigService _networkConfig = NetworkConfigService();

  // Método para obtener la URL base del servidor usando NetworkConfigService
  Future<String> _getBaseUrl() async {
    // Asegurar que la configuración esté inicializada
    if (!_networkConfig.isConfigured) {
      await _networkConfig.initialize();
    }

    final baseUrl = _networkConfig.baseUrl;
    print('🌐 MenuService - URL base del servidor: $baseUrl');
    return baseUrl;
  }

  // NUEVO: Método para corregir las URLs de imágenes en el servidor
  Future<Map<String, dynamic>> fixImageUrls() async {
    try {
      final baseUrl = await _getBaseUrl();
      print('🔧 MenuService: Corrigiendo URLs de imágenes...');

      final response = await http.post(
        Uri.parse('$baseUrl/admin/fix-image-urls'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ URLs de imágenes corregidas exitosamente');
        return data;
      } else {
        print('❌ Error al corregir URLs: ${response.statusCode}');
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error en fixImageUrls: $e');
      throw Exception('Error al corregir URLs de imágenes: $e');
    }
  }

  // ACTUALIZADO: Método que usa el endpoint con URLs corregidas dinámicamente
  Future<List<Map<String, dynamic>>> getDishes() async {
    try {
      final baseUrl = await _getBaseUrl();

      // Usar el endpoint que corrige URLs dinámicamente
      final response = await http.get(
        Uri.parse('$baseUrl/menu-with-corrected-urls'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        final dishes = List<Map<String, dynamic>>.from(data);

        print('🍽️ Platos obtenidos con URLs corregidas: ${dishes.length}');

        // Log de algunas URLs para debug
        if (dishes.isNotEmpty) {
          for (int i = 0; i < (dishes.length < 3 ? dishes.length : 3); i++) {
            final dish = dishes[i];
            print('   📸 ${dish['nombre']}: ${dish['imagen_url']}');
          }
        }

        return dishes;
      } else {
        throw Exception('Error al obtener platos: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al obtener platos: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  // NUEVO: Método para obtener menú completo con URLs corregidas
  Future<List<Map<String, dynamic>>> getMenuCompleto() async {
    try {
      final baseUrl = await _getBaseUrl();

      // Usar el endpoint que corrige URLs dinámicamente
      final response = await http.get(
        Uri.parse('$baseUrl/menu-completo-corrected'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        final dishes = List<Map<String, dynamic>>.from(data);

        print(
          '🍽️ Menú completo obtenido con URLs corregidas: ${dishes.length}',
        );
        return dishes;
      } else {
        throw Exception(
          'Error al obtener menú completo: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Error al obtener menú completo: $e');
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
      final baseUrl = await _getBaseUrl();
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/menu'));

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
        print('✅ Plato agregado exitosamente');
        return true;
      } else {
        throw Exception(
          'Error al agregar plato: ${await response.stream.bytesToString()}',
        );
      }
    } catch (e) {
      print('❌ Error al agregar plato: $e');
      throw Exception('Error al agregar plato: $e');
    }
  }
}
