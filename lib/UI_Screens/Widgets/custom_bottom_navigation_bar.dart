import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/logout_button.dart';
import '/UI_Screens/Admin_Screens/ReportScreen.dart';
import '/UI_Screens/Admin_Screens/RegistersScreen.dart';
import '../Admin_Screens/menu_screen.dart';
import '/UI_Screens/Admin_Screens/OrdersScreen.dart';
import '/UI_Screens/Client_Screens/ClientHomeScreen.dart';
import '/UI_Screens/Client_Screens/ChatScreen.dart';
import '/UI_Screens/Client_Screens/CartScreen.dart';
import '/UI_Screens/Client_Screens/ClientMenuScreen.dart';

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
  bool _isLoading = true;
  int _userId = 0; // Nuevo campo para almacenar el ID del usuario

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
    final id = prefs.getInt('user_id') ?? 0; // Obtener el ID del usuario

    if (mounted) {
      setState(() {
        _userRole = role;
        _userName = name;
        _userId = id; // Asignar el ID del usuario
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
      children:
          _userRole == 0
              ? [
                const ReportScreen(),
                const RegistersScreen(),
                const MenuScreen(),
                const OrdersScreen(),
              ]
              : [
                ClientHomeScreen(userName: _userName),
                const ClientMenuScreen(),
                ChatScreen(userId: _userId), // Usar el ID almacenado
                const CartScreen(),
              ],
    );
  }

  BottomNavigationBarItem _buildNavItem(
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;
    final color =
        isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return BottomNavigationBarItem(
      icon: Icon(icon, color: color),
      label: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _userRole == 0
              ? [
                'Reportes',
                'Registros',
                'Menú Admin',
                'Pedidos',
              ][_selectedIndex]
              : ['Inicio', 'Menú', 'Chat', 'Carrito'][_selectedIndex],
        ),
        actions: const [LogoutButton()],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items:
            _userRole == 0
                ? [
                  _buildNavItem(Icons.report, 'Reporte', 0),
                  _buildNavItem(Icons.person, 'Registros', 1),
                  _buildNavItem(Icons.menu, 'Menú', 2),
                  _buildNavItem(Icons.shopping_bag, 'Pedidos', 3),
                ]
                : [
                  _buildNavItem(Icons.home, 'Inicio', 0),
                  _buildNavItem(Icons.menu, 'Menú', 1),
                  _buildNavItem(Icons.chat, 'Chat', 2),
                  _buildNavItem(Icons.shopping_cart, 'Carrito', 3),
                ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }
}
