import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/theme.dart';
import 'dart:async';
import 'Api_services/gemini_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'UI_Screens/Widgets/routes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ScaffoldMessengerState global para mostrar SnackBars desde cualquier parte
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Asegurar que los servicios de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno
  await dotenv.load(fileName: ".env");

  // Inicializar el servicio de Gemini (precarga)
  final geminiService = GeminiService();

  // Verificar conexión con el servidor (en segundo plano)
  unawaited(
    geminiService.checkServerConnection().then((isConnected) {
      print(
        'Conexión con el servidor: [32m${isConnected ? 'EXITOSA' : 'FALLIDA'}[0m',
      );

      if (isConnected) {
        // Intentar cargar el menú para tenerlo precargado
        unawaited(
          geminiService.getFullMenu().then((menu) {
            if (menu != null) {
              print('Menú precargado con ${menu.length} platos');
            } else {
              print('⚠️ No se pudo precargar el menú');
            }
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
    bool isConnected = await geminiService.checkServerConnection();

    print(
      'Prueba de conexión con Gemini/Servidor: ${isConnected ? 'EXITOSA' : 'FALLIDA'}',
    );

    if (isConnected) {
      // Si hay conexión, también intentar obtener el menú para verificar funcionalidad completa
      final menu = await geminiService.getFullMenu();
      if (menu != null) {
        print('Verificación completa: Menú obtenido con ${menu.length} platos');
      } else {
        print('⚠️ Conexión establecida pero no se pudo obtener el menú');
      }
    }
  } catch (e) {
    print('Error al probar conexión con Gemini/Servidor: $e');
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
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
