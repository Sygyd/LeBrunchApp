import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:audioplayers/audioplayers.dart';
import 'gemini_api_client.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Instancias de los servicios
  AudioRecorder? _audioRecorder;
  stt.SpeechToText? _speechToText;
  AudioPlayer? _audioPlayer;
  GeminiApiClient? _geminiClient;

  // Estados
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _speechEnabled = false;
  bool _isDisposed = false;
  String? _currentRecordingPath;

  // Información de diagnóstico del último intento
  double? _lastMaxSoundLevel;
  bool? _lastHadDetectedSound;

  // Variables para capturar errores durante la grabación
  String? _currentError;
  bool _hasCurrentError = false;

  // Getters
  bool get isRecording => _isRecording;
  bool get isInitialized => _isInitialized && !_isDisposed;
  bool get speechEnabled => _speechEnabled && !_isDisposed;

  /// Inicializar el servicio de audio con manejo robusto de errores
  Future<bool> initialize() async {
    // Resetear el estado disposed si se intenta reinicializar
    if (_isDisposed) {
      print(
        '🔄 AudioService: Reseteando estado disposed para reinicialización',
      );
      _isDisposed = false;
    }

    // Si ya está inicializado, no hacer nada
    if (_isInitialized && !_isDisposed) {
      print('✅ AudioService: Ya está inicializado');
      return true;
    }

    try {
      print('🎤 Inicializando AudioService...');

      // Inicializar instancias de forma segura
      _audioRecorder ??= AudioRecorder();
      _speechToText ??= stt.SpeechToText();
      _audioPlayer ??= AudioPlayer();

      // Inicializar cliente de Gemini para fallback de audio
      try {
        _geminiClient ??= GeminiApiClient(); // Usar configuración simple
        print('✅ Cliente de Gemini inicializado para procesamiento de audio');
      } catch (e) {
        print('⚠️ No se pudo inicializar cliente de Gemini: $e');
        // No es crítico, el servicio puede funcionar sin este fallback
      }

      // Verificar disponibilidad de funciones de audio
      if (!await _checkAudioAvailability()) {
        print('❌ Funciones de audio no disponibles en este dispositivo');
        return false;
      }

      // Solicitar permisos con timeout
      final hasPermissions = await _requestPermissions().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ Timeout al solicitar permisos');
          return false;
        },
      );

      if (!hasPermissions) {
        print('❌ No se obtuvieron los permisos necesarios');
        return false;
      }

      // Inicializar speech-to-text con manejo de errores mejorado y reintentos
      int speechInitAttempts = 0;
      const maxSpeechAttempts = 3;

      while (!_speechEnabled && speechInitAttempts < maxSpeechAttempts) {
        speechInitAttempts++;
        print(
          '🔧 Intento $speechInitAttempts/$maxSpeechAttempts de inicializar Speech-to-Text...',
        );

        try {
          // Recrear instancia en cada intento si es necesario
          if (speechInitAttempts > 1) {
            _speechToText = stt.SpeechToText();
            await Future.delayed(
              const Duration(milliseconds: 500),
            ); // Pequeña pausa
          }

          _speechEnabled = await _speechToText!
              .initialize(
                onError: (error) {
                  print(
                    '❌ Error en Speech-to-Text (intento $speechInitAttempts): ${error.errorMsg}',
                  );
                  _speechEnabled = false;

                  // Capturar error para uso durante la grabación
                  _currentError = error.errorMsg;
                  _hasCurrentError = true;
                },
                onStatus: (status) {
                  print(
                    '🔊 Estado Speech-to-Text (intento $speechInitAttempts): $status',
                  );

                  // Detectar estados de error adicionales
                  if (status == 'error' || status.contains('error')) {
                    _hasCurrentError = true;
                    if (_currentError == null) {
                      _currentError = status;
                    }
                  }
                },
              )
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  print(
                    '⏰ Timeout al inicializar Speech-to-Text (intento $speechInitAttempts)',
                  );
                  return false;
                },
              );

          if (_speechEnabled) {
            print(
              '✅ Speech-to-Text inicializado exitosamente en intento $speechInitAttempts',
            );
            break;
          } else {
            print('❌ Fallo en intento $speechInitAttempts de Speech-to-Text');
          }
        } catch (e) {
          print(
            '❌ Error crítico al inicializar Speech-to-Text (intento $speechInitAttempts): $e',
          );
          _speechEnabled = false;

          // Pausa antes del siguiente intento
          if (speechInitAttempts < maxSpeechAttempts) {
            await Future.delayed(
              Duration(milliseconds: 1000 * speechInitAttempts),
            );
          }
        }
      }

      if (!_speechEnabled) {
        print(
          '❌ No se pudo inicializar Speech-to-Text después de $maxSpeechAttempts intentos',
        );
        print(
          '⚠️ Continuando sin speech-to-text, solo grabación básica disponible',
        );
      } else {
        print('✅ Speech-to-Text inicializado correctamente');
      }

      _isInitialized = true;
      print('✅ AudioService inicializado correctamente');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error crítico al inicializar AudioService: $e');
      print('📍 StackTrace: $stackTrace');
      _isInitialized = false;
      return false;
    }
  }

  /// Verificar disponibilidad de funciones de audio
  Future<bool> _checkAudioAvailability() async {
    try {
      // Verificar si el dispositivo soporta grabación
      if (Platform.isAndroid || Platform.isIOS) {
        return true; // Asumimos que dispositivos móviles soportan audio
      }

      // Para otras plataformas, hacer verificación más específica
      return false;
    } catch (e) {
      print('❌ Error al verificar disponibilidad de audio: $e');
      return false;
    }
  }

  /// Solicitar permisos necesarios con manejo robusto
  Future<bool> _requestPermissions() async {
    try {
      print('🔐 Solicitando permisos de audio...');

      // Verificar estado actual del permiso de micrófono
      var microphoneStatus = await Permission.microphone.status;
      print('🎤 Estado actual del micrófono: $microphoneStatus');

      // Si ya está concedido, continuar
      if (microphoneStatus == PermissionStatus.granted) {
        print('✅ Permiso de micrófono ya concedido');
      } else if (microphoneStatus == PermissionStatus.denied) {
        // Solicitar permiso
        microphoneStatus = await Permission.microphone.request();
        print('🎤 Resultado de solicitud de micrófono: $microphoneStatus');
      } else if (microphoneStatus == PermissionStatus.permanentlyDenied) {
        print('❌ Permiso de micrófono permanentemente denegado');
        return false;
      }

      if (microphoneStatus != PermissionStatus.granted) {
        print('❌ Permiso de micrófono denegado');
        return false;
      }

      // En Android, manejar permisos de almacenamiento de forma opcional
      if (Platform.isAndroid) {
        try {
          var storageStatus = await Permission.storage.status;
          if (storageStatus == PermissionStatus.denied) {
            storageStatus = await Permission.storage.request();
          }

          if (storageStatus != PermissionStatus.granted) {
            // Intentar con el nuevo permiso de Android 13+
            var manageStorageStatus =
                await Permission.manageExternalStorage.status;
            if (manageStorageStatus == PermissionStatus.denied) {
              manageStorageStatus =
                  await Permission.manageExternalStorage.request();
            }

            if (manageStorageStatus != PermissionStatus.granted) {
              print(
                '⚠️ Permiso de almacenamiento denegado, pero continuando...',
              );
              // No es crítico, podemos usar directorio temporal
            }
          }
        } catch (e) {
          print('⚠️ Error al solicitar permisos de almacenamiento: $e');
          // Continuamos sin permisos de almacenamiento
        }
      }

      print('✅ Permisos obtenidos correctamente');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error crítico al solicitar permisos: $e');
      print('📍 StackTrace: $stackTrace');
      return false;
    }
  }

  /// Iniciar grabación de audio con validaciones mejoradas
  Future<bool> startRecording() async {
    if (_isDisposed) {
      print('❌ AudioService disposed, no se puede grabar');
      return false;
    }

    try {
      if (!_isInitialized) {
        print(
          '❌ AudioService no está inicializado, intentando reinicializar...',
        );
        final reinitialized = await initialize();
        if (!reinitialized) {
          print('❌ No se pudo reinicializar AudioService');
          return false;
        }
      }

      if (_isRecording) {
        print('⚠️ Ya se está grabando');
        return false;
      }

      // Verificar y reinicializar AudioRecorder si es necesario
      if (_audioRecorder == null) {
        print('🔄 AudioRecorder es null, creando nueva instancia...');
        _audioRecorder = AudioRecorder();
      }

      // Verificar permisos antes de grabar
      bool canRecord = false;
      try {
        canRecord = await _audioRecorder!.hasPermission();
      } catch (e) {
        print('❌ Error al verificar permisos: $e');
        // Intentar recrear el AudioRecorder
        print('🔄 Recreando AudioRecorder...');
        try {
          await _audioRecorder?.dispose();
        } catch (disposeError) {
          print('⚠️ Error al limpiar AudioRecorder anterior: $disposeError');
        }
        _audioRecorder = AudioRecorder();
        canRecord = await _audioRecorder!.hasPermission();
      }

      if (!canRecord) {
        print('❌ No hay permisos para grabar');
        return false;
      }

      // Crear directorio temporal para el audio de forma segura
      Directory? tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (e) {
        print('❌ Error al obtener directorio temporal: $e');
        return false;
      }

      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = path.join(tempDir.path, fileName);

      // Configurar la grabación con parámetros optimizados para reconocimiento
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000, // Optimizado para speech-to-text
        numChannels: 1, // Mono para mejor reconocimiento
      );

      // Verificar estado del AudioRecorder antes de iniciar
      try {
        final isRecording = await _audioRecorder!.isRecording();
        if (isRecording) {
          print('⚠️ AudioRecorder ya está grabando, deteniéndolo...');
          await _audioRecorder!.stop();
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        print('⚠️ Error al verificar estado de grabación: $e');
      }

      // Iniciar grabación con timeout y mejor manejo de errores
      try {
        await _audioRecorder!
            .start(config, path: _currentRecordingPath!)
            .timeout(
              const Duration(seconds: 10), // Aumentar timeout
              onTimeout: () {
                print('⏰ Timeout al iniciar grabación');
                throw Exception('Timeout al iniciar grabación');
              },
            );

        _isRecording = true;
        print('🎤 Grabación iniciada exitosamente: $_currentRecordingPath');
        return true;
      } catch (startError) {
        print('❌ Error específico al iniciar grabación: $startError');

        // Intentar una vez más con AudioRecorder nuevo
        print('🔄 Reintentando con AudioRecorder nuevo...');
        try {
          await _audioRecorder?.dispose();
          _audioRecorder = AudioRecorder();

          // Verificar permisos nuevamente
          final hasPermission = await _audioRecorder!.hasPermission();
          if (!hasPermission) {
            print('❌ Permisos perdidos durante reintento');
            return false;
          }

          await _audioRecorder!
              .start(config, path: _currentRecordingPath!)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  print('⏰ Timeout en reintento de grabación');
                  throw Exception('Timeout en reintento');
                },
              );

          _isRecording = true;
          print('🎤 Grabación iniciada en reintento: $_currentRecordingPath');
          return true;
        } catch (retryError) {
          print('❌ Error en reintento de grabación: $retryError');
          _isRecording = false;
          return false;
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error crítico al iniciar grabación: $e');
      print('📍 StackTrace: $stackTrace');
      _isRecording = false;

      // Intentar limpiar el estado
      try {
        await _audioRecorder?.dispose();
        _audioRecorder = AudioRecorder();
      } catch (cleanupError) {
        print('⚠️ Error al limpiar después de fallo: $cleanupError');
      }

      return false;
    }
  }

  /// Detener grabación de audio con manejo seguro
  Future<String?> stopRecording() async {
    if (_isDisposed) {
      print('❌ AudioService disposed, no se puede detener grabación');
      return null;
    }

    try {
      if (!_isRecording) {
        print('⚠️ No se está grabando');
        return null;
      }

      if (_audioRecorder == null) {
        print('❌ AudioRecorder no está disponible');
        return null;
      }

      // Detener grabación con timeout
      final path = await _audioRecorder!.stop().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ Timeout al detener grabación');
          return null;
        },
      );

      _isRecording = false;

      if (path != null && path.isNotEmpty) {
        print('✅ Grabación detenida: $path');
        return path;
      } else {
        print('❌ No se pudo obtener el archivo de audio');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error al detener grabación: $e');
      print('📍 StackTrace: $stackTrace');
      _isRecording = false;
      return null;
    }
  }

  /// Convertir audio a texto con manejo robusto de errores
  Future<String?> convertAudioToText({
    String locale = 'es_ES',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_isDisposed) {
      print('❌ AudioService disposed, no se puede convertir audio');
      return null;
    }

    try {
      // Verificar y reparar el estado del Speech-to-Text si es necesario
      if (!_speechEnabled || _speechToText == null) {
        print('❌ Speech-to-Text no está habilitado, intentando reparar...');

        // Intentar reparar el estado
        final repaired = await verifyAndRepairState();
        if (!repaired || !_speechEnabled || _speechToText == null) {
          print('❌ No se pudo reparar Speech-to-Text');
          return null;
        }

        print('✅ Speech-to-Text reparado, continuando con conversión...');
      }

      print('🔊 Iniciando conversión de audio a texto...');

      // Resetear variables de error
      _currentError = null;
      _hasCurrentError = false;

      // Verificar idiomas disponibles con timeout
      List<stt.LocaleName> locales = [];
      try {
        locales = await _speechToText!.locales().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('⏰ Timeout al obtener idiomas');
            return <stt.LocaleName>[];
          },
        );
      } catch (e) {
        print('❌ Error al obtener idiomas: $e');
        locales = [];
      }

      print(
        '🌐 Idiomas disponibles: ${locales.map((l) => l.localeId).join(', ')}',
      );

      // Buscar el idioma español más apropiado
      String selectedLocale = locale;
      if (locales.isNotEmpty) {
        final spanishLocales =
            locales
                .where(
                  (l) =>
                      l.localeId.startsWith('es') ||
                      l.localeId.contains('Spanish') ||
                      l.localeId.contains('Español'),
                )
                .toList();

        if (spanishLocales.isNotEmpty) {
          selectedLocale = spanishLocales.first.localeId;
          print('🇪🇸 Usando idioma: $selectedLocale');
        } else {
          // Intentar con es_US si está disponible
          final esUS = locales.where((l) => l.localeId == 'es_US').firstOrNull;
          if (esUS != null) {
            selectedLocale = 'es_US';
            print('🇺🇸 Usando español de US: $selectedLocale');
          } else {
            selectedLocale = locales.first.localeId;
            print('⚠️ No se encontró español, usando: $selectedLocale');
          }
        }
      }

      String recognizedText = '';
      bool isCompleted = false;
      bool hasError = false;
      String? errorCode;
      double maxSoundLevel = 0.0;
      bool hasDetectedSound = false;

      // Configurar listeners de error mejorados
      void onError(error) {
        hasError = true;
        errorCode = error.toString();
        print('❌ Error en Speech-to-Text (intento 1): $error');
        print('🔍 Tipo de error detectado: ${error.runtimeType}');

        // Forzar completado para que se procese el error
        isCompleted = true;
      }

      void onStatus(String status) {
        print('🔊 Estado Speech-to-Text: $status');
        if (status == 'done' || status == 'notListening') {
          isCompleted = true;
        }

        // Detectar estados de error adicionales
        if (status == 'error' || status.contains('error')) {
          hasError = true;
          if (errorCode == null) {
            errorCode = status;
          }
          isCompleted = true;
        }
      }

      // Iniciar reconocimiento de voz con configuración mejorada
      try {
        // Configuración inicial adaptativa basada en experiencia previa
        Duration initialTimeout = const Duration(
          seconds: 15,
        ); // Reducir timeout inicial
        Duration initialPause = const Duration(seconds: 1);
        stt.ListenMode initialMode =
            stt.ListenMode.dictation; // Cambiar a dictation por defecto

        // Si hay información previa de volumen alto, usar configuración específica
        if (_lastMaxSoundLevel != null && _lastMaxSoundLevel! > 0.8) {
          initialTimeout = const Duration(seconds: 10);
          initialPause = const Duration(milliseconds: 800);
          initialMode = stt.ListenMode.dictation;
          print(
            '🔧 Usando configuración inicial para volumen alto detectado previamente',
          );
        }

        await _speechToText!.listen(
          onResult: (result) {
            if (!_isDisposed) {
              recognizedText = result.recognizedWords;
              isCompleted = result.finalResult;
              print(
                '🎯 Texto reconocido: "$recognizedText" (Final: $isCompleted, Confianza: ${result.confidence})',
              );
            }
          },
          onSoundLevelChange: (level) {
            // Monitorear nivel de sonido para diagnosticar problemas
            if (level > maxSoundLevel) {
              maxSoundLevel = level;
            }
            if (level > 0.1) {
              hasDetectedSound = true;
              print(
                '🔊 Nivel de sonido: ${level.toStringAsFixed(2)} (Max: ${maxSoundLevel.toStringAsFixed(2)})',
              );
            }

            // Detectar si el volumen es demasiado alto (gritando)
            if (level > 0.8) {
              print(
                '⚠️ Volumen muy alto detectado: ${level.toStringAsFixed(2)} - Puede afectar el reconocimiento',
              );
            }
          },

          localeId: selectedLocale,
          listenFor: initialTimeout,
          pauseFor: initialPause,
          partialResults: true,
          cancelOnError: false, // No cancelar automáticamente en errores
          listenMode: initialMode,
        );
      } catch (e) {
        print('❌ Error al iniciar reconocimiento: $e');
        return null;
      }

      // Esperar a que termine el reconocimiento con timeout mejorado
      int attempts = 0;
      const maxAttempts = 60; // 30 segundos máximo
      while (!isCompleted &&
          !hasError &&
          !_hasCurrentError &&
          !_isDisposed &&
          _speechToText!.isListening &&
          attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;

        // Verificar si hay error global capturado
        if (_hasCurrentError && _currentError != null) {
          print('🔍 Error global detectado: $_currentError');
          hasError = true;
          errorCode = _currentError;
          break;
        }

        // Log de progreso cada 5 segundos
        if (attempts % 10 == 0) {
          print('⏳ Esperando reconocimiento... ${attempts * 0.5}s');
        }
      }

      // Verificación adicional: si no hay texto y no hay error detectado,
      // pero se detectó sonido alto, asumir error_no_match
      if (!hasError &&
          !_hasCurrentError &&
          recognizedText.isEmpty &&
          maxSoundLevel > 0.8 &&
          hasDetectedSound) {
        print(
          '🔍 Detectando error_no_match implícito por volumen alto sin resultado',
        );
        hasError = true;
        errorCode = 'error_no_match';
      }

      // Verificar también si hay error global sin error local
      if (!hasError && _hasCurrentError && _currentError != null) {
        print('🔍 Aplicando error global capturado: $_currentError');
        hasError = true;
        errorCode = _currentError;
      }

      // Detener el reconocimiento si aún está activo
      try {
        if (!_isDisposed && _speechToText!.isListening) {
          await _speechToText!.stop();
          print('⏹️ Reconocimiento detenido manualmente');
        }
      } catch (e) {
        print('⚠️ Error al detener reconocimiento: $e');
      }

      // Manejo de errores específicos
      if (hasError) {
        print('❌ Error durante el reconocimiento de voz: $errorCode');
        print('📊 Contexto del error:');
        print('   - Texto reconocido: "${recognizedText}"');
        print(
          '   - Nivel máximo de sonido: ${maxSoundLevel.toStringAsFixed(2)}',
        );
        print('   - Sonido detectado: $hasDetectedSound');
        print('   - Speech habilitado: $_speechEnabled');

        // Manejar errores específicos que pueden ser recuperables
        if (errorCode == 'error_no_match' ||
            errorCode == 'error_client' ||
            errorCode == 'error_speech_timeout' ||
            errorCode?.contains('timeout') == true) {
          print(
            '🔄 Error recuperable detectado: $errorCode, reintentando con configuración alternativa...',
          );

          // Para error_no_match, intentar múltiples configuraciones
          if (errorCode == 'error_no_match') {
            print('🎯 Manejo específico para error_no_match...');
            print(
              '💡 Consejo específico: ${getRecognitionTips(maxSoundLevel, hasDetectedSound)}',
            );

            // Primer reintento con configuración optimizada
            final firstRetry = await _retryWithAlternativeConfig(
              selectedLocale,
              maxSoundLevel,
              hasDetectedSound,
            );

            if (firstRetry != null && firstRetry.isNotEmpty) {
              print('✅ Primer reintento exitoso: "$firstRetry"');
              return firstRetry;
            }

            // Segundo reintento con configuración mínima
            print('🔄 Segundo reintento con configuración mínima...');
            final secondRetry = await _finalRetryWithMinimalConfig(
              selectedLocale,
            );

            if (secondRetry != null && secondRetry.isNotEmpty) {
              print('✅ Segundo reintento exitoso: "$secondRetry"');
              return secondRetry;
            }

            print('❌ Todos los reintentos fallaron para error_no_match');
            return null;
          }

          return await _retryWithAlternativeConfig(
            selectedLocale,
            maxSoundLevel,
            hasDetectedSound,
          );
        }

        // Para otros errores, intentar una vez más con configuración básica
        if (recognizedText.isEmpty) {
          print('🔄 Último intento con configuración básica...');
          return await _retryWithAlternativeConfig(
            selectedLocale,
            maxSoundLevel,
            hasDetectedSound,
          );
        }

        return null;
      }

      // Guardar información de diagnóstico para uso posterior
      _lastMaxSoundLevel = maxSoundLevel;
      _lastHadDetectedSound = hasDetectedSound;

      if (recognizedText.isNotEmpty) {
        print('✅ Conversión completada: "$recognizedText"');
        return recognizedText;
      } else {
        // Diagnosticar el problema basado en el nivel de sonido
        String diagnosticMessage = '❌ No se pudo reconocer texto del audio';

        if (!hasDetectedSound) {
          diagnosticMessage += ' - No se detectó sonido suficiente';
          print('🔇 $diagnosticMessage');
        } else if (maxSoundLevel > 0.8) {
          diagnosticMessage +=
              ' - Volumen demasiado alto (${maxSoundLevel.toStringAsFixed(2)})';
          print('📢 $diagnosticMessage');
        } else if (maxSoundLevel < 0.2) {
          diagnosticMessage +=
              ' - Volumen demasiado bajo (${maxSoundLevel.toStringAsFixed(2)})';
          print('🔉 $diagnosticMessage');
        } else {
          diagnosticMessage +=
              ' - Nivel de sonido normal (${maxSoundLevel.toStringAsFixed(2)})';
          print('🎤 $diagnosticMessage');
        }

        // Intentar con configuración alternativa
        print('🔄 Reintentando con configuración alternativa...');
        return await _retryWithAlternativeConfig(
          selectedLocale,
          maxSoundLevel,
          hasDetectedSound,
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error crítico al convertir audio a texto: $e');
      print('📍 StackTrace: $stackTrace');
      return null;
    }
  }

  /// Reintentar reconocimiento con configuración alternativa
  Future<String?> _retryWithAlternativeConfig(
    String locale, [
    double? maxSoundLevel,
    bool? hasDetectedSound,
  ]) async {
    if (_isDisposed) return null;

    try {
      print('🔄 Reintentando reconocimiento con configuración alternativa...');

      // Configuración más robusta para errores de timeout y cliente
      Duration listenDuration = const Duration(
        seconds: 10,
      ); // Reducir timeout inicial
      Duration pauseDuration = const Duration(milliseconds: 800);
      stt.ListenMode listenMode = stt.ListenMode.dictation;

      if (maxSoundLevel != null && hasDetectedSound != null) {
        if (maxSoundLevel > 0.8) {
          // Para volumen alto, usar configuración más tolerante y corta
          listenDuration = const Duration(seconds: 8);
          pauseDuration = const Duration(seconds: 1);
          listenMode = stt.ListenMode.confirmation;
          print('🔧 Configuración para volumen alto (timeout reducido)');
        } else if (maxSoundLevel < 0.2) {
          // Para volumen bajo, usar configuración más sensible pero no muy larga
          listenDuration = const Duration(seconds: 12);
          pauseDuration = const Duration(milliseconds: 500);
          listenMode = stt.ListenMode.dictation;
          print('🔧 Configuración para volumen bajo (timeout moderado)');
        } else if (!hasDetectedSound) {
          // Si no se detectó sonido, usar configuración moderada
          listenDuration = const Duration(seconds: 15);
          pauseDuration = const Duration(milliseconds: 600);
          listenMode = stt.ListenMode.dictation;
          print('🔧 Configuración para mejorar detección de sonido');
        } else {
          // Configuración estándar para errores de cliente/timeout
          listenDuration = const Duration(seconds: 8);
          pauseDuration = const Duration(milliseconds: 800);
          listenMode = stt.ListenMode.dictation;
          print('🔧 Configuración estándar para errores de cliente/timeout');
        }
      } else {
        // Configuración por defecto para errores sin diagnóstico previo
        listenDuration = const Duration(seconds: 10);
        pauseDuration = const Duration(milliseconds: 1000);
        listenMode = stt.ListenMode.dictation;
        print('🔧 Configuración por defecto para reintento');
      }

      String recognizedText = '';
      bool isCompleted = false;
      bool hasError = false;

      await _speechToText!.listen(
        onResult: (result) {
          if (!_isDisposed) {
            recognizedText = result.recognizedWords;
            isCompleted = result.finalResult;
            print(
              '🎯 Reintento - Texto: "$recognizedText" (Final: $isCompleted, Confianza: ${result.confidence})',
            );
          }
        },
        onSoundLevelChange: (level) {
          if (level > 0.1) {
            print('🔊 Reintento - Nivel: ${level.toStringAsFixed(2)}');
          }

          // Detectar errores implícitos en reintentos también
          if (level > 0.9) {
            print(
              '⚠️ Reintento - Volumen extremadamente alto: ${level.toStringAsFixed(2)}',
            );
          }
        },
        localeId: locale,
        listenFor: listenDuration,
        pauseFor: pauseDuration,
        partialResults:
            true, // Permitir resultados parciales para mejor feedback
        cancelOnError: false, // No cancelar automáticamente
        listenMode: listenMode,
      );

      // Esperar resultado con timeout ajustado
      int attempts = 0;
      final maxAttempts =
          (listenDuration.inSeconds * 2); // Ajustar según duración configurada
      while (!isCompleted &&
          !hasError &&
          !_isDisposed &&
          _speechToText!.isListening &&
          attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      try {
        if (!_isDisposed && _speechToText!.isListening) {
          await _speechToText!.stop();
        }
      } catch (e) {
        print('⚠️ Error al detener reintento: $e');
      }

      if (recognizedText.isNotEmpty) {
        print('✅ Reintento exitoso: "$recognizedText"');
        return recognizedText;
      } else {
        print('❌ Reintento falló - intentando configuración mínima...');
        return await _finalRetryWithMinimalConfig(locale);
      }
    } catch (e) {
      print('❌ Error en reintento: $e');
      return null;
    }
  }

  /// Último intento con configuración mínima
  Future<String?> _finalRetryWithMinimalConfig(String locale) async {
    if (_isDisposed) return null;

    try {
      print('🔄 Último intento con configuración mínima...');

      String recognizedText = '';
      bool isCompleted = false;

      // Configuración mínima y más simple
      await _speechToText!.listen(
        onResult: (result) {
          if (!_isDisposed) {
            recognizedText = result.recognizedWords;
            isCompleted = result.finalResult;
            print(
              '🎯 Último intento - Texto: "$recognizedText" (Final: $isCompleted)',
            );
          }
        },
        localeId: locale,
        listenFor: const Duration(seconds: 5), // Muy corto
        pauseFor: const Duration(milliseconds: 500), // Pausa corta
        partialResults: false, // Solo resultados finales
        cancelOnError: true, // Cancelar en errores
        listenMode: stt.ListenMode.dictation,
      );

      // Esperar resultado con timeout muy corto
      int attempts = 0;
      const maxAttempts = 10; // 5 segundos máximo
      while (!isCompleted &&
          !_isDisposed &&
          _speechToText!.isListening &&
          attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      try {
        if (!_isDisposed && _speechToText!.isListening) {
          await _speechToText!.stop();
        }
      } catch (e) {
        print('⚠️ Error al detener último intento: $e');
      }

      if (recognizedText.isNotEmpty) {
        print('✅ Último intento exitoso: "$recognizedText"');
        return recognizedText;
      } else {
        print('❌ Todos los intentos fallaron');
        return null;
      }
    } catch (e) {
      print('❌ Error en último intento: $e');
      return null;
    }
  }

  /// Nuevo método: Convertir audio a texto usando Gemini como fallback
  /// Se usa cuando el Speech-to-Text local falla completamente
  Future<String?> convertAudioToTextWithGemini(
    String audioFilePath, {
    String sessionId = 'audio_fallback_session',
    String languageCode = 'es',
  }) async {
    if (_isDisposed) {
      print('❌ AudioService disposed, no se puede usar Gemini fallback');
      return null;
    }

    if (_geminiClient == null) {
      print('❌ Cliente de Gemini no está disponible para fallback');
      return null;
    }

    try {
      print('🤖 Iniciando conversión de audio con Gemini (fallback)...');
      print('📁 Archivo de audio: $audioFilePath');
      print('🆔 Session ID: $sessionId');
      print('🌐 Idioma: $languageCode');

      // Verificar que el archivo existe
      final file = File(audioFilePath);
      if (!await file.exists()) {
        print('❌ Archivo de audio no existe para Gemini: $audioFilePath');
        return null;
      }

      // Verificar el tamaño del archivo
      final fileSize = await file.length();
      print('📊 Tamaño del archivo para Gemini: ${fileSize} bytes');

      if (fileSize == 0) {
        print('❌ Archivo de audio está vacío');
        return null;
      }

      if (fileSize > 10 * 1024 * 1024) {
        print('❌ Archivo demasiado grande para Gemini (${fileSize} bytes)');
        return null;
      }

      // Llamar a Gemini para procesar el audio
      final result = await _geminiClient!.processAudioWithGemini(
        audioFilePath,
        sessionId: sessionId,
        languageCode: languageCode,
        timeout: 45, // Timeout más largo para Gemini
      );

      if (result != null) {
        final success = result['success'] as bool? ?? false;
        final textResponse = result['text_response'] as String?;
        final transcribedText = result['transcribed_text'] as String?;
        final error = result['error'] as String?;

        print('📬 Respuesta de Gemini recibida:');
        print('   ✅ Éxito: $success');
        print('   📝 Texto de respuesta: $textResponse');
        print('   🎯 Texto transcrito: $transcribedText');
        print('   ❌ Error: $error');

        if (success && transcribedText != null && transcribedText.isNotEmpty) {
          print('✅ Gemini transcribió exitosamente: "$transcribedText"');
          return transcribedText;
        } else if (success && textResponse != null && textResponse.isNotEmpty) {
          // Si no hay transcribed_text pero hay text_response, usar eso
          print('✅ Gemini procesó audio con respuesta: "$textResponse"');
          return textResponse;
        } else {
          print('❌ Gemini no pudo transcribir el audio: $error');
          return null;
        }
      } else {
        print('❌ No se recibió respuesta de Gemini');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error crítico al usar Gemini fallback: $e');
      print('📍 StackTrace: $stackTrace');
      return null;
    }
  }

  /// Procesar audio y devolver respuesta completa de Gemini
  /// Incluye tanto transcripción como posibles acciones de carrito
  Future<Map<String, dynamic>?> processAudioWithGeminiComplete(
    String audioFilePath, {
    String sessionId = 'audio_complete_session',
    String languageCode = 'es',
  }) async {
    if (_isDisposed) {
      print('❌ AudioService disposed, no se puede usar Gemini completo');
      return null;
    }

    if (_geminiClient == null) {
      print('❌ Cliente de Gemini no disponible para procesamiento completo');
      return null;
    }

    try {
      print('🤖 Procesando audio con Gemini (${sessionId})...');

      // Verificar que el archivo existe
      final file = File(audioFilePath);
      if (!await file.exists()) {
        print('❌ Archivo de audio no existe: $audioFilePath');
        return null;
      }

      // Verificar el tamaño del archivo
      final fileSize = await file.length();
      if (fileSize == 0) {
        print('❌ Archivo de audio está vacío');
        return null;
      }

      if (fileSize > 10 * 1024 * 1024) {
        print('❌ Archivo demasiado grande (${fileSize} bytes)');
        return null;
      }

      // Llamar a Gemini para procesar el audio
      final result = await _geminiClient!.processAudioWithGemini(
        audioFilePath,
        sessionId: sessionId,
        languageCode: languageCode,
        timeout: 45,
      );

      if (result != null) {
        final success = result['success'] as bool? ?? false;
        final textResponse = result['text_response'] as String?;
        final transcribedText = result['transcribed_text'] as String?;

        if (success) {
          // Si hay texto transcrito, enviarlo a Brunchy para procesamiento completo
          final textToProcess = transcribedText ?? textResponse;

          if (textToProcess != null && textToProcess.isNotEmpty) {
            print(
              '🔄 Enviando a Brunchy: "${textToProcess.length > 30 ? textToProcess.substring(0, 30) + '...' : textToProcess}"',
            );

            // Usar el cliente de Gemini para enviar el texto transcrito a Brunchy
            final brunchyResponse = await _geminiClient!.generateContent(
              textToProcess,
              sessionId: sessionId,
            );

            if (brunchyResponse != null) {
              print('✅ Respuesta completa de Brunchy recibida');

              // Agregar información del audio original
              brunchyResponse['original_audio_path'] = audioFilePath;
              brunchyResponse['transcribed_text'] = textToProcess;
              brunchyResponse['audio_duration'] = await _getAudioDuration(
                audioFilePath,
              );

              return brunchyResponse;
            } else {
              return {
                'text_response': textToProcess,
                'transcribed_text': textToProcess,
                'original_audio_path': audioFilePath,
                'audio_duration': await _getAudioDuration(audioFilePath),
              };
            }
          }
        } else {
          print('❌ Gemini no pudo procesar el audio');
        }
      }

      return null;
    } catch (e) {
      print('❌ Error al procesar audio completo con Gemini: $e');
      return null;
    }
  }

  /// Método auxiliar para obtener la duración del audio
  Future<int?> _getAudioDuration(String audioFilePath) async {
    try {
      // Esto es una estimación simple, en una implementación real
      // podrías usar una librería para obtener la duración exacta
      final file = File(audioFilePath);
      final fileSize = await file.length();

      // Estimación aproximada: 1 segundo por cada 16KB (para audio comprimido)
      final estimatedDurationSeconds = (fileSize / 16000).round();
      return estimatedDurationSeconds * 1000; // Devolver en milisegundos
    } catch (e) {
      print('❌ Error al obtener duración del audio: $e');
      return null;
    }
  }

  /// Método mejorado que combina Speech-to-Text local con fallback de Gemini
  Future<String?> convertAudioToTextWithFallback({
    String? audioFilePath,
    String locale = 'es_ES',
    Duration timeout = const Duration(seconds: 30),
    String sessionId = 'audio_session',
  }) async {
    if (_isDisposed) {
      print('❌ AudioService disposed, no se puede convertir audio');
      return null;
    }

    print('🎯 Iniciando conversión de audio con fallback inteligente...');

    // Paso 1: Intentar con Speech-to-Text local
    print('🔄 Paso 1: Intentando con Speech-to-Text local...');
    final localResult = await convertAudioToText(
      locale: locale,
      timeout: timeout,
    );

    if (localResult != null && localResult.isNotEmpty) {
      print('✅ Speech-to-Text local exitoso: "$localResult"');
      return localResult;
    }

    print('❌ Speech-to-Text local falló, intentando con Gemini...');

    // Paso 2: Si falla el local y tenemos archivo de audio, usar Gemini
    if (audioFilePath != null && audioFilePath.isNotEmpty) {
      print('🔄 Paso 2: Intentando con Gemini fallback...');

      // Extraer código de idioma para Gemini (es_ES -> es)
      String languageCode = locale.split('_').first;

      final geminiResult = await convertAudioToTextWithGemini(
        audioFilePath,
        sessionId: sessionId,
        languageCode: languageCode,
      );

      if (geminiResult != null && geminiResult.isNotEmpty) {
        print('✅ Gemini fallback exitoso: "$geminiResult"');
        return geminiResult;
      }
    } else {
      print('⚠️ No se proporcionó archivo de audio para Gemini fallback');
    }

    print('❌ Todos los métodos de conversión fallaron');
    return null;
  }

  /// Reproducir audio grabado con manejo seguro
  Future<bool> playAudio(String audioPath) async {
    if (_isDisposed) {
      print('❌ AudioService disposed, no se puede reproducir');
      return false;
    }

    try {
      if (_audioPlayer == null) {
        print('❌ AudioPlayer no está disponible');
        return false;
      }

      await _audioPlayer!.play(DeviceFileSource(audioPath));
      print('🔊 Reproduciendo audio: $audioPath');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error al reproducir audio: $e');
      print('📍 StackTrace: $stackTrace');
      return false;
    }
  }

  /// Detener reproducción de forma segura
  Future<void> stopPlayback() async {
    if (_isDisposed) return;

    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        print('⏹️ Reproducción detenida');
      }
    } catch (e) {
      print('❌ Error al detener reproducción: $e');
    }
  }

  /// Obtener duración de la grabación actual (simplificado)
  Stream<Duration> getRecordingDuration() async* {
    final startTime = DateTime.now();
    while (_isRecording && !_isDisposed) {
      yield DateTime.now().difference(startTime);
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Limpiar recursos de forma segura
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    try {
      print('🧹 Iniciando limpieza de AudioService...');

      // Detener grabación si está activa
      if (_isRecording) {
        await stopRecording();
      }

      // Detener speech-to-text si está activo
      try {
        if (_speechToText?.isListening == true) {
          await _speechToText!.stop();
        }
      } catch (e) {
        print('⚠️ Error al detener speech-to-text: $e');
      }

      // Limpiar recursos de audio
      try {
        await _audioPlayer?.dispose();
      } catch (e) {
        print('⚠️ Error al limpiar AudioPlayer: $e');
      }

      try {
        await _audioRecorder?.dispose();
      } catch (e) {
        print('⚠️ Error al limpiar AudioRecorder: $e');
      }

      // Resetear variables
      _audioPlayer = null;
      _audioRecorder = null;
      _speechToText = null;
      _isInitialized = false;
      _speechEnabled = false;
      _isRecording = false;

      print('✅ AudioService limpiado correctamente');
    } catch (e, stackTrace) {
      print('❌ Error durante limpieza de AudioService: $e');
      print('📍 StackTrace: $stackTrace');
    }
  }

  /// Verificar y reparar el estado del AudioService
  Future<bool> verifyAndRepairState() async {
    if (_isDisposed) {
      print('🔧 AudioService disposed, reinicializando...');
      return await initialize();
    }

    try {
      print('🔍 Verificando estado del AudioService...');

      // Verificar AudioRecorder
      if (_audioRecorder == null) {
        print('🔧 AudioRecorder es null, creando nuevo...');
        _audioRecorder = AudioRecorder();
      }

      // Verificar permisos
      bool hasPermission = false;
      try {
        hasPermission = await _audioRecorder!.hasPermission();
      } catch (e) {
        print('🔧 Error al verificar permisos, recreando AudioRecorder: $e');
        try {
          await _audioRecorder?.dispose();
        } catch (disposeError) {
          print('⚠️ Error al limpiar AudioRecorder: $disposeError');
        }
        _audioRecorder = AudioRecorder();
        hasPermission = await _audioRecorder!.hasPermission();
      }

      if (!hasPermission) {
        print('❌ No hay permisos de grabación');
        return false;
      }

      // Verificar y reparar Speech-to-Text
      if (_speechToText == null || !_speechEnabled) {
        print(
          '🔧 SpeechToText necesita reparación (null: ${_speechToText == null}, enabled: $_speechEnabled)',
        );

        // Crear nueva instancia si es necesario
        if (_speechToText == null) {
          _speechToText = stt.SpeechToText();
        }

        // Intentar inicializar con timeout y manejo robusto
        try {
          print('🔧 Reinicializando Speech-to-Text...');
          _speechEnabled = await _speechToText!
              .initialize(
                onError: (error) {
                  print(
                    '❌ Error en Speech-to-Text durante reparación: ${error.errorMsg}',
                  );
                  _speechEnabled = false;
                },
                onStatus: (status) {
                  print('🔊 Estado Speech-to-Text durante reparación: $status');
                },
              )
              .timeout(
                const Duration(seconds: 15),
                onTimeout: () {
                  print('⏰ Timeout al reparar Speech-to-Text');
                  return false;
                },
              );

          if (_speechEnabled) {
            print('✅ Speech-to-Text reparado exitosamente');
          } else {
            print('❌ No se pudo reparar Speech-to-Text');
          }
        } catch (e) {
          print('❌ Error crítico al reparar Speech-to-Text: $e');
          _speechEnabled = false;
        }
      } else {
        print('✅ Speech-to-Text ya está funcionando correctamente');
      }

      // Verificar AudioPlayer
      if (_audioPlayer == null) {
        print('🔧 AudioPlayer es null, creando nuevo...');
        _audioPlayer = AudioPlayer();
      }

      // Actualizar estado de inicialización si todo está bien
      if (hasPermission &&
          _audioRecorder != null &&
          _speechToText != null &&
          _audioPlayer != null) {
        _isInitialized = true;
        print('✅ Estado del AudioService verificado y reparado completamente');
        print(
          '📊 Estado final: initialized=$_isInitialized, speechEnabled=$_speechEnabled',
        );
        return true;
      } else {
        print('⚠️ Algunos componentes no pudieron ser reparados');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Error al verificar/reparar estado: $e');
      print('📍 StackTrace: $stackTrace');
      return false;
    }
  }

  /// Verificar si el dispositivo soporta grabación
  Future<bool> isRecordingSupported() async {
    if (_isDisposed) return false;

    try {
      if (_audioRecorder == null) return false;
      return await _audioRecorder!.hasPermission();
    } catch (e) {
      print('❌ Error al verificar soporte de grabación: $e');
      return false;
    }
  }

  /// Obtener consejos para mejorar el reconocimiento de voz
  String getRecognitionTips(double? maxSoundLevel, bool? hasDetectedSound) {
    if (maxSoundLevel == null || hasDetectedSound == null) {
      return 'Habla de forma clara y natural cerca del micrófono.';
    }

    if (!hasDetectedSound) {
      return 'No se detectó sonido. Verifica que el micrófono esté funcionando y habla más fuerte.';
    } else if (maxSoundLevel > 0.8) {
      return 'El volumen está muy alto. Habla más suave y a una distancia normal del micrófono.';
    } else if (maxSoundLevel < 0.2) {
      return 'El volumen está muy bajo. Acércate más al micrófono y habla más fuerte.';
    } else if (maxSoundLevel < 0.4) {
      return 'Habla un poco más fuerte y asegúrate de estar cerca del micrófono.';
    } else {
      return 'El nivel de audio es bueno. Habla de forma clara y pausada.';
    }
  }

  /// Obtener información del dispositivo de audio de forma segura
  Future<Map<String, dynamic>> getAudioDeviceInfo() async {
    if (_isDisposed) {
      return {
        'hasPermission': false,
        'speechAvailable': false,
        'supportedLocales': [],
        'isInitialized': false,
        'error': 'Service disposed',
        'lastSoundLevel': _lastMaxSoundLevel,
        'lastHadSound': _lastHadDetectedSound,
      };
    }

    try {
      bool hasPermission = false;
      bool speechAvailable = false;
      List<Map<String, String>> supportedLocales = [];

      // Verificar permisos de forma segura
      try {
        if (_audioRecorder != null) {
          hasPermission = await _audioRecorder!.hasPermission();
        }
      } catch (e) {
        print('⚠️ Error al verificar permisos: $e');
      }

      // Verificar speech-to-text de forma segura
      try {
        if (_speechToText != null) {
          speechAvailable = await _speechToText!.initialize();
          if (speechAvailable) {
            final locales = await _speechToText!.locales();
            supportedLocales =
                locales
                    .map((l) => {'localeId': l.localeId, 'name': l.name})
                    .toList();
          }
        }
      } catch (e) {
        print('⚠️ Error al verificar speech-to-text: $e');
      }

      return {
        'hasPermission': hasPermission,
        'speechAvailable': speechAvailable,
        'supportedLocales': supportedLocales,
        'isInitialized': _isInitialized,
        'isDisposed': _isDisposed,
        'lastSoundLevel': _lastMaxSoundLevel,
        'lastHadSound': _lastHadDetectedSound,
      };
    } catch (e, stackTrace) {
      print('❌ Error al obtener info del dispositivo: $e');
      print('📍 StackTrace: $stackTrace');
      return {
        'hasPermission': false,
        'speechAvailable': false,
        'supportedLocales': [],
        'isInitialized': false,
        'error': e.toString(),
        'lastSoundLevel': _lastMaxSoundLevel,
        'lastHadSound': _lastHadDetectedSound,
      };
    }
  }
}
