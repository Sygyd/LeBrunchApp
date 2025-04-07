import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../Api_services/gemini_service.dart';

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
        // Marcar que el usuario ha cerrado sesión (para limpiar el historial de chat)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('user_logged_out', true);

        final response = await http.post(
          Uri.parse('http://192.168.1.121:3000/logout'),
          headers: {"Content-Type": "application/json"},
        );

        // Limpiar preferencias excepto las necesarias para mantener configuraciones de la app
        await prefs.remove('user_id');
        await prefs.remove('user_role');
        await prefs.remove('user_name');
        await prefs.remove('token');
        await prefs.remove('persistent_chat_user_id');

        // Limpiar historial de chat inmediatamente
        await _clearChatHistory();

        if (!context.mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (Route<dynamic> route) => false,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
      }
    }
  }

  /// Limpia el historial de chat al cerrar sesión
  Future<void> _clearChatHistory() async {
    try {
      // Usar el servicio Gemini directamente ya que ahora lo importamos
      final geminiService = GeminiService();
      await geminiService.resetChat();
      print('Historial de chat limpiado después del cierre de sesión');
    } catch (e) {
      print('Error al limpiar historial de chat: $e');
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
