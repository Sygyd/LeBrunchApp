import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../Api_services/gemini_service.dart';
import '../../Api_services/cart_service.dart';
import '../../models/chat_message.dart';
import '../Widgets/chat_message_bubble.dart';
import '../Widgets/custom_modal.dart';
import '../Client_Screens/CartScreen.dart';
import '../../services/user_preferences_service.dart';

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

  // Lista de mensajes
  List<ChatMessage> _messages = [];

  // Indicadores de estado
  bool _isTyping = false;
  bool _showConnectionStatusInAppBar = true;
  bool _debugMode = false;

  // Timers y controladores
  Timer? _typingTimer;
  Timer? _cartSyncTimer;

  // Variables para personalización de administrador
  String _serverIp = "192.168.1.121";
  String _currentModelName = "gemini-1.5-flash";
  bool _showSystemMessages = true;

  // ID de usuario
  String? _userId;
  String _sessionId = '';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      this._checkServerConnection();
      if (!widget.isAdmin) {
        _startCartSyncTimer();
      }
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

      if (currentUserId != null) {
        _userId = currentUserId.toString();
        print('📱 Chat: ID de usuario cargado: $_userId');
      } else {
        // Si no hay usuario logueado, usar el sessionId como userId
        _userId = _sessionId;
        print('📱 Chat: Usando sessionId como userId: $_userId');
      }
    } catch (e) {
      print('❌ Error al inicializar userId: $e');
      // En caso de error, usar sessionId como fallback
      _userId = _sessionId;
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
          if (userChanged) await prefs.remove('user_changed');
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
      final responseMap = await _geminiService.sendMessageToBrunchy(
        messageText,
        _sessionId,
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

        if (action == 'add_to_cart') {
          String snackBarMessage = 'Brunchy está procesando tu pedido.';
          if (items != null && items.isNotEmpty) {
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
          _addSystemMessage("Brunchy dice: $brunchyResponseText");
        }
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

    return Scaffold(
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
                              ? Theme.of(context).colorScheme.outline
                              : aktuellenIsConnected
                              ? (aktuellenIsGeminiWorking
                                  ? Colors.green.shade700
                                  : Theme.of(context).colorScheme.error)
                              : Theme.of(
                                context,
                              ).colorScheme.error.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_applications),
              onPressed: () {
                /* Lógica para admin settings */
              },
            ),
          if (_debugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
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
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: const AssetImage("assets/images/fondolb.jpg"),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.white.withOpacity(0.85),
                        BlendMode.lighten,
                      ),
                    ),
                  ),
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
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
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
                              );
                            },
                          ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              margin: EdgeInsets.only(
                bottom:
                    MediaQuery.of(context).viewInsets.bottom > 0
                        ? MediaQuery.of(context).viewInsets.bottom -
                            (widget.isAdmin
                                ? 0
                                : (kBottomNavigationBarHeight * 0.6))
                        : 8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
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
                        ).colorScheme.surfaceVariant.withOpacity(0.7),
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
                  const SizedBox(width: 10),
                  Material(
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
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 22,
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
