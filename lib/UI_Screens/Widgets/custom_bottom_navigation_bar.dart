import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import '/UI_Screens/Admin_Screens/ReportScreen.dart';
import '/UI_Screens/Admin_Screens/RegistersScreen.dart';
import '../Admin_Screens/menu_screen.dart';
import '/UI_Screens/Admin_Screens/OrdersScreen.dart';
import '/UI_Screens/Admin_Screens/AdminChatScreen.dart';
import '/UI_Screens/Client_Screens/ClientHomeScreen.dart';
import '/UI_Screens/Client_Screens/ChatScreen.dart';
import '/UI_Screens/Client_Screens/CartScreen.dart';
import '/UI_Screens/Client_Screens/ClientMenuScreen.dart';
import '/UI_Screens/Cook_Screens/CookHomeScreen.dart';
import '/UI_Screens/Cook_Screens/ActiveOrdersScreen.dart';
import '/UI_Screens/Cook_Screens/OrderHistoryScreen.dart';
import '/UI_Screens/Cook_Screens/CookProfileScreen.dart';
import '/UI_Screens/Barista_Screens/BaristaHomeScreen.dart';
import '/UI_Screens/Barista_Screens/BaristaActiveOrdersScreen.dart';
import '/UI_Screens/Barista_Screens/BaristaOrderHistoryScreen.dart';
import '/UI_Screens/Barista_Screens/BaristaProfileScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class CustomBottomNavigationBar extends StatefulWidget {
  const CustomBottomNavigationBar({super.key});

  @override
  State<CustomBottomNavigationBar> createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  int _selectedIndex = 0;
  int? _userRole;
  String _userName = 'Usuario';
  String _userCedula = '';
  bool _isLoading = true;
  final GlobalKey<CurvedNavigationBarState> _navBarKey = GlobalKey();

  final _pageController = PageController(initialPage: 0);
  final _scrollPhysics = const ClampingScrollPhysics();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getInt('user_rol') ?? 1;
    final name = prefs.getString('user_name') ?? 'Usuario';
    final cedula = prefs.getString('user_cedula') ?? '';

    if (mounted) {
      setState(() {
        _userRole = role;
        _userName = name;
        _userCedula = cedula;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      // Sincronizar la barra de navegación con la página actual
      final CurvedNavigationBarState? navBarState = _navBarKey.currentState;
      navBarState?.setPage(index);
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView(
      controller: _pageController,
      physics: _scrollPhysics,
      onPageChanged: _onPageChanged,
      children: _getPages(),
    );
  }

  List<Widget> _getPages() {
    switch (_userRole) {
      case 0: // Admin
        return [
          const ReportScreen(),
          const RegistersScreen(),
          const MenuScreen(),
          const OrdersScreen(),
          const AdminChatScreen(),
        ];
      case 2: // Cocinero
        return [
          const CookHomeScreen(),
          const ActiveOrdersScreen(),
          const OrderHistoryScreen(),
          const CookProfileScreen(),
        ];
      case 3: // Barista
        return [
          const BaristaHomeScreen(),
          const BaristaActiveOrdersScreen(),
          const BaristaOrderHistoryScreen(),
          const BaristaProfileScreen(),
        ];
      default: // Cliente (rol 1)
        return [
          ClientHomeScreen(
            userName: _userName,
            userCedula: _userCedula,
            onNavigate: _onItemTapped,
          ),
          const ClientMenuScreen(),
          const ChatScreen(),
          const CartScreen(),
        ];
    }
  }

  List<Widget> _getNavigationItems() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    switch (_userRole) {
      case 0: // Admin
        return [
          _buildNavItem(Icons.report, 'Reportes', 0, primaryColor),
          _buildNavItem(Icons.person, 'Registros', 1, primaryColor),
          _buildNavItem(Icons.menu, 'Menú', 2, primaryColor),
          _buildNavItem(Icons.shopping_bag, 'Pedidos', 3, primaryColor),
          _buildNavItem(Icons.chat, 'Chat', 4, primaryColor),
        ];
      case 2: // Cocinero
        return [
          _buildNavItem(Icons.home, 'Inicio', 0, primaryColor),
          _buildNavItem(Icons.lunch_dining, 'Pedidos', 1, primaryColor),
          _buildNavItem(Icons.history, 'Historial', 2, primaryColor),
          _buildNavItem(Icons.person, 'Perfil', 3, primaryColor),
        ];
      case 3: // Barista
        return [
          _buildNavItem(Icons.home, 'Inicio', 0, primaryColor),
          _buildNavItem(Icons.coffee, 'Pedidos', 1, primaryColor),
          _buildNavItem(Icons.history, 'Historial', 2, primaryColor),
          _buildNavItem(Icons.person, 'Perfil', 3, primaryColor),
        ];
      default: // Cliente (rol 1)
        return [
          _buildNavItem(Icons.home, 'Inicio', 0, primaryColor),
          _buildNavItem(Icons.menu, 'Menú', 1, primaryColor),
          _buildNavItem(Icons.chat, 'Chat', 2, primaryColor),
          _buildNavItem(Icons.shopping_cart, 'Carrito', 3, primaryColor),
        ];
    }
  }

  // Método auxiliar para construir los items de navegación
  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    Color primaryColor,
  ) {
    final isSelected = _selectedIndex == index;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 26, color: isSelected ? Colors.white : Colors.grey),
        if (isSelected)
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: null,
      body: Column(
        children: [
          // Nuevo encabezado personalizado con título y badge de rol
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Título con fuente Lighthouse y color del tema
                  Text(
                    _getAppBarTitle(),
                    style: TextStyle(
                      fontFamily: 'Lighthouse',
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Badge de rol del usuario (con funcionalidad de modal)
                  GestureDetector(
                    onTap: _showUserProfileModal,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getUserRoleIcon(),
                            color: theme.colorScheme.onPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getRoleName().toLowerCase(),
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Contenido principal
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _navBarKey,
        index: _selectedIndex,
        height: 60.0,
        items: _getNavigationItems(),
        color: Colors.white,
        buttonBackgroundColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.primaryContainer,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        onTap: _onItemTapped,
        letIndexChange: (index) => true,
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_userRole) {
      case 0: // Admin
        return [
          'Reportes',
          'Registros',
          'Menú Admin',
          'Pedidos',
          'Chat Admin',
        ][_selectedIndex];
      case 2: // Cocinero
        return [
          'Inicio',
          'Pedidos Activos',
          'Historial',
          'Perfil',
        ][_selectedIndex];
      case 3: // Barista
        return [
          'Inicio',
          'Pedidos Activos',
          'Historial',
          'Perfil',
        ][_selectedIndex];
      default: // Cliente (rol 1)
        return ['Inicio', 'Menú', 'Chat', 'Carrito'][_selectedIndex];
    }
  }

  void _showUserProfileModal() {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          alignment: Alignment.topRight,
          insetPadding: const EdgeInsets.only(top: 70, right: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con avatar y nombre
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      radius: 24,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _getRoleName(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),

                // Información del usuario
                if (_userCedula.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildInfoItem(Icons.credit_card, "Cédula", _userCedula),
                ],

                const SizedBox(height: 16),
                const Divider(),

                // Botón de cerrar sesión
                InkWell(
                  onTap: () async {
                    Navigator.pop(context); // Cerrar el modal
                    _logout();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.red.withOpacity(0.1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Cerrar Sesión",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  String _getRoleName() {
    switch (_userRole) {
      case 0:
        return "Administrador";
      case 2:
        return "Cocinero";
      case 3:
        return "Barista";
      default:
        return "Cliente";
    }
  }

  IconData _getUserRoleIcon() {
    switch (_userRole) {
      case 0: // Admin
        return Icons.admin_panel_settings;
      case 2: // Cocinero
        return Icons.restaurant;
      case 3: // Barista
        return Icons.coffee;
      default: // Cliente (rol 1)
        return Icons.person;
    }
  }

  Future<void> _logout() async {
    // Diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Limpiar datos locales
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('user_rol');
        await prefs.remove('user_name');
        await prefs.remove('user_cedula');
        await prefs.remove('gemini_connected');
        await prefs.remove('debug_mode');
        await prefs.remove('echo_mode');
        await prefs.remove('persistent_chat_user_id');
        await prefs.remove('temporary_chat_id');

        // Limpia cualquier dato del carrito
        await prefs.remove('cart');

        // Limpiar otros datos importantes
        try {
          http
              .post(
                Uri.parse('http://192.168.1.121:3000/logout'),
                headers: {"Content-Type": "application/json"},
              )
              .timeout(const Duration(seconds: 2))
              .catchError((_) {});
        } catch (_) {}

        // Esperar brevemente para que se completen operaciones pendientes
        await Future.delayed(Duration(milliseconds: 100));

        // Método de solución para error de Hero:
        // Usar Navigator.pushNamedAndRemoveUntil con reemplazo directo a la ruta inicial
        // sin intentar hacer pop o realizar animaciones de transición
        if (mounted) {
          // Usar este método evita problemas con animaciones Hero
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) => Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    ),
                transitionDuration: Duration.zero,
                opaque: false,
              ),
              (_) => false,
            );

            // Después de un breve retraso, ir a la página principal
            Future.delayed(const Duration(milliseconds: 50), () {
              Navigator.of(context).pushReplacementNamed('/');
            });
          });
        }
      } catch (e) {
        print("Error durante logout: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al cerrar sesión: ${e.toString()}")),
          );
        }
      }
    }
  }
}
