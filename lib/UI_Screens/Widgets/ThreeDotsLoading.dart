import 'package:flutter/material.dart';

/// Widget que muestra una animación de tres puntos para indicar carga/escritura
class ThreeDotsLoading extends StatefulWidget {
  final Color? color;
  final double size;
  final double spacing;

  const ThreeDotsLoading({
    Key? key,
    this.color,
    this.size = 4,
    this.spacing = 2,
  }) : super(key: key);

  @override
  State<ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<ThreeDotsLoading>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    // Crear controladores y animaciones para los tres puntos
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: Duration(milliseconds: 150),
        vsync: this,
      ),
    );

    // Configurar animaciones con retrasos diferentes
    _animations =
        _controllers
            .map(
              (controller) => Tween<double>(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
              ),
            )
            .toList();

    // Iniciar animaciones secuenciales
    _startAnimations();
  }

  void _startAnimations() async {
    // Duración total de un ciclo
    const cycleDuration = 900;

    while (mounted) {
      // Primer punto
      await Future.delayed(Duration(milliseconds: 120));
      if (!mounted) return;
      await _controllers[0].forward();
      if (!mounted) return;
      await _controllers[0].reverse();

      // Segundo punto
      await Future.delayed(Duration(milliseconds: 120));
      if (!mounted) return;
      await _controllers[1].forward();
      if (!mounted) return;
      await _controllers[1].reverse();

      // Tercer punto
      await Future.delayed(Duration(milliseconds: 120));
      if (!mounted) return;
      await _controllers[2].forward();
      if (!mounted) return;
      await _controllers[2].reverse();

      // Pausa entre ciclos
      await Future.delayed(Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.spacing),
          child: AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: _animations[index].value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
