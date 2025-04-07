import 'package:flutter/material.dart';
import '../Auth_Screens/auth_modals.dart';
import '../Client_Screens/ChatScreen.dart';
import '../Client_Screens/ClientHomeScreen.dart';
import '../Client_Screens/ClientMenuScreen.dart';
import '../Client_Screens/CartScreen.dart';
import '../Admin_Screens/AdminChatScreen.dart';
import '../Auth_Screens/login.dart';
import '../Auth_Screens/register.dart';
import 'splash_screen.dart';
import 'welcome.dart';
import 'custom_bottom_navigation_bar.dart';

/// Clase para manejar las rutas de la aplicación
class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case '/':
      case '/welcome':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case '/home':
        return MaterialPageRoute(
          builder: (_) => const CustomBottomNavigationBar(),
        );

      case '/client/home':
        return MaterialPageRoute(
          builder: (_) => ClientHomeScreen(userName: '', userCedula: ''),
        );

      case '/menu':
      case '/client/menu':
        return MaterialPageRoute(builder: (_) => const ClientMenuScreen());

      case '/cart':
      case '/client/cart':
        return MaterialPageRoute(builder: (_) => const CartScreen());

      case '/chat':
      case '/client/chat':
        return MaterialPageRoute(builder: (_) => const ChatScreen());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case '/admin/chat':
        return MaterialPageRoute(builder: (_) => AdminChatScreen());

      default:
        // Si la ruta no existe, redirigir a la pantalla de inicio
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Center(
                  child: Text('No se encontró la ruta ${settings.name}'),
                ),
              ),
        );
    }
  }
}
