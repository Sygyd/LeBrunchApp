import 'package:flutter/material.dart';
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
  final int userRole;

  const CustomBottomNavigationBar({super.key, required this.userRole});

  @override
  _CustomBottomNavigationBarState createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  List<BottomNavigationBarItem> _buildBottomNavigationBarItems() {
    if (widget.userRole == 0) {
      return const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Reporte'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Registros'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menú'),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_bag),
          label: 'Pedidos',
        ),
      ];
    } else {
      return const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Bienvenida'),
        BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menú'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'Carrito',
        ),
      ];
    }
  }

  List<Widget> _buildPageViewChildren() {
    if (widget.userRole == 0) {
      return const <Widget>[
        ReportScreen(),
        RegistersScreen(),
        MenuScreen(), // Mostrar MenuScreen para admin
        OrdersScreen(),
      ];
    } else {
      return const <Widget>[
        ClientHomeScreen(
          userName: 'Cliente',
        ), // Ajusta el nombre del cliente según sea necesario
        ClientMenuScreen(), // Mostrar MenuScreen para cliente
        ChatScreen(),
        CartScreen(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App'),
        automaticallyImplyLeading: false,
        actions: [if (widget.userRole == 0) const LogoutButton()],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _buildPageViewChildren(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: _buildBottomNavigationBarItems(),
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        onTap: _onItemTapped,
      ),
    );
  }
}
