import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _elasticController;
  late AnimationController _growController;
  late Animation<double> _elasticAnimation;
  late Animation<double> _growAnimation;
  late Animation<double> _fadeAnimation;
  bool _transitionStarted = false;

  @override
  void initState() {
    super.initState();

    _elasticController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _growController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _elasticAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _elasticController, curve: Curves.elasticOut),
    );

    _growAnimation = Tween<double>(begin: 1.0, end: 8.0).animate(
      CurvedAnimation(parent: _growController, curve: Curves.easeInExpo),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _elasticController, curve: Curves.easeInCubic),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    // 1. Animación elástica inicial
    await _elasticController.forward();

    // 2. Animación de crecimiento exponencial
    await _growController.forward();

    // 3. Transición suave a la pantalla principal
    if (!mounted) return;
    setState(() => _transitionStarted = true);
    await Navigator.pushReplacementNamed(context, '/');
  }

  @override
  void dispose() {
    _elasticController.dispose();
    _growController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_elasticController, _growController]),
          builder: (context, child) {
            final currentScale = _elasticAnimation.value * _growAnimation.value;

            return _transitionStarted
                ? const SizedBox.shrink()
                : Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: currentScale,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF3EA69B),
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: MediaQuery.of(context).size.width * 0.4,
                      ),
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }
}
