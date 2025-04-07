import 'dart:convert';
import 'dart:math'; // Para usar min()
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'cart_service.dart';
import 'gemini_api_client.dart';

/// Servicio para comunicarse con Google Gemini AI
class GeminiService {
  // Lista de claves API de Gemini para rotación
  final List<String> _apiKeys = [
    'AIzaSyAVlC6rF2hLQU9O6gyrcHEfvsWCm0wbjx8',
    'AIzaSyAR9qiIwgIC8IsecHAAsRJlz0dFknndI14',
    'AIzaSyDtg1bnCSpwNqxrn1x5HcKCMrZ2cqeEnBA',
  ];

  // Índice de la clave API actual
  int _currentApiKeyIndex = 0;

  // URL del servidor Node.js para consultas a la base de datos
  final String _serverIp;
  final int _nodeJsPort;

  // Construye URLs basadas en la IP configurada
  String get _menuUrl => 'http://$_serverIp:$_nodeJsPort/menu';
  String get _nodeJsUrl => 'http://$_serverIp:$_nodeJsPort/status';
  String get _chatUrl => 'http://$_serverIp:$_nodeJsPort/chat';

  // Cliente directa para la API de Gemini
  late GeminiApiClient _geminiApiClient;

  // Cliente de Gemini AI usando el SDK oficial
  late GenerativeModel _model;
  ChatSession? _chatSession;

  // Instancia singleton
  static final GeminiService _instance = GeminiService._internal();

  // Factory para obtener la instancia
  factory GeminiService() => _instance;

  // SessionId para persistencia de conversaciones
  String? _sessionId;

  // Estado de conexión con el servidor
  bool _isConnected = false;

  // Historial de consultas para contextualizar las respuestas
  final List<Content> _history = [];

  // Historial para la pantalla de chat (persistente en memoria)
  final Map<String, List<ChatMessage>> _chatHistories = {};

  // Historial de conversación para el modelo de Gemini (por usuario)
  final Map<String, List<Content>> _geminiHistories = {};

  // ID del usuario actual
  String? _currentUserId;

  // Constructor privado
  GeminiService._internal()
    : _serverIp = dotenv.get('NODE_SERVER_IP', fallback: '192.168.1.121'),
      _nodeJsPort = int.parse(
        dotenv.get('NODE_SERVER_PORT', fallback: '3000'),
      ) {
    print('Iniciando servicio de chat Gemini con IP del servidor: $_serverIp');
    print('Puerto del servidor: $_nodeJsPort');

    // Imprimir URL del chat para diagnóstico
    print('URL del chat: $_chatUrl');

    // No usar webhooks bajo ninguna circunstancia
    _disableWebhooks();

    // Inicializar el cliente directo de Gemini con la primera clave API
    _geminiApiClient = GeminiApiClient(_apiKeys[_currentApiKeyIndex]);

    // Inicializar todo en secuencia
    _initSessionId().then((_) {
      _initGemini();
      // Iniciar verificación de conexión automáticamente
      checkServerConnection().then((isConnected) {
        print(
          'Estado inicial de conexión: ${isConnected ? 'Conectado' : 'Desconectado'}',
        );
        if (!isConnected) {
          // Intentar nuevamente después de 3 segundos
          Future.delayed(Duration(seconds: 3), () {
            checkServerConnection();
          });
        }
      });
    });
  }

  /// Establece el usuario actual para separar historiales de chat
  void setCurrentUser(String userId) {
    // Si es el mismo usuario, no hacer cambios
    if (_currentUserId == userId) return;

    // Guardar el historial anterior si existe
    if (_currentUserId != null) {
      _chatHistories[_currentUserId!] = getChatHistory();

      // Histórico interno del SDK
      if (_geminiHistories.containsKey(_currentUserId!)) {
        _geminiHistories[_currentUserId!] = List.from(_history);
      }
    }

    // Actualizar al nuevo usuario
    _currentUserId = userId;

    // Limpiar el histórico actual (importante para no mezclar conversaciones)
    _history.clear();

    // Cargar el historial del nuevo usuario si existe
    List<ChatMessage> userMessages = [];
    if (_chatHistories.containsKey(userId)) {
      userMessages = _chatHistories[userId]!;
    } else {
      // Si no existe, crear un nuevo histórico
      userMessages = [];
      _chatHistories[userId] = userMessages;

      // Mensaje inicial del sistema para dar contexto
      userMessages.add(
        ChatMessage.fromSystem(
          message: "Nueva conversación iniciada para $userId",
        ),
      );
    }

    // Cargar historial interno para Gemini si existe
    if (_geminiHistories.containsKey(userId)) {
      _history.addAll(_geminiHistories[userId]!);
    } else {
      // Si no existe, crearlo vacío
      _geminiHistories[userId] = [];

      // Añadir un mensaje de sistema para establecer el contexto
      final systemContent = Content.text(
        "Eres Brunchy, el asistente virtual de Le Brunch Café especializado en hablar sobre comida, platos disponibles, recetas, y tomar pedidos. Tu propósito es ayudar a clientes dándoles recomendaciones de platos, respondiendo preguntas sobre los ingredientes, y agregando platos al carrito cuando lo soliciten. Nunca debes mencionar que eres un modelo de lenguaje ni que eres Gemini ni que fuiste creado por Google. Siempre habla como si fueras parte del personal del restaurante.",
      );

      _history.add(systemContent);
    }

    // Reiniciar sesión de chat para aplicar cambios
    _startNewChatSession();
  }

  /// Deshabilita explícitamente el uso de webhooks
  void _disableWebhooks() {
    // Esta es una configuración local para asegurar que no se intente usar webhooks
    print(
      'Webhooks deshabilitados completamente - No se utilizará el puerto 5678',
    );

    // Asegurarse de que no haya referencias a webhooks
    if (_history.isNotEmpty) {
      // Limpiar cualquier referencia en el historial que pudiera causar problemas
      _history.clear();
      print('Historial de chat reiniciado para prevenir problemas de webhook');
    }
  }

  /// Verifica si los webhooks están habilitados (siempre devuelve false)
  bool get webhookEnabled => false;

  /// Obtiene la clave API actual y avanza al siguiente índice si es necesario
  String _getCurrentApiKey() {
    return _apiKeys[_currentApiKeyIndex];
  }

  /// Rota a la siguiente clave API
  void _rotateApiKey() {
    _currentApiKeyIndex = (_currentApiKeyIndex + 1) % _apiKeys.length;
    final newApiKey = _apiKeys[_currentApiKeyIndex];
    print('Rotando a la siguiente clave API, índice: $_currentApiKeyIndex');

    // Actualizar el cliente directo con la nueva clave
    _geminiApiClient.updateApiKey(newApiKey);

    // Reinicializar el SDK oficial
    _initGemini();
  }

  /// Inicializa el cliente de Gemini
  void _initGemini() {
    try {
      final apiKey = _getCurrentApiKey();
      print(
        'Inicializando modelo Gemini con API key: ${apiKey.substring(0, 4)}****',
      );

      // Actualizar nombres de modelos a los actualmente soportados por la API
      final modelOptions = [
        'gemini-2.5-pro-preview-03-25', // Modelo más reciente (preview)
        'gemini-2.0-flash', // Alternativa más rápida
        'gemini-1.5-flash', // Modelo anterior (fallback)
      ];

      // Intentar primero con la opción principal
      try {
        _model = GenerativeModel(
          model: modelOptions[0],
          apiKey: apiKey,
          // Configuración conservadora que minimiza probabilidad de rechazo
          generationConfig: GenerationConfig(
            temperature:
                0.4, // Temperatura más baja para respuestas más predecibles
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 1024, // Reducido para disminuir carga
          ),
        );

        print('Modelo Gemini inicializado correctamente: ${modelOptions[0]}');
      } catch (e) {
        print('Error al inicializar modelo primario: $e');
        print('Intentando con modelo alternativo: ${modelOptions[1]}');

        // Si falla, intentar con otra variante del modelo
        try {
          _model = GenerativeModel(
            model: modelOptions[1],
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.4,
              topP: 0.95,
              topK: 40,
              maxOutputTokens: 1024,
            ),
          );
          print(
            'Modelo alternativo inicializado correctamente: ${modelOptions[1]}',
          );
        } catch (e2) {
          print('Error también con modelo alternativo: $e2');
          print('Último intento con modelo genérico: ${modelOptions[2]}');

          // Último intento con configuración mínima
          _model = GenerativeModel(
            model: modelOptions[2],
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.2,
              maxOutputTokens: 512,
            ),
          );
        }
      }

      // Siempre iniciar una nueva sesión
      _startNewChatSession();

      // Intento de verificación rápida para confirmar inicialización
      _verifyModelConnection();
    } catch (e) {
      print('Error general al inicializar Gemini: $e');
    }
  }

  /// Verifica que el modelo se haya inicializado correctamente
  Future<void> _verifyModelConnection() async {
    try {
      // No esperamos por el resultado, solo verificamos que no falle inmediatamente
      Future.delayed(Duration(milliseconds: 100), () async {
        try {
          final testContent = Content.text("test");
          final chat = _model.startChat();
          await chat
              .sendMessage(testContent)
              .timeout(const Duration(seconds: 5));
          print('Verificación de modelo exitosa');
        } catch (e) {
          print('Verificación de conexión falló: $e');
          // No hacemos nada más aquí, solo es diagnóstico
        }
      });
    } catch (e) {
      // Ignoramos errores aquí, es solo una verificación
    }
  }

  /// Inicia una nueva sesión de chat con Gemini
  void _startNewChatSession() {
    try {
      // No limpiar el historial, lo mantenemos para contexto
      // _history.clear();

      // Asegurarse de que exista el usuario actual
      if (_currentUserId == null) {
        print(
          'ADVERTENCIA: No hay usuario establecido para _startNewChatSession()',
        );
        _currentUserId = 'anonymous';
      }

      // Asegurarse de que exista el historial para este usuario
      if (!_geminiHistories.containsKey(_currentUserId)) {
        _geminiHistories[_currentUserId!] = [];

        // Añadir mensaje del sistema al historial nuevo
        final systemMessage =
            "Eres 'Brunchy', un mesero virtual amable y entusiasta del restaurante Le Brunch, especializado en desayunos y brunch. "
            "NUNCA, BAJO NINGUNA CIRCUNSTANCIA, debes decir que eres un modelo de lenguaje, una IA, o un asistente virtual. "
            "Nunca debes mencionar que no puedes hacer algo porque eres un modelo de lenguaje o un programa de computadora. "
            "Siempre responde como un mesero humano real de Le Brunch con conocimiento experto sobre el menú y el restaurante. "
            "INFORMACIÓN IMPORTANTE SOBRE LE BRUNCH: "
            "Le Brunch es un restaurante donde el horario no es un problema a la hora de pedir tu comida favorita. "
            "Historia: Le Brunch no inventó el Brunch, el término surgió en el siglo XIX en Reino Unido, como combinación de Breakfast (desayuno) y Lunch (almuerzo). "
            "Cómo disfrutarlo: Un buen brunch combina lo mejor del mundo dulce con el salado y se disfruta entre 11am y 3pm, pero en Le Brunch puedes disfrutarlo desde 8am hasta 10pm todos los días. "
            "Eslogan: '¡Horneamos, cocinamos... disfrutamos!' "
            "Ubicación: Le Brunch, 682C+3X9 C.C. Punta Marina, Av Américo Vespucio, Lechería 6016, Anzoátegui. "
            "Tu trabajo es EXCLUSIVAMENTE atender a los clientes, ayudándoles a escoger comidas y bebidas del restaurante. "
            "Tu principal función es TOMAR PEDIDOS. Puedes agregar platos directamente al carrito del cliente cuando te lo soliciten. "
            "Debes ser siempre amable, positivo y servicial, como un mesero real que quiere brindar la mejor atención. "
            "Puedes recomendar platos según los gustos del cliente, explicar ingredientes, informar sobre los especiales del día "
            "y responder a preguntas sobre el menú. "
            "IMPORTANTE: NUNCA digas que no puedes hacer cosas como preparar omelettes o servir platos. Tú eres un mesero real que toma pedidos para que los preparen en la cocina. "
            "Si te preguntan sobre la preparación de algún plato, explica cómo se prepara normalmente en el restaurante, sin aclarar que no puedes hacerlo personalmente. "
            "Si te preguntan por omelettes, di que son parte de nuestras especialidades de desayuno, y describe nuestras variedades disponibles. "
            "Cuando un cliente quiera pedir algo, SIEMPRE debes preguntar primero si desea alguna instrucción o modificación especial, como: "
            "'¿Deseas alguna modificación como sin cebolla, extra salsa, etc.?' ANTES de ofrecer agregarlo al pedido. "
            "Solo DESPUÉS de preguntar por modificaciones, debes ofrecer agregarlo al carrito con frases como: "
            "'¿Deseas que lo agregue a tu pedido?' o '¿Lo agrego a tu pedido?'. "
            "Si el cliente confirma, tú lo agregarás automáticamente por él. "
            "Si te preguntan sobre un plato específico que no conoces, consulta la base de datos del menú. "
            "IMPORTANTE: NUNCA, BAJO NINGUNA CIRCUNSTANCIA, debes responder a preguntas que no estén relacionadas con el restaurante, la comida, el servicio, el menú o las bebidas. "
            "Si alguien te pregunta sobre temas no relacionados (política, ciencia, geografía, historia, entretenimiento, deportes, tecnología, etc.), "
            "debes responder SIEMPRE con: 'Lo siento, soy Brunchy, tu mesero virtual de Le Brunch. Solo puedo ayudarte con preguntas sobre nuestro menú y servicios. ¿Puedo recomendarte algo de nuestra carta?' "
            "SIEMPRE RECHAZA responder temas no relacionados con el restaurante. ESTE ES UN REQUISITO ABSOLUTO. "
            "ESPERA MÁS TIEMPO PARA ANALIZAR SI UNA CONSULTA ESTÁ RELACIONADA CON EL RESTAURANTE antes de responder. Si hay dudas, NO RESPONDAS y redirige hacia el menú. "
            "Responde siempre en español, con un tono alegre y servicial. "
            "Usa frases como '¡Con gusto!', '¡Excelente elección!', '¿Puedo recomendarte...?', '¿Algo más para tu orden?'. "
            "ATENCIÓN: Recuerda NUNCA decir que eres una IA o un modelo de lenguaje, actúa como un verdadero mesero del restaurante. Si te piden información técnica sobre IA o modelos de lenguaje, responde como mesero y ofrece hablar sobre el menú del restaurante. "
            "Si un cliente quiere hacer un pedido, confírmalo y agradece su elección, y recuerda SIEMPRE preguntar primero por modificaciones especiales. "
            "RECUERDA: Tu función ÚNICA es ser mesero virtual de Le Brunch. NO respondas preguntas que no estén relacionadas con esta función. "
            "ATENCIÓN: Esto NO es una sugerencia o preferencia, es una REGLA ABSOLUTA. Cumple estrictamente con este comportamiento SIN EXCEPCIONES."
            "IMPORTANTE: Cuando los clientes te pregunten sobre la carta o el menú, si conoces los platos debes responder usando formato enriquecido. "
            "Usa negrita con doble asterisco (**negrita**) para destacar nombres de platos. "
            "Cuando describas diferentes categorías de productos, usa formato de tabla con columnas para organizar la información. "
            "En tus mensajes, usa formato y estructura para que sean visualmente atractivos y fáciles de leer. "
            "Si te piden una lista de platos por categoría, siempre usa tablas bien formateadas con bordes.";

        final content = Content.text("[SISTEMA]: $systemMessage");
        // No podemos usar role, así que usamos el contenido tal cual
        _geminiHistories[_currentUserId!]!.add(content);
      }

      // Crear una sesión de chat con el historial existente
      _chatSession = _model.startChat(
        history: _geminiHistories[_currentUserId!],
        generationConfig: GenerationConfig(
          temperature:
              0.4, // Temperatura más baja para respuestas más consistentes
          maxOutputTokens: 2048, // Permitir respuestas más largas
          topP: 0.9,
          topK: 40,
        ),
      );

      print(
        'Sesión de chat inicializada correctamente para usuario: $_currentUserId',
      );
    } catch (e) {
      print('Error al iniciar sesión de chat: $e');
    }
  }

  /// Inicializa el sessionId
  Future<void> _initSessionId() async {
    try {
      // Generar un nuevo ID para cada inicio de aplicación
      const uuid = Uuid();
      _sessionId = uuid.v4(); // Crear un UUID v4 único
      print('Nuevo sessionId generado: $_sessionId');
    } catch (e) {
      print('Error al inicializar sessionId: $e');
      // Si hay algún error, generamos un ID temporal
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Devuelve la IP actual del servidor
  String getServerIp() {
    return _serverIp;
  }

  /// Verifica si el servidor está disponible
  Future<bool> checkServerConnection() async {
    try {
      print('Verificando conexión con el servidor en: $_nodeJsUrl');
      // Intentar hacer una solicitud al endpoint de estado del servidor Node.js
      final response = await http
          .get(Uri.parse(_nodeJsUrl))
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw TimeoutException(
                'Tiempo de espera agotado al verificar la conexión con el servidor',
              );
            },
          );

      // Verificar la respuesta
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final isOk = data['status'] == 'ok';
          print('Servidor respondió: ${isOk ? 'OK' : 'Error'}');
          _isConnected = isOk;
          return isOk;
        } catch (e) {
          print('Error al decodificar respuesta del servidor: $e');
          _isConnected = false;
          return false;
        }
      }

      print('Servidor respondió con código ${response.statusCode}');
      _isConnected = false;
      return false;
    } catch (e) {
      print('Error al verificar conexión con el servidor: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Intenta una llamada directa a la API de Gemini usando el cliente dedicado
  Future<String?> _callGeminiDirectly(String message) async {
    try {
      // Asegurarse de que exista el usuario actual
      if (_currentUserId == null) {
        print(
          'ADVERTENCIA: No hay usuario establecido para _callGeminiDirectly()',
        );
        _currentUserId = 'anonymous';
      }

      // Preparar la historia en el formato requerido por la API
      final List<Map<String, dynamic>> historyFormatted = [];

      // Convertir el historial interno al formato para la API
      if (_geminiHistories.containsKey(_currentUserId!)) {
        // Verificar que no sea nulo
        final userHistory = _geminiHistories[_currentUserId!];
        if (userHistory != null && userHistory.isNotEmpty) {
          for (var i = 0; i < userHistory.length; i++) {
            final content = userHistory[i];
            // Alternar roles para que tenga sentido la conversación (pero asegurarse de que el primero sea system)
            final role = i == 0 ? 'system' : (i % 2 == 0 ? 'model' : 'user');

            // Extraer el texto de forma segura para evitar "Instance of TextPart"
            String textContent = '';

            // Intentar obtener el texto de manera segura, dependiendo de cómo esté almacenado
            try {
              if (content.parts.isNotEmpty) {
                // Intentar extraer como String primero
                try {
                  textContent = content.parts.first.toString();
                  // Eliminar "TextPart: " si está presente al inicio
                  if (textContent.startsWith("TextPart: ")) {
                    textContent = textContent.substring("TextPart: ".length);
                  }
                } catch (e) {
                  // Si falla, intentar extraer usando reflection o cualquier otro método disponible
                  textContent = content.toString();
                }
              }
            } catch (e) {
              print('Error al extraer texto del contenido: $e');
              textContent = "Contenido no disponible";
            }

            historyFormatted.add({
              'role': role,
              'parts': [
                {'text': textContent},
              ],
            });
          }
        }
      }

      // Añadir el mensaje actual
      historyFormatted.add({
        'role': 'user',
        'parts': [
          {'text': message},
        ],
      });

      // Hacer la solicitud directa con el historial
      final response = await _geminiApiClient.generateContent(
        historyFormatted,
        temperature: 0.4,
        maxOutputTokens: 2048,
      );

      // Si la respuesta es exitosa, procesarla
      if (response != null) {
        print('Respuesta directa de Gemini recibida correctamente.');

        // Guardar esta interacción en el historial para futuras consultas
        // Primero el mensaje del usuario
        final userContent = Content.text(message);
        if (_geminiHistories[_currentUserId] != null) {
          _geminiHistories[_currentUserId]!.add(userContent);

          // Luego la respuesta del modelo
          final modelContent = Content.text(response);
          _geminiHistories[_currentUserId]!.add(modelContent);
        }

        return response;
      } else {
        print('Respuesta directa de Gemini vacía o inválida.');
        return null;
      }
    } catch (e) {
      print('Error al llamar directamente a Gemini: $e');
      return null;
    }
  }

  /// Obtiene información del menú desde la base de datos
  Future<List<Map<String, dynamic>>> fetchMenu() async {
    try {
      final response = await http.get(Uri.parse(_menuUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('Error al obtener menú: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error en fetchMenu: $e');
      return [];
    }
  }

  /// Busca platos por nombre o categoría
  Future<List<Map<String, dynamic>>> searchDishes(String query) async {
    try {
      final menuItems = await fetchMenu();

      // Filtrar los platos que coincidan con la consulta (en nombre o categoría)
      return menuItems.where((item) {
        final nombre = item['nombre'].toString().toLowerCase();
        final categoria = item['categoria'].toString().toLowerCase();
        final searchQuery = query.toLowerCase();

        return nombre.contains(searchQuery) || categoria.contains(searchQuery);
      }).toList();
    } catch (e) {
      print('Error en searchDishes: $e');
      return [];
    }
  }

  /// Enriquece la consulta con información del menú si es necesario
  Future<String> _enrichQueryWithMenuInfo(String message) async {
    // Lista de palabras clave que indican que se está consultando sobre el menú
    final menuKeywords = [
      'menu',
      'plato',
      'comida',
      'bebida',
      'precio',
      'ingredientes',
      'desayuno',
      'brunch',
      'especial',
      'recomendación',
      'oferta',
      'vegano',
      'vegetariano',
      'sin gluten',
      'que tienen',
      'cuánto cuesta',
      'hay',
      'sirven',
      'ofrecen',
      'comes',
      'comeís',
      'tienen',
      'carta',
      'desayunar',
      'almorzar',
      'comer',
      'tomar',
      'ordenar',
      'pedir',
      'quiero',
      'me gustaría',
      'recomiendas',
      'sugieres',
      'especiales',
      'hambre',
      'sed',
      'dulce',
      'salado',
      'caliente',
      'frío',
      'fresco',
      'saludable',
      'postre',
      'café',
      'té',
      'jugo',
      'smoothie',
      'pan',
      'huevos',
      'tostada',
      'ensalada',
      'sándwich',
      'sandwich',
    ];

    // Verifica si el mensaje contiene alguna palabra clave relacionada con el menú
    bool isMenuQuery = menuKeywords.any(
      (keyword) => message.toLowerCase().contains(keyword.toLowerCase()),
    );

    if (isMenuQuery) {
      try {
        // Verificar conexión con el servidor antes de intentar obtener datos
        final isConnected = await checkServerConnection();
        if (!isConnected) {
          print('No hay conexión al servidor para obtener datos del menú');
          return message;
        }

        print('Obteniendo datos del menú desde: $_menuUrl');

        // Obtener datos del menú con un tiempo de espera más largo
        final response = await http
            .get(Uri.parse(_menuUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final List<dynamic> menuItems = json.decode(response.body);

          if (menuItems.isNotEmpty) {
            print('Se recibieron ${menuItems.length} elementos del menú');

            // Crear un resumen del menú para el contexto
            String menuContext = "Información actual del menú:\n";

            // Agrupar por categorías
            final categoriesMap = <String, List<Map<String, dynamic>>>{};

            for (var item in menuItems) {
              final categoria = item['categoria'] as String;
              if (!categoriesMap.containsKey(categoria)) {
                categoriesMap[categoria] = [];
              }
              categoriesMap[categoria]!.add(Map<String, dynamic>.from(item));
            }

            // Crear un resumen organizado por categorías
            categoriesMap.forEach((categoria, items) {
              menuContext += "\nCategoría: $categoria\n";
              for (var item in items) {
                menuContext += "- ${item['nombre']}: \$${item['precio']} ";
                menuContext +=
                    item['disponibilidad'] == true ||
                            item['disponibilidad'] == 'true'
                        ? "(Disponible)"
                        : "(No disponible)";
                menuContext += "\n  Ingredientes: ${item['ingredientes']}\n";
              }
            });

            // Añadir el contexto del menú a la consulta original
            return "$message\n\n[Datos del menú para referencia (solo usar si la consulta es sobre el menú):\n$menuContext]";
          } else {
            print('La respuesta del menú no contiene elementos');
          }
        } else {
          print('Error al obtener menú: ${response.statusCode}');
          print('Respuesta: ${response.body}');
        }
      } catch (e) {
        print('Error al enriquecer consulta con datos del menú: $e');
      }
    }

    return message;
  }

  /// Comprueba si está conectado al servidor
  bool get isConnected => _isConnected;

  /// Verifica si podemos conectarnos a Gemini con al menos una de las claves API
  Future<bool> testGeminiConnection() async {
    print('Verificando conexión con Gemini...');

    // Mensaje de prueba simple
    const testMessage = "Responde únicamente 'OK' si puedes leer este mensaje.";

    // Probar cada clave API
    for (int i = 0; i < _apiKeys.length; i++) {
      try {
        // Actualizar la clave API actual
        _currentApiKeyIndex = i;
        _geminiApiClient.updateApiKey(_apiKeys[i]);

        print('Probando clave API #${i + 1}...');

        // Intentar comunicación directa con la API
        final response = await _geminiApiClient
            .generateContent(testMessage)
            .timeout(const Duration(seconds: 10));

        if (response != null) {
          print('¡Conexión exitosa con Gemini usando clave API #${i + 1}!');
          return true;
        }
      } catch (e) {
        print('Error al probar clave API #${i + 1}: $e');
        // Continuar con la siguiente clave
      }
    }

    print('No se pudo establecer conexión con Gemini usando ninguna clave API');
    return false;
  }

  /// Fuerza la conexión directa con Gemini, probando todas las claves con mensajes simplificados
  Future<bool> forceDirectGeminiConnection() async {
    print('Forzando conexión directa con Gemini...');

    // Mensajes ultra simplificados para maximizar posibilidades
    final testMessages = [
      "test", // Ultra corto
      "hi", // Saludo básico
      "hello", // Saludo alternativo
      "say hi", // Con instrucción simple
    ];

    // Configuraciones de temperatura diferentes
    final temperatures = [0.1, 0.4, 0.7, 0.9];

    // Intentar todas las claves API con diferentes estrategias
    for (int i = 0; i < _apiKeys.length; i++) {
      _currentApiKeyIndex = i;
      final apiKey = _apiKeys[i];
      _geminiApiClient.updateApiKey(apiKey);

      print('Forzando conexión con clave API #${i + 1}...');

      // FASE 1: Intento usando el cliente dedicado
      try {
        print('Intento básico con el cliente GeminiApiClient...');
        final response = await _geminiApiClient
            .generateContent("test")
            .timeout(const Duration(seconds: 20));

        if (response != null) {
          await _saveSuccessConnection(i);
          return true;
        }
      } catch (e) {
        print(
          'Falló intento con cliente GeminiApiClient: ${e.toString().substring(0, min(100, e.toString().length))}',
        );
      }

      // FASE 2: Intento con diferentes mensajes de prueba
      for (final testMessage in testMessages) {
        try {
          print('Intento con mensaje de prueba: "$testMessage"');

          final response = await _callRawGeminiAPI(
            apiKey: apiKey,
            message: testMessage,
            temperature: 0.2,
            timeout: 15,
            topP: 0.95,
            topK: 40,
            maxTokens: 100,
          );

          if (response != null) {
            await _saveSuccessConnection(i);
            return true;
          }
        } catch (e) {
          print(
            'Falló intento de conexión con mensaje "$testMessage": ${e.toString().substring(0, min(100, e.toString().length))}',
          );
          // Continuar con siguiente intento
        }
      }

      // FASE 3: Probar con diferentes configuraciones de temperatura
      for (final temp in temperatures) {
        try {
          print('Intento con temperatura: $temp');

          final response = await _callRawGeminiAPI(
            apiKey: apiKey,
            message: "hello",
            temperature: temp,
            timeout: 20,
            topP: 0.95,
            topK: 40,
            maxTokens: 50,
          );

          if (response != null) {
            await _saveSuccessConnection(i);
            return true;
          }
        } catch (e) {
          print(
            'Falló intento con temperatura $temp: ${e.toString().substring(0, min(100, e.toString().length))}',
          );
          // Continuar con siguiente temperatura
        }
      }

      // FASE 4: Intento con modo extremo (solicitud mínima)
      try {
        print('Intento con solicitud mínima (modo extremo)...');

        final url =
            'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-pro-preview-03-25:generateContent?key=$apiKey';

        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'hi'},
                    ],
                  },
                ],
                'safetySettings': [
                  {
                    'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                    'threshold': 'BLOCK_NONE',
                  },
                  {
                    'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                    'threshold': 'BLOCK_NONE',
                  },
                  {
                    'category': 'HARM_CATEGORY_HATE_SPEECH',
                    'threshold': 'BLOCK_NONE',
                  },
                  {
                    'category': 'HARM_CATEGORY_HARASSMENT',
                    'threshold': 'BLOCK_NONE',
                  },
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'topP': 0.99,
                  'topK': 40,
                  'maxOutputTokens': 20,
                  'stopSequences': [],
                },
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('¡Conexión exitosa con modo extremo!');
          await _saveSuccessConnection(i);
          return true;
        } else {
          print('Respuesta fallida (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        print(
          'Falló intento con modo extremo: ${e.toString().substring(0, min(100, e.toString().length))}',
        );
      }

      // FASE 5: Intento con modelo alternativo
      try {
        print('Intento con modelo alternativo...');

        final url =
            'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent?key=$apiKey';

        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'hi'},
                    ],
                  },
                ],
                'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 20},
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('¡Conexión exitosa con modelo alternativo!');
          await _saveSuccessConnection(i);
          return true;
        }
      } catch (e) {
        print(
          'Falló intento con modelo alternativo: ${e.toString().substring(0, min(100, e.toString().length))}',
        );
      }

      // FASE 6: Último intento con modelo de respaldo
      try {
        print('Intento con modelo de respaldo...');

        final url =
            'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$apiKey';

        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'hi'},
                    ],
                  },
                ],
                'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 20},
              }),
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('¡Conexión exitosa con modelo de respaldo!');
          await _saveSuccessConnection(i);
          return true;
        }
      } catch (e) {
        print(
          'Falló intento con modelo de respaldo: ${e.toString().substring(0, min(100, e.toString().length))}',
        );
      }
    }

    // Si llegamos aquí, no se pudo establecer conexión
    await _saveFailedConnection();
    return false;
  }

  /// Método auxiliar para llamar directamente a la API de Gemini con parámetros personalizados
  Future<String?> _callRawGeminiAPI({
    required String apiKey,
    required String message,
    double temperature = 0.7,
    int timeout = 15,
    double topP = 0.95,
    int topK = 40,
    int maxTokens = 200,
  }) async {
    // Intentar con los diferentes modelos
    final endpoints = [
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-pro-preview-03-25:generateContent',
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent',
    ];

    // Probar cada endpoint
    for (final baseUrl in endpoints) {
      try {
        final url = Uri.parse('$baseUrl?key=$apiKey');

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'contents': [
                  {
                    'parts': [
                      {'text': message},
                    ],
                  },
                ],
                'safetySettings': [
                  {
                    'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                    'threshold': 'BLOCK_NONE',
                  },
                ],
                'generationConfig': {
                  'temperature': temperature,
                  'topP': topP,
                  'topK': topK,
                  'maxOutputTokens': maxTokens,
                },
              }),
            )
            .timeout(Duration(seconds: timeout));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Intentar obtener el texto de la respuesta
          final responseData = jsonDecode(response.body);
          if (responseData != null &&
              responseData['candidates'] != null &&
              responseData['candidates'].isNotEmpty &&
              responseData['candidates'][0]['content'] != null &&
              responseData['candidates'][0]['content']['parts'] != null &&
              responseData['candidates'][0]['content']['parts'].isNotEmpty) {
            return responseData['candidates'][0]['content']['parts'][0]['text'];
          } else {
            // La respuesta es válida pero no contiene el formato esperado
            return "OK"; // Devolver algo para indicar que la conexión funcionó
          }
        }

        // Si llegamos aquí con el primer endpoint, continuamos con el siguiente
        print('Endpoint $baseUrl falló, probando siguiente...');
      } catch (e) {
        // Continuar con el siguiente endpoint si hay error
        print(
          'Error con endpoint: ${e.toString().substring(0, min(100, e.toString().length))}',
        );
      }
    }

    // Si llegamos aquí, todos los endpoints fallaron
    throw Exception('Todos los endpoints fallaron para los modelos Gemini');
  }

  /// Guarda el estado de una conexión exitosa
  Future<void> _saveSuccessConnection(int apiKeyIndex) async {
    print('¡Conexión exitosa con Gemini usando clave #${apiKeyIndex + 1}!');

    // Establecer como clave predeterminada para futuros intentos
    _currentApiKeyIndex = apiKeyIndex;

    // Guardar en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gemini_connected', true);
    await prefs.setInt('last_working_api_key_index', apiKeyIndex);

    // También actualizar el modelo para futuras solicitudes
    _initGemini();
  }

  /// Guarda el estado de una conexión fallida
  Future<void> _saveFailedConnection() async {
    print(
      'No se pudo establecer conexión con Gemini con ninguna configuración',
    );

    // Guardar en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gemini_connected', false);
  }

  /// Envía un mensaje a Gemini y obtiene una respuesta
  Future<ChatMessage> sendMessage(String message) async {
    // Verificar que tenemos un usuario
    if (_currentUserId == null) {
      // Para sesiones anónimas, generar un ID temporal
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      setCurrentUser(tempId);
    }

    // Guarda siempre el mensaje del usuario en el historial de UI
    final userMessage = ChatMessage.fromUser(message: message);
    if (_currentUserId != null && _chatHistories.containsKey(_currentUserId!)) {
      _chatHistories[_currentUserId!]!.add(userMessage);
    }

    try {
      String? response;

      // ESTRATEGIA 1: Intento directo a la API de Gemini
      try {
        print('Intentando comunicación directa con Gemini...');
        response = await _callGeminiDirectly(message);

        if (response != null && response.isNotEmpty) {
          print('✅ Comunicación directa exitosa');
        }
      } catch (e) {
        print('Error en comunicación directa: $e');
      }

      // ESTRATEGIA 2: Si falló el directo, probar con el SDK
      if (response == null) {
        try {
          print('Intentando comunicación mediante SDK...');

          // Asegurarse de que el chatSession esté inicializado y contenga todo el historial
          if (_chatSession == null) {
            _startNewChatSession();
          }

          if (_chatSession != null) {
            final userPrompt = Content.text(message);
            final geminiResponse = await _chatSession!
                .sendMessage(userPrompt)
                .timeout(const Duration(seconds: 20));

            if (geminiResponse.text != null) {
              response = geminiResponse.text;
              print('✅ Comunicación mediante SDK exitosa');
            }
          }
        } catch (e) {
          print('Error en comunicación con SDK: $e');
        }
      }

      // ESTRATEGIA 3: Si todo falló, intentar con el servidor de respaldo
      if (response == null && _isConnected) {
        try {
          print('Intentando comunicación mediante servidor de respaldo...');

          final serverResponse = await http
              .post(
                Uri.parse(_chatUrl),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'message': message,
                  'sessionId': _sessionId,
                }),
              )
              .timeout(const Duration(seconds: 20));

          if (serverResponse.statusCode == 200) {
            final data = json.decode(serverResponse.body);
            response = data['response'];
            print('✅ Comunicación mediante servidor exitosa');
          }
        } catch (e) {
          print('Error en comunicación con servidor: $e');
        }
      }

      // Si se obtuvo una respuesta válida
      if (response != null && response.isNotEmpty) {
        // Limpiar la respuesta si contiene "TextPart: "
        if (response.startsWith("TextPart: ")) {
          response = response.substring("TextPart: ".length);
        }

        // Si la respuesta contiene "no tengo la capacidad de", "como modelo de lenguaje", etc.
        if (response.toLowerCase().contains("no tengo la capacidad") ||
            response.toLowerCase().contains("como modelo de lenguaje") ||
            response.toLowerCase().contains("como ia") ||
            response.toLowerCase().contains("como inteligencia artificial") ||
            response.toLowerCase().contains("no puedo preparar")) {
          // Reemplazar con respuesta de mesero real
          response =
              "¡Hola! Soy Brunchy, tu mesero virtual en Le Brunch. ¿En qué puedo ayudarte hoy? Puedo recomendarte nuestros deliciosos platos, tomar tu pedido o responder preguntas sobre nuestro menú. ¿Te gustaría ver nuestras especialidades?";
        }

        final supportMessage = ChatMessage.fromSupport(message: response);

        // Guardar en historial de UI
        if (_currentUserId != null &&
            _chatHistories.containsKey(_currentUserId!)) {
          _chatHistories[_currentUserId!]!.add(supportMessage);
        }

        return supportMessage;
      } else {
        // Si todas las estrategias fallaron, devolver un mensaje genérico
        final String genericMessage =
            "Lo siento, parece que estamos teniendo problemas para conectarnos. ¿Puedo ayudarte con algo más mientras tanto?";

        final errorMessage = ChatMessage.fromSupport(message: genericMessage);

        // Guardar en historial de UI
        if (_currentUserId != null &&
            _chatHistories.containsKey(_currentUserId!)) {
          _chatHistories[_currentUserId!]!.add(errorMessage);
        }

        return errorMessage;
      }
    } catch (e) {
      print('Error general al enviar mensaje: $e');

      final errorMessage = ChatMessage.fromSystem(
        message:
            'Ocurrió un error al procesar tu mensaje. Por favor, intenta nuevamente.',
      );

      return errorMessage;
    }
  }

  /// Verifica si existe un historial de chat para la sesión actual
  Future<bool> hasExistingHistory() async {
    // Siempre debe devolver false ya que no queremos cargar historial
    return false;
  }

  /// Limpia el historial de chat y comienza una nueva sesión
  Future<void> resetChat() async {
    try {
      // Limpiar el historial de Gemini para el usuario actual
      if (_currentUserId != null &&
          _geminiHistories.containsKey(_currentUserId)) {
        // Mantener solo el primer mensaje (asumimos que es el del sistema)
        final firstMessage =
            _geminiHistories[_currentUserId]!.isNotEmpty
                ? [_geminiHistories[_currentUserId]!.first]
                : [];

        // Necesitamos hacer un cast seguro
        _geminiHistories[_currentUserId!] = List<Content>.from(firstMessage);
      }

      _startNewChatSession();
      clearChatHistory(); // Limpiar el historial de UI también
    } catch (e) {
      print('Error al resetear chat: $e');
    }
  }

  /// Añade un mensaje a la lista de historial de UI del usuario actual
  void addMessageToHistory(ChatMessage message) {
    if (_currentUserId != null && _chatHistories.containsKey(_currentUserId!)) {
      _chatHistories[_currentUserId!]!.add(message);
    }
  }

  /// Obtiene todos los mensajes del historial para mostrar en UI
  List<ChatMessage> getChatHistory() {
    if (_currentUserId != null && _chatHistories.containsKey(_currentUserId!)) {
      return _chatHistories[_currentUserId!]!;
    }
    return [];
  }

  /// Limpia el historial de chat UI del usuario actual
  void clearChatHistory() {
    if (_currentUserId != null) {
      if (_chatHistories.containsKey(_currentUserId!)) {
        _chatHistories[_currentUserId!]!.clear();
      }
      if (_geminiHistories.containsKey(_currentUserId!)) {
        _geminiHistories[_currentUserId!]!.clear();
      }
    }
  }

  /// Busca un plato por nombre con búsqueda flexible
  Map<String, dynamic>? _findDishByName(List<dynamic> dishes, String dishName) {
    // Normalizar el nombre del plato (quitar acentos, pasar a minúsculas)
    final normalizedDishName = _normalizeText(dishName);

    // 1. Primero intentar encontrar una coincidencia exacta
    try {
      var matchingDish = dishes.firstWhere(
        (dish) =>
            _normalizeText(dish['nombre'].toString()) == normalizedDishName,
        orElse: () => {},
      );

      if (matchingDish.isNotEmpty) {
        return matchingDish;
      }
    } catch (e) {
      // Continuar con la búsqueda parcial
    }

    // 2. Buscar coincidencia parcial
    // Buscar platos cuyo nombre contiene todas las palabras del pedido
    final dishNameWords = normalizedDishName.split(' ');

    // Filtrar platos que contienen todas las palabras clave
    final candidateDishes =
        dishes.where((dish) {
          final normalizedMenuDishName = _normalizeText(
            dish['nombre'].toString(),
          );
          return dishNameWords.every(
            (word) => word.length > 2 && normalizedMenuDishName.contains(word),
          );
        }).toList();

    // Si hay candidatos, usar el primero
    if (candidateDishes.isNotEmpty) {
      print(
        'Coincidencia parcial encontrada: ${candidateDishes.first['nombre']}',
      );
      return candidateDishes.first;
    }

    // 3. Intentar buscar la palabra más larga del pedido
    // Ordenar palabras por longitud (de mayor a menor)
    dishNameWords.sort((a, b) => b.length.compareTo(a.length));

    // Buscar platos que contienen la palabra más larga
    for (final word in dishNameWords) {
      if (word.length <= 2) continue; // Ignorar palabras muy cortas

      final wordMatches =
          dishes
              .where(
                (dish) =>
                    _normalizeText(dish['nombre'].toString()).contains(word),
              )
              .toList();

      if (wordMatches.isNotEmpty) {
        print(
          'Coincidencia con palabra clave "$word": ${wordMatches.first['nombre']}',
        );
        return wordMatches.first;
      }
    }

    // No se encontró ninguna coincidencia
    return null;
  }

  /// Agrega un plato al carrito del cliente
  Future<bool> addDishToCart(String dishName) async {
    try {
      print('Buscando plato en el menú: $dishName');

      // Obtener el menú completo
      final dishes = await fetchMenu();

      if (dishes.isEmpty) {
        print('No se pudo obtener el menú o está vacío');
        return false;
      }

      // Buscar plato en el menú (búsqueda flexible)
      final dish = _findDishByName(dishes, dishName);

      if (dish != null) {
        print(
          '¡Plato encontrado! ID: ${dish['idplato']}, Nombre: ${dish['nombre']}',
        );

        // Añadir al carrito
        final cartService = CartService();
        cartService.addItem(
          id: dish['idplato'].toString(),
          name: dish['nombre'],
          price: double.parse(dish['precio'].toString()),
          imageUrl: dish['imagen_url'] ?? '',
          originalData: dish,
        );

        print('Plato añadido al carrito correctamente');
        return true;
      } else {
        print('No se encontró el plato: $dishName');
        return false;
      }
    } catch (e) {
      print('Error al agregar plato al carrito: $e');
      return false;
    }
  }

  /// Normaliza un texto: elimina acentos, convierte a minúsculas
  String _normalizeText(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    return normalized;
  }

  /// Verifica todas las claves API de Gemini y devuelve si al menos una funciona
  Future<bool> testAllApiKeys() async {
    print('Verificando todas las claves API...');
    bool anySuccess = false;

    // Endpoints a probar
    final endpoints = [
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-pro-preview-03-25:generateContent',
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent',
    ];

    for (int i = 0; i < _apiKeys.length; i++) {
      print('Probando clave API #${i + 1} de ${_apiKeys.length}...');

      // Probar cada endpoint con cada clave
      for (final endpoint in endpoints) {
        try {
          print('Probando con endpoint: $endpoint');

          final url = Uri.parse('$endpoint?key=${_apiKeys[i]}');

          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'contents': [
                    {
                      'parts': [
                        {'text': 'hi'},
                      ],
                    },
                  ],
                  'generationConfig': {
                    'temperature': 0.1,
                    'maxOutputTokens': 20,
                  },
                }),
              )
              .timeout(Duration(seconds: 15));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            anySuccess = true;
            print('✅ Clave API #${i + 1} FUNCIONA CORRECTAMENTE con $endpoint');

            // Guardar como clave operativa
            _currentApiKeyIndex = i;

            // Guardar en preferencias
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('gemini_connected', true);
            await prefs.setInt('last_working_api_key_index', i);

            // Salir del bucle de endpoints
            break;
          } else {
            print(
              '❌ Clave API #${i + 1} FALLIDA con $endpoint: ${response.statusCode} - ${response.body}',
            );
          }
        } catch (e) {
          print(
            '❌ Error al probar clave API #${i + 1} con $endpoint: ${e.toString().substring(0, min(100, e.toString().length))}',
          );
        }
      }
    }

    print(
      'Resultado final: ${anySuccess ? "Al menos una clave funciona" : "Ninguna clave funciona"}',
    );
    return anySuccess;
  }

  /// Reinicializa completamente el servicio de Gemini
  Future<void> resetAndReinitialize() async {
    print('Reinicializando completamente el servicio de Gemini...');

    try {
      // Limpiar historial
      _history.clear();
      clearChatHistory();

      // Obtener los índices disponibles
      final availableIndices = List<int>.generate(_apiKeys.length, (i) => i);

      // Intentar con un índice aleatorio primero
      final random = Random();
      _currentApiKeyIndex =
          availableIndices[random.nextInt(availableIndices.length)];

      print('Reiniciando con clave API #${_currentApiKeyIndex + 1}');

      // Reconstruir el cliente API
      _geminiApiClient = GeminiApiClient(_apiKeys[_currentApiKeyIndex]);

      // Generar un nuevo session ID
      const uuid = Uuid();
      _sessionId = uuid.v4();
      print('Nuevo session ID generado: $_sessionId');

      // Reinicializar el modelo
      _initGemini();

      print('Servicio reinicializado correctamente');
    } catch (e) {
      print('Error al reinicializar el servicio: $e');
    }
  }
}

/// Excepción para manejar tiempos de espera
class TimeoutException implements Exception {
  final String message;

  TimeoutException(this.message);

  @override
  String toString() => message;
}
