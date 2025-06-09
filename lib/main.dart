import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/theme.dart';
import 'dart:async';
import 'dart:io';
import 'Api_services/gemini_service.dart';
import 'Api_services/network_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'UI_Screens/Widgets/routes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/notification_service.dart';

// ScaffoldMessengerState global para mostrar SnackBars desde cualquier parte
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Asegurar que los servicios de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno (opcional)
  await _initializeDotenv();

  // Inicializar configuración de red centralizada
  final networkConfig = NetworkConfigService();
  await networkConfig.initialize();
  print('🌐 Red configurada: ${networkConfig.baseUrl}');

  // Inicializar el servicio de notificaciones
  await NotificationService.initialize();

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

Future<void> _initializeDotenv() async {
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Archivo .env cargado correctamente');
  } catch (e) {
    print(
      '⚠️ Archivo .env no encontrado, usando configuración por defecto: $e',
    );
    // Inicializar dotenv con valores por defecto
    try {
      // Crear un mapa con valores por defecto
      const defaultEnvValues = {
        'NODE_SERVER_IP': '192.168.1.121',
        'NODE_SERVER_PORT': '3000',
        'GEMINI_API_KEY_1': 'FALLBACK_KEY_1',
        'GEMINI_API_KEY_2': 'FALLBACK_KEY_2',
        'GEMINI_API_KEY_3': 'FALLBACK_KEY_3',
      };

      // Cargar desde un string con los valores por defecto
      await dotenv.load(
        fileName: ".env.defaults",
        mergeWith: defaultEnvValues,
        isOptional: true,
      );

      // Si aún falla, establecer manualmente
      for (final entry in defaultEnvValues.entries) {
        if (!dotenv.env.containsKey(entry.key)) {
          dotenv.env[entry.key] = entry.value;
        }
      }

      print('✅ Configuración por defecto establecida');
    } catch (fallbackError) {
      print('⚠️ Error estableciendo valores por defecto: $fallbackError');
      // Como último recurso, crear el archivo .env
      await _createDefaultEnvFile();
    }
  }
}

Future<void> _createDefaultEnvFile() async {
  try {
    // Crear el archivo .env con valores por defecto
    const defaultEnvContent = '''
NODE_SERVER_IP=192.168.1.121
NODE_SERVER_PORT=3000
GEMINI_API_KEY_1=FALLBACK_KEY_1
GEMINI_API_KEY_2=FALLBACK_KEY_2
GEMINI_API_KEY_3=FALLBACK_KEY_3
''';

    final envFile = File('.env');
    await envFile.writeAsString(defaultEnvContent);

    // Intentar cargar el archivo recién creado
    await dotenv.load(fileName: ".env");
    print('✅ Archivo .env creado y cargado correctamente');
  } catch (e) {
    print('❌ Error crítico al crear archivo .env: $e');
    print('⚠️ La aplicación continuará sin archivo .env');
    // Si todo falla, al menos la app no crashea
  }
}
