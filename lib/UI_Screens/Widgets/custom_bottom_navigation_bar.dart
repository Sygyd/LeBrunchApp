import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '/UI_Screens/Admin_Screens/menu_screen.dart';
import '/UI_Screens/Client_Screens/ClientHomeScreen.dart';
import '/UI_Screens/Client_Screens/CartScreen.dart';
import '/UI_Screens/Client_Screens/ChatScreen.dart';
import '/UI_Screens/Cook_Screens/ActiveOrdersScreen.dart';
import '/UI_Screens/Barista_Screens/BaristaActiveOrdersScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import '../Admin_Screens/AdminHomeScreen.dart';
import '../Client_Screens/ClientMenuScreen.dart';
import '../Admin_Screens/AdminChatScreen.dart';
import '../Cook_Screens/CookHomeScreen.dart';
import '../Cook_Screens/OrderHistoryScreen.dart';
import '../Cook_Screens/CookProfileScreen.dart';
import '../Barista_Screens/BaristaHomeScreen.dart';
import '../Barista_Screens/BaristaOrderHistoryScreen.dart';
import '../Barista_Screens/BaristaProfileScreen.dart';
import '../Admin_Screens/Users/AdminUsersScreen.dart';
import 'text_with_border.dart';
import 'package:http/http.dart' as http;
import '../../Api_services/cart_service.dart';
import '../../services/cart_event_bus.dart';
import 'background_scaffold.dart';

// PlaceholderScreen para reemplazar pantallas eliminadas o no implementadas
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: BackgroundScaffold(
        appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 80, color: Colors.amber),
              SizedBox(height: 20),
              Text(
                'Pantalla en construcción',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 10),
              Text(
                'Esta funcionalidad estará disponible próximamente',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomBottomNavigationBar extends StatefulWidget {
  final int initialIndex;

  const CustomBottomNavigationBar({super.key, this.initialIndex = 0});

  @override
  State<CustomBottomNavigationBar> createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  late int _currentIndex;
  int _userRole = 0;
  String? _userName;
  String? _userId; // Variable para almacenar el ID del usuario actual
  bool _isSuperAdmin =
      false; // **NUEVO**: Variable para trackear si es super admin
  bool _isLoading = true;
  final GlobalKey<CurvedNavigationBarState> _navBarKey = GlobalKey();
  final storage = const FlutterSecureStorage();
  bool showAdminSettings = false;
  bool _isShowingDialog =
      false; // Variable para rastrear si hay un diálogo activo

  late PageController _pageController;
  late Stream<int> _pageStream;
  late StreamController<int> _pageStreamController;

  // CartService para obtener la cantidad de elementos
  final CartService _cartService = CartService();

  // Usar ValueNotifier para el contador del carrito - esto permite actualizaciones más eficientes
  final ValueNotifier<int> _cartItemCountNotifier = ValueNotifier<int>(0);

  // Getter para acceder al valor actual
  int get _cartItemCount => _cartItemCountNotifier.value;

  // Timer para actualizar periódicamente el contador del carrito
  Timer? _cartUpdateTimer;

  // Suscripción a eventos del bus de carrito
  StreamSubscription<CartEvent>? _cartEventSubscription;

  // Variable para cachear el contador y reducir llamadas a SharedPreferences
  int _cachedCartCount = 0;
  DateTime _lastCartCountCheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _pageStreamController = StreamController<int>.broadcast();
    _pageStream = _pageStreamController.stream;
    _loadUserData();
    _checkDebugMode();

    // Configurar un temporizador para actualizar el contador del carrito más frecuentemente
    _cartUpdateTimer = Timer.periodic(Duration(milliseconds: 1000), (_) async {
      if (mounted) {
        await _updateCartItemCount();

        // Verificar actualizaciones desde ChatScreen cada vez
        await _checkPendingCartUpdatesFromChat();
      }
    });

    // Registrar como listener prioritario para recibir notificaciones inmediatas
    _cartService.addPriorityListener(_onCartChanged);

    // También escuchar cambios normales para compatibilidad
    _cartService.addListener(_onCartChanged);

    // Suscribirse a eventos del CartEventBus
    _cartEventSubscription = _cartService.cartEvents.listen(
      _onCartEventReceived,
    );
    print('⚡ BottomNav: Suscrito a eventos del CartEventBus');

    // Actualizar el contador inmediatamente
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _updateCartItemCount();

      // Verificar actualizaciones desde ChatScreen inmediatamente
      await _checkPendingCartUpdatesFromChat();

      // Verificar si hay una solicitud de navegación pendiente
      await _checkPendingNavigation();

      // Suscribirse a eventos del carrito para mantener actualizado el badge
      _subscribeToCartEvents();
    });
  }

  @override
  void dispose() {
    _pageStreamController.close();
    _pageController.dispose();

    // Eliminar ambos tipos de listeners
    _cartService.removePriorityListener(_onCartChanged);
    _cartService.removeListener(_onCartChanged);

    // Cancelar el temporizador al destruir el widget
    _cartUpdateTimer?.cancel();

    // NUEVO: Cancelar suscripción a eventos
    _cartEventSubscription?.cancel();
    print('⚡ BottomNav: Cancelada suscripción a eventos del CartEventBus');

    super.dispose();
  }

  // Este método se ejecuta cuando hay cambios en el carrito
  void _onCartChanged() async {
    if (mounted) {
      try {
        // Flujo estándar: Acceder directamente al contador
        final count = _cartService.itemCount;

        // Actualizar el contador directamente sin setState
        if (count != _cartItemCountNotifier.value) {
          print('🛒 Cambio detectado en el carrito: $_cartItemCount → $count');
          _cartItemCountNotifier.value = count;
        }
      } catch (e) {
        print('❌ Error en _onCartChanged: $e');
      }
    }
  }

  // NUEVO: Método para recibir eventos de cart_event_bus.dart
  void _onCartEventReceived(CartEvent event) {
    if (mounted) {
      print('📣 BottomNav: Evento del carrito recibido: ${event.type}');

      // Actualizar contador para cualquier tipo de evento
      _updateCartItemCount();
    }
  }

  // Método para actualizar el contador del carrito desde el servicio
  Future<void> _updateCartItemCount() async {
    try {
      // Resetear la caché para forzar una recarga fresca
      _cachedCartCount = 0;

      // Obtener el contador desde SharedPreferences
      final count = await _getCartCountFromPrefs();

      // Solo actualizar si es necesario para evitar ciclos
      if (count != _cartItemCountNotifier.value) {
        _cartItemCountNotifier.value = count;
      }

      // Si estamos montados, considerar una actualización de UI
      if (mounted) {
        // No actualizar el estado directamente para evitar reconstrucciones innecesarias
        // Solo actualizar si hay un cambio significativo
        final currentValue = _cartItemCountNotifier.value;
        if ((currentValue == 0 && count > 0) ||
            (currentValue > 0 && count == 0)) {
          setState(() {});
        }
      }
    } catch (e) {
      print('❌ Error al actualizar contador del carrito: $e');
    }
  }

  // Método para cambiar de página de manera más eficiente
  Future<void> _changePage(int index) async {
    if (index != _currentIndex) {
      try {
        print('🧭 Navegando a página $index desde $_currentIndex');

        // Guardar el índice anterior para referencia
        final fromIndex = _currentIndex;

        // Cambiar la página inmediatamente para mejor respuesta
        setState(() {
          _currentIndex = index;
        });

        // Actualizar PageController sin esperar
        try {
          _pageController.jumpToPage(index);
        } catch (e) {
          print('⚠️ Error en PageController: $e');
          _pageController = PageController(initialPage: index);
        }

        // Actualizar contadores pero sin forzar múltiples sincronizaciones
        final cartService = CartService();
        await cartService.registerScreenNavigation(fromIndex, index);

        // Una única actualización del contador después de cambiar de página
        await _updateCartItemCount();
      } catch (e) {
        print('❌ Error al cambiar página: $e');
      }
    }
  }

  // Verificar si hay una solicitud para navegar a una pestaña específica
  Future<void> _checkPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetTab = prefs.getInt('navigate_to_tab');
      final timestamp = prefs.getString('navigation_timestamp');

      // Solo procesar si hay un valor y el timestamp es reciente (últimos 5 segundos)
      if (targetTab != null && timestamp != null) {
        final navTime = DateTime.parse(timestamp);
        final now = DateTime.now();
        final diff = now.difference(navTime).inSeconds;

        if (diff <= 5) {
          // Considerar válidas las navegaciones de los últimos 5 segundos
          print(
            '🧭 CustomBottomNavigationBar: Navegando a pestaña $targetTab desde flag en SharedPreferences',
          );

          // Cambiar a la pestaña indicada
          if (mounted && targetTab != _currentIndex) {
            _changePage(targetTab);
          }
        }

        // Limpiar los valores después de procesarlos
        await prefs.remove('navigate_to_tab');
        await prefs.remove('navigation_timestamp');
      }

      // NUEVO: Verificar si hay actualizaciones pendientes del carrito desde ChatScreen
      await _checkPendingCartUpdatesFromChat();
    } catch (e) {
      print('❌ Error al verificar navegación pendiente: $e');
    }
  }

  // Método para verificar actualizaciones pendientes del carrito desde ChatScreen
  Future<void> _checkPendingCartUpdatesFromChat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool needsUpdate = false;

      // 1. Verificar todas las posibles marcas de tiempo de actualización
      final possibleMarks = [
        'chat_force_cart_update',
        'force_cart_update',
        'cart_force_update',
        'bottom_nav_cart_update',
      ];

      // Buscar la marca de tiempo más reciente
      DateTime? mostRecentUpdate;
      for (final mark in possibleMarks) {
        final updateMark = prefs.getString(mark);
        if (updateMark != null) {
          final updateTime = DateTime.parse(updateMark);
          if (mostRecentUpdate == null ||
              updateTime.isAfter(mostRecentUpdate)) {
            mostRecentUpdate = updateTime;
          }
        }
      }

      // Si encontramos una marca de tiempo, verificar si es reciente (últimos 60 segundos)
      if (mostRecentUpdate != null) {
        final now = DateTime.now();
        if (now.difference(mostRecentUpdate).inSeconds < 60) {
          print(
            '⚡ BottomNav: Detectada actualización reciente desde marca de tiempo',
          );
          needsUpdate = true;
        }
      }

      // 2. Verificar si el contador actual es diferente del almacenado
      final storedCount = prefs.getInt('cart_item_count') ?? 0;
      final currentNavCount = _cartItemCountNotifier.value;

      if (storedCount != currentNavCount) {
        print(
          '⚡ BottomNav: Discrepancia en contador: stored=$storedCount vs navBar=$currentNavCount',
        );
        needsUpdate = true;
      }

      // 3. También verificar el contador del servicio de carrito directamente
      final serviceCount = _cartService.itemCount;
      if (serviceCount != currentNavCount || serviceCount != storedCount) {
        print(
          '⚡ BottomNav: Discrepancia con servicio: service=$serviceCount, navBar=$currentNavCount, stored=$storedCount',
        );
        needsUpdate = true;
      }

      if (needsUpdate) {
        // Siempre usar el valor del servicio como fuente de verdad
        if (serviceCount != _cartItemCountNotifier.value) {
          // Actualizar el contador directamente
          _cartItemCountNotifier.value = serviceCount;

          // También actualizar prefs para mayor coherencia
          await prefs.setInt('cart_item_count', serviceCount);
          await prefs.setInt('current_cart_count', serviceCount);
          await prefs.setInt('last_nav_cart_count', serviceCount);

          // Forzar actualización del estado para reflejar cambios inmediatamente
          if (mounted) {
            setState(() {});
          }

          print(
            '🔄 BottomNav: Contador actualizado a $serviceCount desde actualización pendiente',
          );
        }
      }
    } catch (e) {
      print(
        '❌ Error al verificar actualizaciones del carrito desde ChatScreen: $e',
      );
    }
  }

  // Método para suscribirse a eventos del carrito
  void _subscribeToCartEvents() {
    // Cancelar suscripción anterior si existe
    _cartEventSubscription?.cancel();

    // Crear nueva suscripción
    _cartEventSubscription = _cartService.cartEvents.listen((event) {
      // Resetear caché para forzar recarga desde SharedPreferences
      _cachedCartCount = 0;

      // Actualizar el contador del carrito
      _updateCartItemCount();

      // Si es un evento de fuerza mayor, invalidar caché y forzar reconstrucción
      if (event.type == CartEventType.forceRefresh) {
        setState(() {}); // Forzar reconstrucción de la UI
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const BackgroundScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor = theme.colorScheme.surface;

    // Forzar actualización del contador del carrito cada vez que se construye el widget
    // para mantener sincronización entre todas las pantallas
    if (_userRole == 1) {
      // Solo para clientes
      _updateCartItemCount();
    }

    return WillPopScope(
      onWillPop: () async {
        // Evitar mostrar múltiples diálogos
        if (_isShowingDialog) return false;

        setState(() {
          _isShowingDialog = true;
        });

        // Mostrar diálogo de confirmación para cerrar sesión
        final shouldLogout = await showDialog<bool>(
          context: context,
          barrierDismissible: false, // Evitar cerrar el diálogo tocando fuera
          builder:
              (context) => AlertDialog(
                title: const Text('Cerrar sesión'),
                content: const Text('¿Deseas cerrar sesión?'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                      setState(() {
                        _isShowingDialog = false;
                      });
                    },
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context, true);
                      setState(() {
                        _isShowingDialog = false;
                      });
                    },
                    child: const Text(
                      'Cerrar sesión',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        );

        // Restablecer el estado del diálogo si se cerró inesperadamente
        if (mounted && _isShowingDialog) {
          setState(() {
            _isShowingDialog = false;
          });
        }

        if (shouldLogout == true) {
          await _logout();
        }
        return false; // Siempre retornar false para evitar la navegación hacia atrás
      },
      child: BackgroundScaffold(
        appBar: AppBar(
          title: _buildAppBarTitle(),
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF3ea69b),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          toolbarHeight: 70.0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.white, width: 1.5),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF3ea69b),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              image: DecorationImage(
                image: AssetImage('assets/images/fondo-flores-2.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () => _showUserModal(context),
                child: Tooltip(
                  message: 'Perfil de usuario',
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    child: Icon(_getRoleIcon(), size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });

            // Actualizar contador del carrito cuando cambia la página
            if (_userRole == 1) {
              // Solo para clientes
              _updateCartItemCount();
            }
          },
          children: _getPagesForRole(_userRole),
        ),
        bottomNavigationBar: CurvedNavigationBar(
          key: _navBarKey,
          index: _currentIndex,
          height: 60.0,
          items: _getNavItemsForRole(_userRole, Colors.white),
          color: primaryColor,
          buttonBackgroundColor: primaryColor,
          backgroundColor: Colors.transparent,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 300),
          onTap: (index) {
            _changePage(index);

            // Forzar actualización inmediata del contador cuando cambia la página
            if (_userRole == 1) {
              Future.delayed(Duration(milliseconds: 100), () {
                if (mounted) _updateCartItemCount();
              });
            }
          },
          letIndexChange: (index) => true,
        ),
      ),
    );
  }

  // Obtener páginas según el rol del usuario
  List<Widget> _getPagesForRole(int role) {
    switch (role) {
      case 0: // Administrador
        return [
          AdminHomeScreen(
            userName: _userName ?? 'Administrador',
            onNavigate:
                (index) => setState(() {
                  _currentIndex = index;
                  _pageController.jumpToPage(index);
                }),
          ),
          const MenuScreen(),
          const AdminChatScreen(),
          const AdminUsersScreen(), // Pantalla de administración de usuarios
        ];
      case 1: // Cliente
        return [
          ClientHomeScreen(
            userName: _userName ?? 'Usuario',
            onNavigate:
                (index) => setState(() {
                  _currentIndex = index;
                  _pageController.jumpToPage(index);
                }),
          ),
          const ClientMenuScreen(),
          const ChatScreen(),
          CartScreen(
            isEmbedded: true,
            onTabChange: (index) {
              setState(() {
                _currentIndex = index;
                _pageController.jumpToPage(index);
              });
            },
          ),
        ];
      case 2: // Cocinero
        return [
          CookHomeScreen(
            userName: _userName ?? 'Cocinero',
            onNavigate: (index) {
              setState(() {
                _currentIndex = index;
                _pageController.jumpToPage(index);
              });
            },
          ),
          const ActiveOrdersScreen(),
          const OrderHistoryScreen(),
          const CookProfileScreen(),
        ];
      case 3: // Barista
        return [
          BaristaHomeScreen(
            userName: _userName ?? 'Barista',
            onNavigate: (index) {
              setState(() {
                _currentIndex = index;
                _pageController.jumpToPage(index);
              });
            },
          ),
          const BaristaActiveOrdersScreen(),
          const BaristaOrderHistoryScreen(),
          const BaristaProfileScreen(),
        ];
      default:
        return [const PlaceholderScreen(title: 'Error de Rol')];
    }
  }

  // Obtener ítems de navegación según el rol
  List<Widget> _getNavItemsForRole(int role, Color iconColor) {
    switch (role) {
      case 0: // Administrador
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard, color: iconColor),
              Text(
                'Inicio',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu, color: iconColor),
              Text(
                'Menú',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat, color: iconColor),
              Text(
                'Chat',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, color: iconColor),
              Text(
                'Usuarios',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
        ];
      case 1: // Cliente
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home, color: iconColor),
              Text(
                'Cliente',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu, color: iconColor),
              Text(
                'Menú',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat, color: iconColor),
              Text(
                'Chat',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          _buildCartItem(iconColor),
        ];
      case 2: // Cocinero
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home, color: iconColor),
              Text(
                'Inicio',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fastfood, color: iconColor),
              Text(
                'Órdenes',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, color: iconColor),
              Text(
                'Historial',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, color: iconColor),
              Text(
                'Perfil',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
        ];
      case 3: // Barista
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home, color: iconColor),
              Text(
                'Inicio',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.coffee, color: iconColor),
              Text(
                'Órdenes',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, color: iconColor),
              Text(
                'Historial',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person, color: iconColor),
              Text(
                'Perfil',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
        ];
      default:
        return [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: iconColor),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Lighthouse',
                  color: iconColor,
                ),
              ),
            ],
          ),
        ];
    }
  }

  // Método especializado para construir el ítem de carrito con el badge
  Widget _buildCartItem(Color iconColor) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, color: iconColor),
            Text(
              'Carrito',
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'Lighthouse',
                color: iconColor,
              ),
            ),
          ],
        ),
        // Badge del carrito usando FutureBuilder para leer siempre desde SharedPreferences
        FutureBuilder<int>(
          // Leer contador siempre desde SharedPreferences
          future: _getCartCountFromPrefs(),
          builder: (context, snapshot) {
            // Mostrar contador solo si hay datos y es mayor que cero
            final count = snapshot.data ?? 0;

            // Usar post-frame callback para actualizar el notificador después del build
            if (count != _cartItemCountNotifier.value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _cartItemCountNotifier.value = count;
              });
            }

            return count > 0
                ? Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                : SizedBox.shrink();
          },
        ),
      ],
    );
  }

  // Método para obtener el contador del carrito desde SharedPreferences con caché temporal
  Future<int> _getCartCountFromPrefs() async {
    try {
      // Si ha pasado menos de 500ms desde la última verificación, usar el valor en caché
      final now = DateTime.now();
      final timeSinceLastCheck =
          now.difference(_lastCartCountCheck).inMilliseconds;

      if (timeSinceLastCheck < 500 && _cachedCartCount > 0) {
        return _cachedCartCount;
      }

      // Actualizar el timestamp de verificación
      _lastCartCountCheck = now;

      final prefs = await SharedPreferences.getInstance();

      // Intentar leer de las múltiples claves, tomando el mayor valor por seguridad
      final keys = [
        'cart_item_count',
        'current_cart_count',
        'last_nav_cart_count',
        'nav_bar_badge_count',
      ];
      int maxCount = 0;

      for (final key in keys) {
        final count = prefs.getInt(key) ?? 0;
        if (count > maxCount) {
          maxCount = count;
        }
      }

      // Comparar también con el contador del servicio
      final serviceCount = _cartService.itemCount;

      // Tomar el mayor valor entre SharedPreferences y el servicio
      final finalCount = maxCount > serviceCount ? maxCount : serviceCount;

      // Cachear el resultado para futuras llamadas
      _cachedCartCount = finalCount;

      return finalCount;
    } catch (e) {
      print('❌ Error al leer contador desde SharedPreferences: $e');

      // En caso de error, intentar leer directamente del servicio
      return _cartService.itemCount;
    }
  }

  // Construir el título de la barra de aplicación según el índice actual
  Widget _buildAppBarTitle() {
    final titleStyle = TextStyle(
      fontFamily: 'Lighthouse',
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.3),
          offset: const Offset(1, 1),
          blurRadius: 3,
        ),
      ],
    );

    switch (_userRole) {
      case 0: // Admin
        switch (_currentIndex) {
          case 0:
            return Text('Dashboard', style: titleStyle);
          case 1:
            return Text('Menú', style: titleStyle);
          case 2:
            return Text('Chat', style: titleStyle);
          case 3:
            return Text('Usuarios', style: titleStyle);
          default:
            return Text('Admin', style: titleStyle);
        }
      case 1: // Cliente
        switch (_currentIndex) {
          case 0:
            return Text('Cliente', style: titleStyle);
          case 1:
            return Text('Menú', style: titleStyle);
          case 2:
            return Text('Chat', style: titleStyle);
          case 3:
            return Text('Carrito', style: titleStyle);
          default:
            return Text('Cliente', style: titleStyle);
        }
      case 2: // Cocinero
        switch (_currentIndex) {
          case 0:
            return Text('Cocinero', style: titleStyle);
          case 1:
            return Text('Órdenes Activas', style: titleStyle);
          case 2:
            return Text('Historial', style: titleStyle);
          case 3:
            return Text('Perfil', style: titleStyle);
          default:
            return Text('Cocinero', style: titleStyle);
        }
      case 3: // Barista
        switch (_currentIndex) {
          case 0:
            return Text('Barista', style: titleStyle);
          case 1:
            return Text('Órdenes Activas', style: titleStyle);
          case 2:
            return Text('Historial', style: titleStyle);
          case 3:
            return Text('Perfil', style: titleStyle);
          default:
            return Text('Barista', style: titleStyle);
        }
      default:
        return Text('Le Brunch', style: titleStyle);
    }
  }

  // Mostrar modal con información del usuario
  void _showUserModal(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar y nombre
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  _userName != null && _userName!.isNotEmpty
                      ? _userName!.substring(0, 1).toUpperCase()
                      : 'U',
                  style: TextStyle(
                    fontSize: 30,
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _userName ?? 'Usuario',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getRoleName(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Opciones
              ListTile(
                leading: Icon(
                  Icons.person_outline,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Mi Perfil'),
                onTap: () {
                  Navigator.pop(context);
                  _showUserProfileModal(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // Cerrar el modal
                  setState(() {
                    _isShowingDialog = true;
                  });

                  // Mostrar diálogo de confirmación
                  showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Cerrar sesión'),
                          content: const Text('¿Deseas cerrar sesión?'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, false);
                                setState(() {
                                  _isShowingDialog = false;
                                });
                              },
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context, true);
                                _logout(); // Llamar directamente al método de cierre de sesión
                                setState(() {
                                  _isShowingDialog = false;
                                });
                              },
                              child: const Text(
                                'Cerrar sesión',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  ).then((value) {
                    // Asegurarse de restablecer el estado del diálogo
                    if (mounted && _isShowingDialog) {
                      setState(() {
                        _isShowingDialog = false;
                      });
                    }
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Mostrar los datos del perfil del usuario en un modal
  Future<void> _showUserProfileModal(BuildContext context) async {
    final theme = Theme.of(context);
    final prefs = await SharedPreferences.getInstance();

    // Obtener información básica del usuario desde SharedPreferences
    final userId = prefs.getInt('user_id');
    final serverIp = prefs.getString('serverIp') ?? '192.168.1.121';
    final serverPort = '3000';

    // Valores por defecto mientras se cargan los datos
    Map<String, String> userInfo = {
      'nombre': _userName?.split(' ').first ?? '',
      'apellido':
          (_userName != null && _userName!.split(' ').length > 1)
              ? _userName!.split(' ').last
              : '',
      'cedula': prefs.getString('user_cedula') ?? '',
      'email': prefs.getString('user_email') ?? '',
      'id': userId?.toString() ?? '',
    };

    // Intentar obtener datos actualizados del servidor antes de mostrar el modal
    if (userId != null) {
      try {
        print('📊 Obteniendo datos actualizados del usuario $userId...');

        final response = await http
            .get(
              Uri.parse('http://$serverIp:$serverPort/users/$userId'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final Map<String, dynamic> userData =
              json.decode(response.body) as Map<String, dynamic>;

          print('✅ Datos del usuario obtenidos: $userData');

          // Actualizar con los datos reales del servidor
          userInfo = {
            'nombre': userData['nombre']?.toString() ?? '',
            'apellido': userData['apellido']?.toString() ?? '',
            'cedula': userData['cedula']?.toString() ?? '',
            'email': userData['email']?.toString() ?? '',
            'id': userData['id']?.toString() ?? userId.toString(),
          };

          // Actualizar también SharedPreferences con datos frescos
          if (userData['email'] != null &&
              userData['email'].toString().isNotEmpty) {
            await prefs.setString('user_email', userData['email'].toString());
          }
          if (userData['cedula'] != null &&
              userData['cedula'].toString().isNotEmpty) {
            await prefs.setString('user_cedula', userData['cedula'].toString());
          }

          print('✅ Datos del usuario actualizados en SharedPreferences');
        } else {
          print('❌ Error al obtener datos del usuario: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error al cargar datos del usuario: $e');
        // Continuamos con los datos de SharedPreferences si hay error
      }
    }

    // Mostrar el modal con los datos obtenidos (ya sean del servidor o locales)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado con avatar y nombre
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              userInfo['nombre']?.isNotEmpty == true
                                  ? userInfo['nombre']!
                                      .substring(0, 1)
                                      .toUpperCase()
                                  : _userName != null && _userName!.isNotEmpty
                                  ? _userName!.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 60,
                                color: theme.colorScheme.onPrimary,
                                fontFamily: 'LightHouse',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userInfo['nombre']?.isNotEmpty == true &&
                                    userInfo['apellido']?.isNotEmpty == true
                                ? '${userInfo['nombre']} ${userInfo['apellido']}'
                                : _userName ?? 'Usuario',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _getRoleName(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Información personal
                    _buildSectionHeader(context, 'Información Personal'),
                    _buildInfoCard(context, [
                      _buildInfoRow(context, 'ID', userInfo['id'] ?? ''),
                      _buildInfoRow(
                        context,
                        'Nombre',
                        userInfo['nombre'] ?? '',
                      ),
                      _buildInfoRow(
                        context,
                        'Apellido',
                        userInfo['apellido'] ?? '',
                      ),
                      _buildInfoRow(
                        context,
                        'Cédula',
                        userInfo['cedula'] ?? '',
                      ),
                      _buildInfoRow(context, 'Email', userInfo['email'] ?? ''),
                    ]),

                    const SizedBox(height: 20),

                    // Botones de acción según el rol
                    _userRole == 0
                        ? _buildAdminActions(context)
                        : _userRole == 1
                        ? _buildClientActions(context)
                        : _userRole == 2
                        ? _buildCookActions(context)
                        : _buildBaristaActions(context),

                    const SizedBox(height: 20),

                    // Botón para cerrar
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Widgets auxiliares para construir la UI de perfil
  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: theme.colorScheme.primary.withOpacity(0.5),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  // Secciones de acciones según el rol
  Widget _buildAdminActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Acciones de Administrador'),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Usar Future.delayed para evitar que se active el teclado automáticamente
            Future.delayed(Duration.zero, () {
              setState(() => _currentIndex = 3); // Ir a la pantalla de usuarios
              _pageController.jumpToPage(3);
              // Asegurar que ningún campo de texto obtiene el foco automáticamente
              FocusManager.instance.primaryFocus?.unfocus();
            });
          },
          icon: const Icon(Icons.people),
          label: const Text('Gestionar Usuarios'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Usar Future.delayed para evitar que se active el teclado automáticamente
            Future.delayed(Duration.zero, () {
              setState(() => _currentIndex = 1); // Ir a la pantalla de menú
              _pageController.jumpToPage(1);
              // Asegurar que ningún campo de texto obtiene el foco automáticamente
              FocusManager.instance.primaryFocus?.unfocus();
            });
          },
          icon: const Icon(Icons.restaurant_menu),
          label: const Text('Gestionar Menú'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildClientActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Mis Acciones'),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _currentIndex = 3); // Ir al carrito
            _pageController.jumpToPage(3);
          },
          icon: const Icon(Icons.shopping_cart),
          label: const Text('Ver mi Carrito'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildCookActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Acciones de Cocinero'),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _currentIndex = 1); // Ir a órdenes activas
            _pageController.jumpToPage(1);
          },
          icon: const Icon(Icons.restaurant),
          label: const Text('Ver Órdenes Activas'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _currentIndex = 2); // Ir al historial
            _pageController.jumpToPage(2);
          },
          icon: const Icon(Icons.history),
          label: const Text('Historial de Órdenes'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildBaristaActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Acciones de Barista'),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _currentIndex = 1); // Ir a órdenes activas
            _pageController.jumpToPage(1);
          },
          icon: const Icon(Icons.coffee),
          label: const Text('Ver Órdenes Activas'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _currentIndex = 2); // Ir al historial
            _pageController.jumpToPage(2);
          },
          icon: const Icon(Icons.history),
          label: const Text('Historial de Órdenes'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  // Obtener nombre del rol actual
  String _getRoleName() {
    // **NUEVO**: Verificar si es super admin primero
    if (_isSuperAdmin && _userRole == 0) {
      return 'Super Administrador';
    }

    switch (_userRole) {
      case 0:
        return 'Administrador';
      case 1:
        return 'Cliente';
      case 2:
        return 'Cocinero';
      case 3:
        return 'Barista';
      default:
        return 'Invitado';
    }
  }

  // Obtener ícono según el rol del usuario
  IconData _getRoleIcon() {
    switch (_userRole) {
      case 0: // Administrador
        return Icons.admin_panel_settings;
      case 1: // Cliente
        return Icons.person;
      case 2: // Cocinero
        return Icons.restaurant;
      case 3: // Barista
        return Icons.coffee;
      default:
        return Icons.person;
    }
  }

  // Método para cerrar sesión
  Future<void> _logout() async {
    try {
      // IMPORTANTE: Limpiar primero todos los datos de carrito, antes de cualquier otra cosa
      try {
        // Limpiar todos los datos del carrito con el método especializado
        await _cartService.clearAllCarts();
        print('🧹 Carrito limpiado completamente usando clearAllCarts');
      } catch (e) {
        print('❌ Error al limpiar el carrito: $e');
      }

      // 1. Llamar al endpoint de logout en el backend
      final response = await http.post(
        Uri.parse('http://192.168.1.121:3000/logout'),
        headers: {"Content-Type": "application/json"},
      );

      // Limpiar completamente TODOS los datos del usuario en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();

      // Eliminar todas las claves excepto las de configuración de la app
      final keysToKeep = ['app_theme', 'app_language', 'first_run'];
      for (final key in allKeys) {
        // Preservar solo claves específicas de configuración de la app
        if (!keysToKeep.contains(key)) {
          await prefs.remove(key);
          print('🗑️ Eliminada clave: $key');
        }
      }

      // Limpiar las preferencias de platos del usuario
      await prefs.remove('user_dish_preferences');

      // Establecer flags para indicar que se ha cerrado sesión
      await prefs.setBool('user_logged_out', true);
      await prefs.setBool('cart_cleared_on_logout', true);

      // Asegurarse que cualquier dato de chat se limpie al cerrar sesión
      await prefs.remove('chat_history_global');
      await prefs.remove('chat_history_timestamp');
      await prefs.remove('persistent_chat_user_id');

      // Forzar limpieza específica de chat en SharedPreferences
      await prefs.remove('chat_messages');
      await prefs.remove('chat_last_timestamp');
      await prefs.remove('temporary_chat_id');
      print('🧹 Historial de chat eliminado de SharedPreferences');

      // Resetear el servicio de carrito completamente como respaldo adicional
      await _cartService.resetService();

      // Navegar a la pantalla de inicio de sesión (usando ruta nombrada)
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      print('❌ Error al cerrar sesión: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al cerrar sesión')));
      }
    }
  }

  // Intentamos sincronizar números de carrito inconsistentes
  Future<void> _attemptToSyncCartInconsistency() async {
    // Verificar si hay diferencias entre estado local y servicio
    final serviceCount = _cartService.itemCount;
    if (serviceCount != _cartItemCount) {
      print(
        '⚠️ Inconsistencia detectada: NavBar=$_cartItemCount, Service=$serviceCount',
      );

      // Dar precedencia al servicio (fuente de verdad)
      _cartItemCountNotifier.value = serviceCount;

      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cart_item_count', serviceCount);
      await prefs.setInt('current_cart_count', serviceCount);

      // No necesitamos disparar evento aquí ya que ahora usamos eventos de CartService

      // Forzar actualización del estado
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Cargar datos del usuario desde preferencias
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleId = prefs.getInt('user_rol');
      final name = prefs.getString('user_name');
      final userId = prefs.getInt('user_id');
      final isSuperAdmin =
          prefs.getBool('is_super_admin') ??
          false; // **NUEVO**: Cargar flag de super admin

      // Guardar ID de usuario para referencia en CartService
      if (userId != null) {
        _userId = userId.toString();
        // Usar el método setUserId para asegurar que el servicio esté sincronizado
        await _cartService.setUserId(_userId!);
        print('✅ ID de usuario actualizado en CartService: $_userId');
      } else {
        print('⚠️ No se encontró ID de usuario en SharedPreferences');
        // Establecer como usuario invitado
        _userId = 'guest';
        await _cartService.setUserId('guest');
      }

      print('🔑 Datos cargados del usuario:');
      print('   - Rol: $roleId');
      print('   - Nombre: $name');
      print('   - ID: $userId');
      print('   - Es Super Admin: $isSuperAdmin');

      setState(() {
        _userRole = roleId ?? 1; // Por defecto cliente si no hay rol
        _userName = name;
        _isSuperAdmin =
            isSuperAdmin; // **NUEVO**: Guardar estado de super admin
        _isLoading = false;
      });

      // **NUEVO**: Si es super admin con rol 0, asegurar que las pantallas de admin se carguen
      if (_isSuperAdmin && _userRole == 0) {
        print('🔑 Super Admin detectado - Cargando pantallas de administrador');
      }
    } catch (e) {
      print('Error al cargar datos de usuario: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkDebugMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final debugMode = prefs.getBool('debug_mode') ?? false;
      setState(() {
        showAdminSettings = debugMode;
      });
    } catch (e) {
      print('Error al verificar modo debug: $e');
    }
  }
}
