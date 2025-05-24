import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  int _totalPedidosCompletados = 0;
  int _totalPedidosCancelados = 0;

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

      int totalCompletados = 0;
      int totalCancelados = 0;
      String updatedEmail = userEmail;

      // Verificar si el widget sigue montado antes de continuar
      if (!mounted) return;

      // Intentar obtener la información del usuario directamente desde la base de datos
      // para asegurar que tenemos los datos más actualizados
      final serverIp =
          prefs.getString('serverIp') ??
          dotenv.env['NODE_SERVER_IP'] ??
          '192.168.1.121';
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

      // Verificar si el widget sigue montado antes de continuar
      if (!mounted) return;

      // Cargar estadísticas - pedidos completados y cancelados
      try {
        final url = Uri.parse('http://$serverIp:$serverPort/db/query');

        // Obtener pedidos completados
        final responseCompletados = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'query': '''
              SELECT COUNT(*) as total 
              FROM pedidos 
              WHERE estado = 'completado'
            ''',
              }),
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⏱️ Timeout al obtener pedidos completados');
                throw Exception('Timeout en la conexión');
              },
            );

        // Verificar si el widget sigue montado
        if (!mounted) return;

        if (responseCompletados.statusCode == 200) {
          final data = json.decode(responseCompletados.body);
          if (data['result'] != null && data['result'].isNotEmpty) {
            totalCompletados =
                int.tryParse(data['result'][0]['total'].toString()) ?? 0;
          }
        }

        // Verificar si el widget sigue montado antes de continuar
        if (!mounted) return;

        // Obtener pedidos cancelados
        final responseCancelados = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'query': '''
              SELECT COUNT(*) as total 
              FROM pedidos 
              WHERE estado = 'cancelado'
            ''',
              }),
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                debugPrint('⏱️ Timeout al obtener pedidos cancelados');
                throw Exception('Timeout en la conexión');
              },
            );

        // Verificar si el widget sigue montado
        if (!mounted) return;

        if (responseCancelados.statusCode == 200) {
          final data = json.decode(responseCancelados.body);
          if (data['result'] != null && data['result'].isNotEmpty) {
            totalCancelados =
                int.tryParse(data['result'][0]['total'].toString()) ?? 0;
          }
        }
      } catch (e) {
        debugPrint('Error al cargar estadísticas: $e');
        // Continuamos con los valores por defecto (0)
      }

      // Verificación final de mounted antes de actualizar el estado
      if (mounted) {
        setState(() {
          _userInfo = userInfo;
          _userName = userName;
          _userEmail = updatedEmail;
          _totalPedidosCompletados = totalCompletados;
          _totalPedidosCancelados = totalCancelados;
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

            const SizedBox(height: 20),

            // Estadísticas
            _buildSectionHeader(context, 'Estadísticas'),
            _buildStatsCard(context),
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

  Widget _buildStatsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Pedidos Completados',
                    _totalPedidosCompletados.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Pedidos Cancelados',
                    _totalPedidosCancelados.toString(),
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
