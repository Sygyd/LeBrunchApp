import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../Api_services/network_config_service.dart';

/// Pantalla de perfil compartida que puede ser usada tanto por Cocinero como por Barista
/// Recibe parámetros para personalizar la apariencia y comportamiento según el rol
class SharedProfileScreen extends StatefulWidget {
  final String role; // 'cook' o 'barista'
  final String roleTitle;
  final String roleEspecialidad;
  final String defaultInitial;
  final IconData roleIcon;

  const SharedProfileScreen({
    super.key,
    required this.role,
    required this.roleTitle,
    required this.roleEspecialidad,
    this.defaultInitial = 'U',
    this.roleIcon = Icons.person,
  });

  @override
  State<SharedProfileScreen> createState() => _SharedProfileScreenState();
}

class _SharedProfileScreenState extends State<SharedProfileScreen> {
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  Map<String, dynamic> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final userEmail = prefs.getString('user_email') ?? '';
      final userCedula = prefs.getString('user_cedula') ?? '';
      final userName = prefs.getString('user_name') ?? '';

      // Imprimir información para debug
      final roleEmoji = widget.role == 'barista' ? '🧋' : '🧑‍🍳';
      debugPrint('$roleEmoji Datos de usuario ${widget.roleTitle}:');
      debugPrint('ID: $userId');
      debugPrint('Email: $userEmail');
      debugPrint('Cédula: $userCedula');
      debugPrint('Nombre: $userName');

      // Preparamos datos iniciales para el estado por si falla la carga
      Map<String, dynamic> userInfo = {
        'id': userId?.toString() ?? 'N/A',
        'nombre': userName.split(' ').first,
        'apellido':
            userName.split(' ').length > 1
                ? userName.substring(userName.indexOf(' ') + 1)
                : '',
        'cedula': userCedula,
        'email': userEmail,
        'cargo': widget.roleTitle,
        'especialidad': widget.roleEspecialidad,
      };

      String updatedEmail = userEmail;

      // Verificar si el widget sigue montado antes de continuar
      if (!mounted) return;

      // Intentar obtener la información del usuario directamente desde la base de datos
      // para asegurar que tenemos los datos más actualizados
      final serverIp =
          prefs.getString('serverIp') ??
          dotenv.env['NODE_SERVER_IP'] ??
          NetworkConfigService().serverIp;
      final serverPort = dotenv.env['NODE_SERVER_PORT'] ?? '3000';

      if (userId != null) {
        try {
          final url = Uri.parse('http://$serverIp:$serverPort/users/$userId');
          final response = await http
              .get(url)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  debugPrint('⏱️ Timeout al obtener datos del usuario');
                  throw Exception('Timeout en la conexión');
                },
              );

          // Verificar si el widget sigue montado
          if (!mounted) return;

          if (response.statusCode == 200) {
            final userData = json.decode(response.body);
            debugPrint('📊 Datos de usuario desde API: $userData');

            // Actualizar información del email si está disponible en la respuesta
            if (userData['email'] != null &&
                userData['email'].toString().isNotEmpty) {
              updatedEmail = userData['email'];
              await prefs.setString('user_email', updatedEmail);
            }
          }
        } catch (e) {
          debugPrint('❌ Error obteniendo datos del usuario: $e');
          // No detenemoas la ejecución, continuamos con los datos disponibles
        }
      }

      // Verificación final de mounted antes de actualizar el estado
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _userName = userName;
          _userEmail = updatedEmail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error cargando datos del usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar y nombre de usuario
            CircleAvatar(
              radius: 60,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                _userName.isNotEmpty
                    ? _userName.substring(0, 1).toUpperCase()
                    : widget.defaultInitial,
                style: TextStyle(
                  fontSize: 60,
                  color: theme.colorScheme.onPrimary,
                  fontFamily: 'LightHouse',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _userName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              _userInfo['cargo'] ?? widget.roleTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Información personal
            _buildSectionHeader(context, 'Información Personal'),
            _buildInfoCard(context, [
              _buildInfoRow(context, 'ID', _userInfo['id'] ?? ''),
              _buildInfoRow(context, 'Cédula', _userInfo['cedula'] ?? ''),
              _buildInfoRow(context, 'Email', _userEmail),
            ]),

            const SizedBox(height: 20),

            // Información laboral
            _buildSectionHeader(context, 'Información Laboral'),
            _buildInfoCard(context, [
              _buildInfoRow(context, 'Cargo', _userInfo['cargo'] ?? ''),
              _buildInfoRow(
                context,
                'Especialidad',
                _userInfo['especialidad'] ?? '',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: theme.colorScheme.primary.withOpacity(0.5),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
