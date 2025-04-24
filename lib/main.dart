import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/theme.dart';
import 'dart:async';
import 'dart:io';
import 'Api_services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'UI_Screens/Widgets/routes.dart';

// ScaffoldMessengerState global para mostrar SnackBars desde cualquier parte
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Asegurar que los servicios de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno con manejo de errores más robusto
  try {
    // Verificar si existe el archivo .env
    File envFile = File('.env');
    bool envExists = await envFile.exists();

    if (envExists) {
      await dotenv.load(fileName: ".env");
      print('Variables de entorno cargadas correctamente desde .env');
    } else {
      // Si no existe el archivo, crear uno con valores predeterminados
      print('Archivo .env no encontrado, usando valores predeterminados');

      // Cargar dotenv con un string vacío para inicializarlo
      await dotenv.load(fileName: "");

      // Configurar variables de entorno predeterminadas
      dotenv.env['NODE_SERVER_IP'] = '192.168.1.121';
      dotenv.env['NODE_SERVER_PORT'] = '3000';
      dotenv.env['GEMINI_API_KEY'] = '';

      print('Valores predeterminados configurados en memoria');
    }
  } catch (e) {
    print('Error al cargar .env: $e');
    print('La aplicación continuará con valores predeterminados');
  }

  // Inicializar el servicio de Gemini (precarga)
  final geminiService = GeminiService();

  // Verificar conexión con el servidor (en segundo plano)
  unawaited(
    geminiService.checkServerConnection().then((isConnected) {
      print('Conexión con el servidor: ${isConnected ? 'EXITOSA' : 'FALLIDA'}');

      if (isConnected) {
        // Intentar cargar el menú para tenerlo precargado
        unawaited(
          geminiService.fetchMenu().then((menu) {
            print('Menú precargado con ${menu.length} platos');
          }),
        );
      }
    }),
  );

  // Registrar un callback para borrar el historial del chat al cerrar sesión
  setupLogoutCallback();

  // Iniciar la aplicación
  runApp(const MainApp());
}

void setupLogoutCallback() async {
  final prefs = await SharedPreferences.getInstance();
  // Establecer un listener para el logout
  prefs.setBool('setup_logout_callback', true);
}

Future<void> _testGeminiConnection() async {
  try {
    final geminiService = GeminiService();
    bool isConnected = await geminiService.testGeminiConnection();

    print(
      'Prueba de conexión con Gemini: ${isConnected ? 'EXITOSA' : 'FALLIDA'}',
    );

    if (isConnected) {
      // Si hay conexión, también probar la conexión con el servidor
      final serverConnected = await geminiService.checkServerConnection();
      print(
        'Conexión con el servidor: ${serverConnected ? 'EXITOSA' : 'FALLIDA'}',
      );
    }
  } catch (e) {
    print('Error al probar conexión con Gemini: $e');
  }
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Brunch',
      debugShowCheckedModeBanner: false,
      theme: lightMode,
      themeMode: ThemeMode.light, // Forzar modo claro
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      initialRoute: '/splash',
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
