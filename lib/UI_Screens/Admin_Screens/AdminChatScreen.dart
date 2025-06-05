import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../Api_services/admin_chat_service.dart';
import '../../Api_services/global_config_service.dart';
import '../../Api_services/audio_service.dart';
import '../../models/chat_message.dart';
import '../Widgets/chat_message_bubble.dart';
import '../Widgets/custom_modal.dart';
import '../Widgets/audio_recorder_widget.dart';
import '../Widgets/telegram_audio_button.dart';
import '../../services/user_preferences_service.dart';
import '../Widgets/background_scaffold.dart';
import '../Widgets/chat_config_modal_content.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({Key? key}) : super(key: key);

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final AdminChatService _adminChatService = AdminChatService();
  final GlobalConfigService _globalConfig = GlobalConfigService();
  final UserPreferencesService _userPreferencesService =
      UserPreferencesService();
  final AudioService _audioService = AudioService();

  // Lista de mensajes
  List<ChatMessage> _messages = [];

  // Indicadores de estado
  bool _isTyping = false;
  bool _isConnected = false;
  bool _debugMode = false;
  bool _audioInitialized = false;
  bool _hasText = false; // Nueva variable para trackear si hay texto

  // Timers y controladores
  Timer? _typingTimer;

  // ID de sesión único para el admin
  String _sessionId = '';
  int? _userRole = 0; // Admin role

  @override
  void initState() {
    super.initState();

    print('🚀 AdminChatScreen: initState INICIADO');
    _sessionId = 'admin_${const Uuid().v4()}';
    print('🆔 AdminChatScreen: SessionId generado: $_sessionId');

    _initializeAdmin();
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
      _checkServerConnection();
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
    super.dispose();
  }

  /// Inicializa el admin y carga configuración global
  Future<void> _initializeAdmin() async {
    try {
      // Cargar configuración global primero
      await _globalConfig.loadConfig();

      // Intentar sincronizar con el servidor si es posible
      try {
        await _globalConfig.loadConfigFromServer();
      } catch (e) {
        print('⚠️ No se pudo sincronizar con servidor: $e');
      }

      await _loadMessageHistory();
      if (_messages.isEmpty && mounted) {
        _addWelcomeMessage();
      }
    } catch (e) {
      print('❌ Error al inicializar admin: $e');
    }
  }

  /// Carga configuraciones previas
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _debugMode = prefs.getBool('admin_debug_mode') ?? false;
      });
    } catch (e) {
      print('❌ Error al cargar configuraciones del admin: $e');
    }
  }

  /// Verifica la conexión con el servidor
  Future<void> _checkServerConnection() async {
    final isConnected = await _globalConfig.testConnection();

    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });

      if (!isConnected) {
        _addSystemMessage(
          "⚠️ No se pudo conectar con el servidor. Verifica la configuración.",
        );
      }
    }
  }

  /// Carga el historial de mensajes del admin
  Future<void> _loadMessageHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('admin_chat_history');

      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        final List<ChatMessage> loadedMessages =
            historyList
                .map((messageJson) => ChatMessage.fromJson(messageJson))
                .toList();

        if (mounted) {
          setState(() {
            _messages = loadedMessages;
          });
        }
      }
    } catch (e) {
      print('❌ Error al cargar historial del admin: $e');
    }
  }

  /// Guarda el historial de mensajes del admin
  Future<void> _saveMessageHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = json.encode(
        _messages.map((m) => m.toJson()).toList(),
      );
      await prefs.setString('admin_chat_history', historyJson);
    } catch (e) {
      print('❌ Error al guardar historial del admin: $e');
    }
  }

  /// Añade mensaje de bienvenida especializado para admin
  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage.fromSystem(
      message: '''🔧 Chat Admin

Comandos principales:
• `/help` - Ver comandos
• `/config` - Configuración
• `/status` - Estado

Escribe `/help` para más info.''',
      id: const Uuid().v4(),
    );

    setState(() {
      _messages.add(welcomeMessage);
    });
    _saveMessageHistory();
  }

  /// Añade mensaje del sistema
  void _addSystemMessage(String text) {
    final systemMessage = ChatMessage.fromSystem(
      message: text,
      id: const Uuid().v4(),
    );

    setState(() {
      _messages.add(systemMessage);
    });
    _saveMessageHistory();
    _scrollToBottom();
  }

  /// Inicializa el servicio de audio
  Future<void> _initializeAudio() async {
    try {
      final initialized = await _audioService.initialize();
      if (mounted) {
        setState(() {
          _audioInitialized = initialized;
        });
      }

      if (initialized) {
        print('✅ AudioService inicializado correctamente en Admin');
      } else {
        print('❌ No se pudo inicializar AudioService en Admin');
      }
    } catch (e) {
      print('❌ Error al inicializar AudioService en Admin: $e');
      if (mounted) {
        setState(() {
          _audioInitialized = false;
        });
      }
    }
  }

  /// Muestra el modal de grabación de audio
  void _showAudioRecorderModal() {
    if (!_audioInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El servicio de audio no está disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
      _sendMessage();
    }
  }

  /// Envía mensaje del admin
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Añadir mensaje del usuario
    final userMessage = ChatMessage.fromUser(
      message: messageText,
      id: const Uuid().v4(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _messageController.clear();
    _saveMessageHistory();
    _scrollToBottom();

    try {
      // Procesar mensaje con AdminChatService
      final response = await _adminChatService.processAdminMessage(messageText);

      // Crear mensaje de respuesta
      final responseMessage = ChatMessage.fromSupport(
        message: response['text_response'] ?? 'Error: No se recibió respuesta',
        id: const Uuid().v4(),
      );

      setState(() {
        _messages.add(responseMessage);
        _isTyping = false;
      });

      _saveMessageHistory();
      _scrollToBottom();

      // Manejar acciones especiales
      if (response['action'] == 'test_connection') {
        Future.delayed(const Duration(seconds: 1), _checkServerConnection);
      }
    } catch (e) {
      setState(() {
        _isTyping = false;
      });

      final errorMessage = ChatMessage.fromSystem(
        message: '❌ Error al procesar comando: $e',
        id: const Uuid().v4(),
      );

      setState(() {
        _messages.add(errorMessage);
      });

      _saveMessageHistory();
      _scrollToBottom();
    }
  }

  /// Desplaza hacia abajo
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

  /// Construye indicador de escritura
  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          height: 4,
          width: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  /// Limpia el historial de chat
  void _clearChatHistory() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Limpiar Historial'),
            content: const Text(
              '¿Estás seguro de que quieres limpiar todo el historial del chat de administración?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() {
                    _messages.clear();
                  });
                  await _saveMessageHistory();
                  _addWelcomeMessage();
                },
                child: const Text('Limpiar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.admin_panel_settings,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Chat Admin',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    _isConnected
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 12,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _isConnected ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () {
              CustomModal.showFullScreenConfig(
                context: context,
                title: 'Configuración Global del Asistente',
                content: ChatConfigModalContent(
                  onConfigSaved: () async {
                    // Recargar configuración global
                    await _globalConfig.loadConfig();
                    // Recargar configuraciones locales
                    await _loadSettings();
                    // Verificar conexión
                    await _checkServerConnection();
                    // Mostrar mensaje de confirmación
                    if (mounted) {
                      _addSystemMessage(
                        "✅ Configuración actualizada desde el modal",
                      );
                    }
                  },
                ),
              );
            },
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          IconButton(
            icon: Icon(
              Icons.clear_all,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: _clearChatHistory,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Expanded(
              child:
                  _messages.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 70,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chat Admin',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Controla la configuración del asistente',
                              style: TextStyle(
                                fontSize: 15,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor:
                                    Theme.of(context).colorScheme.onPrimary,
                              ),
                              onPressed: () {
                                _messageController.text = '/help';
                                _sendMessage();
                              },
                              icon: const Icon(Icons.help_outline, size: 20),
                              label: const Text('Ver Comandos'),
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
            if (_isTyping)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Text(
                      'Procesando...',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 20, height: 12, child: _buildTypingDots()),
                  ],
                ),
              ),
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.5),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Comando o pregunta...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.5),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.9),
                        prefixIcon: Icon(
                          Icons.terminal,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 6),
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
                            ? Container(
                              key: const ValueKey('send_button'),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.send_rounded,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                                onPressed: _sendMessage,
                              ),
                            )
                            : TelegramAudioButton(
                              key: const ValueKey('audio_button'),
                              sessionId: _sessionId,
                              isEnabled: _audioInitialized,
                              onAudioRecorded: _handleAudioMessage,
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
}
