import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/theme.dart';
import 'dart:async';
import 'dart:io';
import 'Api_services/gemini_service.dart';
import 'Api_services/network_config_service.dart';
import 'Api_services/global_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'UI_Screens/Widgets/routes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/notification_service.dart';

// ScaffoldMessengerState global para mostrar SnackBars desde cualquier parte
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar manejo de errores
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🚨 Error no capturado: ${details.exception}');
    print('📍 Stack trace: ${details.stack}');
  };

  // Cargar variables de entorno
  try {
    await dotenv.load();
    print('✅ Variables de entorno cargadas exitosamente');
  } catch (e) {
    print('! Archivo .env no encontrado, usando configuración por defecto: $e');
    print('✅ Configuración por defecto establecida');
  }

  // Limpiar configuraciones obsoletas al inicio
  print('🧹 Limpiando configuraciones obsoletas al inicio...');
  await _cleanObsoleteConfigurations();
  print('✅ No se encontraron configuraciones obsoletas');

  // OPTIMIZACIÓN: Inicialización rápida de red
  print('🌐 Inicializando configuración de red (optimizada)...');
  final networkService = NetworkConfigService();

  try {
    // NUEVO: Verificar primero si ya tenemos configuración válida
    final prefs = await SharedPreferences.getInstance();
    final savedIp =
        prefs.getString('serverIp') ??
        prefs.getString('network_server_ip') ??
        prefs.getString('global_server_ip');

    if (savedIp != null && savedIp.isNotEmpty && _isValidIpFormat(savedIp)) {
      print('✅ IP ya configurada: $savedIp, saltando auto-discovery');
      // Solo hacer una verificación rápida y continuar
      print('🚀 Usando IP guardada para inicio rápido');
    } else {
      print('🔍 No hay IP configurada, iniciando auto-discovery rápido...');
      // Solo hacer auto-discovery si no hay configuración previa
      await networkService.initialize().timeout(
        const Duration(seconds: 5), // Reducido drásticamente
        onTimeout: () {
          print(
            '⏰ Timeout en auto-discovery, usando configuración por defecto',
          );
        },
      );
    }
  } catch (e) {
    print('❌ Error en configuración de red: $e');
    print('🔧 Continuando con configuración por defecto');
  }

  // Simplemente continuar - no forzar más configuración
  print('⚡ Configuración de red completada, continuando...');

  // PASO 3: Inicializar el servicio de notificaciones (no requiere red)
  await NotificationService.initialize();

  // OPTIMIZACIÓN: Todas las demás operaciones se mueven a segundo plano para no bloquear la UI
  print('🚀 Iniciando aplicación con inicio ultra-rápido...');

  // Ejecutar toda la configuración pesada en segundo plano DESPUÉS de que se inicie la app
  unawaited(_initializeBackgroundServices(networkService));

  print('🚀 Iniciando aplicación...');

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
      // Crear un mapa con valores por defecto (sin IP hardcodeada)
      const defaultEnvValues = {
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
    // Crear el archivo .env con valores por defecto (sin IP hardcodeada)
    const defaultEnvContent = '''
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

// NUEVO: Función para limpiar configuraciones obsoletas al inicio
Future<void> _cleanObsoleteConfigurations() async {
  try {
    print('🧹 Limpiando configuraciones obsoletas al inicio...');
    final prefs = await SharedPreferences.getInstance();

    // Lista de IPs obsoletas que debemos limpiar
    const obsoleteIPs = ['192.168.1.121', '192.168.1.136'];
    bool hasChanges = false;

    // Limpiar configuraciones de NetworkConfigService
    final networkServerIp = prefs.getString('network_server_ip');
    if (networkServerIp != null && obsoleteIPs.contains(networkServerIp)) {
      await prefs.remove('network_server_ip');
      await prefs.remove('network_server_port');
      await prefs.remove('network_last_updated');
      await prefs.remove('network_server_info');
      print(
        '🧹 Limpiada configuración obsoleta de NetworkConfigService: $networkServerIp',
      );
      hasChanges = true;
    }

    // Limpiar configuraciones de GlobalConfigService
    final globalServerIp = prefs.getString('global_server_ip');
    if (globalServerIp != null && obsoleteIPs.contains(globalServerIp)) {
      await prefs.remove('global_server_ip');
      print(
        '🧹 Limpiada configuración obsoleta de GlobalConfigService: $globalServerIp',
      );
      hasChanges = true;
    }

    // Limpiar configuraciones legacy
    final legacyServerIp = prefs.getString('serverIp');
    if (legacyServerIp != null && obsoleteIPs.contains(legacyServerIp)) {
      await prefs.remove('serverIp');
      await prefs.remove('serverPort');
      await prefs.remove('lastDiscoveryCheck');
      await prefs.remove('lastSuccessfulConnect');
      print('🧹 Limpiada configuración legacy obsoleta: $legacyServerIp');
      hasChanges = true;
    }

    if (hasChanges) {
      print(
        '✅ Configuraciones obsoletas limpiadas, se activará auto-discovery',
      );
    } else {
      print('✅ No se encontraron configuraciones obsoletas');
    }
  } catch (error) {
    print('⚠️ Error al limpiar configuraciones obsoletas: $error');
  }
}

// Función para validar formato de IP
bool _isValidIpFormat(String ip) {
  final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
  if (!ipRegex.hasMatch(ip)) return false;

  final parts = ip.split('.');
  return parts.every((part) {
    final num = int.tryParse(part);
    return num != null && num >= 0 && num <= 255;
  });
}

// Función para inicializar servicios pesados en segundo plano
Future<void> _initializeBackgroundServices(
  NetworkConfigService networkService,
) async {
  print('⚙️ Inicializando servicios en segundo plano...');

  try {
    // Paso 1: GlobalConfigService
    print('⚙️ Inicializando GlobalConfigService en segundo plano...');
    final globalConfig = GlobalConfigService();

    // Migrar configuración de modelo
    await _migrateObsoleteModelConfiguration();

    // Cargar configuración
    await globalConfig.loadConfig().catchError((e) {
      print('⚠️ Error al cargar GlobalConfigService: $e');
    });
    print('✅ GlobalConfigService inicializado');

    // Paso 2: Inicializar Gemini Service
    print('🤖 Inicializando GeminiService en segundo plano...');
    final geminiService = GeminiService();

    // Paso 3: Verificar conexión (con timeout corto)
    print('🔌 Verificando conexión en segundo plano...');
    final isConnected = await geminiService.checkServerConnection().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('⏰ Timeout en verificación de conexión');
        return false;
      },
    );

    print('Conexión con el servidor: ${isConnected ? 'EXITOSA' : 'FALLIDA'}');

    if (isConnected) {
      // Paso 4: Precargar menú si hay conexión
      print('📋 Precargando menú en segundo plano...');
      final menu = await geminiService.getFullMenu().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ Timeout en precarga de menú');
          return null;
        },
      );

      if (menu != null) {
        print('✅ Menú precargado con ${menu.length} platos');
      } else {
        print('⚠️ No se pudo precargar el menú');
      }
    } else {
      // Programar reintento para más tarde
      print('🔄 Programando reintento de conexión para más tarde...');
      Future.delayed(const Duration(seconds: 30), () async {
        print('🔄 Reintentando conexión automática...');
        try {
          await networkService.refreshConfiguration();
          final retryConnected = await geminiService.checkServerConnection();
          print(
            'Reintento de conexión: ${retryConnected ? 'EXITOSO' : 'FALLÓ'}',
          );
        } catch (e) {
          print('❌ Error en reintento: $e');
        }
      });
    }

    print('✅ Inicialización de servicios en segundo plano completada');
  } catch (e) {
    print('❌ Error en inicialización de servicios en segundo plano: $e');
  }
}

// NUEVO: Función para migrar configuraciones obsoletas al nuevo modelo
Future<void> _migrateObsoleteModelConfiguration() async {
  try {
    print('🔄 Verificando migración de modelo de Gemini...');
    final prefs = await SharedPreferences.getInstance();

    final currentSavedModel = prefs.getString('global_gemini_model');
    const obsoleteModels = ['gemini-2.0-flash', 'gemini-1.5-flash'];
    const newDefaultModel = 'gemini-2.5-flash-preview-05-20';

    // Si tiene un modelo obsoleto o no tiene modelo guardado, actualizar
    if (currentSavedModel == null ||
        obsoleteModels.contains(currentSavedModel)) {
      await prefs.setString('global_gemini_model', newDefaultModel);
      print('✅ Modelo migrado de "$currentSavedModel" a "$newDefaultModel"');
    } else if (currentSavedModel != newDefaultModel) {
      // NUEVO: Forzar migración a 2.5 preview si no es exactamente el correcto
      await prefs.setString('global_gemini_model', newDefaultModel);
      print(
        '🔄 Modelo actualizado de "$currentSavedModel" a "$newDefaultModel" (migración forzada)',
      );
    } else {
      print('✅ Modelo actual "$currentSavedModel" ya está actualizado');
    }

    // NUEVO: También limpiar cualquier configuración de modelo obsoleta en otras claves
    final networkModel = prefs.getString('gemini_model_name');
    if (networkModel != null && obsoleteModels.contains(networkModel)) {
      await prefs.remove('gemini_model_name');
      print('🧹 Configuración de modelo obsoleta limpiada: gemini_model_name');
    }
  } catch (e) {
    print('⚠️ Error en migración de modelo: $e');
  }
}
