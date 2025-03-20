import 'package:flutter/material.dart';
import '/theme/theme.dart';
import '/UI_Screens/Widgets/welcome.dart';
import '/UI_Screens/Auth_Screens/login.dart';
import '/UI_Screens/Auth_Screens/register.dart';
import '/UI_Screens/Admin_Screens/MenuScreen.dart';
import '/UI_Screens/Client_Screens/ClientHomeScreen.dart';
import '/UI_Screens/Admin_Screens/ReportScreen.dart';
import '/UI_Screens/Admin_Screens/RegistersScreen.dart';
import '/UI_Screens/Admin_Screens/OrdersScreen.dart';
import '/UI_Screens/Client_Screens/ChatScreen.dart';
import '/UI_Screens/Client_Screens/CartScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Le Brunch App',
      theme: lightMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const WelcomeScreen(),
            );
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginScreen());
          case '/register':
            return MaterialPageRoute(
              builder: (context) => const RegisterScreen(),
            );
          case '/menu':
            return MaterialPageRoute(builder: (context) => const MenuScreen());
          case '/client':
            if (settings.arguments != null &&
                settings.arguments is Map<String, dynamic>) {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder:
                    (context) => ClientHomeScreen(userName: args['userName']),
              );
            } else {
              return MaterialPageRoute(
                builder:
                    (context) => const ClientHomeScreen(userName: 'Cliente'),
              );
            }
          case '/report':
            return MaterialPageRoute(
              builder: (context) => const ReportScreen(),
            );
          case '/registers':
            return MaterialPageRoute(
              builder: (context) => const RegistersScreen(),
            );
          case '/orders':
            return MaterialPageRoute(
              builder: (context) => const OrdersScreen(),
            );
          case '/chat':
            return MaterialPageRoute(builder: (context) => const ChatScreen());
          case '/cart':
            return MaterialPageRoute(builder: (context) => const CartScreen());
          default:
            return MaterialPageRoute(
              builder: (context) => const WelcomeScreen(),
            );
        }
      },
    );
  }
}
