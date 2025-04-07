import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente para comunicarse directamente con la API de Gemini
class GeminiApiClient {
  // URL base de la API de Gemini
  static const String baseUrl = "https://generativelanguage.googleapis.com";

  // Cliente HTTP normal sin interceptores para evitar problemas
  late final http.Client _client;

  // Clave API actual
  String _apiKey;

  // Constructor
  GeminiApiClient(this._apiKey) {
    // Usar un cliente HTTP normal en lugar de interceptores
    _client = http.Client();
  }

  // Actualizar la clave API
  void updateApiKey(String newApiKey) {
    _apiKey = newApiKey;
  }

  /// Envía una solicitud simple a la API de Gemini (compatibilidad con versiones anteriores)
  Future<String?> generateContent(
    dynamic content, {
    double temperature = 0.7,
    int maxOutputTokens = 2048,
    double topP = 0.9,
    int topK = 40,
  }) async {
    // Si el contenido es una cadena simple, convertirlo al formato de historial
    if (content is String) {
      return _generateContentWithHistory(
        [
          {
            'role': 'user',
            'parts': [
              {'text': content},
            ],
          },
        ],
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
        topP: topP,
        topK: topK,
      );
    } else if (content is List) {
      // Si ya es una lista de mensajes, enviarla directamente
      return _generateContentWithHistory(
        content,
        temperature: temperature,
        maxOutputTokens: maxOutputTokens,
        topP: topP,
        topK: topK,
      );
    } else {
      throw ArgumentError(
        'El contenido debe ser una cadena o una lista de mensajes',
      );
    }
  }

  /// Envía una solicitud con historial de conversación a la API de Gemini
  Future<String?> _generateContentWithHistory(
    List<dynamic> history, {
    double temperature = 0.7,
    int maxOutputTokens = 2048,
    double topP = 0.9,
    int topK = 40,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/v1/models/gemini-2.5-pro-preview-03-25:generateContent?key=$_apiKey',
      );

      final payload = jsonEncode({
        'contents': history,
        'generationConfig': {
          'temperature': temperature,
          'topP': topP,
          'topK': topK,
          'maxOutputTokens': maxOutputTokens,
        },
      });

      print('GeminiApiClient: Enviando solicitud a Gemini API...');

      // Intentar hasta 3 veces
      int attempts = 0;
      const maxAttempts = 3;
      http.Response? response;

      while (attempts < maxAttempts) {
        try {
          attempts++;
          response = await _client
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: payload,
              )
              .timeout(const Duration(seconds: 20));

          // Si la respuesta es exitosa, no necesitamos más intentos
          if (response.statusCode >= 200 && response.statusCode < 300) {
            break;
          }

          // Si hay un error 404, intentar con la versión beta o modelo alternativo
          if (response.statusCode == 404 && attempts == 1) {
            print(
              'Modelo no encontrado en v1, intentando con modelo alternativo...',
            );
            final urlAlt = Uri.parse(
              '$baseUrl/v1/models/gemini-2.0-flash:generateContent?key=$_apiKey',
            );

            response = await _client
                .post(
                  urlAlt,
                  headers: {'Content-Type': 'application/json'},
                  body: payload,
                )
                .timeout(const Duration(seconds: 20));

            if (response.statusCode >= 200 && response.statusCode < 300) {
              break;
            }
          }

          // Si sigue fallando, intentar con un tercer modelo
          if (response.statusCode == 404 && attempts == 2) {
            print('Segundo modelo falló, intentando con modelo de respaldo...');
            final urlFallback = Uri.parse(
              '$baseUrl/v1/models/gemini-1.5-flash:generateContent?key=$_apiKey',
            );

            response = await _client
                .post(
                  urlFallback,
                  headers: {'Content-Type': 'application/json'},
                  body: payload,
                )
                .timeout(const Duration(seconds: 20));

            if (response.statusCode >= 200 && response.statusCode < 300) {
              break;
            }
          }

          print(
            'Intento $attempts falló con código ${response.statusCode}. ${attempts < maxAttempts ? "Reintentando..." : ""}',
          );

          // Esperar brevemente antes del siguiente intento
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: 1));
          }
        } catch (e) {
          print('Error en intento $attempts: $e');
          // Esperar brevemente antes del siguiente intento
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }

      // Procesar la respuesta final
      if (response != null &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded['candidates'] != null &&
            decoded['candidates'].isNotEmpty &&
            decoded['candidates'][0]['content'] != null &&
            decoded['candidates'][0]['content']['parts'] != null &&
            decoded['candidates'][0]['content']['parts'].isNotEmpty) {
          return decoded['candidates'][0]['content']['parts'][0]['text'];
        }
      } else if (response != null) {
        throw Exception('${response.statusCode} - ${response.body}');
      } else {
        throw Exception('Todas las solicitudes fallaron sin respuesta');
      }
    } catch (e) {
      print('Error en GeminiApiClient: $e');
      throw e;
    }
    return null;
  }

  // Cerrar el cliente cuando ya no sea necesario
  void dispose() {
    _client.close();
  }
}
