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

  Future<int> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_rol') ?? 1;
  }

  Future<String> _getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? 'Usuario';
  }

  @override
  State<CustomBottomNavigationBar> createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  late final Future<int> _userRoleFuture;
  late final Future<String> _userNameFuture;
  int _selectedIndex = 0;
  late PageController _pageController;
  int? _userRole;
  String _userName = 'Usuario';

  final List<String> _adminScreenTitles = [
    'Reportes',
    'Registros',
    'Menú Admin',
    'Pedidos',
  ];
  final List<String> _clientScreenTitles = [
    'Inicio',
    'Menú',
    'Chat',
    'Carrito',
  ];

  @override
  void initState() {
    super.initState();
    _userRoleFuture = widget._getUserRole();
    _userNameFuture = widget._getUserName();
    _pageController = PageController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final role = await _userRoleFuture;
    final name = await _userNameFuture;
    if (mounted) {
      setState(() {
        _userRole = role;
        _userName = name;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  List<BottomNavigationBarItem> _buildBottomNavItems(BuildContext context) {
    final theme = Theme.of(context);

    if (_userRole == 0) {
      return [
        BottomNavigationBarItem(
          icon: const Icon(Icons.report),
          label: 'Reporte',
          activeIcon: Icon(
            Icons.report,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person),
          label: 'Registros',
          activeIcon: Icon(
            Icons.person,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.menu),
          label: 'Menú',
          activeIcon: Icon(
            Icons.menu,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.shopping_bag),
          label: 'Pedidos',
          activeIcon: Icon(
            Icons.shopping_bag,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
      ];
    } else {
      return [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: 'Inicio',
          activeIcon: Icon(
            Icons.home,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.menu),
          label: 'Menú',
          activeIcon: Icon(
            Icons.menu,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.chat),
          label: 'Chat',
          activeIcon: Icon(
            Icons.chat,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.shopping_cart),
          label: 'Carrito',
          activeIcon: Icon(
            Icons.shopping_cart,
            color: theme.colorScheme.primaryContainer,
          ),
        ),
      ];
    }
  }

  List<Widget> _buildPageViewChildren() {
    if (_userRole == 0) {
      return [ReportScreen(), RegistersScreen(), MenuScreen(), OrdersScreen()];
    } else {
      return [
        ClientHomeScreen(userName: _userName),
        ClientMenuScreen(),
        ChatScreen(),
        CartScreen(),
      ];
    }
  }

  String _getAppBarTitle() {
    return _userRole == 0
        ? _adminScreenTitles[_selectedIndex]
        : _clientScreenTitles[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder(
      future: Future.wait([_userRoleFuture, _userNameFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(_getAppBarTitle()),
            automaticallyImplyLeading: false,
            actions: const [LogoutButton()],
          ),
          body: PageView(
            controller: _pageController,
            physics:
                const ClampingScrollPhysics(), // Para una sensación más natural
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            children: _buildPageViewChildren(),
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: _buildBottomNavItems(context),
            currentIndex: _selectedIndex,
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
            backgroundColor: theme.colorScheme.surface,
            selectedLabelStyle: const TextStyle(
              fontFamily: 'LightHouse',
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'LightHouse',
              fontSize: 12,
            ),
            onTap: _onItemTapped,
          ),
        );
      },
    );
  }
}
