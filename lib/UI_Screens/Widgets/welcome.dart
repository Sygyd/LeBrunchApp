import 'package:flutter/material.dart';
import '/UI_Screens/Widgets/text_with_border.dart';
import '/UI_Screens/Widgets/welcome_button.dart';
import '/UI_Screens/Auth_Screens/auth_modals.dart';
import '../../Api_services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  bool _imagesPreloaded = false;

  // Variables para la animación optimizada
  late AnimationController _animationController;
  late Animation<double> _backgroundAnimation;

  @override
  void initState() {
    super.initState();

    // Inicializar animación inmediatamente (síncrono)
    _initializeAnimation();

    // Hacer precarga e inicialización en background (asíncrono)
    _initializeScreen();
  }

  void _initializeAnimation() {
    // Animación más lenta y suave
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Animación mucho más lenta
    );

    // Animación lineal continua
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    // Repetir la animación infinitamente
    _animationController.repeat();
  }

  Future<void> _initializeScreen() async {
    // Precargar imágenes en background
    _preloadImages();

    // Limpiar carrito en background
    _cleanAllCarts();
  }

  Future<void> _preloadImages() async {
    // Pequeño delay para permitir que el primer frame se renderice
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      // Precargar imágenes críticas
      await precacheImage(
        const AssetImage('assets/images/fondolb.jpg'),
        context,
      );
      await precacheImage(
        const AssetImage('assets/logos/logo_lebrunch.png'),
        context,
      );

      if (mounted) {
        setState(() {
          _imagesPreloaded = true;
        });
      }
    } catch (e) {
      print('⚠️ Error precargando imágenes: $e');
      // Continuar sin precargar si hay error
      if (mounted) {
        setState(() {
          _imagesPreloaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Método optimizado para limpiar carritos (sin bloquear UI)
  Future<void> _cleanAllCarts() async {
    if (_isInitialized) return;

    try {
      // Ejecutar en microtask para no bloquear la UI
      Future.microtask(() async {
        final prefs = await SharedPreferences.getInstance();
        final allKeys = prefs.getKeys().toList();
        int contadorEliminados = 0;

        for (final key in allKeys) {
          if (key.startsWith('cart_')) {
            await prefs.remove(key);
            contadorEliminados++;
          }
        }

        final cartService = CartService();
        await cartService.clearAllCarts();
        await cartService.setUserId('guest');

        print(
          '✅ WelcomeScreen: Carritos limpiados ($contadorEliminados eliminados)',
        );

        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
    } catch (e) {
      print('❌ Error al limpiar carritos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco siempre
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo animado optimizado
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, child) {
              // Calcular posición de la animación de manera más eficiente
              final double offset1 =
                  (_backgroundAnimation.value * screenHeight) % screenHeight;
              final double offset2 = offset1 - screenHeight;

              return Stack(
                children: [
                  // Contenedor blanco de fondo siempre visible
                  Positioned.fill(child: Container(color: Colors.white)),

                  // Primera imagen de fondo
                  Positioned(
                    top: offset1,
                    left: 0,
                    right: 0,
                    height: screenHeight + 100, // Buffer extra para suavidad
                    child:
                        _imagesPreloaded
                            ? Image.asset(
                              'assets/images/fondolb.jpg',
                              fit: BoxFit.cover,
                              // Cache para mejor rendimiento
                              cacheHeight: (screenHeight * 1.5).toInt(),
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white, // Fondo blanco en error
                                );
                              },
                            )
                            : Container(
                              color:
                                  Colors.white, // Fondo blanco mientras carga
                            ),
                  ),

                  // Segunda imagen para transición suave
                  Positioned(
                    top: offset2,
                    left: 0,
                    right: 0,
                    height: screenHeight + 100,
                    child:
                        _imagesPreloaded
                            ? Image.asset(
                              'assets/images/fondolb.jpg',
                              fit: BoxFit.cover,
                              cacheHeight: (screenHeight * 1.5).toInt(),
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white, // Fondo blanco en error
                                );
                              },
                            )
                            : Container(
                              color:
                                  Colors.white, // Fondo blanco mientras carga
                            ),
                  ),
                ],
              );
            },
          ),

          // Contenido principal (SIN OVERLAY)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 20), // Espaciado superior
                // Contenido central con logo y texto
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo con cache y error handling
                      _imagesPreloaded
                          ? Image.asset(
                            'assets/logos/logo_lebrunch.png',
                            height: screenHeight * 0.22,
                            fit: BoxFit.contain,
                            cacheHeight: (screenHeight * 0.3).toInt(),
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.restaurant,
                                size: screenHeight * 0.15,
                                color: const Color(0xFF3ea69b),
                              );
                            },
                          )
                          : Container(
                            height: screenHeight * 0.22,
                            color: Colors.white,
                            child: Center(
                              child: Icon(
                                Icons.restaurant,
                                size: screenHeight * 0.15,
                                color: const Color(0xFF3ea69b),
                              ),
                            ),
                          ),
                      SizedBox(height: screenHeight * 0.05),

                      // Título "Bienvenido"
                      const TextWithBorder(
                        text: 'Bienvenido',
                        fontSize: 45,
                        fontWeight: FontWeight.w600,
                        borderWidth: 3.0,
                      ),
                      const SizedBox(height: 16),

                      // Subtítulo
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: TextWithBorder(
                          text: 'Horneamos, Cocinamos y Disfrutamos',
                          fontSize: 22,
                          fontWeight: FontWeight.normal,
                          borderWidth: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botones de acceso
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
