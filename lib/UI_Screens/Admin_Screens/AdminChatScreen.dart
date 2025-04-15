import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../Api_services/gemini_service.dart';
import '../../models/chat_message.dart';
import '../Widgets/chat_message_bubble.dart';
import '../Widgets/custom_modal.dart';

class AdminChatScreen extends StatefulWidget {
  const AdminChatScreen({super.key});

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();

  List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isCheckingConnection = false;
  bool _isEchoMode = false;
  bool _isConnected = false;
  bool _isGeminiWorking = false;
  bool _debugMode = false;

  // Variables de configuración administrador
  String _serverIp = "192.168.1.121";
  String _currentModelName = "gemini-2.5-pro-preview-03-25";
  List<String> _apiKeys = [];
  int _currentApiKeyIndex = 0;
  bool _showSystemMessages = true;
  bool _showConnectionStatus = true;
  bool _showApiDebug = false;

  // Lista para detectar taps para activar modo debug
  final List<DateTime> _debugTaps = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkServerConnection();
    _setupAdminOptions();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    // Evitar lógica que use el contexto después de desmontar el widget
    // El problema estaba en el manejo del hero animation y navegación después del desmonte

    super.dispose();
  }

  /// Carga configuraciones previas
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _debugMode = prefs.getBool('debug_mode') ?? false;
      _isEchoMode = prefs.getBool('echo_mode') ?? false;
      _isGeminiWorking = prefs.getBool('gemini_connected') ?? false;
      _serverIp = prefs.getString('server_ip') ?? "192.168.1.121";
      _apiKeys = prefs.getStringList('gemini_api_keys') ?? [];
      _currentApiKeyIndex = prefs.getInt('last_working_api_key_index') ?? 0;
      _currentModelName =
          prefs.getString('gemini_model_name') ??
          "gemini-2.5-pro-preview-03-25";
      _showSystemMessages = prefs.getBool('show_system_messages') ?? true;
      _showConnectionStatus = prefs.getBool('show_connection_status') ?? true;
      _showApiDebug = prefs.getBool('show_api_debug') ?? false;
    });

    _messages = _geminiService.getChatHistory();
  }

  /// Carga opciones adicionales para el administrador
  Future<void> _setupAdminOptions() async {
    // Obtener la lista actual de mensajes
    setState(() {
      _messages = _geminiService.getChatHistory();
    });
  }

  /// Verifica la conexión con el servidor
  Future<void> _checkServerConnection() async {
    if (_isCheckingConnection) return;

    setState(() {
      _isCheckingConnection = true;
    });

    try {
      final isConnected = await _geminiService.checkServerConnection();

      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _isCheckingConnection = false;
        });

        if (_isConnected) {
          _checkGeminiConnection();
        } else {
          _addSystemMessage(
            "No se pudo conectar al servidor. Modo offline activado.",
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isCheckingConnection = false;
        });
        _addSystemMessage("Error al verificar conexión: $e");
      }
    }
  }

  /// Verifica la conexión con Gemini
  Future<void> _checkGeminiConnection() async {
    if (mounted) {
      setState(() {
        _isTyping = true;
      });
    }

    try {
      // Añadir un mensaje técnico para administradores
      _addSystemMessage("Verificando estado de Gemini API...");

      // Verificar estado de API
      final isApiWorking = await _geminiService.testAllApiKeys();

      if (mounted) {
        setState(() {
          _isGeminiWorking = isApiWorking;
          _isTyping = false;
        });

        // Guardar en preferencias
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('gemini_connected', isApiWorking);

        // Actualizar el modelo que estamos usando
        if (isApiWorking) {
          _addSystemMessage("✅ Gemini API está funcionando correctamente");
        } else {
          _addSystemMessage(
            "❌ No se pudo conectar con ninguna API key de Gemini",
          );

          if (!_isEchoMode) {
            setState(() {
              _isEchoMode = true;
            });
            await prefs.setBool('echo_mode', true);
            _addSystemMessage("⚠️ Modo eco activado automáticamente");
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeminiWorking = false;
          _isTyping = false;
        });
        _addSystemMessage("Error al verificar Gemini: $e");
      }
    }
  }

  /// Añade un mensaje del sistema a la conversación
  void _addSystemMessage(String message) {
    if (_showSystemMessages && mounted) {
      setState(() {
        _messages.add(ChatMessage.fromSystem(message: message));
      });
      _scrollToBottom();
    }
  }

  /// Maneja el envío de mensajes
  Future<void> _handleSendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Limpiar el campo de texto
    _messageController.clear();

    // Añadir mensaje del usuario a la lista
    setState(() {
      final userMessage = ChatMessage.fromUser(message: message);
      _messages.add(userMessage);
      _isTyping = true;
    });

    // Scroll al final para mostrar el mensaje nuevo
    _scrollToBottom();

    try {
      // Si estamos en modo debug, mostrar información de desarrollo
      if (_showApiDebug) {
        _addSystemMessage("Enviando mensaje a la API...");
      }

      // Enviar el mensaje a Gemini
      final response = await _geminiService.sendMessage(message);

      if (mounted) {
        setState(() {
          _messages.add(response);
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(
            ChatMessage.fromSystem(message: "Error al enviar mensaje: $e"),
          );
        });
        _scrollToBottom();
      }
    }
  }

  /// Desplaza la vista hasta el final para mostrar mensajes recientes
  void _scrollToBottom() {
    // Usar addPostFrameCallback para asegurar que el scroll se realiza después de la actualización UI
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

  /// Muestra un indicador de escritura
  void _showTypingIndicator() {
    setState(() {
      _isTyping = true;
    });
  }

  /// Oculta el indicador de escritura
  void _hideTypingIndicator() {
    setState(() {
      _isTyping = false;
    });
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

      // Mostrar mensaje
      if (mounted) {
        _addSystemMessage(
          "Modo de depuración ${_debugMode ? "activado" : "desactivado"}",
        );
      }
    }
  }

  /// Alterna el modo de depuración
  Future<void> _toggleDebugMode() async {
    setState(() {
      _debugMode = !_debugMode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_mode', _debugMode);

    if (_debugMode) {
      // Si activamos el modo debug, mostrar opciones inmediatamente
      _showAdminOptions();
    }
  }

  /// Muestra opciones de administrador
  Future<void> _showAdminOptions() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      SizedBox(width: 8),
                      Text('Configuración de Chat'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Estado actual
                        _buildSectionTitle('Estado de conexión'),
                        _buildStateCard(
                          'Servidor NodeJS:',
                          _isConnected ? 'CONECTADO ✅' : 'DESCONECTADO ⚠️',
                          !_isConnected,
                        ),
                        _buildStateCard(
                          'API de Gemini:',
                          _isGeminiWorking ? 'FUNCIONAL ✅' : 'NO FUNCIONAL ⚠️',
                          !_isGeminiWorking,
                        ),
                        _buildStateCard(
                          'Modo eco:',
                          _isEchoMode ? 'ACTIVO ⚠️' : 'INACTIVO ✅',
                          _isEchoMode,
                        ),

                        const Divider(height: 24),

                        // Configuración de IP
                        _buildSectionTitle('Configuración del servidor'),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'IP del servidor',
                            hintText: 'Ej. 192.168.1.121',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(text: _serverIp),
                          onChanged: (value) {
                            _serverIp = value;
                          },
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(Icons.save),
                          label: Text('Guardar IP'),
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('server_ip', _serverIp);
                            _addSystemMessage(
                              "IP del servidor actualizada a: $_serverIp",
                            );
                            Navigator.pop(context);
                          },
                        ),

                        const Divider(height: 24),

                        // Configuración de API Keys
                        _buildSectionTitle('Claves API de Gemini'),
                        ..._apiKeys.asMap().entries.map((entry) {
                          final i = entry.key;
                          final key = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: 'API Key ${i + 1}',
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: key,
                                    ),
                                    obscureText: true,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        _apiKeys[i] = value;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () {
                                    setDialogState(() {
                                      _apiKeys.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        ElevatedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text('Añadir API Key'),
                          onPressed: () {
                            setDialogState(() {
                              _apiKeys.add('');
                            });
                          },
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(Icons.save),
                          label: Text('Guardar API Keys'),
                          onPressed: () async {
                            // Filtrar claves vacías
                            _apiKeys =
                                _apiKeys
                                    .where((key) => key.trim().isNotEmpty)
                                    .toList();
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setStringList(
                              'gemini_api_keys',
                              _apiKeys,
                            );
                            _addSystemMessage(
                              "Claves API actualizadas (${_apiKeys.length} claves guardadas)",
                            );
                            Navigator.pop(context);
                          },
                        ),

                        const Divider(height: 24),

                        // Configuración de visualización
                        _buildSectionTitle('Opciones de visualización'),
                        SwitchListTile(
                          title: Text('Mostrar mensajes del sistema'),
                          subtitle: Text(
                            'Incluye mensajes técnicos y de estado',
                          ),
                          value: _showSystemMessages,
                          onChanged: (value) async {
                            setDialogState(() {
                              _showSystemMessages = value;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('show_system_messages', value);
                          },
                        ),
                        SwitchListTile(
                          title: Text('Mostrar estado de conexión'),
                          subtitle: Text('Indicador de estado en tiempo real'),
                          value: _showConnectionStatus,
                          onChanged: (value) async {
                            setDialogState(() {
                              _showConnectionStatus = value;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(
                              'show_connection_status',
                              value,
                            );
                          },
                        ),
                        SwitchListTile(
                          title: Text('Modo desarrollador API'),
                          subtitle: Text(
                            'Muestra detalles técnicos de llamadas API',
                          ),
                          value: _showApiDebug,
                          onChanged: (value) async {
                            setDialogState(() {
                              _showApiDebug = value;
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('show_api_debug', value);
                          },
                        ),

                        const Divider(height: 24),

                        // Acciones de mantenimiento
                        _buildSectionTitle('Acciones de mantenimiento'),
                        ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text('Probar conexión con servidor'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            _checkServerConnection();
                            Navigator.pop(context);
                          },
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(Icons.api),
                          label: Text('Probar claves API de Gemini'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            _checkGeminiConnection();
                            Navigator.pop(context);
                          },
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(Icons.cleaning_services),
                          label: Text('Limpiar historial'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.errorContainer,
                            foregroundColor:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          onPressed: () {
                            _geminiService.resetChat();
                            setState(() {
                              _messages = [];
                            });
                            Navigator.pop(context);
                          },
                        ),
                        SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: Icon(Icons.restart_alt),
                          label: Text('Reiniciar completamente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                            foregroundColor:
                                Theme.of(context).colorScheme.onError,
                          ),
                          onPressed: () async {
                            await _geminiService.resetAndReinitialize();
                            _addSystemMessage(
                              "Sistema reiniciado completamente",
                            );
                            setState(() {
                              _messages = _geminiService.getChatHistory();
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cerrar'),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildStateCard(String label, String value, bool isWarning) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      color:
          isWarning
              ? Theme.of(context).colorScheme.errorContainer.withOpacity(0.3)
              : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    isWarning
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chat Admin'),
                    if (_showConnectionStatus)
                      Text(
                        _isGeminiWorking
                            ? 'Gemini conectado'
                            : (_isConnected
                                ? 'Usando servidor de respaldo'
                                : 'Sin conexión - Modo eco'),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              _isGeminiWorking
                                  ? Colors.green
                                  : (_isConnected ? Colors.amber : Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: _showAdminOptions,
              icon: Icon(Icons.settings),
              tooltip: 'Configuración',
            ),
          ],
        ),
        body: Column(
          children: [
            // Lista de mensajes
            Expanded(
              child: GestureDetector(
                onTap: _handleDebugTap,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      // Indicador de escritura
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return ChatMessageBubble(message: _messages[index]);
                  },
                ),
              ),
            ),

            // Barra de estado (solo en modo debug)
            if (_debugMode)
              Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'API: ${_isGeminiWorking ? "✓" : "✗"} | '
                        'Servidor: ${_isConnected ? "✓" : "✗"} | '
                        'Modo: ${_isEchoMode ? "Eco" : "Normal"} | '
                        'API Key: ${_currentApiKeyIndex + 1}/${_apiKeys.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Área de input
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 12.0,
              ),
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Botón de opciones adicionales
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.refresh),
                        onPressed: _checkGeminiConnection,
                        tooltip: 'Verificar conexión',
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Campo de texto
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              spreadRadius: 1,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).colorScheme.surfaceVariant,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            suffixIcon:
                                _debugMode
                                    ? IconButton(
                                      icon: Icon(
                                        Icons.bug_report,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                      onPressed: _showAdminOptions,
                                      tooltip: 'Opciones de depuración',
                                    )
                                    : null,
                          ),
                          onSubmitted: (_) => _handleSendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Botón de enviar
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: FloatingActionButton(
                        onPressed: _handleSendMessage,
                        mini: true,
                        tooltip: 'Enviar mensaje',
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        child: const Icon(Icons.send),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
