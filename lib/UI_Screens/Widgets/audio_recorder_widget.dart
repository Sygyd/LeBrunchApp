import 'package:flutter/material.dart';
import 'dart:async';
import '../../Api_services/audio_service.dart';

class AudioRecorderWidget extends StatefulWidget {
  final Function(String) onAudioRecorded;
  final Function(Map<String, dynamic>)? onAudioProcessed;
  final VoidCallback? onCancel;
  final Color? primaryColor;
  final Color? backgroundColor;
  final String? sessionId;

  const AudioRecorderWidget({
    Key? key,
    required this.onAudioRecorded,
    this.onAudioProcessed,
    this.onCancel,
    this.primaryColor,
    this.backgroundColor,
    this.sessionId,
  }) : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();

  // Estados
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isDisposed = false;
  String _recordingDuration = '00:00';
  Timer? _timer;
  DateTime? _startTime;

  // Animaciones
  AnimationController? _pulseController;
  AnimationController? _waveController;
  Animation<double>? _pulseAnimation;
  Animation<double>? _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeAudioService();
  }

  void _initializeAnimations() {
    try {
      // Animación de pulso para el botón de grabación
      _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );

      // Animación de ondas para el indicador de grabación
      _waveController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _waveController!, curve: Curves.easeInOut),
      );
    } catch (e) {
      print('❌ Error al inicializar animaciones: $e');
    }
  }

  Future<void> _initializeAudioService() async {
    if (_isDisposed) return;

    try {
      print('🎤 AudioRecorderWidget: Verificando servicio de audio...');

      // Verificar si ya está inicializado
      if (_audioService.isInitialized) {
        print('✅ AudioRecorderWidget: AudioService ya estaba inicializado');
        if (mounted && !_isDisposed) {
          setState(() {
            _isInitialized = true;
          });
        }
        return;
      }

      print('🎤 AudioRecorderWidget: Inicializando servicio de audio...');
      final initialized = await _audioService.initialize();

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitialized = initialized;
        });
      }

      if (!initialized) {
        _showErrorSnackBar('No se pudo inicializar el servicio de audio');
      } else {
        print('✅ AudioRecorderWidget: Servicio de audio inicializado');
      }
    } catch (e) {
      print('❌ AudioRecorderWidget: Error al inicializar audio: $e');
      if (mounted && !_isDisposed) {
        _showErrorSnackBar('Error al inicializar audio: $e');
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted && !_isDisposed) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        print('❌ Error al mostrar SnackBar: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted && !_isDisposed) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        print('❌ Error al mostrar SnackBar de éxito: $e');
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isDisposed || !mounted) return;

    if (!_isInitialized) {
      _showErrorSnackBar('El servicio de audio no está listo');
      return;
    }

    try {
      // Verificar y reparar el estado del AudioService antes de grabar
      print('🔍 Verificando estado del AudioService antes de grabar...');
      final stateOk = await _audioService.verifyAndRepairState();
      if (!stateOk) {
        _showErrorSnackBar('No se pudo preparar el servicio de audio');
        return;
      }

      final success = await _audioService.startRecording();
      if (success && mounted && !_isDisposed) {
        setState(() {
          _isRecording = true;
          _startTime = DateTime.now();
        });

        // Iniciar animaciones de forma segura
        try {
          _pulseController?.repeat(reverse: true);
          _waveController?.repeat(reverse: true);
        } catch (e) {
          print('⚠️ Error al iniciar animaciones: $e');
        }

        // Iniciar timer para mostrar duración
        _startTimer();

        _showSuccessSnackBar('🎤 Grabación iniciada');
      } else {
        _showErrorSnackBar(
          'No se pudo iniciar la grabación. Verifica los permisos del micrófono.',
        );
      }
    } catch (e) {
      print('❌ Error en _startRecording: $e');
      _showErrorSnackBar('Error al iniciar grabación: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_isDisposed || !mounted) return;

    try {
      if (mounted && !_isDisposed) {
        setState(() {
          _isProcessing = true;
        });
      }

      // Detener animaciones y timer de forma segura
      try {
        _pulseController?.stop();
        _waveController?.stop();
      } catch (e) {
        print('⚠️ Error al detener animaciones: $e');
      }
      _stopTimer();

      // Detener grabación
      final audioPath = await _audioService.stopRecording();

      if (audioPath != null && audioPath.isNotEmpty) {
        print('🎵 Archivo de audio creado: $audioPath');

        // Primero intentar con Speech-to-Text local rápido
        print('🔄 Paso 1: Intentando Speech-to-Text local...');
        final localText = await _audioService.convertAudioToText(
          locale: 'es_ES',
          timeout: const Duration(seconds: 10),
        );

        if (localText != null && localText.isNotEmpty) {
          print('✅ Speech-to-Text local exitoso: "$localText"');

          if (mounted && !_isDisposed) {
            setState(() {
              _isRecording = false;
              _isProcessing = false;
            });
          }

          _showSuccessSnackBar('✅ Audio convertido a texto');
          widget.onAudioRecorded(localText);
          return;
        }

        // Si falla el local, usar procesamiento completo con Gemini
        print('🔄 Usando procesamiento completo con Gemini...');
        final completeResponse = await _audioService
            .processAudioWithGeminiComplete(
              audioPath,
              sessionId:
                  widget.sessionId ??
                  'audio_widget_${DateTime.now().millisecondsSinceEpoch}',
            );

        if (mounted && !_isDisposed) {
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }

        if (completeResponse != null) {
          print('✅ Audio procesado exitosamente');
          _showSuccessSnackBar('✅ Audio procesado');

          // Si hay callback para respuesta completa, usarlo
          if (widget.onAudioProcessed != null) {
            widget.onAudioProcessed!(completeResponse);
          } else {
            // Fallback: usar solo el texto transcrito
            final transcribedText =
                completeResponse['transcribed_text'] as String? ??
                completeResponse['text_response'] as String? ??
                'Audio procesado';
            widget.onAudioRecorded(transcribedText);
          }
        } else {
          print('❌ No se pudo procesar el audio');

          // Obtener consejos específicos basados en el diagnóstico del audio
          final deviceInfo = await _audioService.getAudioDeviceInfo();
          String errorMessage = 'No se pudo reconocer el audio.';

          // Si hay información de diagnóstico disponible, usar consejos específicos
          if (deviceInfo.containsKey('lastSoundLevel') &&
              deviceInfo.containsKey('lastHadSound')) {
            final tips = _audioService.getRecognitionTips(
              deviceInfo['lastSoundLevel'] as double?,
              deviceInfo['lastHadSound'] as bool?,
            );
            errorMessage = '$errorMessage $tips';
          } else {
            errorMessage =
                '$errorMessage Intenta hablar más claro y cerca del micrófono.';
          }

          _showErrorSnackBar(errorMessage);
        }
      } else {
        if (mounted && !_isDisposed) {
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }
        _showErrorSnackBar('Error al procesar el audio');
      }
    } catch (e) {
      print('❌ Error en _stopRecording: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }
      _showErrorSnackBar('Error al procesar audio: $e');
    }
  }

  void _cancelRecording() async {
    if (_isDisposed) return;

    try {
      if (_isRecording) {
        await _audioService.stopRecording();
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }

      // Detener animaciones y timer de forma segura
      try {
        _pulseController?.stop();
        _waveController?.stop();
      } catch (e) {
        print('⚠️ Error al detener animaciones en cancelación: $e');
      }
      _stopTimer();

      widget.onCancel?.call();
      _showSuccessSnackBar('Grabación cancelada');
    } catch (e) {
      print('❌ Error en _cancelRecording: $e');
      _showErrorSnackBar('Error al cancelar: $e');
    }
  }

  void _startTimer() {
    try {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_startTime != null && mounted && !_isDisposed) {
          final duration = DateTime.now().difference(_startTime!);
          setState(() {
            _recordingDuration = _formatDuration(duration);
          });
        }
      });
    } catch (e) {
      print('❌ Error al iniciar timer: $e');
    }
  }

  void _stopTimer() {
    try {
      _timer?.cancel();
      _timer = null;
      if (mounted && !_isDisposed) {
        setState(() {
          _recordingDuration = '00:00';
        });
      }
    } catch (e) {
      print('❌ Error al detener timer: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _isDisposed = true;

    try {
      // Detener timer
      _timer?.cancel();
      _timer = null;

      // Limpiar animaciones de forma segura
      try {
        _pulseController?.dispose();
      } catch (e) {
        print('⚠️ Error al limpiar pulseController: $e');
      }

      try {
        _waveController?.dispose();
      } catch (e) {
        print('⚠️ Error al limpiar waveController: $e');
      }

      // NO llamar dispose en AudioService ya que es un singleton
      // que debe mantenerse vivo durante toda la aplicación
      print(
        'ℹ️ AudioRecorderWidget: No se llama dispose en AudioService (singleton)',
      );

      print('✅ AudioRecorderWidget disposed correctamente');
    } catch (e) {
      print('❌ Error durante dispose de AudioRecorderWidget: $e');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return const SizedBox.shrink();
    }

    final primaryColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final backgroundColor = widget.backgroundColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título
          Text(
            _isRecording
                ? '🎤 Grabando...'
                : _isProcessing
                ? '🔄 Procesando...'
                : '🎙️ Toca para grabar',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          // Indicador visual de grabación
          if (_isRecording) ...[
            _buildWaveIndicator(primaryColor),
            const SizedBox(height: 15),

            // Duración de grabación
            Text(
              _recordingDuration,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 20),
          ],

          // Botones de control
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón cancelar (solo visible durante grabación)
              if (_isRecording) ...[
                _buildControlButton(
                  icon: Icons.close,
                  color: Colors.red,
                  onPressed: _cancelRecording,
                  label: 'Cancelar',
                ),
              ],

              // Botón principal (grabar/detener)
              _buildMainButton(primaryColor),

              // Espacio para mantener simetría
              if (_isRecording) ...[
                const SizedBox(width: 80), // Espacio vacío para simetría
              ],
            ],
          ),

          const SizedBox(height: 15),

          // Texto de ayuda
          Text(
            _isRecording
                ? 'Habla claramente hacia el micrófono'
                : _isProcessing
                ? 'Convirtiendo audio a texto...'
                : 'Mantén presionado para grabar tu mensaje',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWaveIndicator(Color primaryColor) {
    if (_waveAnimation == null) {
      return const SizedBox(height: 50); // Placeholder si no hay animación
    }

    return AnimatedBuilder(
      animation: _waveAnimation!,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.2;
            final animationValue = (_waveAnimation!.value + delay) % 1.0;
            final height = 20 + (animationValue * 30);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMainButton(Color primaryColor) {
    if (_isProcessing) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_pulseAnimation == null) {
      // Botón sin animación como fallback
      return GestureDetector(
        onTap: _isRecording ? _stopRecording : _startRecording,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red : primaryColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: 40,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _isRecording ? _pulseAnimation!.value : 1.0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? Colors.red : primaryColor)
                        .withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: _isRecording ? 5 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
