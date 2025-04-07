import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'UI_Screens/Widgets/routes.dart';
import 'theme/theme.dart';
import 'Api_services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'UI_Screens/Client_Screens/ChatScreen.dart';
import 'UI_Screens/Client_Screens/ClientHomeScreen.dart';
import 'UI_Screens/Client_Screens/ClientMenuScreen.dart';
import 'UI_Screens/Client_Screens/CartScreen.dart';
import 'UI_Screens/Admin_Screens/AdminChatScreen.dart';

// Clave global para mostrar SnackBar en cualquier parte de la app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  // Inicializar Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Registrar un callback para borrar el historial del chat al cerrar sesión
  setupLogoutCallback();

  // Probar conexión con Gemini al inicio
  await _testGeminiConnection();

  // Iniciar la aplicación
  runApp(const MainApp());
}

/// Prueba la conexión con Gemini al inicio y guarda el estado
Future<void> _testGeminiConnection() async {
  try {
    // Esperar 2 segundos para dar tiempo a que otros servicios se inicialicen
    await Future.delayed(Duration(seconds: 2));

    // Obtener el servicio de Gemini
    final geminiService = GeminiService();

    // Verificar conexión con Gemini al inicio
    bool isConnected = await geminiService.testGeminiConnection();

    // Guardar el estado en SharedPreferences para usarlo más tarde
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gemini_connected', isConnected);

    // Configurar las claves API si no existen
    final apiKeys = prefs.getStringList('gemini_api_keys') ?? [];
    if (apiKeys.isEmpty) {
      // Configurar las claves API por defecto
      await prefs.setStringList('gemini_api_keys', [
        'AIzaSyA2-6S6R8YSCVtLI-g9swXcK06y3qFQh-Y',
        'AIzaSyBJUELm8-Z2jyWS1NnPnQFtTMvVrkhGK_g',
        'AIzaSyByjwt8rczLyPj20WodqrBOEcaBZXNWvB4',
      ]);
    }

    print(
      'Estado inicial de conexión con Gemini: ${isConnected ? "CONECTADO" : "DESCONECTADO"}',
    );
  } catch (e) {
    print('Error al verificar la conexión con Gemini: $e');
    // Guardar como desconectado en caso de error
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gemini_connected', false);
  }
}

// Configura el callback para manejar el cierre de sesión
void setupLogoutCallback() async {
  // Configurar un listener para borrar el chat cuando el usuario cierra sesión
  final prefs = await SharedPreferences.getInstance();

  // Registrar el callback para futuras referencias
  prefs.setBool('logout_handler_registered', true);

  // Limpiar cualquier sesión anterior terminada incorrectamente
  final bool wasLoggedOut = prefs.getBool('user_logged_out') ?? false;
  if (wasLoggedOut) {
    // Si hay una bandera de cierre de sesión, limpiar el historial de chat
    await clearChatOnLogout();
    // Restablecer la bandera
    await prefs.setBool('user_logged_out', false);
  }
}

// Función para limpiar el historial de chat al cerrar sesión
Future<void> clearChatOnLogout() async {
  try {
    print('Limpiando historial de chat después del cierre de sesión');

    // Limpiar el ID de usuario de chat persistente
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistent_chat_user_id');

    // Limpiar el historial de chat a través del servicio
    final geminiService = GeminiService();
    await geminiService.resetChat();

    print('Historial de chat limpiado exitosamente');
  } catch (e) {
    print('Error al limpiar historial de chat: $e');
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
      darkTheme: darkMode,
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        // Agregamos ruta para la pantalla de administración primero
        if (settings.name == '/admin/chat') {
          return MaterialPageRoute(builder: (_) => const AdminChatScreen());
        }
        // Para las rutas existentes, usamos el generador actual
        return AppRoutes.generateRoute(settings);
      },
    );
  }
}
