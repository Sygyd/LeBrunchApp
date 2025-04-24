import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Cliente para comunicarse directamente con la API de Gemini
/// y con compatibilidad con el MCP del servidor Node.js
class GeminiApiClient {
  // URL base de la API de Gemini
  static const String baseUrl = "https://generativelanguage.googleapis.com";

  // Cliente HTTP normal
  final http.Client _client = http.Client();

  // Clave API actual
  String _apiKey;

  // Servidor de Node.js para fallback
  String _serverUrl =
      'http://192.168.1.121:3000'; // Valor predeterminado inicial

  // Modelos de Gemini ordenados por preferencia
  static const List<String> _models = [
    'gemini-2.5-pro-preview-03-25',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  // Constructor
  GeminiApiClient(this._apiKey) {
    // Inicializar el serverUrl de manera segura
    String serverIp;
    String serverPort;

    try {
      // Intentar obtener los valores de dotenv si están disponibles
      if (dotenv.env.containsKey('NODE_SERVER_IP')) {
        serverIp = dotenv.env['NODE_SERVER_IP']!;
      } else {
        serverIp = '192.168.1.121'; // Valor predeterminado
      }

      if (dotenv.env.containsKey('NODE_SERVER_PORT')) {
        serverPort = dotenv.env['NODE_SERVER_PORT']!;
      } else {
        serverPort = '3000'; // Valor predeterminado
      }
    } catch (e) {
      // Si hay algún error, usar valores predeterminados
      print('Error al acceder a variables de entorno en GeminiApiClient: $e');
      serverIp = '192.168.1.121';
      serverPort = '3000';
    }

    _serverUrl = 'http://$serverIp:$serverPort';
    print('GeminiApiClient inicializado con servidor: $_serverUrl');
  }

  // Actualizar la clave API
  void updateApiKey(String newApiKey) {
    _apiKey = newApiKey;
  }

  /// Envía una solicitud a la API de Gemini con opción de fallback al MCP
  Future<String?> generateContent(
    dynamic content, {
    double temperature = 0.7,
    int maxOutputTokens = 2048,
    double topP = 0.9,
    int topK = 40,
    bool useMcpIfAvailable = true,
  }) async {
    // Convertir el contenido al formato requerido
    String? message;
    List<dynamic> formattedContent;

    if (content is String) {
      message = content;
      formattedContent = [
        {
          'role': 'user',
          'parts': [
            {'text': content},
          ],
        },
      ];
    } else if (content is List) {
      formattedContent = content;

      // Intentar extraer el mensaje del usuario para usar con MCP si es necesario
      try {
        for (final item in content) {
          if (item['role'] == 'user') {
            final parts = item['parts'];
            if (parts is List && parts.isNotEmpty) {
              message = parts.last['text'];
              break;
            }
          }
        }
      } catch (e) {
        print('Error al extraer mensaje para MCP: $e');
      }
    } else {
      throw ArgumentError(
        'El contenido debe ser una cadena o una lista de mensajes',
      );
    }

    // ESTRATEGIA 1: Intentar primero con MCP si hay mensaje disponible y está habilitado
    if (useMcpIfAvailable && message != null) {
      try {
        final mcpResponse = await _tryMcpGeneration(message);
        if (mcpResponse != null) {
          return mcpResponse;
        }
      } catch (e) {
        print('Error con MCP, continuando con Gemini directo: $e');
      }
    }

    // ESTRATEGIA 2: Intentar con cada modelo de Gemini en orden
    return await _tryDirectGeminiGeneration(
      formattedContent,
      temperature,
      maxOutputTokens,
      topP,
      topK,
    );
  }

  /// Intenta generar contenido usando el MCP del servidor Node.js
  Future<String?> _tryMcpGeneration(String message) async {
    try {
      // Verificar si el servidor MCP está disponible
      final statusUrl = Uri.parse('$_serverUrl/mcp/status');
      final statusResponse = await _client
          .get(statusUrl)
          .timeout(const Duration(seconds: 5));

      if (statusResponse.statusCode != 200) {
        print('MCP no disponible (${statusResponse.statusCode})');
        return null;
      }

      // Usar el MCP para enriquecer el contexto
      final mcpUrl = Uri.parse('$_serverUrl/mcp/chat');
      final mcpResponse = await _client
          .post(
            mcpUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'sessionId': 'flutter_${DateTime.now().millisecondsSinceEpoch}',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (mcpResponse.statusCode == 200) {
        final mcpData = jsonDecode(mcpResponse.body);

        // Si el MCP proporciona un contexto enriquecido, usarlo con Gemini
        if (mcpData['enrichedContext'] != null) {
          print('Recibido contexto enriquecido de MCP');

          // Usar el contexto enriquecido con una API key de Gemini
          for (final model in _models) {
            try {
              final url = Uri.parse(
                '$baseUrl/v1/models/$model:generateContent?key=$_apiKey',
              );

              final payload = jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': mcpData['enrichedContext']},
                    ],
                  },
                ],
                'generationConfig': {
                  'temperature': 0.4, // Más bajo para respuestas consistentes
                  'topP': 0.95,
                  'topK': 40,
                  'maxOutputTokens': 2048,
                  'stopSequences': ['Tu respuesta como Brunchy:'],
                },
              });

              final response = await _client
                  .post(
                    url,
                    headers: {'Content-Type': 'application/json'},
                    body: payload,
                  )
                  .timeout(const Duration(seconds: 15));

              if (response.statusCode >= 200 && response.statusCode < 300) {
                final decoded = jsonDecode(response.body);
                if (decoded['candidates'] != null &&
                    decoded['candidates'].isNotEmpty &&
                    decoded['candidates'][0]['content'] != null &&
                    decoded['candidates'][0]['content']['parts'] != null &&
                    decoded['candidates'][0]['content']['parts'].isNotEmpty) {
                  String responseText =
                      decoded['candidates'][0]['content']['parts'][0]['text'];

                  // Validar la respuesta usando el endpoint de validación MCP
                  final validateUrl = Uri.parse('$_serverUrl/mcp/validate');
                  try {
                    final validateResponse = await _client
                        .post(
                          validateUrl,
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({'response': responseText}),
                        )
                        .timeout(const Duration(seconds: 5));

                    if (validateResponse.statusCode == 200) {
                      final validateData = jsonDecode(validateResponse.body);

                      // Si la respuesta no es válida, usar la sugerencia
                      if (validateData['valid'] == false &&
                          validateData['suggestion'] != null) {
                        print(
                          'Respuesta invalidada por MCP, usando sugerencia',
                        );
                        responseText = validateData['suggestion'];
                      }
                    }
                  } catch (e) {
                    print('Error al validar respuesta: $e');
                  }

                  return responseText;
                }
              }
            } catch (e) {
              print('Error con modelo $model usando contexto MCP: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error al usar MCP: $e');
    }

    return null;
  }

  /// Intenta generar contenido directamente con la API de Gemini
  Future<String?> _tryDirectGeminiGeneration(
    List<dynamic> formattedContent,
    double temperature,
    int maxOutputTokens,
    double topP,
    int topK,
  ) async {
    try {
      // Intentar con cada modelo en orden
      for (final model in _models) {
        try {
          final url = Uri.parse(
            '$baseUrl/v1/models/$model:generateContent?key=$_apiKey',
          );

          final payload = jsonEncode({
            'contents': formattedContent,
            'generationConfig': {
              'temperature': temperature,
              'topP': topP,
              'topK': topK,
              'maxOutputTokens': maxOutputTokens,
            },
          });

          final response = await _client
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: payload,
              )
              .timeout(const Duration(seconds: 15));

          // Si la respuesta es exitosa, procesar y devolver
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final decoded = jsonDecode(response.body);
            if (decoded['candidates'] != null &&
                decoded['candidates'].isNotEmpty &&
                decoded['candidates'][0]['content'] != null &&
                decoded['candidates'][0]['content']['parts'] != null &&
                decoded['candidates'][0]['content']['parts'].isNotEmpty) {
              return decoded['candidates'][0]['content']['parts'][0]['text'];
            }
          } else {
            print(
              'Error con modelo $model: ${response.statusCode} - ${response.body}',
            );
          }
        } catch (e) {
          print('Error con modelo $model: $e');
          // Continuar con el siguiente modelo
        }
      }

      // Si todos los modelos fallan, intentar con el servidor directo
      if (_extractMessage(formattedContent) != null) {
        return await _fallbackToServer(_extractMessage(formattedContent)!);
      }
    } catch (e) {
      print('Error en GeminiApiClient: $e');

      // Intentar con servidor como último recurso
      if (_extractMessage(formattedContent) != null) {
        return await _fallbackToServer(_extractMessage(formattedContent)!);
      }
    }
    return null;
  }

  /// Extrae el mensaje del usuario de un formato estructurado
  String? _extractMessage(List<dynamic> content) {
    try {
      for (var item in content) {
        if (item['role'] == 'user') {
          if (item['parts'] != null && item['parts'].isNotEmpty) {
            return item['parts'][0]['text'];
          }
        }
      }
    } catch (e) {
      print('Error al extraer mensaje: $e');
    }
    return null;
  }

  /// Último recurso: usar el servidor Node.js directamente
  Future<String?> _fallbackToServer(String message) async {
    try {
      print('Intentando fallback al servidor...');
      final response = await _client
          .post(
            Uri.parse('$_serverUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'message': message,
              'sessionId':
                  'flutter_fallback_${DateTime.now().millisecondsSinceEpoch}',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['response'] != null) {
          print('Respuesta obtenida del servidor de respaldo');
          return data['response'];
        }
      }
    } catch (e) {
      print('Error en fallback al servidor: $e');
    }
    return null;
  }

  // Cerrar el cliente cuando ya no sea necesario
  void dispose() {
    _client.close();
  }
}
