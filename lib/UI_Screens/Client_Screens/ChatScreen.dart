import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../Widgets/chat_message_bubble.dart';
import 'dart:async';
import 'dart:math'; // Importación de dart:math para usar min()
import '../../Api_services/gemini_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../Api_services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import '../Widgets/custom_modal.dart'; // Importar nuestros modales personalizados

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Lista de mensajes
  final List<ChatMessage> _messages = [];

  // Indicador de tipeo
  bool _isTyping = false;
  Timer? _typingTimer;

  // Estado de conexión con el servidor
  bool _isConnected = false;
  bool _isCheckingConnection = false;

  // Indicador si Gemini está funcionando o estamos en modo eco
  bool _isGeminiWorking = false;
  bool _isEchoMode = false;

  // Servicio Gemini
  final _geminiService = GeminiService();

  // ID de usuario único para esta sesión
  String? _userId;

  // Modo de depuración para mostrar información adicional
  bool _debugMode = false;

  // Lista para almacenar tiempos de toques para debug
  final List<DateTime> _debugTaps = [];

  // Variables para procesar mensajes especiales
  String? _pendingDishName;
  String? _pendingModifications;
  bool _awaitingSpecialInstructions = false;

  // Control para el desplazamiento automático
  bool _shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();

    // Inicializar usuario único para esta instancia de chat
    _initUserId();

    // Verificar conexión con el servidor automáticamente al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkGeminiConnection();
      _checkServerConnection();

      // Cargar mensajes existentes desde el historial en memoria
      _loadMessagesFromHistory();

      // Si no hay mensajes, mostrar mensaje de bienvenida
      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }

      // Cargar el modo de depuración desde preferencias
      _loadDebugMode();

      // Desplazar al último mensaje después de cargar la pantalla
      _scrollToBottom();
    });

    // Agregar listener al controlador de scroll para detectar cuando se añaden nuevos mensajes
    _scrollController.addListener(() {
      // Si estamos cerca del final del scroll, mantener el desplazamiento automático activo
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >
              _scrollController.position.maxScrollExtent - 100) {
        _shouldAutoScroll = true;
      } else {
        _shouldAutoScroll = false;
      }
    });
  }

  /// Inicializa el ID del usuario para persistencia del chat
  Future<void> _initUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Intentar obtener primero datos del usuario logueado
      final role = prefs.getInt('user_rol');
      final name = prefs.getString('user_name');

      // Crear un identificador único para el usuario actual
      String userId;

      if (role != null && name != null) {
        // Para usuarios registrados: rol + nombre como ID
        userId = 'user_${role}_$name';
      } else {
        // Para usuarios anónimos: usar un UUID temporal
        userId = prefs.getString('temporary_chat_id') ?? '';

        if (userId.isEmpty) {
          userId = 'anonymous_${const Uuid().v4()}';
          await prefs.setString('temporary_chat_id', userId);
        }
      }

      // Guardar el ID para uso persistente
      await prefs.setString('persistent_chat_user_id', userId);

      // Configurar el ID en el servicio de Gemini
      _geminiService.setCurrentUser(userId);

      // También configurar el ID en el servicio de carrito
      final cartService = CartService();
      cartService.setUserId(userId);

      setState(() {
        _userId = userId;
      });
    } catch (e) {
      print('Error al inicializar ID de usuario: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();

    // Importante: Asegurarnos de que cualquier mensaje pendiente sea cancelado
    _pendingDishName = null;
    _pendingModifications = null;
    _awaitingSpecialInstructions = false;

    super.dispose();
  }

  /// Verifica la conexión con el servidor
  Future<void> _checkServerConnection() async {
    if (_isCheckingConnection) {
      return; // Evitar múltiples verificaciones simultáneas
    }

    try {
      setState(() {
        _isCheckingConnection = true;
      });

      // Intentar obtener el estado de conexión desde el servicio
      final isConnected = await _geminiService.checkServerConnection();

      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _isCheckingConnection = false;
        });

        // Si estamos conectados, mostrar mensaje de bienvenida
        if (isConnected) {
          // Si no hay mensajes, agregamos el mensaje de bienvenida
          if (_messages.isEmpty) {
            _addWelcomeMessage();
          }
        } else {
          _showConnectionErrorMessage();
          // Programar un reintento automático en 5 segundos
          Future.delayed(Duration(seconds: 5), _retryConnection);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isCheckingConnection = false;
        });
        _showConnectionErrorMessage();
        // Programar un reintento automático en 5 segundos
        Future.delayed(Duration(seconds: 5), _retryConnection);
      }
    }
  }

  /// Verifica la conexión con Gemini
  Future<void> _checkGeminiConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final geminiConnected = prefs.getBool('gemini_connected') ?? false;

      if (!mounted) return;
      setState(() {
        _isGeminiWorking = geminiConnected;
        _isEchoMode = !geminiConnected;
      });

      print(
        'Estado de Gemini cargado: ${_isGeminiWorking ? "CONECTADO" : "DESCONECTADO"}',
      );

      // Intentar conectar con Gemini
      bool connected = await _geminiService.testGeminiConnection();

      if (!mounted) return;
      setState(() {
        _isGeminiWorking = connected;
        _isEchoMode = !connected;
      });

      // Mostrar indicación si estamos en modo eco
      if (_isEchoMode && mounted) {
        _showEchoModeWarning();
      }
    } catch (e) {
      print('Error al verificar estado de Gemini: $e');
      if (!mounted) return;
      setState(() {
        _isGeminiWorking = false;
        _isEchoMode = true;
      });
    }
  }

  /// Muestra un mensaje de conexión exitosa
  void _showConnectionSuccessMessage() {
    // Método eliminado ya que no queremos mostrar este mensaje
  }

  /// Muestra un mensaje de error de conexión
  Future<void> _showConnectionErrorMessage() async {
    if (!mounted) return;

    await CustomModal.showWarning(
      context: context,
      title: 'Conectando...',
      message: 'Intentando establecer conexión con Brunchy...',
      buttonText: 'Entendido',
    );
  }

  /// Reintenta la conexión con el servidor
  void _retryConnection() {
    if (!mounted) return;

    // Cerrar cualquier modal abierto
    Navigator.of(context).popUntil((route) => route.isFirst);

    setState(() {
      _isCheckingConnection = false;
    });

    _checkServerConnection();
  }

  /// Hace scroll hasta el último mensaje
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Muestra un indicador de tipeo
  void _showTypingIndicator() {
    if (!mounted) return;
    setState(() {
      _isTyping = true;
    });

    // Hacer scroll cuando aparece el indicador
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Cancelar timer existente
    _typingTimer?.cancel();

    // Si después de 30 segundos aún estamos "escribiendo", desactivar
    _typingTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    });
  }

  /// Oculta el indicador de tipeo
  void _hideTypingIndicator() {
    _typingTimer?.cancel();
    if (mounted) {
      setState(() {
        _isTyping = false;
      });
    }
  }

  /// Muestra una advertencia de modo eco
  Future<void> _showEchoModeWarning() async {
    if (!mounted) return;

    await CustomModal.showWarning(
      context: context,
      title: 'Modo Eco Activado',
      message: 'Gemini no está disponible. Las respuestas serán genéricas.',
      buttonText: 'Reintentar',
      onPressed: () {
        _checkGeminiConnection();
        _geminiService.resetChat();
      },
    );
  }

  /// Carga el estado del modo de depuración
  Future<void> _loadDebugMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _debugMode = prefs.getBool('debug_mode') ?? false;
      });
      print('Modo de depuración: ${_debugMode ? "ACTIVADO" : "DESACTIVADO"}');
    } catch (e) {
      print('Error al cargar modo de depuración: $e');
    }
  }

  /// Cambia el estado del modo de depuración
  Future<void> _toggleDebugMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newValue = !_debugMode;
      await prefs.setBool('debug_mode', newValue);

      if (!mounted) return;
      setState(() {
        _debugMode = newValue;

        // Mostrar mensaje informativo
        _messages.add(
          ChatMessage.fromSystem(
            message:
                "Modo de depuración ${_debugMode ? "ACTIVADO" : "DESACTIVADO"}.\n" +
                (_debugMode
                    ? "Se mostrará información adicional sobre las conexiones."
                    : "La información de depuración quedará oculta."),
          ),
        );
      });

      _scrollToBottom();
    } catch (e) {
      print('Error al cambiar modo de depuración: $e');
    }
  }

  /// Intenta forzar el uso de Gemini directamente
  Future<void> _forceGeminiConnection() async {
    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage.fromSystem(
          message:
              "Intentando conectar directamente con Gemini...\n" +
              (_debugMode
                  ? "Este proceso puede tardar hasta 30 segundos, probando múltiples configuraciones."
                  : ""),
        ),
      );
    });

    _scrollToBottom();

    // Crear temporizador para mostrar progreso
    Timer? progressTimer;
    if (_debugMode) {
      int dots = 0;
      progressTimer = Timer.periodic(Duration(seconds: 3), (timer) {
        if (mounted) {
          dots = (dots + 1) % 4;
          String dotStr = List.filled(dots, '.').join();

          setState(() {
            _messages.add(
              ChatMessage.fromSystem(
                message: "Todavía intentando$dotStr (${timer.tick * 3}s)",
              ),
            );
          });

          _scrollToBottom();

          // Si han pasado más de 24 segundos, cancelar
          if (timer.tick > 8) {
            timer.cancel();
          }
        }
      });
    }

    // Forzar la conexión directa con Gemini
    bool connected = await _geminiService.forceDirectGeminiConnection();

    // Cancelar temporizador de progreso si estaba activo
    progressTimer?.cancel();

    setState(() {
      _isGeminiWorking = connected;
      _isEchoMode = !connected;

      // Eliminar mensajes de progreso temporales
      _messages.removeWhere(
        (msg) =>
            msg.isFromSystem &&
            (msg.message.contains(
                  "Intentando conectar directamente con Gemini",
                ) ||
                msg.message.contains("Todavía intentando")),
      );

      // Añadir mensaje de resultado
      if (connected) {
        _messages.add(
          ChatMessage.fromSystem(
            message: "¡Conexión exitosa! Ahora puedes chatear con Brunchy.",
          ),
        );
      } else {
        // Mensaje detallado en modo de depuración
        if (_debugMode) {
          _messages.add(
            ChatMessage.fromSystem(
              message:
                  "No se pudo conectar con Gemini después de múltiples intentos.\n\n" +
                  "Posibles causas:\n" +
                  "• Todas las claves API podrían estar inactivas o deshabilitadas\n" +
                  "• Podrías estar en una región donde Gemini está restringido\n" +
                  "• Tu conexión a Internet podría tener problemas para acceder a los servidores de Google\n" +
                  "• Las cuotas de API podrían haberse agotado\n\n" +
                  "Soluciones:\n" +
                  "• Reiniciar la aplicación completamente\n" +
                  "• Usar una VPN si estás en una región restringida\n" +
                  "• Verificar tu conexión a Internet\n" +
                  "• Esperar unos minutos antes de volver a intentar",
            ),
          );

          // Añadir opción para usar el servidor de respaldo
          _messages.add(
            ChatMessage.fromSystem(
              message:
                  "Se usará el servidor de respaldo para las respuestas mientras tanto.",
            ),
          );
        } else {
          _messages.add(
            ChatMessage.fromSystem(
              message:
                  "No se pudo conectar con Gemini. Por favor, verifica tu conexión a internet o intenta más tarde.",
            ),
          );
        }

        // Botón para activar el modo de depuración
        if (!_debugMode) {
          _messages.add(
            ChatMessage.fromSystem(
              message:
                  "Para ver información más detallada sobre el problema, puedes activar el modo de depuración dando 5 toques rápidos al logo de Brunchy en la parte superior izquierda.",
            ),
          );
        }
      }
    });

    _scrollToBottom();
  }

  /// Envía un mensaje al servidor y procesa la respuesta
  Future<void> _handleSendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    // Obtener el mensaje y restablecer el controlador
    final message = _messageController.text.trim();
    _messageController.clear();

    // Activar el auto-scroll cuando enviamos un nuevo mensaje
    _shouldAutoScroll = true;

    // Mostrar el mensaje del usuario inmediatamente
    setState(() {
      _messages.add(ChatMessage.fromUser(message: message));
      _isTyping = true; // Mostrar el indicador de escritura
    });

    // Hacer scroll al fondo después de mostrar el mensaje
    if (_shouldAutoScroll) {
      _scrollToBottom();
    }

    // Procesar el mensaje para detectar posibles pedidos de platos
    await _processMessageForDishRequest(message);

    try {
      // Esperar la respuesta del servicio Gemini sin mostrar mensaje temporal
      final response = await _geminiService.sendMessage(message);

      // Verificar si el widget sigue montado antes de actualizar el estado
      if (!mounted) return;

      // Actualizar el estado con la respuesta real
      setState(() {
        _messages.add(response);
        _isTyping = false;
      });

      // Verificar si la respuesta de Gemini indica agregar algo al carrito
      if (response.isFromSupport &&
          (response.message.contains("¿Deseas agregarlo a tu pedido?") ||
              response.message.contains(
                "¿Quieres que lo agregue a tu pedido?",
              ) ||
              response.message.contains("¿Lo agrego a tu pedido?"))) {
        await _processMessageForDishRequest(response.message);
      }

      // Hacer scroll al fondo si el auto-scroll está activo
      if (_shouldAutoScroll) {
        _scrollToBottom();
      }
    } catch (e) {
      // Verificar si el widget sigue montado antes de actualizar el estado
      if (!mounted) return;

      // Manejar error
      print('Error al enviar mensaje: $e');

      setState(() {
        _messages.add(
          ChatMessage.fromSystem(
            message:
                "Lo siento, hubo un problema. Por favor intenta nuevamente.",
          ),
        );
        _isTyping = false;
      });

      if (_shouldAutoScroll) {
        _scrollToBottom();
      }
    }
  }

  /// Carga mensajes existentes desde el historial en memoria del servicio
  void _loadMessagesFromHistory() {
    final chatHistory = _geminiService.getChatHistory();

    if (chatHistory.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(chatHistory);
      });

      // Hacer scroll al final de la conversación
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  /// Carga todos los mensajes del historial
  Future<void> _loadAllMessages() async {
    // Este método ya no se usa - eliminamos la carga de mensajes anteriores
  }

  /// Añade un mensaje de bienvenida
  void _addWelcomeMessage() {
    const welcomeMessage =
        '¡Hola! 👋 Soy Brunchy, tu mesero virtual de Le Brunch. '
        '¿En qué puedo ayudarte hoy? Puedo recomendarte nuestros deliciosos desayunos, brunch o bebidas. '
        '¿Te gustaría ver nuestras especialidades?';

    final welcomeMsg = ChatMessage.fromSupport(message: welcomeMessage);

    // Guardar en el historial del servicio
    _geminiService.addMessageToHistory(welcomeMsg);

    // Actualizar la UI
    setState(() {
      _messages.clear();
      _messages.add(welcomeMsg);
    });
  }

  /// Detecta si hay un pedido de platos en un mensaje de usuario
  Future<void> _processMessageForDishRequest(String message) async {
    // Palabras clave que indican intención de añadir al carrito
    final addKeywords = [
      'quiero',
      'ordenar',
      'pedir',
      'añadir',
      'agregar',
      'comprar',
      'llevar',
      'me gustaría',
      'me gustaria',
      'dame',
      'tráeme',
      'traeme',
      'ponme',
      'me apetece',
      'por favor tráeme',
      'por favor traeme',
      'sírveme',
      'sirveme',
    ];

    // Palabras que indican modificaciones a la orden
    final modifierKeywords = [
      'sin',
      'con',
      'extra',
      'adicional',
      'agregale',
      'agrégale',
      'añadele',
      'añádele',
      'quítale',
      'quitale',
      'cambiale',
      'cámbialo',
      'sustitúyele',
      'sustituye',
      'modifica',
    ];

    // Verificar si el mensaje contiene alguna de las palabras clave
    bool containsAddIntent = false;
    String? matchedKeyword;

    // Buscamos la palabra clave más larga que coincida primero
    addKeywords.sort((a, b) => b.length.compareTo(a.length));
    for (final keyword in addKeywords) {
      if (message.toLowerCase().contains(keyword.toLowerCase())) {
        containsAddIntent = true;
        matchedKeyword = keyword.toLowerCase();
        break;
      }
    }

    if (containsAddIntent) {
      // Palabras a ignorar en la extracción del nombre del plato
      final ignoreWords = [
        'el',
        'la',
        'los',
        'las',
        'un',
        'una',
        'unos',
        'unas',
        'de',
        'del',
        'por',
        'para',
        'mi',
        'tu',
        'su',
        'nuestro',
        'vuestro',
        'quiero',
        'ordenar',
        'pedir',
        'añadir',
        'agregar',
        'comprar',
        'llevar',
      ];

      // Extraer el texto después de la palabra clave
      final messageLower = message.toLowerCase();
      final int keywordIndex = messageLower.indexOf(matchedKeyword!);
      final int startIndex = keywordIndex + matchedKeyword.length;

      if (startIndex < messageLower.length) {
        // Obtener el resto del texto después de la palabra clave
        String remainingText = messageLower.substring(startIndex).trim();

        // Eliminar palabras iniciales como "un", "una", etc.
        for (final word in ignoreWords) {
          if (remainingText.startsWith("$word ")) {
            remainingText = remainingText.substring(word.length).trim();
          }
        }

        // Buscar modificadores para separar el nombre del plato de las modificaciones
        String? dishName;
        String? modifications;

        // Buscar el primer modificador en el texto
        int modifierPos = -1;
        for (final modifier in modifierKeywords) {
          final pos = remainingText.indexOf(" $modifier ");
          if (pos != -1 && (modifierPos == -1 || pos < modifierPos)) {
            modifierPos = pos;
          }
        }

        if (modifierPos != -1) {
          // Si hay un modificador, separar el nombre del plato y las modificaciones
          dishName = remainingText.substring(0, modifierPos).trim();
          modifications = remainingText.substring(modifierPos).trim();
        } else {
          // Si no hay modificador claro, usar todo como nombre del plato
          dishName = remainingText;
        }

        // Limpiar el nombre del plato de puntuación al final (comas, puntos, etc.)
        if (dishName != null && dishName.isNotEmpty) {
          dishName = dishName.replaceAll(RegExp(r'[.,;:!?]$'), '').trim();

          // Limitar el nombre a un máximo de 8 palabras
          final dishWords = dishName.split(' ');
          if (dishWords.length > 8) {
            dishName = dishWords.take(8).join(' ');
          }

          print('Detectado posible pedido: "$dishName"');

          if (dishName.isNotEmpty) {
            // Guardar el nombre del plato y modificaciones para procesarlo después
            _pendingDishName = dishName;
            _pendingModifications = modifications;
            _awaitingSpecialInstructions = true;

            // Enviar mensaje a Gemini pidiendo confirmación y preguntando por instrucciones especiales
            final promptForGemini =
                "El cliente ha pedido '$dishName'" +
                (modifications != null
                    ? " con las siguientes modificaciones: $modifications."
                    : ".") +
                " Por favor, confirma el pedido y pregunta si desea agregar instrucciones especiales (sin ingredientes, cocción especial, etc.) o si desea añadirlo directamente a su pedido.";

            // Mostrar indicador de escritura
            _showTypingIndicator();

            // Enviar la solicitud a Gemini
            try {
              final response = await _geminiService.sendMessage(
                promptForGemini,
              );

              if (mounted) {
                setState(() {
                  _messages.add(response);
                  _isTyping = false;
                });
                _scrollToBottom();
              }
            } catch (e) {
              // Si falla, mostrar un mensaje del sistema como fallback
              print('Error al solicitar confirmación a Gemini: $e');
              if (mounted) {
                setState(() {
                  _isTyping = false;
                  final String promptMessage =
                      modifications != null
                          ? '¿Deseas agregar "$dishName" con las modificaciones: $modifications a tu pedido? ¿Alguna instrucción especial adicional?'
                          : '¿Deseas agregar "$dishName" a tu pedido? ¿Alguna instrucción especial?';

                  _messages.add(
                    ChatMessage.fromSupport(message: promptMessage),
                  );
                });
                _scrollToBottom();
              }
            }

            return;
          }
        }
      }
    }

    // Si estamos esperando instrucciones especiales para un plato ya detectado
    if (_awaitingSpecialInstructions && _pendingDishName != null) {
      // Buscar indicadores de confirmación o negación
      final confirmations = [
        'sí',
        'si',
        'por supuesto',
        'claro',
        'ok',
        'okay',
        'vale',
      ];
      final denials = [
        'no',
        'nada',
        'ninguna',
        'así está bien',
        'así está',
        'está bien así',
      ];

      String? specialInstructions;

      // Comprobar si el mensaje contiene una confirmación o negación simple
      final messageLower = message.toLowerCase();

      bool isConfirmation = confirmations.any(
        (word) => messageLower.contains(word),
      );
      bool isDenial = denials.any((word) => messageLower.contains(word));

      if (isDenial) {
        specialInstructions =
            _pendingModifications; // Usar solo las modificaciones ya detectadas, si las hay
      } else if (!isConfirmation || messageLower.length > 10) {
        // Si no es una simple negación y el mensaje tiene cierta longitud, asumimos que contiene instrucciones
        specialInstructions =
            messageLower.contains(_pendingDishName!.toLowerCase())
                ? message // Usar el mensaje completo si contiene el nombre del plato
                : (_pendingModifications != null
                    ? "$_pendingModifications, $message" // Combinar con modificaciones previas
                    : message); // Usar solo el mensaje actual
      }

      // Intentar añadir el plato al carrito con las instrucciones especiales
      final success = await _geminiService.addDishToCart(
        _pendingDishName!,
        specialNotes: specialInstructions,
      );

      if (success) {
        // Mostrar notificación emergente
        _showDishAddedConfirmation(_pendingDishName!);

        // Mostrar mensaje de confirmación
        _showTypingIndicator();

        // Enviar mensaje a Gemini para confirmar la adición al carrito
        try {
          final confirmMessage =
              specialInstructions != null && specialInstructions.isNotEmpty
                  ? "Confirma al cliente que has añadido $_pendingDishName a su pedido con las instrucciones especiales que solicitó. Sugiere también que revise su carrito para comprobar y completar el pedido."
                  : "Confirma al cliente que has añadido $_pendingDishName a su pedido. Sugiere también que revise su carrito para comprobar y completar el pedido.";

          final response = await _geminiService.sendMessage(confirmMessage);

          if (mounted) {
            setState(() {
              _messages.add(response);
              _isTyping = false;
            });
            _scrollToBottom();
          }
        } catch (e) {
          // Si falla, usar un mensaje del sistema como fallback
          if (mounted) {
            setState(() {
              _isTyping = false;
              final message =
                  specialInstructions != null && specialInstructions.isNotEmpty
                      ? '¡He agregado "$_pendingDishName" a tu pedido con las instrucciones solicitadas!\nPuedes ver y editar tu pedido completo en la sección de carrito.'
                      : '¡He agregado "$_pendingDishName" a tu pedido!\nPuedes ver tu pedido completo en la sección de carrito.';

              _messages.add(ChatMessage.fromSupport(message: message));
            });
            _scrollToBottom();
          }
        }

        // Resetear variables para la próxima orden
        _pendingDishName = null;
        _pendingModifications = null;
        _awaitingSpecialInstructions = false;
        return;
      } else {
        // Si no se pudo agregar, mostrar un mensaje de error
        _showTypingIndicator();

        try {
          // Buscar sugerencias en el menú
          final menuItems = await _geminiService.fetchMenu();
          final suggestions = _findSimilarDishes(menuItems, _pendingDishName!);

          String errorPrompt;
          if (suggestions.isNotEmpty) {
            // Crear lista de sugerencias para incluir en el mensaje
            final suggestionsList = suggestions
                .take(3)
                .map((dish) => "- ${dish['nombre']} (${dish['categoria']})")
                .join("\n");

            errorPrompt =
                "Informa al cliente que no pudiste encontrar exactamente '$_pendingDishName' en el menú, pero " +
                "que tenemos estas alternativas similares:\n$suggestionsList\n" +
                "Pregunta si le gustaría alguna de estas opciones en su lugar.";
          } else {
            errorPrompt =
                "Informa al cliente que no pudiste encontrar '$_pendingDishName' en el menú y pídele que sea más específico " +
                "o que mencione otro plato de nuestro menú.";
          }

          final response = await _geminiService.sendMessage(errorPrompt);

          if (mounted) {
            setState(() {
              _messages.add(response);
              _isTyping = false;
            });
            _scrollToBottom();
          }
        } catch (e) {
          // Fallback a mensaje del sistema
          if (mounted) {
            setState(() {
              _isTyping = false;
              _messages.add(
                ChatMessage.fromSupport(
                  message:
                      'Lo siento, no pude encontrar "$_pendingDishName" en nuestro menú. ¿Podrías ser más específico o pedir algo de nuestra carta?',
                ),
              );
            });
            _scrollToBottom();
          }
        }

        // Resetear variables para la próxima orden
        _pendingDishName = null;
        _pendingModifications = null;
        _awaitingSpecialInstructions = false;
        return;
      }
    }
  }

  /// Busca platos similares por nombre
  List<Map<String, dynamic>> _findSimilarDishes(
    List<dynamic> dishes,
    String queryName,
  ) {
    if (dishes.isEmpty) return [];

    // Normalizar consulta (simplificar para comparación)
    final normalizedQuery = _normalizeText(queryName);
    final queryWords =
        normalizedQuery.split(' ').where((word) => word.length > 2).toList();

    if (queryWords.isEmpty) return [];

    // Calcular puntuación para cada plato
    final scoredDishes =
        dishes
            .map((dish) {
              if (dish['nombre'] == null) return {'dish': dish, 'score': 0};

              final String dishName = dish['nombre'].toString();
              final normalizedDishName = _normalizeText(dishName);

              // Calcular puntuación por coincidencia de palabras
              int score = 0;
              for (final word in queryWords) {
                if (normalizedDishName.contains(word)) {
                  score +=
                      word.length; // Palabras más largas tienen mayor puntuación
                }
              }

              // Bonificación por categoría
              if (dish['categoria'] != null) {
                final categoria = _normalizeText(dish['categoria'].toString());
                if (normalizedQuery.contains(categoria)) {
                  score += 5;
                }
              }

              return {'dish': dish, 'score': score};
            })
            .where((item) => item['score'] > 0)
            .toList();

    // Ordenar por puntuación más alta
    scoredDishes.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );

    // Extraer sólo los platos
    return scoredDishes
        .take(5) // Limitar a 5 sugerencias
        .map((item) => item['dish'] as Map<String, dynamic>)
        .toList();
  }

  /// Normaliza un texto para comparaciones
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  /// Muestra un mensaje de confirmación cuando se agrega un plato
  Future<void> _showDishAddedConfirmation(String dishName) async {
    if (!mounted) return;

    await CustomModal.showSuccess(
      context: context,
      title: '¡Plato Agregado!',
      message: '¡"$dishName" ha sido agregado a tu pedido!',
      buttonText: 'Aceptar',
    );
  }

  /// Maneja los toques para activar el modo de depuración
  void _handleDebugTap() {
    final now = DateTime.now();

    // Añadir el tiempo del toque
    _debugTaps.add(now);

    // Limpiar toques antiguos (más de 3 segundos)
    _debugTaps.removeWhere((tap) => now.difference(tap).inSeconds > 3);

    // Si hay 5 o más toques en menos de 3 segundos, activar/desactivar modo debug
    if (_debugTaps.length >= 5) {
      _debugTaps.clear(); // Reiniciar contador
      _toggleDebugMode();

      // Dar feedback
      HapticFeedback.heavyImpact();

      // Mostrar mensaje en un modal en lugar de snackbar
      if (mounted) {
        CustomModal.showInfo(
          context: context,
          title: 'Modo de Desarrollo',
          message:
              'Modo de depuración ${_debugMode ? "activado" : "desactivado"}',
          buttonText: 'OK',
        );
      }
    }
  }

  /// Muestra opciones de depuración
  Future<void> _showDebugOptions() async {
    // Conservar el diálogo original para no cambiar demasiado la UI de depuración
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text('Opciones de diagnóstico'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estados actuales:'),
                  SizedBox(height: 8),
                  _buildDebugItem(
                    'Modo eco:',
                    _isEchoMode ? 'ACTIVO ⚠️' : 'Desactivado ✅',
                    _isEchoMode,
                  ),
                  _buildDebugItem(
                    'Conexión al servidor:',
                    _isConnected ? 'DISPONIBLE ✅' : 'NO DISPONIBLE ⚠️',
                    !_isConnected,
                  ),
                  _buildDebugItem(
                    'Gemini funcional:',
                    _isGeminiWorking ? 'SÍ ✅' : 'NO ⚠️',
                    !_isGeminiWorking,
                  ),

                  Divider(height: 24),

                  Text('Acciones de diagnóstico:'),
                  SizedBox(height: 12),

                  // Botones de acciones
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text('Probar todas las claves API'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _debugTestAllApiKeys();
                    },
                  ),

                  SizedBox(height: 8),

                  ElevatedButton.icon(
                    icon: Icon(Icons.power_settings_new),
                    label: Text('Inicializar nuevo modelo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _debugReinitializeGemini();
                    },
                  ),

                  SizedBox(height: 8),

                  ElevatedButton.icon(
                    icon: Icon(Icons.clear_all),
                    label: Text('Limpiar historial completo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _debugClearAllHistory();
                    },
                  ),

                  SizedBox(height: 8),

                  ElevatedButton.icon(
                    icon: Icon(Icons.settings_backup_restore),
                    label: Text('Restablecer aplicación'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.errorContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _debugResetApp();
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cerrar'),
              ),
            ],
          ),
    );
  }

  /// Construye un elemento de información de depuración
  Widget _buildDebugItem(String title, String value, bool isError) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color:
                  isError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Verifica todas las claves API una por una
  Future<void> _debugTestAllApiKeys() async {
    setState(() {
      _messages.add(
        ChatMessage.fromSystem(
          message: "Iniciando verificación de todas las claves API...",
        ),
      );
    });

    bool anySuccess = await _geminiService.testAllApiKeys();

    setState(() {
      if (anySuccess) {
        _messages.add(
          ChatMessage.fromSystem(
            message: "✅ ¡Se encontró al menos una clave API funcional!",
          ),
        );
      } else {
        _messages.add(
          ChatMessage.fromSystem(
            message: "❌ Ninguna clave API está funcionando en este momento.",
          ),
        );
      }
    });

    _scrollToBottom();
  }

  /// Reinicializa el cliente de Gemini
  Future<void> _debugReinitializeGemini() async {
    setState(() {
      _messages.add(
        ChatMessage.fromSystem(message: "Reinicializando modelo de Gemini..."),
      );
    });

    await _geminiService.resetAndReinitialize();

    setState(() {
      _messages.add(
        ChatMessage.fromSystem(
          message: "✅ Modelo reinicializado. Probando conexión...",
        ),
      );
    });

    // Probar conexión
    _forceGeminiConnection();
  }

  /// Limpia todo el historial de mensajes
  Future<void> _debugClearAllHistory() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirmar eliminación'),
            content: Text(
              '¿Estás seguro de que quieres eliminar todo el historial de mensajes? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _geminiService.clearChatHistory();
                  setState(() {
                    _messages.clear();
                    _messages.add(
                      ChatMessage.fromSystem(
                        message: "✅ Historial eliminado completamente.",
                      ),
                    );
                  });
                },
                child: Text(
                  'Eliminar',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }

  /// Restablece la aplicación completamente
  Future<void> _debugResetApp() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('⚠️ Restablecer aplicación'),
            content: Text(
              'Esto eliminará todas las preferencias y el historial, y reiniciará la aplicación a su estado inicial. Se perderán todas las configuraciones personalizadas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  setState(() {
                    _messages.add(
                      ChatMessage.fromSystem(
                        message: "Restableciendo aplicación...",
                      ),
                    );
                  });

                  // Limpiar SharedPreferences
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();

                  // Resetear el servicio
                  await _geminiService.resetAndReinitialize();

                  // Limpiar estado
                  setState(() {
                    _messages.clear();
                    _messages.add(
                      ChatMessage.fromSystem(
                        message: "✅ Aplicación restablecida. Reiniciando...",
                      ),
                    );
                  });

                  // Dar tiempo para ver el mensaje
                  await Future.delayed(Duration(seconds: 2));

                  // Reiniciar la aplicación (navegar a la pantalla principal)
                  if (mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                child: Text(
                  'Restablecer',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar personalizado sin botón de opciones
      appBar: AppBar(
        title: Row(
          children: [
            // Avatar con los colores del tema (verde con ícono blanco)
            CircleAvatar(
              backgroundColor: const Color(
                0xFF3EA69B,
              ), // Verde principal del tema
              child: Icon(
                Icons.restaurant,
                color: Colors.white, // Icono en blanco
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Brunchy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isConnected
                      ? (_isGeminiWorking ? 'En línea' : 'Modo básico')
                      : 'Conectando...',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _isConnected
                            ? (_isGeminiWorking
                                ? Colors.green
                                : Theme.of(context).colorScheme.error)
                            : Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        // Solo mostrar botón de debug si está en modo de depuración
        actions:
            _debugMode
                ? [
                  IconButton(
                    onPressed: _showDebugOptions,
                    icon: Icon(
                      Icons.bug_report,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Opciones de depuración',
                  ),
                ]
                : [], // Lista vacía cuando no está en modo depuración
      ),
      // Cuerpo principal con fondo
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/fondolb.jpg"),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.9), // Atenuar fondo para legibilidad
              BlendMode.lighten,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: _handleDebugTap, // Gestor para activar modo debug
          child: Column(
            children: [
              // Lista de mensajes
              Expanded(
                child:
                    _messages.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isEchoMode
                                    ? Icons.warning_amber_rounded
                                    : Icons.restaurant,
                                size: 80,
                                color:
                                    _isEchoMode
                                        ? Theme.of(
                                          context,
                                        ).colorScheme.error.withOpacity(0.5)
                                        : Theme.of(
                                          context,
                                        ).colorScheme.primary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isEchoMode
                                    ? 'Modo Eco: Gemini no disponible'
                                    : 'Iniciando conversación...',
                                style: TextStyle(
                                  fontSize: 18,
                                  color:
                                      _isEchoMode
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_isCheckingConnection)
                                CircularProgressIndicator(strokeWidth: 3)
                              else if (!_isConnected)
                                ElevatedButton.icon(
                                  onPressed: _retryConnection,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Conectar'),
                                ),
                              if (_isEchoMode && !_isCheckingConnection)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16.0),
                                  child: ElevatedButton.icon(
                                    onPressed: _forceGeminiConnection,
                                    icon: const Icon(Icons.power),
                                    label: const Text(
                                      'Forzar conexión con Gemini',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                        : GestureDetector(
                          onTap: () => FocusScope.of(context).unfocus(),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              // Filtrar mensajes del sistema que no deben mostrarse al cliente
                              final message = _messages[index];
                              if (message.isFromSystem &&
                                  (message.message.contains(
                                        "Nueva conversación iniciada para",
                                      ) ||
                                      message.message.contains(
                                        "chat reiniciado",
                                      ))) {
                                // No mostrar estos mensajes a usuarios normales (solo en modo debug)
                                if (!_debugMode) {
                                  return SizedBox.shrink(); // Widget invisible
                                }
                              }
                              return ChatMessageBubble(message: message);
                            },
                          ),
                        ),
              ),

              // Indicador de escribiendo
              if (_isTyping)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(
                        'Brunchy está escribiendo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        height: 14,
                        child: const ThreeDotsLoading(),
                      ),
                    ],
                  ),
                ),

              // Separador
              Divider(height: 1),

              // Campo de entrada de mensaje
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: Offset(0, -1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Botón para forzar conexión en modo eco
                    if (_isEchoMode)
                      Container(
                        margin: EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.power_settings_new,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: _forceGeminiConnection,
                          tooltip: 'Forzar conexión',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.5),
                          ),
                        ),
                      ),

                    // Campo de texto
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: '¿Qué te gustaría ordenar?',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.5),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          enabled: _isConnected || _isCheckingConnection,
                          // Añadir indicador visual si estamos en modo eco
                          prefixIcon:
                              _isEchoMode
                                  ? Icon(
                                    Icons.warning_amber_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.error.withOpacity(0.7),
                                  )
                                  : null,
                          hintStyle: TextStyle(
                            color:
                                _isEchoMode
                                    ? Theme.of(
                                      context,
                                    ).colorScheme.error.withOpacity(0.7)
                                    : null,
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSendMessage(),
                        maxLines: 5,
                        minLines: 1,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Botón de enviar
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap:
                            (_isConnected && !_isTyping)
                                ? _handleSendMessage
                                : null,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.send,
                            color:
                                (_isConnected && !_isTyping)
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget para mostrar tres puntos animados (indicador de carga)
class ThreeDotsLoading extends StatefulWidget {
  const ThreeDotsLoading({super.key});

  @override
  ThreeDotsLoadingState createState() => ThreeDotsLoadingState();
}

class ThreeDotsLoadingState extends State<ThreeDotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Crear animaciones para cada punto
    _animations = List.generate(
      3,
      (index) => Tween<double>(begin: 0, end: 6).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            0.2 * index,
            0.6 + 0.2 * index,
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (index) => Container(
              margin: EdgeInsets.symmetric(horizontal: 1),
              height: 6,
              width: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              transform: Matrix4.translationValues(
                0,
                -_animations[index].value,
                0,
              ),
            ),
          ),
        );
      },
    );
  }
}
