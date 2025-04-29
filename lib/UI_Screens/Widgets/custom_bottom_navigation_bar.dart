import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
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

// PlaceholderScreen para reemplazar pantallas eliminadas o no implementadas
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
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
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    // Inicializar el índice con el valor proporcionado en el constructor
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _pageStreamController = StreamController<int>.broadcast();
    _pageStream = _pageStreamController.stream;
    _loadUserData();
    _checkDebugMode();

    // Forzar la actualización del carrito
    _resetCartService();

    // Escuchar cambios en el carrito
    _cartService.addListener(_updateCartItemCount);
  }

  @override
  void dispose() {
    _pageStreamController.close();
    _pageController.dispose();
    _cartService.removeListener(_updateCartItemCount);
    super.dispose();
  }

  // Método para reiniciar el servicio de carrito
  Future<void> _resetCartService() async {
    await _cartService.resetService();
    _updateCartItemCount();
  }

  // Actualizar el contador de elementos del carrito
  void _updateCartItemCount() {
    if (mounted) {
      setState(() {
        _cartItemCount = _cartService.itemCount;
        print('🔢 Contador del carrito actualizado: $_cartItemCount');
      });
    }
  }

  // Método para cambiar de página
  void _changePage(int index) {
    if (index != _currentIndex) {
      // Si estamos cambiando a la pestaña de carrito (Cliente, índice 3),
      // forzar una actualización completa del carrito
      if (_userRole == 1 && index == 3) {
        _resetCartService();
      }

      setState(() {
        _currentIndex = index;
      });
      _pageController.jumpToPage(index);
      _pageStreamController.add(index);
    }
  }

  // Cargar datos del usuario desde preferencias
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleId = prefs.getInt('user_rol');
      final name = prefs.getString('user_name');
      final userId = prefs.getInt('user_id');

      // Configurar el CartService con el ID del usuario actual
      if (userId != null) {
        _cartService.setUserId(userId.toString());
        print('✅ CartService inicializado con ID de usuario: $userId');
      } else {
        print('⚠️ No se encontró ID de usuario en SharedPreferences');
      }

      setState(() {
        _userRole = roleId ?? 0;
        _userName = name;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final backgroundColor = theme.colorScheme.surface;

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
      child: Scaffold(
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
          backgroundColor: backgroundColor,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 300),
          onTap: _changePage,
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
          CookHomeScreen(userName: _userName ?? 'Cocinero'),
          const ActiveOrdersScreen(),
          const OrderHistoryScreen(),
          const CookProfileScreen(),
        ];
      case 3: // Barista
        return [
          BaristaHomeScreen(userName: _userName ?? 'Barista'),
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
          Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart, color: iconColor),
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
              if (_cartItemCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _cartItemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
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

    // Obtener información del usuario desde SharedPreferences
    final userId = prefs.getInt('user_id');
    final userEmail = prefs.getString('user_email') ?? 'correo@ejemplo.com';
    final userCedula = prefs.getString('user_cedula') ?? '';

    // En una implementación real, estos datos vendrían del servidor
    final Map<String, String> userInfo = {
      'nombre': _userName?.split(' ').first ?? 'Usuario',
      'apellido':
          (_userName != null && _userName!.split(' ').length > 1)
              ? _userName!.split(' ').last
              : '',
      'cedula': userCedula,
      'email': userEmail,
      'id': userId?.toString() ?? 'N/A',
    };

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
                              _userName != null && _userName!.isNotEmpty
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
                            _userName ?? 'Usuario',
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
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            // Aquí iría la navegación a los pedidos anteriores
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Historial de pedidos no implementado'),
              ),
            );
          },
          icon: const Icon(Icons.history),
          label: const Text('Mis Pedidos Anteriores'),
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
      // 1. Llamar al endpoint de logout en el backend
      final response = await http.post(
        Uri.parse('http://192.168.1.121:3000/logout'),
        headers: {"Content-Type": "application/json"},
      );

      // IMPORTANTE: Limpiar primero todos los datos de carrito, antes de cualquier otra cosa
      try {
        // Limpiar completamente TODOS los carritos guardados en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final allKeys = prefs.getKeys().toList();

        // Eliminar específicamente todas las claves relacionadas con carritos
        for (final key in allKeys) {
          if (key.startsWith('cart_')) {
            await prefs.remove(key);
            print('🗑️ Eliminada clave de carrito: $key');
          }
        }

        // También limpiar la memoria caché del carrito
        await _cartService.clearAllCarts();
        print(
          '🧹 Todos los datos de carritos eliminados de SharedPreferences y memoria',
        );
      } catch (e) {
        print('❌ Error al limpiar datos de carritos: $e');
      }

      if (response.statusCode == 200) {
        // 2. Limpiar todos los datos locales de forma segura
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'user_logged_out',
          true,
        ); // Marcar bandera para limpiar chat history
        await prefs.remove('auth_token'); // Token específico
        await prefs.remove('user_rol'); // Rol del usuario
        await prefs.remove('user_name'); // Nombre del usuario
        await prefs.remove('user_cedula');
        await prefs.remove('user_id'); // Eliminar ID del usuario
        await prefs.remove('gemini_connected');
        await prefs.remove('debug_mode');
        await prefs.remove('echo_mode');
        await prefs.remove('persistent_chat_user_id');
        await prefs.remove('temporary_chat_id');

        // Establecer el ID a 'guest' para el nuevo estado
        await _cartService.setUserId('guest');
        print('✅ CartService reiniciado y establecido como invitado');

        // Actualizar el contador del carrito en la UI
        _updateCartItemCount();

        // 3. Redirección segura a WelcomeScreen
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (Route<dynamic> route) =>
                false, // Elimina toda la pila de navegación
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error al cerrar sesión en el servidor"),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error de conexión: ${e.toString()}")),
        );
      }
    }
  }
}
