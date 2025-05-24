import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../Api_services/gemini_service.dart';
import '../../Api_services/cart_service.dart';
import '../../services/user_preferences_service.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _logout(BuildContext context) async {
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
        print('🔄 Iniciando proceso de cierre de sesión completo...');

        // Mostrar un indicador de carga
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(child: CircularProgressIndicator());
            },
          );
        }

        // 1. PRIMERO: Limpiar el carrito y resetear su estado
        final cartService = CartService();
        await cartService.clearAllCarts();
        print('✅ Carrito limpiado completamente');

        // 2. Limpiar historial de chat y preferencias de usuario
        final geminiService = GeminiService();
        await geminiService.clearChatHistory();
        print('✅ Historial de chat limpiado');

        // Limpiar todas las claves de SharedPreferences relacionadas con el chat
        final prefs = await SharedPreferences.getInstance();
        final chatKeys = prefs.getKeys().toList();
        for (final key in chatKeys) {
          if (key.contains('chat_history') ||
              key.contains('chat_messages') ||
              key.contains('temporary_chat_id') ||
              key.contains('persistent_chat_user_id')) {
            await prefs.remove(key);
            print('🗑️ Eliminada clave de chat: $key');
          }
        }

        // 3. Limpiar preferencias de platos del usuario
        final userPreferencesService = UserPreferencesService();
        await userPreferencesService.clearAllPreferences();
        print('✅ Preferencias de platos eliminadas');

        // 4. Llamar al endpoint de logout del servidor
        try {
          final response = await http
              .post(
                Uri.parse('http://192.168.1.121:3000/logout'),
                headers: {"Content-Type": "application/json"},
              )
              .timeout(const Duration(seconds: 5));
          print('✅ Logout en servidor: ${response.statusCode}');
        } catch (e) {
          print('⚠️ Error al llamar endpoint de logout: $e');
          // Continuamos aunque haya error al contactar al servidor
        }

        // 5. Limpiar TODAS las preferencias excepto configuraciones de la app
        final allKeys = prefs.getKeys().toList();
        final keysToKeep = ['app_theme', 'app_language', 'first_run'];

        print('🧹 Limpiando todas las claves en SharedPreferences...');
        for (final key in allKeys) {
          if (!keysToKeep.contains(key)) {
            await prefs.remove(key);
            print('🗑️ Eliminada clave: $key');
          }
        }

        // 6. Establecer flags para indicar cierre de sesión
        await prefs.setBool('user_logged_out', true);
        await prefs.setBool('cart_cleared_on_logout', true);

        // 7. Reiniciar el carrito con ID de invitado (después de limpiar todo)
        await cartService.setUserId('guest');
        print('✅ CartService reiniciado y establecido como invitado');

        // 8. Cerrar el diálogo de carga y navegar a la pantalla de inicio
        if (context.mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/',
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        print('❌ Error en el proceso de logout: $e');

        // Cerrar diálogo de carga en caso de error
        if (context.mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al cerrar sesión: ${e.toString()}")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => _logout(context),
    );
  }
}
