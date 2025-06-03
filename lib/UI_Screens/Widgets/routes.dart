import 'package:flutter/material.dart';
import '../Auth_Screens/auth_modals.dart';

import '../Client_Screens/ChatScreen.dart';
import '../Client_Screens/ClientHomeScreen.dart';
import '../Client_Screens/ClientMenuScreen.dart';
import '../Client_Screens/CartScreen.dart';
import '../Admin_Screens/AdminChatScreen.dart';
import '../Admin_Screens/ReportsScreen.dart';
import '../Admin_Screens/OrderHistoryScreen.dart';
import '../Admin_Screens/AdminHomeScreen.dart';
import '../Admin_Screens/AdminOrdersScreen.dart';
import '../Admin_Screens/PopularDishesScreen.dart';
import '../Admin_Screens/menu_screen.dart';
import '../Admin_Screens/Users/AdminUsersScreen.dart';
import '../Admin_Screens/DeletedItemsScreen.dart';
import '../Admin_Screens/UserManualScreen.dart';
import '../Admin_Screens/PdfViewerScreen.dart';
import 'splash_screen.dart';
import 'welcome.dart';
import 'custom_bottom_navigation_bar.dart';

/// Clase para manejar las rutas de la aplicación
class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Extraer argumentos si existen - manejar tanto Map como int (para índices)
    final dynamic rawArgs = settings.arguments;
    final Map<String, dynamic> args =
        rawArgs is Map<String, dynamic>
            ? rawArgs
            : rawArgs is int
            ? {'initialIndex': rawArgs}
            : {};

    switch (settings.name) {
      case '/splash':
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case '/':
      case '/welcome':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case '/home':
        return MaterialPageRoute(
          builder:
              (_) => CustomBottomNavigationBar(
                initialIndex:
                    args.containsKey('initialIndex') ? args['initialIndex'] : 0,
              ),
        );

      case '/client_home':
        // Usar CustomBottomNavigationBar con el índice proporcionado
        return MaterialPageRoute(
          builder:
              (_) => CustomBottomNavigationBar(
                initialIndex:
                    args.containsKey('initialIndex') ? args['initialIndex'] : 0,
              ),
        );

      case '/client/home':
        return MaterialPageRoute(
          builder:
              (_) => ClientHomeScreen(userName: 'Cliente', onNavigate: (_) {}),
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
        // Usar el modal de login en lugar de la pantalla
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Builder(
                  builder: (context) {
                    // Mostrar el modal de login automáticamente cuando se carga la página
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      AuthModals.showLoginModal(context);
                    });
                    // Mostrar un fondo mientras tanto
                    return const WelcomeScreen();
                  },
                ),
              ),
        );

      case '/register':
        // Usar el modal de registro en lugar de la pantalla
        return MaterialPageRoute(
          builder:
              (_) => Scaffold(
                body: Builder(
                  builder: (context) {
                    // Mostrar el modal de registro automáticamente cuando se carga la página
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      AuthModals.showRegisterModal(context);
                    });
                    // Mostrar un fondo mientras tanto
                    return const WelcomeScreen();
                  },
                ),
              ),
        );

      // Rutas de Administrador
      case '/admin/chat':
      case '/admin-chat':
        return MaterialPageRoute(builder: (_) => const AdminChatScreen());

      case '/admin/home':
      case '/admin-home':
        return MaterialPageRoute(
          builder:
              (_) => AdminHomeScreen(
                userName: args['userName'] ?? 'Administrador',
                onNavigate: args['onNavigate'],
              ),
        );

      case '/admin/menu':
      case '/admin-menu':
        return MaterialPageRoute(builder: (_) => const MenuScreen());

      case '/admin/reports':
      case '/admin-reports':
        return MaterialPageRoute(builder: (_) => const ReportsScreen());

      case '/admin/orders':
      case '/admin-orders':
        return MaterialPageRoute(builder: (_) => const AdminOrdersScreen());

      case '/admin/order-history':
      case '/admin-order-history':
        return MaterialPageRoute(
          builder:
              (_) => OrderHistoryScreen(
                title: args['title'] ?? 'Historial de Pedidos',
                startDate: args['startDate'],
                endDate: args['endDate'],
                estado: args['estado'],
              ),
        );

      case '/admin/popular-dishes':
      case '/admin-popular-dishes':
        return MaterialPageRoute(builder: (_) => const PopularDishesScreen());

      // Ruta para la administración de usuarios
      case '/admin/users':
      case '/admin-users':
        return MaterialPageRoute(builder: (_) => const AdminUsersScreen());

      // Ruta para elementos eliminados (soft delete)
      case '/admin/deleted-items':
      case '/admin-deleted-items':
        return MaterialPageRoute(builder: (_) => const DeletedItemsScreen());

      // Ruta para el manual de usuario
      case '/user-manual':
        return MaterialPageRoute(builder: (_) => const UserManualScreen());

      // Ruta para el visor de PDF simplificado
      case '/pdf-viewer':
        return MaterialPageRoute(
          builder:
              (_) => PdfViewerScreen(
                pdfPath: args['pdfPath'] ?? '',
                title: args['title'] ?? 'Manual de Usuario',
                initialPage: args['initialPage'],
              ),
        );

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
