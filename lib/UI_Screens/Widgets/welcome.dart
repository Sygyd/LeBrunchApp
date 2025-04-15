import 'package:flutter/material.dart';
import '/UI_Screens/Widgets/text_with_border.dart';
import '/UI_Screens/Widgets/welcome_button.dart';
import '/UI_Screens/Auth_Screens/auth_modals.dart';
import '../../Api_services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isInitialized = false;

  // Variables para la animación
  double _backgroundPosition1 = 0;
  double _backgroundPosition2 = -200; // Comenzar fuera de la pantalla
  late AnimationController _controller;
  late Timer _animationTimer;

  @override
  void initState() {
    super.initState();

    // Inicializar animación
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // Actualizar a 60fps
    );

    // Iniciar timer para actualizar la posición sin depender de MediaQuery en initState
    _animationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        // Mover ambas imágenes hacia abajo (velocidad constante)
        _backgroundPosition1 +=
            0.7; // Ajusta este valor para cambiar la velocidad
        _backgroundPosition2 += 0.7;

        // Usamos un valor fijo para la altura de la pantalla durante el primer frame
        // y luego será corregido en los siguientes frames cuando el contexto esté disponible
        double estimatedScreenHeight = 800.0; // Valor estimado conservador

        try {
          // Intentar obtener la altura real si el contexto está listo
          if (context != null) {
            estimatedScreenHeight = MediaQuery.of(context).size.height;
          }
        } catch (e) {
          // Si MediaQuery falla, seguimos usando el valor estimado
        }

        // Resetear la primera imagen cuando sale completamente de la pantalla
        if (_backgroundPosition1 >= estimatedScreenHeight) {
          _backgroundPosition1 = _backgroundPosition2 - estimatedScreenHeight;
        }

        // Resetear la segunda imagen cuando sale completamente de la pantalla
        if (_backgroundPosition2 >= estimatedScreenHeight) {
          _backgroundPosition2 = _backgroundPosition1 - estimatedScreenHeight;
        }
      });
    });

    // Limpiar carrito
    _cleanAllCarts();
  }

  @override
  void dispose() {
    _animationTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Método para limpiar todos los carritos guardados
  Future<void> _cleanAllCarts() async {
    if (_isInitialized) return;

    try {
      // 1. Eliminar todos los carritos guardados en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      int contadorEliminados = 0;

      // Eliminar específicamente las claves relacionadas con carritos
      for (final key in allKeys) {
        if (key.startsWith('cart_')) {
          await prefs.remove(key);
          contadorEliminados++;
        }
      }

      print(
        '🧹 WelcomeScreen: Se han eliminado $contadorEliminados carritos de SharedPreferences',
      );

      // 2. Reiniciar el servicio de carrito
      final cartService = CartService();
      await cartService.clearAllCarts();

      // 3. Establecer el modo invitado
      await cartService.setUserId('guest');

      print(
        '✅ WelcomeScreen: CartService completamente limpio e inicializado como invitado',
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('❌ Error al limpiar carritos en WelcomeScreen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo con animación sencilla
          AnimatedPositioned(
            duration: const Duration(milliseconds: 16),
            curve: Curves.linear,
            top: _backgroundPosition1,
            left: 0,
            right: 0,
            height:
                screenHeight +
                50, // Imagen ligeramente más grande que la pantalla
            child: Image.asset('assets/images/fondolb.jpg', fit: BoxFit.cover),
          ),

          // Segunda imagen de fondo (para transición continua)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 16),
            curve: Curves.linear,
            top: _backgroundPosition2,
            left: 0,
            right: 0,
            height:
                screenHeight +
                50, // Imagen ligeramente más grande que la pantalla
            child: Image.asset('assets/images/fondolb.jpg', fit: BoxFit.cover),
          ),

          // Contenido
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header con texto elegante
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 0,
                  ),
                ),
                // Contenido central con logo y texto
                Column(
                  children: [
                    // Imagen con tamaño proporcional a la pantalla
                    Image.asset(
                      'assets/logos/logo_lebrunch.png',
                      height: screenHeight * 0.22,
                      fit: BoxFit.contain,
                    ),
                    SizedBox(height: screenHeight * 0.05),

                    // Título "Bienvenido"
                    TextWithBorder(
                      text: 'Bienvenido',
                      fontSize: 45,
                      fontWeight: FontWeight.w600,
                      borderWidth: 3.0,
                    ),
                    const SizedBox(height: 16),

                    // Subtítulo
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextWithBorder(
                        text: 'Horneamos, Cocinamos y Disfrutamos',
                        fontSize: 22,
                        fontWeight: FontWeight.normal,
                        borderWidth: 2.0,
                      ),
                    ),
                  ],
                ),

                // Botones de acceso horizontales
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: WelcomeButton(
                          buttonText: 'Ingresa',
                          onTap: () => AuthModals.showLoginModal(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: WelcomeButton(
                          buttonText: 'Regístrate',
                          onTap: () => AuthModals.showRegisterModal(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
