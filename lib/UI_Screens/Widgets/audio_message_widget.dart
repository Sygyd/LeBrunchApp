import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class AudioMessageWidget extends StatefulWidget {
  final String audioPath;
  final bool isUserMessage;
  final Duration? duration;
  final VoidCallback? onPlaybackComplete;

  const AudioMessageWidget({
    Key? key,
    required this.audioPath,
    required this.isUserMessage,
    this.duration,
    this.onPlaybackComplete,
  }) : super(key: key);

  @override
  State<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<AudioMessageWidget>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAnimations();
    _setupAudioPlayer();
    _loadAudioDuration();
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  void _setupAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _isLoading =
              state == PlayerState.stopped && _currentPosition == Duration.zero;
        });

        if (_isPlaying) {
          _waveController.repeat(reverse: true);
        } else {
          _waveController.stop();
        }

        if (state == PlayerState.completed) {
          _onPlaybackComplete();
        }
      }
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  Future<void> _loadAudioDuration() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Si se proporcionó una duración, usarla
      if (widget.duration != null) {
        setState(() {
          _totalDuration = widget.duration!;
          _isLoading = false;
        });
        return;
      }

      // Intentar obtener la duración del archivo
      final file = File(widget.audioPath);
      if (await file.exists()) {
        await _audioPlayer.setSourceDeviceFile(widget.audioPath);
        // La duración se establecerá automáticamente en el listener
      }
    } catch (e) {
      print('❌ Error al cargar duración del audio: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_currentPosition == Duration.zero) {
          await _audioPlayer.play(DeviceFileSource(widget.audioPath));
        } else {
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      print('❌ Error al reproducir audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al reproducir audio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onPlaybackComplete() {
    setState(() {
      _currentPosition = Duration.zero;
      _isPlaying = false;
    });
    widget.onPlaybackComplete?.call();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(20, (index) {
            final height =
                _isPlaying
                    ? 12.0 +
                        (8.0 *
                            (0.5 +
                                0.5 *
                                    (index % 2 == 0
                                        ? _waveAnimation.value
                                        : 1 - _waveAnimation.value)))
                    : 4.0 + (index % 3) * 2.0;

            return Container(
              width: 2,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color:
                    widget.isUserMessage
                        ? Colors.white.withOpacity(0.7)
                        : Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.7),
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de play/pause
          GestureDetector(
            onTap: _isLoading ? null : _togglePlayback,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    widget.isUserMessage
                        ? Colors.white.withOpacity(0.2)
                        : theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      widget.isUserMessage
                          ? Colors.white.withOpacity(0.5)
                          : theme.colorScheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child:
                  _isLoading
                      ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.isUserMessage
                                ? Colors.white
                                : theme.colorScheme.primary,
                          ),
                        ),
                      )
                      : Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color:
                            widget.isUserMessage
                                ? Colors.white
                                : theme.colorScheme.primary,
                        size: 24,
                      ),
            ),
          ),

          const SizedBox(width: 12),

          // Waveform visual
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildWaveform(),
                const SizedBox(height: 4),
                // Progress bar
                LinearProgressIndicator(
                  value:
                      _totalDuration.inMilliseconds > 0
                          ? _currentPosition.inMilliseconds /
                              _totalDuration.inMilliseconds
                          : 0.0,
                  backgroundColor:
                      widget.isUserMessage
                          ? Colors.white.withOpacity(0.3)
                          : theme.colorScheme.primary.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isUserMessage
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Duración
          Text(
            _isPlaying || _currentPosition > Duration.zero
                ? '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}'
                : _formatDuration(_totalDuration),
            style: TextStyle(
              fontSize: 11,
              color:
                  widget.isUserMessage
                      ? Colors.white.withOpacity(0.8)
                      : theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
