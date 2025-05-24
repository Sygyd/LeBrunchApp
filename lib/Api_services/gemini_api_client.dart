import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Cliente para comunicarse directamente con la API de Gemini
/// y con compatibilidad con el MCP del servidor Node.js
class GeminiApiClient {
  // URL base de la API de Gemini (no usada directamente si siempre vamos al servidor)
  // static const String baseUrl = "https://generativelanguage.googleapis.com";

  // Cliente HTTP normal
  final http.Client _client = http.Client();

  // Clave API actual (puede ser usada para otras funciones, pero no para el chat con Brunchy)
  String _apiKey;

  // Servidor de Node.js para comunicación principal
  final String _serverUrl;

  // Modelos de Gemini ordenados por preferencia (no usados directamente si siempre vamos al servidor)
  static const List<String> _models = [
    'gemini-1.5-flash',
    'gemini-1.5-pro',
    'gemini-1.0-pro',
  ];

  // Constructor
  GeminiApiClient(this._apiKey)
    : _serverUrl =
          'http://${dotenv.get('NODE_SERVER_IP', fallback: '192.168.1.121')}:${dotenv.get('NODE_SERVER_PORT', fallback: '3000')}';

  // Actualizar la clave API
  void updateApiKey(String newApiKey) {
    _apiKey = newApiKey;
  }

  /// Envía un mensaje de chat al servidor Node.js para que sea procesado por BrunchyMCP.
  /// Retorna un Map<String, dynamic> estructurado que contiene la respuesta de texto
  /// y, opcionalmente, acciones para el carrito.
  Future<Map<String, dynamic>?> generateContent(
    String message, { // Cambiado de dynamic content a String message
    String sessionId =
        'default_flutter_session_id', // Añadido sessionId con valor por defecto
    int timeout = 15, // Tiempo de espera para la respuesta del servidor
  }) async {
    print('🟢 GeminiApiClient.generateContent: INICIANDO');
    print('📨 GeminiApiClient.generateContent: Mensaje: "$message"');
    print('🆔 GeminiApiClient.generateContent: SessionId: "$sessionId"');

    try {
      final result = await _callServerChat(
        message,
        sessionId: sessionId,
        timeout: timeout,
      );

      print('🟢 GeminiApiClient.generateContent: Resultado recibido: $result');
      return result;
    } catch (e) {
      print('❌ GeminiApiClient.generateContent: Error crítico: $e');
      print(
        '❌ GeminiApiClient.generateContent: StackTrace: ${StackTrace.current}',
      );
      return {
        'text_response': 'Error en generateContent: $e',
        'action': 'error',
      };
    }
  }

  // El método _extractMessage ya no es necesario si generateContent recibe directamente el String message.
  // Puedes eliminarlo.
  // String? _extractMessage(List<dynamic> content) { ... }

  /// Llama al endpoint de chat del servidor Node.js.
  /// Ahora espera y devuelve un Map<String, dynamic> estructurado.
  Future<Map<String, dynamic>?> _callServerChat(
    String message, {
    String sessionId = 'default_flutter_session_id',
    int timeout = 15,
  }) async {
    try {
      print('🚀 GeminiApiClient: INICIANDO _callServerChat');
      print('📨 GeminiApiClient: Mensaje: "$message"');
      print('🆔 GeminiApiClient: SessionId: "$sessionId"');
      print('🌐 GeminiApiClient: URL del servidor: $_serverUrl/chat');

      final requestBody = jsonEncode({
        'message': message,
        'sessionId': sessionId,
      });

      print('📤 GeminiApiClient: Enviando request body: $requestBody');

      final response = await _client
          .post(
            Uri.parse('$_serverUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(Duration(seconds: timeout));

      print('📬 GeminiApiClient: Response recibido');
      print('📊 GeminiApiClient: Status code: ${response.statusCode}');
      print('📝 GeminiApiClient: Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('✅ GeminiApiClient: JSON parseado exitosamente');
          print('📋 GeminiApiClient: Datos parseados: $data');
          return data;
        } catch (parseError) {
          print('❌ GeminiApiClient: Error parseando JSON: $parseError');
          print('❌ GeminiApiClient: Raw response: ${response.body}');
          return {
            'text_response': 'Error parseando respuesta del servidor',
            'action': 'error',
          };
        }
      } else {
        print(
          '❌ GeminiApiClient: Error del servidor (${response.statusCode}): ${response.body}',
        );
        return {
          'text_response':
              'Lo siento, hubo un problema al conectar con Brunchy. Código: ${response.statusCode}',
          'action': 'error',
        };
      }
    } catch (e) {
      print('❌ GeminiApiClient: Error crítico al llamar al servidor: $e');
      print('❌ GeminiApiClient: StackTrace: ${StackTrace.current}');
      return {
        'text_response':
            'Lo siento, no pude conectar con Brunchy en este momento. Por favor, revisa tu conexión e intenta de nuevo.',
        'action': 'error',
      };
    }
  }

  // Método para obtener el menú completo del servidor Node.js
  Future<List<dynamic>?> getFullMenuFromServer() async {
    try {
      print(
        'Solicitando menú completo al servidor Node.js ($_serverUrl/menu-completo)...',
      );
      final response = await _client
          .get(
            Uri.parse('$_serverUrl/menu-completo'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 15),
          ); // Aumentado ligeramente por si el menú es grande

      if (response.statusCode == 200) {
        final dynamic menuData = jsonDecode(response.body);
        if (menuData is List) {
          print(
            '✅ Menú completo recibido del servidor. Cantidad de ítems: ${menuData.length}',
          );
          return menuData;
        } else {
          print('❌ Error: Formato de menú inesperado del servidor: $menuData');
          return null;
        }
      } else {
        print(
          '❌ Error al obtener el menú completo del servidor (${response.statusCode}): ${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Error al intentar obtener el menú completo del servidor: $e');
      return null;
    }
  }

  // Cerrar el cliente HTTP
  void close() {
    _client.close();
  }
}
