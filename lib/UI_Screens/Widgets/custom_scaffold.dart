import 'package:flutter/material.dart';

// En custom_scaffold.dart
class CustomScaffold extends StatelessWidget {
  const CustomScaffold({
    super.key,
    required this.child, // Hacemos child obligatorio
    this.showAppBar = false, // Cambiamos default a false
    this.backgroundImage = 'assets/images/bg1.png',
    this.showTitle = false, // Nuevo parámetro para controlar el título
  });

  final Widget child; // Ahora es required
  final bool showAppBar;
  final String backgroundImage;
  final bool showTitle; // Controla si muestra "Le Brunch"

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar:
          showAppBar
              ? AppBar(
                iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
                backgroundColor: Colors.transparent,
                elevation: 0,
                title:
                    showTitle // Solo muestra título si es true
                        ? Text(
                          'Le Brunch',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontFamily: 'LightHouse Regular',
                          ),
                        )
                        : null,
              )
              : null,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
            opacity: theme.brightness == Brightness.dark ? 0.3 : 0.8,
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
