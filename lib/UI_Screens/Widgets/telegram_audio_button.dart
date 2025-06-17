import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../Api_services/audio_service.dart';

class TelegramAudioButton extends StatefulWidget {
  final Function(String) onAudioRecorded;
  final Function(Map<String, dynamic>)? onAudioProcessed;
  final VoidCallback? onCancel;
  final Color? primaryColor;
  final Color? backgroundColor;
  final String? sessionId;
  final bool isEnabled;

  const TelegramAudioButton({
    Key? key,
    required this.onAudioRecorded,
    this.onAudioProcessed,
    this.onCancel,
    this.primaryColor,
    this.backgroundColor,
    this.sessionId,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  State<TelegramAudioButton> createState() => _TelegramAudioButtonState();
}

class _TelegramAudioButtonState extends State<TelegramAudioButton>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();

  // Estados de grabación
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isPressed = false;
  bool _shouldCancel = false;
  String _recordingDuration = '00:00';
  Timer? _timer;
  DateTime? _startTime;
  double _dragDistance = 0.0;

  // Controladores de animación
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // Configuración
  static const double _cancelThreshold = 80.0; // Distancia mínima para cancelar
  static const double _buttonSize = 50.0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Animación de escala al presionar
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Animación de deslizamiento para cancelar
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Animación de pulso durante grabación
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startRecording() async {
    if (!widget.isEnabled) return;

    try {
      print('🎤 TelegramAudioButton: Iniciando grabación...');

      // Verificar e inicializar el servicio de audio si es necesario
      if (!_audioService.isInitialized) {
        print('🔄 Inicializando AudioService...');
        final initialized = await _audioService.initialize();
        if (!initialized) {
          // Solo mostrar error crítico de inicialización
          _showErrorSnackBar('No se pudo acceder al micrófono');
          return;
        }
      }

      final success = await _audioService.startRecording();
      if (success && mounted) {
        setState(() {
          _isRecording = true;
          _startTime = DateTime.now();
        });

        // Iniciar animaciones
        _pulseController.repeat(reverse: true);
        _startTimer();

        // Vibración suave
        HapticFeedback.lightImpact();

        print('✅ Grabación iniciada');
      } else {
        // Error silencioso, solo vibración de feedback
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('❌ Error al iniciar grabación: $e');
      // Solo vibración para errores menores
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      setState(() {
        _isProcessing = true;
      });

      // Detener animaciones y timer
      _pulseController.stop();
      _stopTimer();

      final audioPath = await _audioService.stopRecording();

      if (audioPath != null && audioPath.isNotEmpty) {
        print('🎵 Audio grabado: $audioPath');

        // Intentar primero con Speech-to-Text local
        final localText = await _audioService.convertAudioToText(
          locale: 'es_ES',
          timeout: const Duration(seconds: 10),
        );

        if (localText != null && localText.isNotEmpty) {
          print('✅ Speech-to-Text local exitoso: "$localText"');

          if (mounted) {
            setState(() {
              _isRecording = false;
              _isProcessing = false;
            });
          }

          // Vibración de éxito en lugar de SnackBar
          HapticFeedback.selectionClick();
          widget.onAudioRecorded(localText);
          return;
        }

        // Si falla el local, usar Gemini
        print('🔄 Procesando con Gemini...');
        final completeResponse = await _audioService
            .processAudioWithGeminiComplete(
              audioPath,
              sessionId:
                  widget.sessionId ??
                  'telegram_audio_${DateTime.now().millisecondsSinceEpoch}',
            );

        if (mounted) {
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }

        if (completeResponse != null) {
          print('✅ Audio procesado con Gemini');
          // Vibración de éxito en lugar de SnackBar
          HapticFeedback.selectionClick();

          if (widget.onAudioProcessed != null) {
            widget.onAudioProcessed!(completeResponse);
          } else {
            final transcribedText =
                completeResponse['transcribed_text'] as String? ??
                completeResponse['text_response'] as String? ??
                'Audio procesado';
            widget.onAudioRecorded(transcribedText);
          }
        } else {
          // Error silencioso con vibración
          HapticFeedback.heavyImpact();
        }
      } else {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }
        // Error silencioso con vibración
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('❌ Error al detener grabación: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }
      // Solo mostrar error crítico si es un problema serio
      if (e.toString().contains('timeout') ||
          e.toString().contains('network')) {
        _showErrorSnackBar('Error de conexión al procesar audio');
      } else {
        // Error silencioso con vibración para otros casos
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    try {
      await _audioService.stopRecording();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }

      _pulseController.stop();
      _stopTimer();

      widget.onCancel?.call();

      // Vibración suave para indicar cancelación exitosa
      HapticFeedback.selectionClick();
    } catch (e) {
      print('❌ Error al cancelar grabación: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && mounted) {
        final duration = DateTime.now().difference(_startTime!);
        setState(() {
          _recordingDuration = _formatDuration(duration);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _recordingDuration = '00:00';
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mic_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          elevation: 2,
        ),
      );
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isRecording) return;

    setState(() {
      _dragDistance =
          -details.localPosition.dy; // Negativo porque deslizamos hacia arriba
    });

    // Determinar si debemos cancelar
    _shouldCancel = _dragDistance > _cancelThreshold;

    // Actualizar animación de deslizamiento
    if (_shouldCancel) {
      _slideController.forward();
    } else {
      _slideController.reverse();
    }
  }

  void _onPanEnd(DragEndDetails details) async {
    if (!_isPressed) return;

    setState(() {
      _isPressed = false;
      _dragDistance = 0.0;
    });

    _scaleController.reverse();
    _slideController.reverse();

    if (_isRecording) {
      if (_shouldCancel) {
        await _cancelRecording();
      } else {
        await _stopRecording();
      }
    }

    _shouldCancel = false;
  }

  void _onPanStart(DragStartDetails details) async {
    if (!widget.isEnabled || _isProcessing) return;

    setState(() {
      _isPressed = true;
    });

    _scaleController.forward();
    await _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor = theme.colorScheme.surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Indicador de cancelación
        if (_isRecording && _shouldCancel)
          Positioned(
            bottom: _buttonSize + 10,
            left: -50,
            right: -50,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _slideAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🗑️ Suelta para cancelar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),

        // Tiempo de grabación
        if (_isRecording && !_shouldCancel)
          Positioned(
            bottom: _buttonSize + 10,
            left: -30,
            right: -30,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _recordingDuration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Botón principal
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _pulseAnimation]),
            builder: (context, child) {
              double scale = _scaleAnimation.value;
              if (_isRecording) {
                scale *= _pulseAnimation.value;
              }

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: _buttonSize,
                  height: _buttonSize,
                  decoration: BoxDecoration(
                    color:
                        _isProcessing
                            ? Colors.grey[400]
                            : (_isRecording ? Colors.red : primaryColor),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.red : primaryColor)
                            .withOpacity(0.3),
                        blurRadius: _isRecording ? 20 : 10,
                        spreadRadius: _isRecording ? 5 : 0,
                      ),
                    ],
                  ),
                  child:
                      _isProcessing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Icon(
                            _isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
