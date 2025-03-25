import 'package:flutter/material.dart';
import '/UI_Screens/Auth_Screens/login.dart';
import '/UI_Screens/Auth_Screens/register.dart';
import '/UI_Screens/Widgets/welcome.dart';
import '../Admin_Screens/menu_screen.dart';
import '/UI_Screens/Client_Screens/ClientMenuScreen.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case '/menu':
        return MaterialPageRoute(builder: (_) => const MenuScreen());
      case '/clientMenu':
        return MaterialPageRoute(builder: (_) => const ClientMenuScreen());
      default:
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('No route defined for ${settings.name}'),
                ),
              ),
        );
    }
  }
}
