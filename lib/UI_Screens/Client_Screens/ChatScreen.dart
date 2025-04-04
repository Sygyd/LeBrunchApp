import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../Widgets/chat_message_bubble.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Lista de mensajes (simulados para demostración)
  final List<ChatMessage> _messages = [];

  // Indicador de tipeo
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    // Cargar mensajes iniciales de demostración
    _loadInitialMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  // Método para cargar mensajes de demostración
  void _loadInitialMessages() {
    setState(() {
      _messages.add(
        ChatMessage.fromSupport(
          message:
              '¡Hola! Bienvenido al soporte de Le Brunch. ¿En qué podemos ayudarte hoy?',
          id: '1',
        ),
      );
    });

    // Simular respuesta después de 1 segundo
    Future.delayed(const Duration(seconds: 1), () {
      _simulateTyping();

      Future.delayed(const Duration(seconds: 2), () {
        _stopTyping();
        setState(() {
          _messages.add(
            ChatMessage.fromSupport(
              message:
                  'Puedes preguntar sobre tu pedido, nuestro menú, o cualquier otra duda que tengas.',
              id: '2',
            ),
          );
        });
        _scrollToBottom();
      });
    });
  }

  // Simular que el soporte está escribiendo
  void _simulateTyping() {
    setState(() {
      _isTyping = true;
    });
  }

  // Detener la simulación de tipeo
  void _stopTyping() {
    setState(() {
      _isTyping = false;
    });
  }

  // Simular una respuesta automática
  void _simulateResponse(String userMessage) {
    // Cancela cualquier timer existente
    _typingTimer?.cancel();

    // Inicia un nuevo timer para simular respuesta después de 1 segundo
    _typingTimer = Timer(const Duration(seconds: 1), () {
      _simulateTyping();

      // Generar respuesta basada en palabras clave en el mensaje del usuario
      String response = _generateResponse(userMessage);

      // Simular tiempo de tipeo proporcional a la longitud del mensaje
      int typingDuration = (response.length * 0.05).clamp(1, 3).toInt();

      // Después del tiempo de tipeo, enviar respuesta
      Future.delayed(Duration(seconds: typingDuration), () {
        _stopTyping();
        setState(() {
          _messages.add(ChatMessage.fromSupport(message: response));
        });
        _scrollToBottom();
      });
    });
  }

  // Generar respuesta basada en palabras clave
  String _generateResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('hola') ||
        lowerMessage.contains('hi') ||
        lowerMessage.contains('saludos')) {
      return '¡Hola! ¿En qué puedo ayudarte hoy?';
    } else if (lowerMessage.contains('menu') ||
        lowerMessage.contains('platos') ||
        lowerMessage.contains('comida')) {
      return 'Puedes revisar nuestro menú completo en la sección "Menú". Tenemos una gran variedad de platos preparados con ingredientes frescos de primera calidad.';
    } else if (lowerMessage.contains('pedido') ||
        lowerMessage.contains('orden')) {
      return 'Si tienes alguna pregunta sobre tu pedido, por favor proporciona el número de pedido y estaré encantado de ayudarte.';
    } else if (lowerMessage.contains('gracias') ||
        lowerMessage.contains('thank')) {
      return '¡Un placer poder ayudarte! Si tienes más preguntas, estoy a tu disposición.';
    } else if (lowerMessage.contains('reserva') ||
        lowerMessage.contains('reservación')) {
      return 'Para hacer una reservación, puedes indicarnos la fecha, hora y número de personas. ¿Te gustaría hacer una reservación ahora?';
    } else if (lowerMessage.contains('ubicación') ||
        lowerMessage.contains('dirección') ||
        lowerMessage.contains('donde')) {
      return 'Estamos ubicados en el centro comercial Plaza Mayor, local 205. Contamos con estacionamiento gratuito para nuestros clientes.';
    } else if (lowerMessage.contains('horario') ||
        lowerMessage.contains('abierto')) {
      return 'Nuestro horario de atención es de lunes a viernes de 7:00 AM a 9:00 PM, y fines de semana de 8:00 AM a 10:00 PM.';
    } else {
      return 'Gracias por tu mensaje. Un miembro de nuestro equipo de atención al cliente te responderá lo antes posible. ¿Hay algo más en lo que pueda ayudarte mientras tanto?';
    }
  }

  // Enviar un mensaje
  void _handleSubmit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Limpiar input
    _messageController.clear();
    _focusNode.requestFocus();

    // Agregar mensaje del usuario a la lista
    setState(() {
      _messages.add(ChatMessage.fromUser(message: message));
    });

    // Scrollear al final
    _scrollToBottom();

    // Simular respuesta
    _simulateResponse(message);
  }

  // Asegurar que el scroll va al final
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soporte Le Brunch',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'LightHouse',
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onBackground,
              ),
            ),
            if (_isTyping)
              Text(
                'Escribiendo...',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'MADE TOMMY',
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 2,
        shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Avatar circular del soporte
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              radius: 18,
              child: Icon(
                Icons.support_agent,
                color: theme.colorScheme.onPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Área de mensajes
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.95),
              ),
              child:
                  _messages.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildMessageList(theme),
            ),
          ),

          // Área de entrada de mensaje
          _buildInputArea(theme),
        ],
      ),
    );
  }

  // Widget para mostrar cuando no hay mensajes
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Inicia una conversación',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontFamily: 'LightHouse',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nuestro equipo de soporte está listo para ayudarte',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontFamily: 'MADE TOMMY',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Lista de mensajes
  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return ChatMessageBubble(message: _messages[index]);
      },
    );
  }

  // Área de entrada de mensaje
  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botón para adjuntar archivos (opcional)
          IconButton(
            icon: Icon(Icons.attach_file, color: theme.colorScheme.primary),
            onPressed: () {
              // Implementar funcionalidad para adjuntar archivos
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Adjuntar archivos estará disponible próximamente',
                    style: TextStyle(fontFamily: 'MADE TOMMY'),
                  ),
                  backgroundColor: theme.colorScheme.primary,
                ),
              );
            },
          ),

          // Campo de texto para el mensaje
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    fontFamily: 'MADE TOMMY',
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'MADE TOMMY',
                  color: theme.colorScheme.onSurface,
                ),
                onSubmitted: (_) => _handleSubmit(),
              ),
            ),
          ),

          // Botón para enviar mensaje
          IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.primary),
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
