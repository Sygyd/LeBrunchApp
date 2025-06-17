import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config.dart';

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

      // Variables para datos actualizados
      String updatedUserName = userName;
      String updatedEmail = userEmail;
      String updatedCedula = userCedula;

      // Verificar si el widget sigue montado antes de continuar
      if (!mounted) return;

      // SIMPLIFICADO: Usar configuración centralizada de AppConfig
      print('🌐 $roleEmoji Obteniendo configuración del servidor...');

      // Usar la configuración centralizada del proyecto
      final serverUrl = AppConfig.serverUrl;
      print('🔗 $roleEmoji Usando servidor desde AppConfig: $serverUrl');

      if (userId != null) {
        try {
          print('📡 $roleEmoji Conectando a: $serverUrl/users/$userId');

          final url = Uri.parse('$serverUrl/users/$userId');
          final response = await http
              .get(url, headers: {'Content-Type': 'application/json'})
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () {
                  print('⏱️ $roleEmoji Timeout al obtener datos del usuario');
                  throw Exception('Timeout en la conexión');
                },
              );

          // Verificar si el widget sigue montado
          if (!mounted) return;

          print('📊 $roleEmoji Respuesta del servidor: ${response.statusCode}');

          if (response.statusCode == 200) {
            final userData = json.decode(response.body);
            print('✅ $roleEmoji Datos de usuario desde API: $userData');

            // CORREGIDO: Actualizar TODOS los datos del usuario, no solo el email
            if (userData['nombre'] != null &&
                userData['nombre'].toString().isNotEmpty) {
              final firstName = userData['nombre'].toString();
              final lastName = userData['apellido']?.toString() ?? '';
              updatedUserName =
                  lastName.isNotEmpty ? '$firstName $lastName' : firstName;

              // Actualizar SharedPreferences con el nombre completo
              await prefs.setString('user_name', updatedUserName);
              print('📝 $roleEmoji Nombre actualizado: $updatedUserName');
            }

            if (userData['email'] != null &&
                userData['email'].toString().isNotEmpty) {
              updatedEmail = userData['email'].toString();
              await prefs.setString('user_email', updatedEmail);
              print('📝 $roleEmoji Email actualizado: $updatedEmail');
            }

            if (userData['cedula'] != null &&
                userData['cedula'].toString().isNotEmpty) {
              updatedCedula = userData['cedula'].toString();
              await prefs.setString('user_cedula', updatedCedula);
              print('📝 $roleEmoji Cédula actualizada: $updatedCedula');
            }

            // Actualizar el mapa userInfo con los datos frescos del servidor
            userInfo = {
              'id': userData['id']?.toString() ?? userId.toString(),
              'nombre':
                  userData['nombre']?.toString() ?? userName.split(' ').first,
              'apellido':
                  userData['apellido']?.toString() ??
                  (userName.split(' ').length > 1
                      ? userName.substring(userName.indexOf(' ') + 1)
                      : ''),
              'cedula': userData['cedula']?.toString() ?? userCedula,
              'email': userData['email']?.toString() ?? userEmail,
              'cargo': widget.roleTitle,
              'especialidad': widget.roleEspecialidad,
            };

            print('🔄 $roleEmoji UserInfo actualizado con datos del servidor');
          } else {
            print('❌ $roleEmoji Error del servidor: ${response.statusCode}');
            print('📄 $roleEmoji Cuerpo de respuesta: ${response.body}');
          }
        } catch (e) {
          print('❌ $roleEmoji Error obteniendo datos del usuario: $e');
          print(
            '📱 $roleEmoji Continuando con datos locales de SharedPreferences',
          );
          // No detenemos la ejecución, continuamos con los datos disponibles
        }
      } else {
        print('⚠️ $roleEmoji No se encontró userId en SharedPreferences');
      }

      // Verificación final de mounted antes de actualizar el estado
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _userName = updatedUserName;
          _userEmail = updatedEmail;
          _isLoading = false;
        });

        print('✅ $roleEmoji Estado actualizado correctamente');
        print('👤 $roleEmoji Nombre final: $updatedUserName');
        print('📧 $roleEmoji Email final: $updatedEmail');
        print('🆔 $roleEmoji Cédula final: $updatedCedula');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print(
        '❌ ${widget.role == 'barista' ? '🧋' : '🧑‍🍳'} Error cargando datos del usuario: $e',
      );
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
