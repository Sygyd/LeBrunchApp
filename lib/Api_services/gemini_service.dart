import 'dart:convert';
import 'dart:math'; // Para usar min()
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import 'cart_service.dart';
import 'gemini_api_client.dart';
import '../services/user_preferences_service.dart';

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

  // URL base de la API (ajustar según corresponda)
  final String _baseUrl = 'https://api.lebrunch.com/api';

  // Clave para almacenar las preferencias en SharedPreferences
  static const String _prefsKey = 'user_dish_preferences';

  // Cache para el menú obtenido
  List<dynamic>? _menuCache;

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

    // Verificar si el carrito fue limpiado en cierre de sesión anterior
    _checkCartClearedOnLogout().then((wasCleared) {
      if (wasCleared) {
        // Si se limpió el carrito, resetear el chat completamente
        resetChat();
        print('🔄 Chat reiniciado debido a cierre de sesión anterior');
      }
    });

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
        "Eres 'Brunchy', un mesero amable y entusiasta del restaurante Le Brunch. "
        "IMPORTANTE: Genera respuestas COHERENTES y COMPLETAS. Escribe oraciones claras y bien formadas. "
        "Actúa EXACTAMENTE como un mesero real en todas tus respuestas. "
        "Usa un tono casual, amigable y natural. Evita frases robóticas o elaboradas. "
        "NO uses frases como 'Soy Brunchy, tu mesero virtual' o similares. "
        "NO agregues notas explicativas al final de tus mensajes. "
        "NO mezcles conceptos sin relación entre sí. "
        "Mantén las respuestas CONCRETAS y ENFOCADAS como lo haría un mesero real. "
        "Responde DIRECTAMENTE a la pregunta del cliente. "
        "Evita enumerar muchas opciones cuando no te las piden. "
        "Si te preguntan por un plato específico, habla SOLO de ese plato. "
        "NUNCA respondas con fragmentos inconexos de texto. "
        "SIEMPRE mantén la conversación natural y fluida como un humano real.",
      );

      _history.add(systemContent);
    }

    // Reiniciar sesión de chat para aplicar cambios
    _startNewChatSession();
  }

  /// Verifica si el carrito fue limpiado en un cierre de sesión anterior
  Future<bool> _checkCartClearedOnLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasCleared = prefs.getBool('cart_cleared_on_logout') ?? false;

      // Si se encuentra la bandera, eliminarla y devolver true
      if (wasCleared) {
        await prefs.remove('cart_cleared_on_logout');
      }

      return wasCleared;
    } catch (e) {
      print('❌ Error al verificar estado de limpieza del carrito: $e');
      return false;
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

  /// Verifica la conexión con el servidor
  Future<bool> checkServerConnection() async {
    try {
      final response = await http.get(Uri.parse(_nodeJsUrl));
      print('Verificando conexión con el servidor en: $_nodeJsUrl');

      if (response.statusCode == 200) {
        if (response.body.toLowerCase().contains('mcp') ||
            response.body.toLowerCase().contains('context')) {
          // Si contiene cualquiera de estas palabras clave, es probable que sea el MCP actual
          _isConnected = true;
          print('MCP disponible - Servidor respondió');
        } else {
          print('MCP no disponible (respuesta sin MCP)');
          print('Servidor respondió: OK');
          _isConnected = true; // Aún consideramos que hay conexión
        }
        return true;
      } else {
        print('Error de conexión: ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      print('Error al verificar conexión con el servidor: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Llamada directa a la API de Gemini
  Future<String?> _callGeminiDirectly(String message) async {
    try {
      // Generar un ID de sesión único si no existe
      if (_sessionId == null) {
        const uuid = Uuid();
        _sessionId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
        print('Nuevo ID de sesión generado para llamada directa: $_sessionId');
      }

      // Construir el prompt para Gemini con instrucciones explícitas
      final prompt = """
INSTRUCCIONES DEL SISTEMA:
- Eres Brunchy, un mesero real del restaurante Le Brunch, especializado en desayunos y brunch.
- NUNCA digas que eres una inteligencia artificial, un modelo de lenguaje o un asistente virtual.
- NUNCA te refieras a ti mismo como "como mesero virtual" o términos similares.
- NUNCA digas frases como "no tengo un menú físico" o "no puedo".
- Habla SIEMPRE como un mesero real, con un tono conversacional amigable.
- Si te preguntan por el menú, responde con los platos que aparecen en el contexto proporcionado.
- Si no hay información sobre el menú en el contexto, indícale al cliente que consultarás con la cocina.
- Cuando te pregunten por categorías específicas (como postres, bebidas, etc.), solo menciona los platos de esa categoría.
- NUNCA inventes platos que no estén explícitamente mencionados en el contexto.

CONTEXTO DE LE BRUNCH:
- Ubicación: C.C. Punta Marina, Av Américo Vespucio, Lechería, Anzoátegui
- Horario: Abierto de 8am a 10pm todos los días
- Eslogan: "¡Horneamos, cocinamos... disfrutamos!"

$message

Tu respuesta (como un mesero real, NO como IA):
""";

      // Realizar la llamada a la API de Gemini con las configuraciones correctas
      final response = await _model.generateContent(
        [Content.text(prompt)],
        generationConfig: GenerationConfig(
          temperature: 0.2, // Baja temperatura para respuestas más predecibles
          topK: 40,
          topP: 0.9,
          maxOutputTokens: 800,
          stopSequences: [
            "INSTRUCCIONES DEL SISTEMA:",
            "CONTEXTO DE LE BRUNCH:",
          ],
        ),
      );

      final responseText = response.text;
      if (responseText != null && responseText.isNotEmpty) {
        // Verificar si la respuesta tiene indicios de ser una respuesta de IA
        if (responseText.toLowerCase().contains("como modelo") ||
            responseText.toLowerCase().contains("como ia") ||
            responseText.toLowerCase().contains("como asistente") ||
            responseText.toLowerCase().contains("no tengo acceso") ||
            responseText.toLowerCase().contains("no puedo")) {
          print(
            '⚠️ La respuesta contiene indicios de autoidentificación como IA, reemplazando con respuesta predeterminada',
          );
          return "¡Hola! Soy Brunchy, tu mesero en Le Brunch. ¿En qué puedo ayudarte hoy? Puedo mostrarte nuestro menú, tomar tu pedido o hacerte alguna recomendación.";
        }

        return responseText;
      }

      return null;
    } catch (e) {
      print('❌ Error en _callGeminiDirectly: $e');
      return null;
    }
  }

  /// Obtiene información del menú desde la base de datos
  Future<List<Map<String, dynamic>>> fetchMenu() async {
    try {
      print('🍽️ Obteniendo menú desde: $_menuUrl');

      // Usar un timeout más largo para dar tiempo a que responda el servidor
      final response = await http
          .get(Uri.parse(_menuUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Menú obtenido exitosamente: ${data.length} platos');

        // Imprimir primeros 3 platos para diagnóstico (si hay suficientes)
        if (data.isNotEmpty) {
          final int samplesToShow = min(3, data.length);
          print('📋 Primeras ${samplesToShow} entradas del menú:');
          for (int i = 0; i < samplesToShow; i++) {
            print(
              '   - ${data[i]['nombre']} (${data[i]['categoria']}): \$${data[i]['precio']}',
            );
          }
        }

        // Actualizar caché del menú
        _menuCache = data.cast<Map<String, dynamic>>();

        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Error al obtener menú: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');

        // Intentar usar la caché si existe
        if (_menuCache != null && _menuCache!.isNotEmpty) {
          print(
            '⚠️ Usando caché local del menú (${_menuCache!.length} platos)',
          );
          return List<Map<String, dynamic>>.from(_menuCache!);
        }

        return [];
      }
    } catch (e) {
      print('❌ Error en fetchMenu: $e');

      // Intentar usar la caché si existe
      if (_menuCache != null && _menuCache!.isNotEmpty) {
        print(
          '⚠️ Usando caché local del menú debido a error (${_menuCache!.length} platos)',
        );
        return List<Map<String, dynamic>>.from(_menuCache!);
      }

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

  /// Verifica si una respuesta es coherente y la mejora si es necesario
  Future<String> _improveResponse(
    String originalResponse,
    String userQuery,
  ) async {
    try {
      // Verificar si la respuesta contiene indicios de autoidentificación como IA
      if (_containsAIIdentifiers(originalResponse)) {
        print('⚠️ Respuesta identificada como IA, será reemplazada');
        return await _generateHumanLikeResponse(userQuery);
      }

      // Si la respuesta parece coherente, devolverla sin cambios
      if (_isResponseCoherent(originalResponse)) {
        // Verificar específicamente si habla de tablas que no existen
        if (_containsNonexistentTables(originalResponse)) {
          // Si menciona tablas que no existen, generar una nueva respuesta
          return await _generateResponseWithoutTables(userQuery);
        }
        return originalResponse;
      }

      // Si no es coherente, generar una nueva respuesta más simple
      final improvedPrompt =
          "Eres Brunchy, un mesero real del restaurante Le Brunch. Responde de manera conversacional, amigable y natural como un mesero real haría. NUNCA digas que eres una IA o asistente virtual. Pregunta del cliente: '$userQuery'";

      // Usar el modelo con configuración más estricta
      final improvedModel = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _getCurrentApiKey(),
        generationConfig: GenerationConfig(
          temperature: 0.1, // Temperatura muy baja para respuestas predecibles
          topP: 0.8,
          topK: 20,
          maxOutputTokens: 150, // Respuesta más corta
        ),
      );

      final improvedResponse = await improvedModel.generateContent([
        Content.text(improvedPrompt),
      ]);
      final improvedText = improvedResponse.text;

      if (improvedText != null &&
          improvedText.isNotEmpty &&
          _isResponseCoherent(improvedText) &&
          !_containsNonexistentTables(improvedText) &&
          !_containsAIIdentifiers(improvedText)) {
        print('✓ Respuesta mejorada generada correctamente');
        return improvedText;
      } else {
        // Si la mejora también falla, proporcionar una respuesta segura
        return "¡Hola! Soy Brunchy, tu mesero. ¿En qué puedo ayudarte hoy? Puedo informarte sobre nuestro menú actual o tomar tu pedido.";
      }
    } catch (e) {
      print('Error al mejorar respuesta: $e');
      return "¡Hola! Soy Brunchy, tu mesero. ¿En qué puedo ayudarte hoy?";
    }
  }

  /// Verifica si la respuesta contiene identificadores de que fue generada por una IA
  bool _containsAIIdentifiers(String response) {
    final lowerResponse = response.toLowerCase();
    final aiIdentifiers = [
      "como modelo",
      "como ia",
      "como asistente",
      "como una ia",
      "como un modelo",
      "como un asistente",
      "soy un asistente",
      "soy una ia",
      "soy un modelo",
      "no tengo acceso",
      "no puedo acceder",
      "no tengo un menú físico",
      "no tengo la capacidad",
      "no estoy diseñado",
      "no tengo cuerpo",
      "no puedo probar",
      "no puedo ver",
      "no puedo oler",
      "modelo de lenguaje",
      "inteligencia artificial",
    ];

    for (final identifier in aiIdentifiers) {
      if (lowerResponse.contains(identifier)) {
        print('⚠️ Respuesta contiene identificador de IA: "$identifier"');
        return true;
      }
    }

    return false;
  }

  /// Genera una respuesta que simula un mesero humano cuando la respuesta original es mala
  Future<String> _generateHumanLikeResponse(String userQuery) async {
    try {
      // Ver si es una consulta sobre el menú
      bool isMenuQuery =
          userQuery.toLowerCase().contains("menú") ||
          userQuery.toLowerCase().contains("carta") ||
          userQuery.toLowerCase().contains("tienen") ||
          userQuery.toLowerCase().contains("hay");

      if (isMenuQuery) {
        // Obtener el menú real para dar respuestas precisas
        final menuItems = await fetchMenu();

        if (menuItems.isNotEmpty) {
          // Crear un resumen breve del menú por categorías
          final categories = <String, List<String>>{};
          for (var item in menuItems) {
            final categoria = item['categoria'].toString();
            if (!categories.containsKey(categoria)) {
              categories[categoria] = [];
            }
            categories[categoria]!.add(item['nombre'].toString());
          }

          String menuSummary = "";
          categories.forEach((categoria, platos) {
            final availableDishes = platos
                .take(min(3, platos.length))
                .join(", ");
            menuSummary += "En $categoria tenemos $availableDishes";
            if (platos.length > 3) {
              menuSummary += " y otros platos más";
            }
            menuSummary += ". ";
          });

          return "¡Claro! Te puedo contar sobre nuestro menú. $menuSummary ¿Te gustaría que te recomiende algo en particular?";
        } else {
          return "¡Claro! Te puedo mostrar nuestro menú. Tenemos varias opciones de desayunos, brunch y bebidas. ¿Qué te gustaría ver primero?";
        }
      }

      // Para preguntas generales, dar respuestas de mesero
      final generalResponses = [
        "¡Hola! Soy Brunchy, tu mesero. ¿En qué puedo ayudarte hoy?",
        "¡Claro que sí! Puedo mostrarte nuestro menú o recomendarte alguna especialidad. ¿Qué prefieres?",
        "¡Por supuesto! ¿Te gustaría ver nuestras opciones de desayuno o brunch?",
        "¡Con gusto! ¿Buscas algo en particular? Tenemos excelentes opciones para el desayuno.",
      ];

      // Elegir una respuesta aleatoria
      final random = Random();
      return generalResponses[random.nextInt(generalResponses.length)];
    } catch (e) {
      print('Error al generar respuesta humana: $e');
      return "¡Hola! Soy Brunchy, tu mesero. ¿En qué puedo ayudarte hoy?";
    }
  }

  /// Verifica si la respuesta menciona tablas que no existen en el menú
  bool _containsNonexistentTables(String response) {
    try {
      // Verificar si la respuesta menciona tablas
      final containsTablas =
          response.toLowerCase().contains('tabla') ||
          response.toLowerCase().contains('tablas');

      if (!containsTablas) return false;

      // Obtener lista de platos del menú
      final menuItems = _menuCache ?? [];

      // Verificar si algún plato del menú tiene "tabla" en su nombre
      final menuHasTables = menuItems.any(
        (item) => item['nombre'].toString().toLowerCase().contains('tabla'),
      );

      // Si el menú no tiene tablas pero la respuesta menciona tablas, es una invención
      return !menuHasTables && containsTablas;
    } catch (e) {
      print('Error al verificar tablas: $e');
      return false; // En caso de error, asumir que no hay problema
    }
  }

  /// Genera una respuesta que evita mencionar tablas
  Future<String> _generateResponseWithoutTables(String userQuery) async {
    try {
      // Primero obtener el menú actual
      final menuItems = await fetchMenu();

      // Preparar el prompt para evitar tablas
      final menuContext = _prepareMenuContext(menuItems);

      const systemPrompt = """
Eres Brunchy, un mesero amable del restaurante Le Brunch.
INSTRUCCIÓN IMPORTANTE: El restaurante NO tiene "tablas" para compartir en su menú.
No inventes ni menciones tablas de quesos, embutidos ni ningún otro tipo de tabla.
Responde al cliente basándote ÚNICAMENTE en platos que existan en el menú proporcionado.
Si el cliente pregunta por tablas, indícale amablemente que no ofrecemos ese tipo de platos,
pero puedes sugerirle alternativas del menú actual.
""";

      final prompt = """
$systemPrompt

$menuContext

Consulta del cliente: "$userQuery"

Tu respuesta como Brunchy (sin mencionar tablas inexistentes):
""";

      // Usar el modelo con configuración estricta
      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _getCurrentApiKey(),
        generationConfig: GenerationConfig(
          temperature: 0.2,
          topP: 0.7,
          topK: 20,
          maxOutputTokens: 200,
        ),
      );

      final generatedResponse = await model.generateContent([
        Content.text(prompt),
      ]);

      final responseText = generatedResponse.text;

      if (responseText != null && responseText.isNotEmpty) {
        return responseText;
      } else {
        // Respuesta predeterminada si falla la generación
        return "¡Hola! Soy Brunchy, tu mesero de Le Brunch. Actualmente no ofrecemos tablas para compartir, pero tenemos muchas otras opciones deliciosas en nuestro menú. ¿Te gustaría que te mencione algunas?";
      }
    } catch (e) {
      print('Error al generar respuesta sin tablas: $e');
      return "¡Hola! Soy Brunchy, tu mesero de Le Brunch. ¿En qué puedo ayudarte con nuestro menú actual?";
    }
  }

  /// Prepara un contexto con el menú actual para el modelo
  String _prepareMenuContext(List<dynamic> menuItems) {
    try {
      String menuContext = "MENÚ ACTUAL DE LE BRUNCH:\n";

      if (menuItems.isEmpty) {
        return menuContext +
            "Actualmente no hay información disponible sobre nuestro menú.\n";
      }

      // Agrupar por categorías
      final categories = <String, List<Map<String, dynamic>>>{};
      for (var item in menuItems) {
        final categoria = item['categoria'].toString();
        if (!categories.containsKey(categoria)) {
          categories[categoria] = [];
        }
        categories[categoria]!.add(Map<String, dynamic>.from(item));
      }

      // Generar texto estructurado
      categories.forEach((categoria, platos) {
        menuContext += "\n$categoria:\n";
        for (var plato in platos) {
          final disponible = plato['disponibilidad'] == true ? "✓" : "✗";
          menuContext +=
              "- ${plato['nombre']} (\$${plato['precio']}) $disponible\n";

          if (plato['ingredientes'] != null) {
            final ingredientes = plato['ingredientes'].toString().split(',');
            if (ingredientes.isNotEmpty) {
              menuContext += "  Ingredientes: ${ingredientes.join(', ')}\n";
            }
          }
        }
      });

      return menuContext;
    } catch (e) {
      print('Error al preparar contexto del menú: $e');
      return "MENÚ ACTUAL: Información no disponible en este momento.";
    }
  }

  /// Verifica si una respuesta es coherente y bien estructurada
  bool _isResponseCoherent(String response) {
    try {
      // Verificar longitud mínima
      if (response.trim().length < 10) {
        print('⚠️ Respuesta demasiado corta');
        return false;
      }

      // Verificar que tenga al menos 3 fragmentos (aproximación de frases)
      final fragments =
          response
              .split(RegExp(r'[.!?;:]'))
              .where((f) => f.trim().isNotEmpty)
              .toList();
      if (fragments.length < 3) {
        print('⚠️ Respuesta con muy pocas frases');
        return false;
      }

      // Verificar que no haya palabras repetidas consecutivamente
      final words = response.split(' ');
      int repeatedCount = 0;
      String? lastWord;

      for (final word in words) {
        if (word.trim().isNotEmpty) {
          if (word == lastWord) {
            repeatedCount++;
            if (repeatedCount > 2) {
              print('⚠️ Demasiadas palabras repetidas consecutivamente');
              return false;
            }
          } else {
            repeatedCount = 0;
          }
          lastWord = word;
        }
      }

      // Verificar estructura gramatical básica (presencia de puntuación)
      if (!RegExp(r'[.!?;:]').hasMatch(response)) {
        print('⚠️ Respuesta sin puntuación');
        return false;
      }

      // Verificar mezcla de conceptos no relacionados (ejemplo específico)
      if (response.toLowerCase().contains('gofre') &&
          response.toLowerCase().contains('omelette') &&
          !response.toLowerCase().contains('desayuno') &&
          !response.toLowerCase().contains('menu')) {
        print('⚠️ Mezcla de conceptos no relacionados');
        return false;
      }

      return true;
    } catch (e) {
      print('Error al verificar coherencia: $e');
      return false;
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
      print('🍽️ Buscando plato en el menú: "$dishName"');

      // Obtener el menú completo
      final dishes = await fetchMenu();

      if (dishes.isEmpty) {
        print('❌ No se pudo obtener el menú o está vacío');
        return false;
      }

      print('📋 Se encontraron ${dishes.length} platos en el menú');

      // Buscar plato en el menú (búsqueda flexible)
      final dish = _findDishByName(dishes, dishName);

      if (dish != null) {
        print(
          '✅ ¡Plato encontrado! ID: ${dish['idplato']}, Nombre: ${dish['nombre']}',
        );

        // Verificar precio para evitar errores
        double price;
        try {
          price = double.parse(dish['precio'].toString());
        } catch (e) {
          print(
            '⚠️ Error al parsear precio: ${dish['precio']}. Usando valor predeterminado.',
          );
          price = 0.0;
        }

        // Añadir al carrito
        final cartService = CartService();
        cartService.addItem(
          id: dish['idplato'].toString(),
          name: dish['nombre'],
          price: price,
          imageUrl: dish['imagen_url'] ?? '',
          originalData: dish,
        );

        print('🛒 Plato añadido al carrito correctamente');

        // Guardar preferencia de usuario para análisis
        try {
          final prefs = await SharedPreferences.getInstance();
          int orderedCount = prefs.getInt('ordered_dish_count') ?? 0;
          await prefs.setInt('ordered_dish_count', orderedCount + 1);

          // Guardar último plato pedido para recomendaciones futuras
          await prefs.setString('last_ordered_dish', dish['nombre']);
        } catch (e) {
          // Ignorar errores al guardar preferencias
          print('⚠️ No se pudieron guardar preferencias: $e');
        }

        return true;
      } else {
        // Intentar encontrar platos similares para sugerencias
        final similarDishes = _findSimilarDishes(dishes, dishName);
        if (similarDishes.isNotEmpty) {
          print(
            '🔍 No se encontró "$dishName" pero hay sugerencias similares:',
          );
          for (var i = 0; i < min(3, similarDishes.length); i++) {
            print('   - ${similarDishes[i]['nombre']}');
          }
        } else {
          print('❌ No se encontró el plato ni sugerencias: "$dishName"');
        }
        return false;
      }
    } catch (e) {
      print('❌ Error al agregar plato al carrito: $e');
      return false;
    }
  }

  /// Encuentra platos similares para sugerencias
  List<Map<String, dynamic>> _findSimilarDishes(
    List<dynamic> dishes,
    String dishName,
  ) {
    final normalizedName = _normalizeText(dishName);
    final words =
        normalizedName.split(' ').where((word) => word.length > 3).toList();

    if (words.isEmpty) return [];

    // Calcular puntuación de similitud para cada plato
    final scoredDishes =
        dishes
            .map((dish) {
              final normalizedDishName = _normalizeText(
                dish['nombre'].toString(),
              );
              int score = 0;

              // Cada palabra que coincide suma puntos
              for (final word in words) {
                if (normalizedDishName.contains(word)) {
                  score +=
                      10 * word.length; // Palabras más largas tienen más peso
                }
              }

              // Categoría similar suma puntos
              if (dish['categoria'] != null) {
                final normalizedCategory = _normalizeText(
                  dish['categoria'].toString(),
                );
                if (normalizedName.contains(normalizedCategory) ||
                    normalizedCategory.contains(words.first)) {
                  score += 20;
                }
              }

              return {'dish': dish, 'score': score};
            })
            .where((item) => item['score'] > 0)
            .toList();

    // Ordenar por puntuación descendente
    scoredDishes.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );

    // Devolver solo los platos, sin las puntuaciones
    return scoredDishes
        .map((item) => item['dish'] as Map<String, dynamic>)
        .toList();
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

  // Obtener preferencias del usuario
  Future<Map<String, dynamic>> getUserPreferences() async {
    return await UserPreferencesService().getUserPreferences();
  }

  // Actualizar preferencias del usuario cuando pide un plato
  Future<void> updateUserPreferences(String dishName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> userPrefs = await getUserPreferences();

      // Actualizar último plato pedido
      userPrefs['lastOrderedDish'] = dishName;

      // Actualizar contador de platos
      Map<String, dynamic> dishCounts = userPrefs['dishCounts'] ?? {};
      dishCounts[dishName] = (dishCounts[dishName] as int? ?? 0) + 1;
      userPrefs['dishCounts'] = dishCounts;

      // Guardar preferencias actualizadas
      await prefs.setString(_prefsKey, jsonEncode(userPrefs));
    } catch (e) {
      print('Error al actualizar preferencias del usuario: $e');
    }
  }

  // Método para obtener recomendaciones basadas en el historial de pedidos
  Future<List<Map<String, dynamic>>> getRecommendations(
    List<String> currentCartItems,
  ) async {
    try {
      final userPrefs = await getUserPreferences();
      final menu = await fetchMenu();

      // Implementar lógica de recomendación
      final String? lastOrderedDish = userPrefs['lastOrderedDish'];
      final Map<String, dynamic> dishCounts = userPrefs['dishCounts'] ?? {};

      // Filtrar platos que ya están en el carrito
      final availableItems =
          menu
              .where(
                (item) =>
                    !currentCartItems.contains(item['nombre']?.toLowerCase()),
              )
              .toList();

      // Si no hay platos disponibles, retornar lista vacía
      if (availableItems.isEmpty) {
        return [];
      }

      // Crear lista de recomendaciones (máximo 3)
      List<Map<String, dynamic>> recommendations = [];

      // 1. Añadir platos de la misma categoría que el último ordenado
      if (lastOrderedDish != null) {
        final lastDishInfo = menu.firstWhere(
          (dish) =>
              dish['nombre']?.toLowerCase() == lastOrderedDish.toLowerCase(),
          orElse: () => {} as Map<String, dynamic>,
        );

        if (lastDishInfo.isNotEmpty && lastDishInfo['categoria'] != null) {
          final similarCategory =
              availableItems
                  .where(
                    (dish) => dish['categoria'] == lastDishInfo['categoria'],
                  )
                  .toList();

          if (similarCategory.isNotEmpty) {
            recommendations.addAll(similarCategory.take(2));
          }
        }
      }

      // 2. Añadir platos populares basados en el historial
      if (dishCounts.isNotEmpty && recommendations.length < 3) {
        // Ordenar platos por popularidad
        List<MapEntry<String, dynamic>> sortedDishes =
            dishCounts.entries.toList()
              ..sort((a, b) => (b.value as int).compareTo(a.value as int));

        for (var entry in sortedDishes) {
          if (recommendations.length >= 3) break;

          final dishName = entry.key;
          final dishInfo = availableItems.firstWhere(
            (dish) => dish['nombre']?.toLowerCase() == dishName.toLowerCase(),
            orElse: () => {} as Map<String, dynamic>,
          );

          if (dishInfo.isNotEmpty &&
              !recommendations.any(
                (rec) => rec['nombre'] == dishInfo['nombre'],
              )) {
            recommendations.add(dishInfo);
          }
        }
      }

      // 3. Si aún necesitamos más recomendaciones, añadir platos aleatorios
      if (recommendations.length < 3) {
        availableItems.shuffle();
        for (var dish in availableItems) {
          if (!recommendations.any((rec) => rec['nombre'] == dish['nombre'])) {
            recommendations.add(dish);
          }
          if (recommendations.length >= 3) break;
        }
      }

      return recommendations.take(3).toList();
    } catch (e) {
      print('Error al generar recomendaciones: $e');
      return [];
    }
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

  /// Obtiene la clave API actual
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
        'gemini-2.0-flash', // Modelo principal (actualizado)
        'gemini-1.5-flash', // Primera alternativa
        'gemini-1.5-pro', // Segunda alternativa
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
      }

      // Crear una sesión de chat con el historial existente
      _chatSession = _model.startChat(
        history: _geminiHistories[_currentUserId!],
        generationConfig: GenerationConfig(
          temperature:
              0.4, // Temperatura más baja para respuestas más consistentes
          maxOutputTokens: 1024, // Permitir respuestas más largas
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

  /// Procesa un mensaje utilizando API externa (MCP o Gemini directamente)
  Future<String?> _processMessageWithExternalAPI(String message) async {
    try {
      // Generar un ID de sesión único si no existe
      if (_sessionId == null) {
        _sessionId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
        print('Nuevo ID de sesión generado para MCP: $_sessionId');
      }

      // 1. Intentar usar el MCP (Model Context Protocol del servidor)
      try {
        print(
          'Intentando conectar con MCP en http://$_serverIp:$_nodeJsPort/mcp/status',
        );

        // Verificar si el MCP está disponible
        final statusUrl = Uri.parse(
          'http://$_serverIp:$_nodeJsPort/mcp/status',
        );
        final statusResponse = await http
            .get(statusUrl)
            .timeout(const Duration(seconds: 5)); // Aumentar timeout

        if (statusResponse.statusCode == 200) {
          print('✅ MCP disponible. Enviando consulta...');

          // MCP disponible, obtener contexto enriquecido
          final mcpUrl = Uri.parse('http://$_serverIp:$_nodeJsPort/mcp/chat');

          print(
            'Enviando mensaje a MCP: "$message" con sessionId: $_sessionId',
          );

          // Asegurar que tenemos un sessionId único para cada conversación
          String sessionId =
              _sessionId ?? 'flutter_${DateTime.now().millisecondsSinceEpoch}';

          final mcpResponse = await http
              .post(
                mcpUrl,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'message': message,
                  'sessionId': sessionId,
                  'instructions': '''
Responde como un mesero real llamado Brunchy. NUNCA digas que eres una IA o modelo de lenguaje.
Contesta basándote SOLO en platos que existan en la base de datos. 
NO inventes platos ni tablas que no estén en el menú proporcionado.
Si te preguntan por el menú, responde solo con los platos disponibles.
''',
                  'checkDatabase': true,
                }),
              )
              .timeout(const Duration(seconds: 15)); // Aumentar timeout

          if (mcpResponse.statusCode == 200) {
            print(
              '✅ Respuesta recibida del MCP (${mcpResponse.body.length} bytes)',
            );
            final mcpData = jsonDecode(mcpResponse.body);

            // Si el MCP proporciona respuesta directa, usarla
            if (mcpData['response'] != null && mcpData['response'] is String) {
              print('✅ Usando respuesta directa del MCP');
              return mcpData['response'] as String;
            }

            // Si hay contexto enriquecido, usarlo con llamada a API de Gemini
            if (mcpData['enrichedContext'] != null) {
              print('✅ Usando contexto enriquecido del MCP con Gemini');

              // Imprimir la primera parte del contexto para diagnóstico
              final contextPreview = mcpData['enrichedContext']
                  .toString()
                  .substring(
                    0,
                    min(200, mcpData['enrichedContext'].toString().length),
                  );
              print('📝 Contexto recibido (inicio): $contextPreview...');

              // Verificar si el contexto contiene la consulta del cliente
              bool containsUserQuery =
                  mcpData['enrichedContext'].toString().contains(
                    'CONSULTA DEL CLIENTE',
                  ) ||
                  mcpData['enrichedContext'].toString().contains(
                    'Consulta del cliente',
                  );

              // Añadir la consulta si no está incluida
              String finalContext = mcpData['enrichedContext'];
              if (!containsUserQuery) {
                finalContext += "\n\nCONSULTA DEL CLIENTE: \"$message\"\n\n";
              }

              // Añadir instrucciones de comportamiento
              finalContext += '''
INSTRUCCIONES CRÍTICAS: 
- NUNCA digas que eres una IA, un asistente virtual o un modelo de lenguaje.
- Actúa SOLO como un mesero real llamado Brunchy.
- Responde SIEMPRE en español.
- NO uses frases como "no tengo acceso" o "no puedo".
- NO inventes platos que no estén en el menú proporcionado.
- Si te preguntan por platos que no están en el menú, indica amablemente que no están disponibles.
- Si no sabes algo específico del restaurante, di que consultarás con el chef o el gerente.

Tu respuesta (como mesero real):''';

              final apiResponse = await _callGeminiDirectly(finalContext);
              if (apiResponse != null && apiResponse.isNotEmpty) {
                return apiResponse;
              }
            } else {
              print('⚠️ El MCP no proporcionó contexto enriquecido');
            }
          } else {
            print(
              '❌ Error en respuesta MCP: ${mcpResponse.statusCode} - ${mcpResponse.body}',
            );
          }
        } else {
          print(
            '❌ MCP no disponible: ${statusResponse.statusCode} - ${statusResponse.body}',
          );
        }
      } catch (e) {
        print('❌ Error al intentar usar MCP: $e');
        // Continuar con otros métodos si MCP falla
      }

      // 2. Intentar llamada directa a Gemini con menú obtenido directamente de la API
      try {
        print('Obteniendo menú directamente de la API en $_menuUrl');

        // Primero obtener el menú actual para contexto
        final menuItems = await fetchMenu();

        if (menuItems.isEmpty) {
          print('⚠️ No se pudo obtener el menú o está vacío');
        } else {
          print('✅ Menú obtenido con ${menuItems.length} platos');
        }

        _menuCache = menuItems; // Guardar en cache para uso futuro

        String menuContext =
            "MENÚ ACTUAL DE LE BRUNCH (estos son TODOS los platos disponibles):\n";

        if (menuItems.isNotEmpty) {
          // Agrupar por categorías
          final categories = <String, List<Map<String, dynamic>>>{};
          for (var item in menuItems) {
            final categoria = item['categoria'].toString();
            if (!categories.containsKey(categoria)) {
              categories[categoria] = [];
            }
            categories[categoria]!.add(item);
          }

          // Generar texto con el menú
          categories.forEach((categoria, platos) {
            menuContext += "\n$categoria:\n";
            for (var plato in platos) {
              final disponible = plato['disponibilidad'] == true ? "✓" : "✗";
              menuContext +=
                  "- ${plato['nombre']}: \$${plato['precio']} $disponible\n";

              // Incluir ingredientes si están disponibles
              if (plato['ingredientes'] != null &&
                  plato['ingredientes'].toString().isNotEmpty) {
                menuContext += "  Ingredientes: ${plato['ingredientes']}\n";
              }
            }
          });
        } else {
          menuContext +=
              "Actualmente no hay información disponible sobre el menú.\n";
        }

        print('Generando respuesta con menú obtenido directamente');

        // Enriquecer mensaje con el menú
        final enrichedMessage = """
Eres 'Brunchy', un mesero amable y entusiasta del restaurante Le Brunch.
Debes actuar EXACTAMENTE como un mesero real, no como una IA.

Consulta del cliente: "$message"

$menuContext

INSTRUCCIONES IMPORTANTES:
1. Responde SOLO basándote en los platos listados arriba en el MENÚ ACTUAL.
2. NO inventes platos ni tablas que no aparezcan explícitamente en la lista anterior.
3. Si preguntan por un plato que no está en esta lista, indica amablemente que no está disponible actualmente.
4. Si preguntan por una categoría (como "omelettes"), menciona SOLO los platos de esa categoría que aparecen en el menú proporcionado.
5. Escribe como un mesero real, con un tono conversacional natural y amigable.
6. NO menciones que eres una IA o que estás consultando una base de datos.

Tu respuesta como Brunchy (basada EXCLUSIVAMENTE en el menú proporcionado):
""";

        return await _callGeminiDirectly(enrichedMessage);
      } catch (e) {
        print('❌ Error en llamada directa a Gemini: $e');
      }

      // Si todas las estrategias fallaron, devolver un mensaje de error
      return "Disculpa, estoy teniendo problemas para conectarme con nuestra base de datos de menú. ¿Puedo ayudarte con algo más mientras resolvemos este inconveniente?";
    } catch (e) {
      print('❌ Error general en _processMessageWithExternalAPI: $e');
      return null;
    }
  }

  /// Envía un mensaje al chatbot y obtiene una respuesta
  Future<ChatMessage> sendMessage(String message) async {
    try {
      if (message.trim().isEmpty) {
        return ChatMessage.fromSupport(
          message: "Por favor, escribe un mensaje para continuar.",
        );
      }

      // Asegurar que existe un ID de usuario
      if (_currentUserId == null) {
        _currentUserId = 'anonymous';
      }

      // Generar un ID de sesión único si no existe
      if (_sessionId == null) {
        _sessionId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';
        print('Nuevo ID de sesión generado para envío de mensaje: $_sessionId');
      }

      // Convertir el mensaje a un Content para el historial
      final userMessage = Content.text(message);

      // Variable para almacenar la respuesta final
      String? finalResponse;

      // Verificar en .env si se debe usar MCP prioritariamente
      bool useMcpFirst = true;
      try {
        useMcpFirst = dotenv.get('USE_MCP', fallback: 'true') == 'true';
      } catch (e) {
        // Si hay error al leer .env, usar MCP por defecto
        print('⚠️ Error al leer la configuración USE_MCP: $e');
      }

      // 1. Si está configurado para usar MCP primero, intentarlo
      if (useMcpFirst) {
        print('Configurado para usar MCP primero');
        final apiResponse = await _processMessageWithExternalAPI(message);
        if (apiResponse != null) {
          print('✅ Respuesta obtenida desde API externa/MCP');
          finalResponse = await _improveResponse(apiResponse, message);
        }
      }

      // 2. Si no se usó MCP o falló, intentar con chatSession
      if (finalResponse == null && _chatSession != null) {
        try {
          print('Intentando con chatSession local');
          // Añadir el mensaje del usuario al historial
          if (_geminiHistories.containsKey(_currentUserId)) {
            _geminiHistories[_currentUserId!]!.add(userMessage);
          }

          // Obtener respuesta usando la sesión de chat
          final response = await _chatSession!
              .sendMessage(userMessage)
              .timeout(const Duration(seconds: 15));

          // Extraer el texto de la respuesta
          final responseText = response.text;

          if (responseText != null && responseText.isNotEmpty) {
            // Verificar si la respuesta es coherente y mejorarla si es necesario
            finalResponse = await _improveResponse(responseText, message);
            print('✅ Respuesta obtenida desde chatSession local');
          }
        } catch (e) {
          print('Error al usar chatSession: $e');
          // Si falla, continuar con otros métodos
        }
      }

      // 3. Si no se usó MCP primero y los otros métodos fallaron, intentar MCP ahora
      if (finalResponse == null && !useMcpFirst) {
        print('Intentando con API externa/MCP como fallback');
        final apiResponse = await _processMessageWithExternalAPI(message);
        if (apiResponse != null) {
          finalResponse = await _improveResponse(apiResponse, message);
          print('✅ Respuesta obtenida desde API externa/MCP como fallback');
        }
      }

      // 4. Si todo falló, usar respuesta predeterminada
      if (finalResponse == null) {
        finalResponse =
            "¡Hola! Soy Brunchy, tu mesero. ¿En qué puedo ayudarte hoy? Puedo mostrarte nuestro menú actual o tomar tu pedido.";
        print(
          '⚠️ Usando respuesta predeterminada porque todos los métodos fallaron',
        );
      }

      // Detectar si la respuesta contiene indicios de identificarse como IA
      if (finalResponse.toLowerCase().contains("como modelo") ||
          finalResponse.toLowerCase().contains("como ia") ||
          finalResponse.toLowerCase().contains("como asistente") ||
          finalResponse.toLowerCase().contains("no tengo acceso") ||
          finalResponse.toLowerCase().contains("no puedo") ||
          finalResponse.toLowerCase().contains("no tengo un menú físico")) {
        print(
          '⚠️ La respuesta final contiene indicios de respuesta de IA, reemplazando',
        );
        finalResponse =
            "¡Hola! Soy Brunchy, tu mesero en Le Brunch. ¿En qué puedo ayudarte hoy? Puedo mostrarte el menú o sugerirte alguna especialidad de la casa.";
      }

      // Añadir la respuesta al historial
      if (_geminiHistories.containsKey(_currentUserId)) {
        _geminiHistories[_currentUserId!]!.add(Content.text(finalResponse));
      }

      // Crear y devolver el mensaje de respuesta
      final supportMessage = ChatMessage.fromSupport(message: finalResponse);

      // Guardar en historial de UI
      if (_currentUserId != null &&
          _chatHistories.containsKey(_currentUserId!)) {
        _chatHistories[_currentUserId!]!.add(supportMessage);
      }

      return supportMessage;
    } catch (e) {
      print('Error general al procesar mensaje: $e');
      return ChatMessage.fromSystem(
        message:
            'Ocurrió un error al procesar tu mensaje. Por favor, intenta nuevamente.',
      );
    }
  }

  /// Actualiza las preferencias cuando un plato es ordenado
  Future<void> updatePrefsWhenDishOrdered(String dishName) async {
    try {
      await UserPreferencesService().updateOrderedDish(dishName);
    } catch (e) {
      print('Error al actualizar preferencias: $e');
    }
  }

  /// Genera recomendaciones basadas en platos ordenados
  Future<List<String>> getRecommendationsBasedOnHistory() async {
    try {
      return await UserPreferencesService().getMostOrderedDishes();
    } catch (e) {
      print('Error al generar recomendaciones: $e');
      return [];
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
