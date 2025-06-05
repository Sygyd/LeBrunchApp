import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../Api_services/gemini_service.dart';
import '../../Api_services/cart_service.dart';
import '../../Api_services/audio_service.dart';
import '../../models/chat_message.dart';
import '../Widgets/chat_message_bubble.dart';
import '../Widgets/custom_modal.dart';
import '../Widgets/audio_recorder_widget.dart';
import '../Widgets/telegram_audio_button.dart';
import '../Client_Screens/CartScreen.dart';
import '../../services/user_preferences_service.dart';
import '../Widgets/background_scaffold.dart';
import '../Widgets/chat_config_modal_content.dart';

class SharedChatScreen extends StatefulWidget {
  final bool isAdmin;
  final StreamController<int>? pageStreamController;
  final int currentIndex;

  const SharedChatScreen({
    Key? key,
    this.isAdmin = false,
    this.pageStreamController,
    this.currentIndex = 2,
  }) : super(key: key);

  @override
  State<SharedChatScreen> createState() => _SharedChatScreenState();
}

class _SharedChatScreenState extends State<SharedChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GeminiService _geminiService = GeminiService();
  final CartService _cartService = CartService();
  final UserPreferencesService _userPreferencesService =
      UserPreferencesService();
  final AudioService _audioService = AudioService();

  // Lista de mensajes
  List<ChatMessage> _messages = [];

  // Indicadores de estado
  bool _isTyping = false;
  bool _showConnectionStatusInAppBar = true;
  bool _debugMode = false;
  bool _showAudioRecorder = false;
  bool _audioInitialized = false;
  bool _hasText = false; // Nueva variable para trackear si hay texto

  // Timers y controladores
  Timer? _typingTimer;
  Timer? _cartSyncTimer;

  // Variables para personalización de administrador
  String _serverIp = "192.168.1.121";
  String _currentModelName = "gemini-2.0-flash";
  bool _showSystemMessages = true;

  // ID de usuario
  String? _userId;
  String _sessionId = '';
  int? _userRole; // Rol del usuario para mostrar el avatar correcto

  // Lista para detectar taps para activar modo debug
  final List<DateTime> _debugTaps = [];

  @override
  void initState() {
    super.initState();

    print('🚀 SharedChatScreen: initState INICIADO');
    _sessionId = const Uuid().v4();
    print('🆔 SharedChatScreen: SessionId generado: $_sessionId');
    _initUserIdAndLoadHistory();
    _loadSettings();

    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });

    // Listener para detectar cuando hay texto en el campo
    _messageController.addListener(() {
      final hasText = _messageController.text.trim().isNotEmpty;
      if (_hasText != hasText && mounted) {
        setState(() {
          _hasText = hasText;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      this._checkServerConnection();
      if (!widget.isAdmin) {
        _startCartSyncTimer();
      }
      _initializeAudio();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.removeListener(() => setState(() {}));
    _focusNode.dispose();
    _typingTimer?.cancel();
    _cartSyncTimer?.cancel();
    super.dispose();
  }

  final Set<String> _processingMessageIds = {};

  /// Inicializa el ID del usuario desde SharedPreferences o genera uno nuevo
  Future<void> _initializeUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Intentar obtener el ID del usuario actual
      final int? currentUserId = prefs.getInt('user_id');
      final int? currentUserRole = prefs.getInt('user_rol');

      if (currentUserId != null) {
        _userId = currentUserId.toString();
        _userRole =
            currentUserRole ??
            1; // Por defecto cliente si no se encuentra el rol
        print('📱 Chat: ID de usuario cargado: $_userId, Rol: $_userRole');
      } else {
        // Si no hay usuario logueado, usar el sessionId como userId
        _userId = _sessionId;
        _userRole = 1; // Por defecto cliente para usuarios invitados
        print(
          '📱 Chat: Usando sessionId como userId: $_userId, Rol por defecto: $_userRole',
        );
      }
    } catch (e) {
      print('❌ Error al inicializar userId: $e');
      // En caso de error, usar sessionId como fallback
      _userId = _sessionId;
      _userRole = 1; // Por defecto cliente
    }
  }

  /// Inicializa el ID del usuario para persistencia del chat
  Future<void> _initUserIdAndLoadHistory() async {
    await _initializeUserId();
    await _loadMessageHistory();
    if (_messages.isEmpty && mounted) {
      _addWelcomeMessage();
    }
  }

  /// Carga configuraciones previas
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _debugMode = prefs.getBool('debug_mode') ?? false;
        _showSystemMessages = prefs.getBool('show_system_messages') ?? true;
        _showConnectionStatusInAppBar =
            prefs.getBool('show_connection_status') ?? true;
        if (widget.isAdmin) {
          _serverIp = prefs.getString('server_ip') ?? "192.168.1.121";
          _currentModelName =
              prefs.getString('gemini_model_name') ?? "gemini-1.5-flash";
        }
      });
    } catch (e) {
      print('❌ Error al cargar configuraciones: $e');
    }
  }

  /// Verifica la conexión con el servidor
  Future<void> _checkServerConnection() async {
    if (_geminiService.isCheckingConnection && mounted) {
      setState(() {});
      return;
    }

    await _geminiService.checkServerConnection();

    if (mounted) {
      setState(() {
        // _isConnected y _isGeminiWorking se actualizan basados en el estado de GeminiService
      });
      if (_geminiService.isConnected) {
        final prefs = await SharedPreferences.getInstance();
        final wasLoggedOut = prefs.getBool('user_logged_out') ?? false;
        final userChanged = prefs.getBool('user_changed') ?? false;

        if (_messages.isEmpty || wasLoggedOut || userChanged) {
          if (wasLoggedOut) await prefs.remove('user_logged_out');
          if (userChanged) {
            await prefs.remove('user_changed');
            // Recargar información del usuario cuando hay cambios
            await _initializeUserId();
          }
        }
      } else {
        if (widget.isAdmin || _showSystemMessages) {
          _addSystemMessage("No se pudo conectar con Brunchy. Reintentando...");
        }
        Future.delayed(const Duration(seconds: 5), _retryConnection);
      }
    }
  }

  /// Reintenta la conexión con el servidor
  void _retryConnection() {
    if (!mounted) return;
    _checkServerConnection();
  }

  /// Añade un mensaje de bienvenida
  void _addWelcomeMessage() {
    final welcomeMessageText =
        widget.isAdmin
            ? '¡Hola administrador! Esta es la vista de chat de Brunchy.'
            : '¡Hola! 👋 Soy Brunchy, tu mesero virtual de Le Brunch. ¿En qué puedo ayudarte hoy?';
    final welcomeMsg = ChatMessage.fromSupport(message: welcomeMessageText);

    if (mounted) {
      setState(() {
        if (_messages.isEmpty ||
            _messages.first.message != welcomeMessageText) {
          _messages.insert(0, welcomeMsg);
        }
      });
      _saveMessageHistory();
    }
  }

  /// Añade un mensaje del sistema a la conversación
  void _addSystemMessage(String message) {
    if (!mounted) return;
    if (widget.isAdmin || _showSystemMessages) {
      setState(() {
        _messages.add(ChatMessage.fromSystem(message: message));
      });
      _scrollToBottom();
    }
  }

  /// Desplaza la vista hasta el final para mostrar mensajes recientes
  void _scrollToBottom() {
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

  /// Muestra un indicador de tipeo
  void _showTypingIndicator() {
    if (!mounted) return;
    setState(() => _isTyping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) setState(() => _isTyping = false);
    });
  }

  /// Oculta el indicador de tipeo
  void _hideTypingIndicator() {
    _typingTimer?.cancel();
    if (mounted) setState(() => _isTyping = false);
  }

  /// Inicializa el servicio de audio
  Future<void> _initializeAudio() async {
    if (!mounted) return;

    try {
      print('🎤 SharedChatScreen: Iniciando inicialización de AudioService...');

      // Verificar si el servicio ya está inicializado
      if (_audioService.isInitialized) {
        print('✅ AudioService ya estaba inicializado');
        if (mounted) {
          setState(() {
            _audioInitialized = true;
          });
        }
        return;
      }

      final initialized = await _audioService.initialize();

      if (!mounted) return;

      setState(() {
        _audioInitialized = initialized;
      });

      if (initialized) {
        print('✅ AudioService inicializado correctamente en SharedChatScreen');
      } else {
        print('❌ No se pudo inicializar AudioService en SharedChatScreen');
      }
    } catch (e) {
      print('❌ Error al inicializar AudioService en SharedChatScreen: $e');
      if (mounted) {
        setState(() {
          _audioInitialized = false;
        });
      }
    }
  }

  /// Muestra el modal de grabación de audio
  void _showAudioRecorderModal() async {
    print('🎤 SharedChatScreen: Intentando mostrar modal de grabación...');
    print('🎤 SharedChatScreen: _audioInitialized = $_audioInitialized');
    print(
      '🎤 SharedChatScreen: _audioService.isInitialized = ${_audioService.isInitialized}',
    );

    // Verificar si el servicio está realmente disponible
    if (!_audioInitialized || !_audioService.isInitialized) {
      print(
        '⚠️ AudioService no está inicializado, intentando reinicializar...',
      );

      // Intentar reinicializar el servicio
      await _initializeAudio();

      // Verificar nuevamente después de la reinicialización
      if (!_audioInitialized || !_audioService.isInitialized) {
        print('❌ No se pudo inicializar AudioService después del reintento');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El servicio de audio no está disponible. Verifica los permisos.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    print('✅ AudioService listo, mostrando modal...');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(20),
              child: AudioRecorderWidget(
                sessionId: _sessionId,
                onAudioRecorded: (String text) {
                  Navigator.of(context).pop();
                  _handleAudioMessage(text);
                },
                onAudioProcessed: (Map<String, dynamic> response) {
                  Navigator.of(context).pop();
                  _handleCompleteAudioResponse(response);
                },
                onCancel: () {
                  Navigator.of(context).pop();
                },
                primaryColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
    );
  }

  /// Maneja el mensaje de audio convertido a texto
  void _handleAudioMessage(String text) {
    if (text.isNotEmpty) {
      _messageController.text = text;
      _handleSendMessage();
    }
  }

  /// Maneja la respuesta completa del procesamiento de audio con Gemini
  void _handleCompleteAudioResponse(Map<String, dynamic> response) async {
    print('🎵 SharedChatScreen: Procesando respuesta completa de audio');

    // Extraer información de la respuesta con manejo robusto
    String textResponse = response['text_response'] as String? ?? '';

    // Limpiar texto de respuesta si contiene JSON malformado
    if (textResponse.contains('```json') ||
        textResponse.contains('"action":')) {
      // Extraer solo el texto limpio del text_response si está embebido en JSON
      final textMatch = RegExp(
        r'"text_response":\s*"([^"]+)"',
      ).firstMatch(textResponse);
      if (textMatch != null) {
        textResponse = textMatch.group(1) ?? textResponse;
        // Decodificar caracteres escapados
        textResponse = textResponse
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', '\\')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', '\t');
        print('🔧 SharedChatScreen: Texto limpio extraído: "$textResponse"');
      } else {
        // Si no se puede extraer, usar un mensaje por defecto
        textResponse = 'Brunchy procesó tu pedido correctamente.';
        print(
          '⚠️ SharedChatScreen: No se pudo extraer texto limpio, usando mensaje por defecto',
        );
      }
    }

    final String? action = response['action'] as String?;
    final List<dynamic>? items = response['items'] as List<dynamic>?;
    final String? transcribedText = response['transcribed_text'] as String?;
    final String? originalAudioPath =
        response['original_audio_path'] as String?;
    final int? audioDuration = response['audio_duration'] as int?;

    // Crear mensaje de audio del usuario
    if (originalAudioPath != null) {
      final userMsgId = const Uuid().v4();
      final audioMessage = ChatMessage.audioFromUser(
        audioPath: originalAudioPath,
        transcribedText: transcribedText ?? 'Mensaje de audio',
        audioDuration:
            audioDuration != null
                ? Duration(milliseconds: audioDuration)
                : null,
        messageId: userMsgId,
      );

      if (mounted) {
        setState(() {
          _messages.add(audioMessage);
          _isTyping = true;
        });
        _scrollToBottom();
        await _saveMessageHistory();
      }
    }

    // Crear respuesta de Brunchy
    final brunchyResponseText = textResponse;

    final brunchyMsgId = const Uuid().v4();
    final brunchyMessage = ChatMessage.fromSupport(
      message: brunchyResponseText,
      messageId: brunchyMsgId,
    );

    if (mounted) {
      setState(() {
        _messages.add(brunchyMessage);
        _isTyping = false;
      });
      _scrollToBottom();
      await _saveMessageHistory();

      // Manejar acciones de carrito usando método centralizado
      await _handleCartAction(action, items, 'audio');
    }
  }

  /// Método centralizado para manejar acciones de carrito
  Future<void> _handleCartAction(
    String? action,
    List<dynamic>? items,
    String source,
  ) async {
    if (action == 'add_to_cart') {
      print('🎯 SharedChatScreen: Detectada acción add_to_cart desde $source');
      print('🎯 SharedChatScreen: Items recibidos: $items');
      print('🎯 SharedChatScreen: Cantidad de items: ${items?.length ?? 0}');

      String snackBarMessage = 'Brunchy está procesando tu pedido.';
      if (items != null && items.isNotEmpty) {
        print(
          '🎯 SharedChatScreen: Items válidos, procediendo a agregar al carrito',
        );

        // AGREGAR ITEMS AL CARRITO REAL
        try {
          print(
            '🛒 SharedChatScreen: Agregando ${items.length} items al carrito desde $source',
          );

          // Convertir los items al formato esperado por CartService
          final List<Map<String, dynamic>> cartItems =
              items.map((item) {
                final Map<String, dynamic> cartItem = {
                  'name': item['name'] as String? ?? 'Producto',
                  'quantity': item['quantity'] as int? ?? 1,
                  'notes': item['notes'] as String? ?? '',
                };
                return cartItem;
              }).toList();

          // Agregar al carrito usando CartService
          await _cartService.addItemsFromBrunchy(cartItems);

          print('✅ SharedChatScreen: Items agregados al carrito exitosamente');
        } catch (e) {
          print('❌ SharedChatScreen: Error al agregar items al carrito: $e');
        }

        // Actualizar preferencias del usuario para cada item añadido
        try {
          for (final item in items) {
            final String? itemName = item['name'] as String?;
            if (itemName != null && itemName.isNotEmpty) {
              await _userPreferencesService.updateOrderedDish(itemName);
              print('📝 Preferencias actualizadas para: $itemName');
            }
          }
        } catch (e) {
          print('❌ Error al actualizar preferencias de usuario: $e');
        }

        final itemNames = items
            .map((item) => item['name'] as String? ?? 'un producto')
            .take(2)
            .join(', ');
        final additionalItems = items.length > 2 ? ' y más...' : '';
        snackBarMessage =
            'Brunchy añadió $itemNames$additionalItems a tu carrito.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(snackBarMessage),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
      _cartService.forceNotifyListeners();
    } else if (action == 'error') {
      _addSystemMessage("Brunchy dice: Ha ocurrido un error.");
    }
  }

  Future<void> _handleSendMessage() async {
    print('🟡 SharedChatScreen._handleSendMessage: INICIANDO');

    String messageText;
    try {
      messageText = _messageController.text.trim();
      print('📨 SharedChatScreen: Mensaje del usuario: "$messageText"');
      print('🆔 SharedChatScreen: SessionId: "$_sessionId"');

      if (messageText.isEmpty) {
        print('⚠️ SharedChatScreen: Mensaje vacío, retornando');
        return;
      }
    } catch (e) {
      print(
        '❌ SharedChatScreen: Error crítico al inicio de _handleSendMessage: $e',
      );
      print('❌ SharedChatScreen: StackTrace: ${StackTrace.current}');
      return;
    }

    final userMsgId = const Uuid().v4();
    final userMessage = ChatMessage.fromUser(
      message: messageText,
      messageId: userMsgId,
    );
    if (mounted) {
      setState(() {
        _messages.add(userMessage);
        _isTyping = true;
      });
    }
    _messageController.clear();
    _scrollToBottom();
    await _saveMessageHistory();

    try {
      print(
        '📤 SharedChatScreen: Llamando a _geminiService.sendMessageToBrunchy...',
      );

      // Convertir _userId a int para usarlo como clientId
      int? clientId;
      if (_userId != null && _userId != _sessionId) {
        try {
          clientId = int.parse(_userId!);
          print('👤 SharedChatScreen: Usando clientId: $clientId');
        } catch (e) {
          print(
            '⚠️ SharedChatScreen: No se pudo convertir _userId a int: $_userId',
          );
        }
      }

      final responseMap = await _geminiService.sendMessageToBrunchy(
        messageText,
        _sessionId,
        clientId: clientId,
      );

      print(
        '📬 SharedChatScreen: Respuesta recibida de GeminiService: $responseMap',
      );

      final String brunchyResponseText =
          responseMap['text_response'] as String? ??
          "Brunchy no pudo responder en este momento.";
      final String action = responseMap['action'] as String? ?? 'none';
      final List<dynamic>? items = responseMap['items'] as List<dynamic>?;

      final brunchyMsgId = const Uuid().v4();
      final brunchyMessage = ChatMessage.fromSupport(
        message: brunchyResponseText,
        messageId: brunchyMsgId,
      );

      if (mounted) {
        setState(() {
          _messages.add(brunchyMessage);
          _isTyping = false;
        });
        _scrollToBottom();
        await _saveMessageHistory();

        // Manejar acciones de carrito usando método centralizado
        await _handleCartAction(action, items, 'chat');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage.fromSystem(
              message:
                  "Error al conectar con Brunchy. Intenta de nuevo más tarde.",
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
        await _saveMessageHistory();
      }
      print('❌ Error en _handleSendMessage: $e');
    } finally {
      _hideTypingIndicator();
    }
  }

  /// Método para guardar el historial de mensajes
  Future<void> _saveMessageHistory() async {
    if (!mounted || _messages.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> messagesJson =
          _messages.map((m) => m.toJson()).toList();
      final historyKey = 'chat_history_${_userId ?? _sessionId}';
      await prefs.setString(historyKey, jsonEncode(messagesJson));
    } catch (e) {
      print('❌ Error al guardar historial de chat: $e');
    }
  }

  /// Método para cargar el historial de mensajes
  Future<void> _loadMessageHistory() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasLoggedOut = prefs.getBool('user_logged_out') ?? false;

      if (wasLoggedOut) {
        setState(() => _messages = []);
        await prefs.remove('user_logged_out');
        return;
      }

      final historyKey = 'chat_history_${_userId ?? _sessionId}';
      final String? chatHistoryJson = prefs.getString(historyKey);

      if (chatHistoryJson != null && chatHistoryJson.isNotEmpty) {
        final List<dynamic> decodedJson = jsonDecode(chatHistoryJson);
        final List<ChatMessage> loadedMessages =
            decodedJson
                .map(
                  (json) => ChatMessage.fromJson(json as Map<String, dynamic>),
                )
                .toList();
        if (mounted) {
          setState(() => _messages = loadedMessages);
        }
        _scrollToBottom();
      }
    } catch (e) {
      print('❌ Error al cargar historial de chat: $e');
      if (mounted) {
        setState(() => _messages = []);
      }
    }
  }

  /// Cambia el estado del modo de depuración
  Future<void> _toggleDebugMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newValue = !_debugMode;
      await prefs.setBool('debug_mode', newValue);

      setState(() {
        _debugMode = newValue;
        _messages.add(
          ChatMessage.fromSystem(
            message:
                "Modo de depuración ${_debugMode ? "ACTIVADO" : "DESACTIVADO"}",
          ),
        );
      });

      // Dar feedback
      HapticFeedback.heavyImpact();
      _scrollToBottom();
    } catch (e) {
      print('❌ Error al cambiar modo de depuración: $e');
    }
  }

  /// Maneja los toques para activar el modo de depuración
  void _handleDebugTap() {
    final now = DateTime.now();
    _debugTaps.add(now);
    _debugTaps.removeWhere((tap) => now.difference(tap).inSeconds > 3);
    if (_debugTaps.length >= 5) {
      _debugTaps.clear();
      _toggleDebugMode();
    }
  }

  /// Inicia timer para sincronización periódica del carrito
  void _startCartSyncTimer() {
    if (widget.isAdmin) return;
    _cartSyncTimer?.cancel();
    _cartSyncTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) _updateNavigationBadge();
    });
  }

  /// Actualiza el contador de la barra de navegación
  Future<void> _updateNavigationBadge() async {
    if (widget.isAdmin) return;
    try {
      final count = await _cartService.getReliableCartCount();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_nav_cart_count', count);
    } catch (e) {
      print('❌ Error al actualizar badge: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool aktuellenIsConnected = _geminiService.isConnected;
    final bool aktuellenIsGeminiWorking = aktuellenIsConnected;

    return BackgroundScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF3EA69B),
              child: Icon(Icons.support_agent, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin ? 'Brunchy (Admin)' : 'Brunchy Asistente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (_showConnectionStatusInAppBar || widget.isAdmin)
                  Text(
                    _geminiService.isCheckingConnection
                        ? 'Conectando...'
                        : aktuellenIsConnected
                        ? (aktuellenIsGeminiWorking
                            ? 'En línea'
                            : 'Servidor conectado, Gemini no disponible')
                        : 'Desconectado',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          _geminiService.isCheckingConnection
                              ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.7)
                              : aktuellenIsConnected
                              ? (aktuellenIsGeminiWorking
                                  ? Colors.green.shade700
                                  : Colors.red.shade700)
                              : Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: Icon(
                Icons.settings_applications,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                CustomModal.showFullScreenConfig(
                  context: context,
                  title: 'Configuración del Asistente',
                  content: ChatConfigModalContent(
                    onConfigSaved: () {
                      // Recargar configuraciones si es necesario
                      _loadSettings();
                    },
                  ),
                );
              },
            ),
          if (_debugMode)
            IconButton(
              icon: Icon(
                Icons.bug_report_outlined,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                /* Lógica para debug options */
              },
            ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _handleDebugTap();
                },
                child:
                    _messages.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _geminiService.isCheckingConnection ||
                                        !aktuellenIsConnected
                                    ? Icons.wifi_off_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                size: 70,
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.6),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _geminiService.isCheckingConnection
                                    ? 'Conectando con Brunchy...'
                                    : (aktuellenIsConnected
                                        ? 'Envíame un mensaje para empezar'
                                        : 'Buscando a Brunchy...'),
                                style: TextStyle(
                                  fontSize: 17,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              if (_geminiService.isCheckingConnection)
                                const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                )
                              else if (!aktuellenIsConnected)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSecondary,
                                  ),
                                  onPressed: _retryConnection,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                                  label: const Text('Reintentar Conexión'),
                                ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return ChatMessageBubble(
                              key: ValueKey(message.messageId ?? message.id),
                              message: message,
                              userRole: _userRole,
                            );
                          },
                        ),
              ),
            ),
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'Brunchy está escribiendo',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 24, height: 14, child: _buildTypingDots()),
                  ],
                ),
              ),
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.of(context).viewInsets.bottom -
                            (widget.isAdmin
                                ? 0
                                : (kBottomNavigationBarHeight * 0.6)) +
                            12
                        : 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Escribe a Brunchy...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.9),
                      ),
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onSubmitted: (_) {
                        print('🎯 ONSUBMITTED: TextField onSubmitted llamado');
                        _handleSendMessage();
                      },
                      onTap: _scrollToBottom,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón dinámico: Audio o Envío con transición suave
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (
                      Widget child,
                      Animation<double> animation,
                    ) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child:
                        _hasText
                            ? Material(
                              key: const ValueKey('send_button'),
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(25),
                              child: InkWell(
                                onTap: () {
                                  print('🎯 ONTAP: Botón de envío presionado');
                                  _handleSendMessage();
                                },
                                borderRadius: BorderRadius.circular(25),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Icon(
                                    Icons.send_rounded,
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    size: 22,
                                  ),
                                ),
                              ),
                            )
                            : TelegramAudioButton(
                              key: const ValueKey('audio_button'),
                              sessionId: _sessionId,
                              isEnabled: _audioInitialized,
                              onAudioRecorded: _handleAudioMessage,
                              onAudioProcessed: _handleCompleteAudioResponse,
                              primaryColor:
                                  Theme.of(context).colorScheme.secondary,
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedOpacity(
          opacity: 0.5 + (index * 0.15),
          duration: const Duration(milliseconds: 700),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      }),
    );
  }
}
