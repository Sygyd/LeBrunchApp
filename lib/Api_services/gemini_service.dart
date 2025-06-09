import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'cart_service.dart';
import 'gemini_api_client.dart';

/// Servicio para comunicarse con Google Gemini AI (a través del servidor Node.js)
class GeminiService extends ChangeNotifier {
  // Lista de claves API de Gemini (se inicializará después de cargar dotenv)
  late final List<String> _apiKeys;

  int _currentApiKeyIndex =
      0; // Se mantiene por si se usa en el futuro para rotación
  final Map<String, DateTime> _pendingMessageLocks =
      {}; // Puede que ya no sea tan crítico con el servidor
  final Set<String> _processedMessageIds = {}; // Idem
  Timer? _cleanupTimer; // Idem

  // Instancia de GeminiApiClient (inicializada directamente en el constructor)
  final GeminiApiClient _geminiApiClient;

  // Instancia de CartService para añadir ítems (singleton, así que es seguro instanciarla aquí)
  final CartService _cartService = CartService();

  // Getters para el estado de conexión
  bool _isConnected = false;
  bool _isCheckingConnection = false;
  bool get isConnected => _isConnected;
  bool get isCheckingConnection => _isCheckingConnection;

  // Constructor
  GeminiService() : _geminiApiClient = GeminiApiClient('TEMP_INIT_KEY')
  // Inicializa GeminiApiClient con una clave temporal, se actualizará después
  {
    _initializeApiKeys(); // Inicializar las claves API de forma segura
    _initializeConnectivityCheck(); // Inicia la verificación de conectividad
    _startCleanupTimer(); // Si _pendingMessageLocks y _processedMessageIds se usan
  }

  // Método para iniciar el timer de limpieza (si es necesario)
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupProcessedMessages();
    });
  }

  // Método de limpieza (si _pendingMessageLocks y _processedMessageIds se usan)
  void _cleanupProcessedMessages() {
    final now = DateTime.now();
    _pendingMessageLocks.removeWhere(
      (key, value) => now.difference(value).inMinutes > 30,
    );
    // Asumiendo que processedMessageIds también tiene una lógica de expiración si es muy grande.
    // Por ahora, solo se limpia pendingMessageLocks.
  }

  // Método para inicializar las claves API de forma segura
  void _initializeApiKeys() {
    try {
      _apiKeys = [
        dotenv.get('GEMINI_API_KEY_1', fallback: 'FALLBACK_KEY_1'),
        dotenv.get('GEMINI_API_KEY_2', fallback: 'FALLBACK_KEY_2'),
        dotenv.get('GEMINI_API_KEY_3', fallback: 'FALLBACK_KEY_3'),
      ];

      // Actualizar el cliente con la primera clave válida
      if (_apiKeys.isNotEmpty && _apiKeys[0] != 'FALLBACK_KEY_1') {
        _geminiApiClient.updateApiKey(_apiKeys[0]);
      }
    } catch (e) {
      print('⚠️ Error al inicializar API keys desde .env: $e');
      // Usar fallbacks si dotenv no está disponible
      _apiKeys = ['FALLBACK_KEY_1', 'FALLBACK_KEY_2', 'FALLBACK_KEY_3'];
    }
  }

  // Método para inicializar la verificación de conectividad (se llama desde el constructor)
  void _initializeConnectivityCheck() {
    // Usar Future.delayed para que la inicialización de dotenv tenga tiempo de completarse
    Future.delayed(const Duration(milliseconds: 100), () {
      checkServerConnection(); // Llamar al método de verificación al inicio
    });
  }

  /// Nuevo método para enviar mensajes a Brunchy a través del servidor Node.js.
  /// Retorna un Map<String, dynamic> estructurado que contiene la respuesta de texto
  /// y, opcionalmente, acciones para el carrito.
  Future<Map<String, dynamic>> sendMessageToBrunchy(
    String message,
    String sessionId, {
    int? clientId,
  }) async {
    print('🔵 GeminiService.sendMessageToBrunchy: INICIANDO');
    print('📨 GeminiService: Mensaje: "$message"');
    print('🆔 GeminiService: SessionId: "$sessionId"');
    print('👤 GeminiService: ClientId: ${clientId ?? "No proporcionado"}');

    final responseData = await _geminiApiClient.generateContent(
      message,
      sessionId: sessionId,
      clientId: clientId,
    );

    print('📬 GeminiService: Respuesta cruda del servidor:');
    print('   $responseData');

    if (responseData != null) {
      final textResponse =
          responseData['text_response'] as String? ??
          "Lo siento, no pude procesar tu solicitud.";
      final action = responseData['action'] as String? ?? 'none';

      print('📝 GeminiService: text_response extraído: "$textResponse"');
      print('⚡ GeminiService: action extraído: "$action"');

      if (action == 'add_to_cart' && responseData['items'] is List) {
        final List<dynamic> items = responseData['items'];

        print('🛒 GeminiService: ¡ACCIÓN ADD_TO_CART DETECTADA!');
        print(
          '📦 GeminiService: Items recibidos del servidor: ${items.length}',
        );
        for (int i = 0; i < items.length; i++) {
          print('   Item $i: ${items[i]}');
        }

        // Obtener el menú completo para completar la información faltante
        print('📋 GeminiService: Obteniendo menú completo...');
        final menuItems = await getFullMenu();
        if (menuItems == null) {
          print(
            '❌ GeminiService: No se pudo obtener el menú, items serán procesados por la UI',
          );
          // No procesar carrito aquí, dejar que la UI lo maneje
          return responseData;
        }

        print(
          '✅ GeminiService: Menú obtenido con ${menuItems.length} items disponibles',
        );

        // RESTAURADA: Lógica inteligente de búsqueda y validación
        List<Map<String, dynamic>> processedItems = [];

        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          final String itemName = item['name'] as String? ?? 'Sin nombre';
          final int quantity = item['quantity'] as int? ?? 1;
          final String notes = item['notes'] as String? ?? '';

          print('🔍 GeminiService: Procesando item $i: "$itemName" x$quantity');

          // Buscar el item en el menú con lógica inteligente
          final Map<String, dynamic>? menuItem = _findBestMatchingMenuItem(
            menuItems,
            itemName,
          );

          if (menuItem != null) {
            // Crear item procesado con información completa
            final processedItem = {
              'name': menuItem['nombre'], // Usar nombre exacto del menú
              'quantity': quantity,
              'notes': notes,
              'id': menuItem['idplato']?.toString() ?? '',
              'price': _parseDoubleSafely(menuItem['precio']),
              'image_url': menuItem['imagen_url'] ?? '',
              'categoria': menuItem['categoria'] ?? '',
              'disponibilidad': menuItem['disponibilidad'] ?? true,
              'originalName':
                  itemName, // Guardar nombre original por referencia
              'matchScore':
                  menuItem['_matchScore'] ?? 1.0, // Score de coincidencia
            };

            processedItems.add(processedItem);
            print(
              '✅ GeminiService: "${itemName}" → "${menuItem['nombre']}" (score: ${menuItem['_matchScore']?.toStringAsFixed(2) ?? '1.00'})',
            );
          } else {
            print('❌ GeminiService: Item "$itemName" NO encontrado en el menú');
            // Aún así, mantener el item original para que la UI lo maneje
            processedItems.add({
              'name': itemName,
              'quantity': quantity,
              'notes': notes,
              'id': '',
              'price': 0.0,
              'image_url': '',
              'categoria': 'Desconocida',
              'disponibilidad': false,
              'originalName': itemName,
              'matchScore': 0.0,
              'notFound': true,
            });
          }
        }

        // Devolver respuesta con items procesados pero SIN agregar al carrito
        final enhancedResponse = Map<String, dynamic>.from(responseData);
        enhancedResponse['items'] = processedItems;
        enhancedResponse['originalItems'] =
            items; // Mantener items originales por referencia

        print(
          '🔚 GeminiService: Procesamiento completado - ${processedItems.length} items validados',
        );

        return enhancedResponse;
      } else {
        print(
          'ℹ️ GeminiService: No hay acción de carrito (action: "$action", items: ${responseData['items']})',
        );
      }

      print('🔵 GeminiService: Respuesta procesada completamente');
      return responseData; // Devuelve el Map completo tal como lo envió el servidor
    } else {
      // Si la respuesta es nula (ej. error de conexión del cliente en GeminiApiClient),
      // devuelve un Map de error consistente.
      print('❌ GeminiService: responseData es NULL - devolviendo error');
      return {
        'text_response':
            'Lo siento, no pude obtener una respuesta de Brunchy. Por favor, intenta de nuevo.',
        'action': 'error', // Usar 'error' como acción para indicar un problema
      };
    }
  }

  // Método para obtener el menú completo del servidor (útil para la UI o validaciones futuras)
  Future<List<dynamic>?> getFullMenu() async {
    return await _geminiApiClient.getFullMenuFromServer();
  }

  /// Verifica la conectividad con el servidor de respaldo (Node.js).
  Future<bool> checkServerConnection() async {
    if (_isCheckingConnection)
      return false; // Evitar múltiples checks simultáneos
    _isCheckingConnection = true;
    notifyListeners(); // Notificar a los oyentes que la comprobación ha comenzado

    try {
      // Usamos getFullMenuFromServer para verificar la conexión con el servidor Node.js
      final menu = await _geminiApiClient.getFullMenuFromServer();
      _isConnected =
          (menu !=
              null); // Si se recibe el menú (no nulo), la conexión es exitosa.
      print(
        '🌐 Servidor Node.js ' +
            (_isConnected ? '✅ DISPONIBLE' : '❌ NO DISPONIBLE'),
      );

      if (!_isConnected) {
        print(
          '⚠️ Servidor Node.js no respondió o hubo un error. Considerar el sistema como inactivo.',
        );
      }

      return _isConnected;
    } catch (e) {
      print('❌ Error general al verificar conexión con el servidor: $e');
      _isConnected = false;
      return false;
    } finally {
      _isCheckingConnection = false;
      notifyListeners(); // Notificar a los oyentes que la comprobación ha terminado
    }
  }

  // Método para la rotación de claves API (solo si _apiKeys se usan para llamadas directas a Gemini)
  void _rotateApiKey() {
    _currentApiKeyIndex = (_currentApiKeyIndex + 1) % _apiKeys.length;
    _geminiApiClient.updateApiKey(
      _apiKeys[_currentApiKeyIndex],
    ); // Actualizar la clave en el cliente
    print('🔑 Rotando a la API Key: ${_apiKeys[_currentApiKeyIndex]}');
  }

  /// Limpia el historial de chat y reinicia la sesión
  Future<void> clearChatHistory() async {
    try {
      print('🧹 GeminiService: Iniciando limpieza del historial de chat');

      // Limpiar datos en memoria
      _processedMessageIds.clear();
      _pendingMessageLocks.clear();

      // Limpiar datos de SharedPreferences relacionados con el chat
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      int clearedKeys = 0;

      // Patrones de claves relacionadas con el chat
      final chatPatterns = [
        'chat_history',
        'chat_messages',
        'current_chat_session',
        'temporary_chat_id',
        'persistent_chat_user_id',
        'chat_session',
        'message_history',
      ];

      for (final key in allKeys) {
        bool isChatKey = false;

        for (final pattern in chatPatterns) {
          if (key.contains(pattern)) {
            isChatKey = true;
            break;
          }
        }

        if (isChatKey) {
          await prefs.remove(key);
          clearedKeys++;
          print('🗑️ GeminiService: Eliminada clave de chat: $key');
        }
      }

      print(
        '🧹 GeminiService: Limpieza completa - $clearedKeys claves eliminadas',
      );
      notifyListeners(); // Notificar cambios a los listeners
    } catch (e) {
      print('❌ GeminiService: Error al limpiar historial de chat: $e');
    }
  }

  // MÉTODO RESTAURADO: Búsqueda inteligente de items en el menú
  Map<String, dynamic>? _findBestMatchingMenuItem(
    List<dynamic> menuItems,
    String searchName,
  ) {
    if (searchName.isEmpty) return null;

    final String normalizedSearch = searchName.toLowerCase().trim();
    Map<String, dynamic>? bestMatch;
    double bestScore = 0.0;

    for (var menuItem in menuItems) {
      final String menuName =
          (menuItem['nombre'] as String? ?? '').toLowerCase().trim();
      if (menuName.isEmpty) continue;

      // Calcular score de similitud
      double score = _calculateSimilarityScore(normalizedSearch, menuName);

      // Bonus por coincidencia exacta
      if (normalizedSearch == menuName) {
        score = 1.0;
      }
      // Bonus por coincidencia de inicio
      else if (menuName.startsWith(normalizedSearch) ||
          normalizedSearch.startsWith(menuName)) {
        score *= 1.2;
      }
      // Bonus por contener todas las palabras importantes
      else if (_containsAllKeyWords(normalizedSearch, menuName)) {
        score *= 1.1;
      }

      if (score > bestScore && score > 0.3) {
        // Umbral mínimo de similitud
        bestScore = score;
        bestMatch = Map<String, dynamic>.from(menuItem);
        bestMatch!['_matchScore'] = score; // Agregar score para referencia
      }
    }

    return bestMatch;
  }

  // MÉTODO RESTAURADO: Cálculo de score de similitud
  double _calculateSimilarityScore(String search, String target) {
    if (search == target) return 1.0;
    if (search.isEmpty || target.isEmpty) return 0.0;

    // Algoritmo de distancia de Levenshtein simplificado
    final searchWords = search.split(' ').where((w) => w.isNotEmpty).toList();
    final targetWords = target.split(' ').where((w) => w.isNotEmpty).toList();

    if (searchWords.isEmpty || targetWords.isEmpty) return 0.0;

    int matches = 0;
    int totalWords = searchWords.length;

    for (String searchWord in searchWords) {
      for (String targetWord in targetWords) {
        if (targetWord.contains(searchWord) ||
            searchWord.contains(targetWord)) {
          matches++;
          break;
        }
      }
    }

    // Score basado en proporción de palabras coincidentes
    double score = matches / totalWords;

    // Bonus por longitud similar
    final lengthDiff = (search.length - target.length).abs();
    final maxLength = math.max(search.length, target.length);
    final lengthSimilarity = 1.0 - (lengthDiff / maxLength);

    return (score * 0.7) + (lengthSimilarity * 0.3);
  }

  // MÉTODO RESTAURADO: Verificar si contiene todas las palabras clave
  bool _containsAllKeyWords(String search, String target) {
    final searchWords = search.split(' ').where((w) => w.length > 2).toList();
    if (searchWords.isEmpty) return false;

    for (String word in searchWords) {
      if (!target.contains(word)) {
        return false;
      }
    }
    return true;
  }

  // MÉTODO RESTAURADO: Parsing seguro de double
  double _parseDoubleSafely(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Dispose para limpiar recursos (muy importante)
  @override
  void dispose() {
    _cleanupTimer?.cancel(); // Cancelar el timer si existe
    _geminiApiClient.close(); // Cerrar el cliente HTTP
    super.dispose();
  }
}
