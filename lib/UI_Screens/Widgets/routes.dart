import 'package:flutter/material.dart';
import '/UI_Screens/Auth_Screens/login.dart';
import '/UI_Screens/Auth_Screens/register.dart';
import '/UI_Screens/Widgets/welcome.dart';
import '/UI_Screens/Widgets/splash_screen.dart';
import '/UI_Screens/Widgets/custom_bottom_navigation_bar.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/splash':
        return _buildRoute(const SplashScreen());
      case '/':
        return _buildRoute(const WelcomeScreen());
      case '/login':
        return _buildRoute(const LoginScreen());
      case '/register':
        return _buildRoute(const RegisterScreen());
      case '/home':
        return _buildRoute(
          WillPopScope(
            onWillPop: () async => false,
            child: const CustomBottomNavigationBar(),
          ),
        );
      default:
        return _buildRoute(
          Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }

  static MaterialPageRoute _buildRoute(Widget widget) {
    return MaterialPageRoute(
      builder: (_) => widget,
      settings: const RouteSettings(name: '/'),
    );
  }
}
