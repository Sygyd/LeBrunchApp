import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'cart_service.dart';
import 'gemini_api_client.dart';

/// Servicio para comunicarse con Google Gemini AI (a través del servidor Node.js)
class GeminiService extends ChangeNotifier {
  // Lista de claves API de Gemini LEÍDAS DESDE .ENV
  final List<String> _apiKeys = [
    dotenv.get(
      'GEMINI_API_KEY_1',
      fallback: 'TU_FALLBACK_KEY_1_SI_NO_ESTA_EN_ENV',
    ),
    dotenv.get(
      'GEMINI_API_KEY_2',
      fallback: 'TU_FALLBACK_KEY_2_SI_NO_ESTA_EN_ENV',
    ),
    dotenv.get(
      'GEMINI_API_KEY_3',
      fallback: 'TU_FALLBACK_KEY_3_SI_NO_ESTA_EN_ENV',
    ),
    // Asegúrate de que GEMINI_API_KEY_1, GEMINI_API_KEY_2, etc., existan en tu archivo .env
    // O proporciona fallbacks válidos si podrían no estar.
  ];

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
  GeminiService()
    : _geminiApiClient = GeminiApiClient(
        dotenv.get(
          'GEMINI_API_KEY_1',
          fallback: 'FALLBACK_KEY_PARA_CLIENT_INIT',
        ),
      )
  // Inicializa GeminiApiClient con la primera clave del .env o un fallback.
  // Este fallback es solo para la inicialización del ApiClient,
  // la lista _apiKeys se usa si implementas rotación o llamadas directas.
  {
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

  // Método para inicializar la verificación de conectividad (se llama desde el constructor)
  void _initializeConnectivityCheck() {
    checkServerConnection(); // Llamar al método de verificación al inicio, ASEGÚRATE QUE checkServerConnection SEA PÚBLICO
  }

  /// Nuevo método para enviar mensajes a Brunchy a través del servidor Node.js.
  /// Retorna un Map<String, dynamic> estructurado que contiene la respuesta de texto
  /// y, opcionalmente, acciones para el carrito.
  Future<Map<String, dynamic>> sendMessageToBrunchy(
    String message,
    String sessionId,
  ) async {
    print('🔵 GeminiService.sendMessageToBrunchy: INICIANDO');
    print('📨 GeminiService: Mensaje: "$message"');
    print('🆔 GeminiService: SessionId: "$sessionId"');

    final responseData = await _geminiApiClient.generateContent(
      message,
      sessionId: sessionId,
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

      // Si la acción es añadir al carrito, procesar los ítems
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
            '❌ GeminiService: No se pudo obtener el menú, no se añadirán items al carrito',
          );
          return responseData; // Devolver sin procesar carrito
        }

        print(
          '✅ GeminiService: Menú obtenido con ${menuItems.length} items disponibles',
        );

        // Debug: Imprimir algunos items del menú para verificar formato
        print('🔍 GeminiService: Muestra de items del menú:');
        for (
          int i = 0;
          i < (3 < menuItems.length ? 3 : menuItems.length);
          i++
        ) {
          print('   Item $i: ${menuItems[i]}');
        }

        // Completar información de cada item
        final List<Map<String, dynamic>> itemsToAdd = [];
        print(
          '🔄 GeminiService: Iniciando procesamiento de ${items.length} items...',
        );

        for (final item in items) {
          print('🔄 GeminiService: Procesando item raw: $item');

          final String itemName = item['name'] as String? ?? '';
          final int quantity = item['quantity'] as int? ?? 1;
          final String notes = item['notes'] as String? ?? '';

          print(
            '🔍 GeminiService: Procesando item "$itemName" (cantidad: $quantity, notas: "$notes")',
          );

          // Buscar el item en el menú (búsqueda flexible)
          print(
            '🔍 GeminiService: Buscando "$itemName" en menú de ${menuItems.length} items...',
          );
          dynamic menuItem;
          try {
            menuItem = menuItems.firstWhere((menuItem) {
              final menuName =
                  (menuItem['nombre'] as String? ?? '').toLowerCase();
              final searchName = itemName.toLowerCase();

              // Búsqueda exacta o parcial
              final matches =
                  menuName == searchName ||
                  menuName.contains(searchName) ||
                  searchName.contains(menuName);

              if (matches) {
                print(
                  '🎯 GeminiService: Coincidencia encontrada: "$menuName" para "$searchName"',
                );
              }

              return matches;
            });
          } catch (e) {
            print(
              '❌ GeminiService: No se encontró coincidencia para "$itemName" - Error: $e',
            );
            print(
              '❌ GeminiService: Revisando nombres disponibles en el menú...',
            );
            for (
              int i = 0;
              i < (5 < menuItems.length ? 5 : menuItems.length);
              i++
            ) {
              print('   Menú item $i: ${menuItems[i]['nombre']}');
            }
            menuItem = null;
          }

          if (menuItem != null) {
            print('✅ GeminiService: Item encontrado en menú:');
            print('   ID: ${menuItem['idplato']}');
            print('   Nombre: ${menuItem['nombre']}');
            print('   Precio: \$${menuItem['precio']}');
            print('   Imagen: ${menuItem['imagen_url']}');

            // Crear item completo con datos del menú
            // Manejo seguro del precio - puede venir como String o num
            double itemPrice = 0.0;
            final precioRaw = menuItem['precio'];

            print(
              '🔍 GeminiService: Precio raw del menú: $precioRaw (tipo: ${precioRaw.runtimeType})',
            );

            if (precioRaw is num) {
              itemPrice = precioRaw.toDouble();
            } else if (precioRaw is String) {
              itemPrice = double.tryParse(precioRaw) ?? 0.0;
            }

            print(
              '💰 GeminiService: Precio procesado: \$${itemPrice.toStringAsFixed(2)}',
            );

            final completeItem = {
              'id': menuItem['idplato']?.toString() ?? '',
              'name': menuItem['nombre'] ?? itemName,
              'price': itemPrice,
              'quantity': quantity,
              'notes': notes,
              'imageUrl': menuItem['imagen_url'] ?? '',
              'originalData': menuItem,
              // Campos adicionales por compatibilidad
              'item_price': itemPrice,
              'idplato': menuItem['idplato']?.toString() ?? '',
            };

            itemsToAdd.add(completeItem);
            print('📦 GeminiService: Item preparado para carrito exitosamente');
            print(
              '   📊 Resumen: ${completeItem['name']} x${completeItem['quantity']} = \$${completeItem['price']}',
            );
          } else {
            print('❌ GeminiService: Item "$itemName" no encontrado en el menú');

            // Crear item con datos básicos si no se encuentra en el menú
            final basicItem = {
              'id': const Uuid().v4(),
              'name': itemName,
              'price': 0.0, // Precio por defecto
              'quantity': quantity,
              'notes': notes,
              'imageUrl': '',
              'originalData': item,
              'item_price': 0.0,
            };

            itemsToAdd.add(basicItem);
            print('📦 GeminiService: Item básico creado: $basicItem');
          }
        }

        print('🛒 GeminiService: PREPARANDO PARA ENVIAR AL CartService');
        print(
          '📊 GeminiService: Total de items preparados: ${itemsToAdd.length}',
        );

        // Debug: Mostrar resumen de todos los items
        for (int i = 0; i < itemsToAdd.length; i++) {
          final item = itemsToAdd[i];
          print(
            '   Item $i: ${item['name']} (\$${item['price']}) x${item['quantity']}',
          );
        }

        // Llamar al CartService con los items completos
        try {
          print(
            '📤 GeminiService: Llamando a CartService.addItemsFromBrunchy...',
          );
          await _cartService.addItemsFromBrunchy(itemsToAdd);
          print(
            '✅ GeminiService: CartService.addItemsFromBrunchy COMPLETADO EXITOSAMENTE',
          );
        } catch (e) {
          print(
            '❌ GeminiService: ERROR al llamar CartService.addItemsFromBrunchy: $e',
          );
          print('❌ GeminiService: StackTrace: ${StackTrace.current}');
        }

        print('🔚 GeminiService: Proceso de añadir al carrito FINALIZADO');
      } else {
        print(
          'ℹ️ GeminiService: No hay acción de carrito (action: "$action", items: ${responseData['items']})',
        );
      }

      print(
        '🔵 GeminiService.sendMessageToBrunchy: FINALIZANDO - devolviendo responseData',
      );
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

  // Dispose para limpiar recursos (muy importante)
  @override
  void dispose() {
    _cleanupTimer?.cancel(); // Cancelar el timer si existe
    _geminiApiClient.close(); // Cerrar el cliente HTTP
    super.dispose();
  }
}
