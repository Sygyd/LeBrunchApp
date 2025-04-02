import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../Providers/chat_provider.dart';
import '../../Providers/le_cart_provider.dart';
import '../../models/chat_message.dart';
import '../../theme/theme.dart';
import '../../models/cart_item.dart';
import '../../Providers/auth_provider.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  final int userId;

  const ChatScreen({super.key, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isServerAvailable = false;

  @override
  void initState() {
    super.initState();

    // Verificar disponibilidad del servidor en segundo plano
    _checkServerAvailability().then((available) {
      if (mounted) {
        setState(() {
          _isServerAvailable = available;
        });
      }
    });

    // Mensaje inicial del bot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (chatProvider.messages.isEmpty) {
        chatProvider.addBotMessage(
          _isServerAvailable
              ? '¡Hola! Soy el asistente virtual de Le Brunch. Estoy operando en modo offline, pero el servidor está disponible. Escribe "conectar al servidor" si deseas usar el modo online.'
              : '¡Hola! Soy el asistente virtual de Le Brunch. Estoy operando en modo offline y puedo responder preguntas básicas sobre nuestro menú, horarios y servicios.',
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.addUserMessage(text);
    chatProvider.setProcessing(true);
    _messageController.clear();
    _scrollToTop();

    try {
      // Intentar obtener una respuesta offline primero
      final offlineResponse = _getOfflineResponse(text);

      if (offlineResponse != null) {
        // Simular un pequeño retraso para dar sensación de procesamiento
        await Future.delayed(const Duration(milliseconds: 800));
        chatProvider.addBotMessage(offlineResponse);
        chatProvider.setProcessing(false);
        return;
      }

      // Si el mensaje menciona conectar al servidor y el servidor está disponible, intentar conexión
      if (text.toLowerCase().contains("conectar al servidor") &&
          _isServerAvailable) {
        try {
          final url = Uri.parse('http://192.168.1.121:5678/webhook-test/chat');

          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'message': text, 'userId': widget.userId}),
              )
              .timeout(const Duration(seconds: 60));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            chatProvider.addBotMessage(data['response'] ?? 'No entendí eso');
          } else {
            chatProvider.addBotMessage(
              'Lo siento, hubo un problema con el servidor (${response.statusCode})',
            );
          }
        } on TimeoutException {
          chatProvider.addBotMessage(
            'Lo siento, el servidor tardó demasiado en responder. Estoy funcionando en modo offline.',
          );
        } on SocketException {
          chatProvider.addBotMessage(
            'Lo siento, no pude conectarme al servidor. Estoy funcionando en modo offline.',
          );
        } catch (e) {
          chatProvider.addBotMessage(
            'Ocurrió un error: ${e.toString()}. Estoy funcionando en modo offline.',
          );
        }
      } else {
        // Si no se solicita conexión al servidor o no está disponible, usar modo offline
        if (text.toLowerCase().contains("conectar al servidor") &&
            !_isServerAvailable) {
          await Future.delayed(const Duration(milliseconds: 800));
          chatProvider.addBotMessage(
            'Lo siento, el servidor no está disponible en este momento. Seguiré funcionando en modo offline.',
          );
        } else {
          await Future.delayed(const Duration(milliseconds: 800));
          chatProvider.addBotMessage(
            'Estoy en modo offline. Puedo responder preguntas básicas sobre el menú, horarios y servicios. Para intentar conectar con el servidor, escribe "conectar al servidor".',
          );
        }
      }
    } catch (e) {
      // Ofrecer una respuesta de fallback en caso de error
      chatProvider.addBotMessage(
        '⚠️ Error interno: Por favor, intenta con otra pregunta.',
      );
    } finally {
      chatProvider.setProcessing(false);
    }
  }

  Future<void> _sendSuggestion(String message) async {
    _messageController.text = message;
    await _sendMessage();
  }

  Future<Map<String, dynamic>> _processWithN8n(String message) async {
    final cartProvider = Provider.of<LeCartProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await http
          .post(
            Uri.parse(
              'http://localhost:5678/webhook/70b635ca-e6ad-4b4f-9887-2e4eb437ab95/chat',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${authProvider.token}',
            },
            body: jsonEncode({
              'message': message,
              'userId': widget.userId,
              'currentCart': cartProvider.items.map((e) => e.toJson()).toList(),
              'chatHistory':
                  chatProvider.messages
                      .map(
                        (msg) => {
                          'role': msg.isUser ? 'user' : 'assistant',
                          'content': msg.text,
                          'timestamp': msg.timestamp.toIso8601String(),
                        },
                      )
                      .toList(),
              'metadata': {
                'totalItems': cartProvider.items.length,
                'totalAmount': cartProvider.getTotalPrice(),
              },
            }),
          )
          .timeout(
            const Duration(
              seconds: 60,
            ), // Aumentado a 60 segundos para permitir más tiempo de conexión
            onTimeout:
                () => throw TimeoutException('La conexión tardó demasiado'),
          );

      if (response.statusCode != 200) {
        throw Exception('Error en la API: ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      // Verificar si la respuesta viene en el formato esperado
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Formato de respuesta inválido');
      }

      // Asegurarse de que tenga los campos necesarios
      if (!responseData.containsKey('responseText')) {
        responseData['responseText'] =
            responseData['text'] ??
            responseData['content'] ??
            responseData['response'] ??
            'No se pudo procesar la respuesta';
      }

      return responseData;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(
          'La conexión tardó demasiado. Por favor, intenta de nuevo.',
        );
      } else if (e is SocketException) {
        throw Exception(
          'No se pudo conectar al servidor. Verifica tu conexión.',
        );
      } else {
        throw Exception('Error al procesar el mensaje: $e');
      }
    }
  }

  Future<void> _handleN8nResponse(Map<String, dynamic> response) async {
    final cartProvider = Provider.of<LeCartProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    try {
      switch (response['action']) {
        case 'add_to_cart':
          if (response['item'] != null) {
            final item = CartItem.fromJson(response['item']);
            cartProvider.addItem(item);
            chatProvider.addBotMessage(
              '✅ ${response['responseText'] ?? 'Añadido: ${item.name} (x${item.quantity})'}',
              metadata: jsonEncode({'action': 'add', 'itemId': item.id}),
            );
          }
          break;

        case 'update_cart':
          if (response['itemId'] != null && response['newQuantity'] != null) {
            final itemId = response['itemId'].toString();
            final newQuantity =
                int.tryParse(response['newQuantity'].toString()) ?? 0;
            if (newQuantity > 0) {
              cartProvider.updateItemQuantity(itemId, newQuantity);
              chatProvider.addBotMessage(
                '✏️ ${response['responseText'] ?? 'Cantidad actualizada'}',
                metadata: jsonEncode({'action': 'update', 'itemId': itemId}),
              );
            }
          }
          break;

        case 'remove_from_cart':
          if (response['itemId'] != null) {
            final itemId = response['itemId'].toString();
            cartProvider.removeItem(itemId);
            chatProvider.addBotMessage(
              '🗑️ ${response['responseText'] ?? 'Ítem removido'}',
              metadata: jsonEncode({'action': 'remove', 'itemId': itemId}),
            );
          }
          break;

        case 'clear_cart':
          cartProvider.clearCart();
          chatProvider.addBotMessage(
            '🔄 ${response['responseText'] ?? 'Carrito vaciado'}',
            metadata: jsonEncode({'action': 'clear'}),
          );
          break;

        default:
          chatProvider.addBotMessage(
            response['responseText'] ??
                'No entendí tu mensaje. ¿Podrías reformularlo?',
            metadata: jsonEncode(response['metadata'] ?? {}),
          );
      }
    } catch (e) {
      chatProvider.addBotMessage('⚠️ Error al procesar: ${e.toString()}');
    }
    _scrollToTop();
  }

  Widget _buildSuggestions() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (chatProvider.messages.length < 2) return const SizedBox.shrink();

        return Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: Text(
                "Ver menú",
                style: TextStyle(
                  fontFamily: 'MADE TOMMY',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onPressed: () => _sendSuggestion("Recomiéndame platos populares"),
            ),
            ActionChip(
              label: Text(
                "Mi pedido",
                style: TextStyle(
                  fontFamily: 'MADE TOMMY',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onPressed: () => _sendSuggestion("¿Qué hay en mi carrito?"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          itemCount: chatProvider.messages.length,
          itemBuilder:
              (ctx, index) => _buildMessage(chatProvider.messages[index]),
        );
      },
    );
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              return Visibility(
                visible: chatProvider.isProcessing,
                child: LinearProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu mensaje...',
                    hintStyle: TextStyle(
                      fontFamily: 'MADE TOMMY',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.onSurface,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: theme.colorScheme.primary),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            message.isUser
                ? theme.colorScheme.primary.withOpacity(0.1)
                : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.isUser ? 'Tú' : 'Asistente',
            style: theme.textTheme.labelLarge?.copyWith(
              fontFamily: 'LightHouse',
              fontWeight: FontWeight.bold,
              color:
                  message.isUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'MADE TOMMY',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary() {
    return Consumer<LeCartProvider>(
      builder: (context, cartProvider, _) {
        if (cartProvider.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shopping_cart,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${cartProvider.items.length} ítem(s) - \$${cartProvider.getTotalPrice().toStringAsFixed(2)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontFamily: 'MADE TOMMY'),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Asistente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final bool isAvailable = await _checkServerAvailability();
              setState(() {
                _isServerAvailable = isAvailable;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isAvailable
                        ? 'Servidor disponible. Escribe "conectar al servidor" para usarlo.'
                        : 'Servidor no disponible. Usando modo offline.',
                  ),
                  backgroundColor: isAvailable ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildCartSummary(),
          _buildInputArea(),
        ],
      ),
    );
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Método para verificar disponibilidad del servidor
  Future<bool> _checkServerAvailability() async {
    try {
      final response = await http
          .get(Uri.parse('http://192.168.1.121:5678/'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Método para obtener respuestas offline basadas en palabras clave
  String? _getOfflineResponse(String text) {
    // Palabras clave para el menú
    if (text.contains('menú') ||
        text.contains('carta') ||
        text.contains('platos')) {
      return 'Puedes ver nuestro menú completo en la sección "Menú" de la aplicación. Tenemos una variedad de platos como panqueques, tostadas francesas, tablas de desayuno y más.';
    }

    // Palabras clave para platos específicos
    if (text.contains('panqueque') || text.contains('pancake')) {
      return 'Nuestros panqueques son una delicia. Tenemos opciones con frutas frescas, chocolate, miel, y nuestra especialidad de panqueques con sirope de arce y tocino crujiente.';
    }

    if (text.contains('tostada francesa') || text.contains('french toast')) {
      return 'Nuestras tostadas francesas son preparadas con pan brioche, huevo, canela y vainilla. Vienen con frutas de temporada y sirope de tu elección.';
    }

    if (text.contains('gofre') || text.contains('waffle')) {
      return 'Los gofres de Le Brunch son ligeros y crujientes, servidos con crema batida casera y frutas frescas. ¡Son perfectos para comenzar el día!';
    }

    if (text.contains('omelette') || text.contains('huevo')) {
      return 'Nuestros omelettes son preparados con huevos orgánicos y puedes personalizarlos con ingredientes como queso, champiñones, espinaca, jamón y más.';
    }

    // Palabras clave para bebidas
    if (text.contains('bebida') ||
        text.contains('café') ||
        text.contains('jugo') ||
        text.contains('té')) {
      return 'Ofrecemos una variedad de bebidas incluyendo café de especialidad, lattes, cappuccinos, tés orgánicos, jugos naturales recién exprimidos y smoothies de frutas.';
    }

    // Palabras clave para opciones dietéticas
    if (text.contains('vegetariano') ||
        text.contains('vegano') ||
        text.contains('sin gluten') ||
        text.contains('alergia')) {
      return 'Tenemos opciones vegetarianas, veganas y sin gluten. Por favor, notifica al personal sobre cualquier alergia o preferencia dietética al hacer tu pedido.';
    }

    // Palabras clave para precios
    if (text.contains('precio') ||
        text.contains('costo') ||
        text.contains('cuánto')) {
      return 'Los precios de nuestros platos principales oscilan entre \$8 y \$15. Puedes ver el precio exacto de cada plato en nuestra sección de Menú.';
    }

    // Palabras clave para horarios
    if (text.contains('horario') ||
        text.contains('abierto') ||
        text.contains('cerrado') ||
        text.contains('horas')) {
      return 'Nuestro horario de atención es de martes a domingo de 8:00 AM a 4:00 PM. Estamos cerrados los lunes.';
    }

    // Palabras clave para ubicación
    if (text.contains('ubicación') ||
        text.contains('dirección') ||
        text.contains('donde') ||
        text.contains('dónde')) {
      return 'Estamos ubicados en Calle Principal #123, Ciudad. Puedes encontrarnos fácilmente usando Google Maps.';
    }

    // Palabras clave para reservaciones
    if (text.contains('reserva') ||
        text.contains('reservación') ||
        text.contains('mesa')) {
      return 'Para hacer una reservación, puedes llamarnos al 555-123-4567 o hacerlo directamente desde nuestra página web www.lebrunch.com/reservas';
    }

    // Palabras clave para información de contacto
    if (text.contains('contacto') ||
        text.contains('teléfono') ||
        text.contains('email') ||
        text.contains('correo')) {
      return 'Puedes contactarnos al 555-123-4567 o enviarnos un correo a info@lebrunch.com';
    }

    // Palabras clave para el carrito
    if (text.contains('carrito') ||
        text.contains('pedido') ||
        text.contains('ordenar')) {
      return 'Puedes ver tu carrito actual haciendo clic en el ícono de carrito en la parte inferior de la pantalla. Allí podrás modificar tu pedido y proceder al pago.';
    }

    // Palabras clave para delivery/para llevar
    if (text.contains('delivery') ||
        text.contains('llevar') ||
        text.contains('domicilio') ||
        text.contains('pickup')) {
      return 'Ofrecemos servicio a domicilio y para llevar. Puedes hacer tu pedido a través de nuestra aplicación o llamando al 555-123-4567.';
    }

    // Palabras clave para saludos
    if (text.contains('hola') ||
        text.contains('buenos días') ||
        text.contains('buenas tardes') ||
        text.contains('buenas noches')) {
      return '¡Hola! Soy tu asistente virtual de Le Brunch. ¿En qué puedo ayudarte hoy?';
    }

    // Palabras clave para despedidas
    if (text.contains('adiós') ||
        text.contains('hasta luego') ||
        text.contains('chao') ||
        text.contains('gracias')) {
      return '¡Gracias por chatear conmigo! Si necesitas algo más, no dudes en preguntar. ¡Que tengas un excelente día!';
    }

    // Respuesta por defecto si no hay coincidencias específicas
    return 'Lo siento, no tengo información específica sobre eso en mi modo offline. ¿Puedo ayudarte con información sobre nuestro menú, horarios, ubicación o servicios?';
  }
}
