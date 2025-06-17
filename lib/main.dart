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

  // Inicializar configuración de red con timeout mejorado
  print('🌐 Iniciando configuración de red inteligente...');
  final networkService = NetworkConfigService();

  try {
    // Dar más tiempo para el auto-discovery inteligente
    try {
      await networkService.initialize().timeout(
        const Duration(
          seconds: 45,
        ), // Aumentado para dar tiempo al nuevo sistema
        onTimeout: () {
          print(
            '⏰ Timeout en inicialización de red, intentando recuperación...',
          );
          return;
        },
      );
    } catch (e) {
      print('❌ Error en inicialización de red: $e');
    }

    // Verificar si la configuración fue exitosa
    if (!networkService.isConfigured) {
      print(
        '! Configuración inicial fallida, intentando recuperación inteligente...',
      );
      // Intentar recuperación inteligente con timeout RÁPIDO
      final recovered = await networkService.smartRecovery().timeout(
        const Duration(seconds: 8), // Timeout más rápido
        onTimeout: () {
          print('⏰ Timeout en recuperación inteligente (8s)');
          return false;
        },
      );

      if (!recovered) {
        print('❌ No se pudo establecer conexión automática');
        print(
          '🔧 Red configurada con valores por defecto: ${networkService.baseUrl}',
        );
        print(
          '💡 Usa el diagnóstico de red en configuración de chat para conectar automáticamente',
        );
      }
    }
  } catch (e) {
    print('❌ Error en configuración de red: $e');
    print('🔧 Continuando con configuración por defecto');
  }

  // Verificar que NetworkConfigService esté completamente configurado (optimizado)
  print('🔍 Verificando que NetworkConfigService esté configurado...');
  int attempts = 0;
  const maxAttempts = 3; // Reducido para ser más rápido

  while (!networkService.isConfigured && attempts < maxAttempts) {
    attempts++;
    print(
      '⏳ Esperando configuración completa (intento $attempts/$maxAttempts)...',
    );
    await Future.delayed(const Duration(seconds: 1)); // Reducido a 1 segundo
  }

  if (!networkService.isConfigured) {
    print(
      '! NetworkConfigService no está completamente configurado, continuando de todos modos',
    );
  } else {
    print('✅ NetworkConfigService configurado correctamente');
  }

  // PASO 3: Inicializar el servicio de notificaciones (no requiere red)
  await NotificationService.initialize();

  // PASO 3.5: Inicializar GlobalConfigService temprano para sincronización
  print('⚙️ Inicializando GlobalConfigService...');
  try {
    final globalConfig = await Future.delayed(Duration.zero, () {
      final service = GlobalConfigService();
      return service;
    });

    // NUEVO: Migrar configuración de modelo antes de cargar
    await _migrateObsoleteModelConfiguration();

    // Cargar configuración de forma no bloqueante
    unawaited(
      globalConfig
          .loadConfig()
          .then((_) {
            print('✅ GlobalConfigService inicializado exitosamente');
          })
          .catchError((e) {
            print('⚠️ Error al inicializar GlobalConfigService: $e');
          }),
    );
  } catch (e) {
    print('❌ Error al crear GlobalConfigService: $e');
  }

  // PASO 4: Inicializar otros servicios que dependen de la red
  print('🤖 Inicializando servicios que requieren conectividad...');

  // Inicializar el servicio de Gemini (precarga) pero sin bloquear
  final geminiService = GeminiService();

  // PASO 5: Siempre verificar conexión con el servidor (mejorado)
  print('🔌 Verificando conexión con el servidor...');

  // Verificar conexión con el servidor (en segundo plano, sin bloquear la UI)
  unawaited(
    geminiService
        .checkServerConnection()
        .then((isConnected) {
          print(
            'Conexión con el servidor: ${isConnected ? 'EXITOSA' : 'FALLIDA'}',
          );

          if (isConnected) {
            // Intentar cargar el menú para tenerlo precargado (en segundo plano)
            unawaited(
              geminiService.getFullMenu().then((menu) {
                if (menu != null) {
                  print('Menú precargado con ${menu.length} platos');
                } else {
                  print('⚠️ No se pudo precargar el menú');
                }
              }),
            );
          } else {
            // Si no hay conexión, intentar recovery después de unos segundos
            print('🔄 Programando reintento de conexión...');
            unawaited(
              Future.delayed(const Duration(seconds: 10)).then((_) async {
                print('🔄 Reintentando conexión automática...');
                await networkService.refreshConfiguration();
                final retryConnected =
                    await geminiService.checkServerConnection();
                print(
                  'Reintento de conexión: ${retryConnected ? 'EXITOSO' : 'FALLÓ'}',
                );
              }),
            );
          }
        })
        .catchError((e) {
          print('❌ Error en verificación de conexión: $e');
          // Programar reintento en caso de error
          unawaited(
            Future.delayed(const Duration(seconds: 15)).then((_) async {
              print('🔄 Reintentando después de error...');
              await networkService.refreshConfiguration();
            }),
          );
        }),
  );

  // PASO 6: Configurar callback de logout
  setupLogoutCallback();

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
