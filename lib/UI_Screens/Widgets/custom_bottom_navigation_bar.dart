import 'package:flutter/material.dart';

class CustomBottomNavigationBar extends StatefulWidget {
  final int userRole; // 0 para admin, 1 para cliente

  const CustomBottomNavigationBar({super.key, required this.userRole});

  @override
  _CustomBottomNavigationBarState createState() =>
      _CustomBottomNavigationBarState();
}

class _CustomBottomNavigationBarState extends State<CustomBottomNavigationBar> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navegar a la pantalla correspondiente
    switch (widget.userRole) {
      case 0: // Admin
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/report');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/registers');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/menu');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/orders');
            break;
        }
        break;
      case 1: // Cliente
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/welcome');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/menu');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/chat');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/cart');
            break;
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items:
          widget.userRole == 0
              ? const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.report),
                  label: 'Reporte',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Registros',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menú'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_bag),
                  label: 'Pedidos',
                ),
              ]
              : const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Bienvenida',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menú'),
                BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_cart),
                  label: 'Carrito',
                ),
              ],
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.teal,
      onTap: _onItemTapped,
    );
  }
}
