import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaristaProfileScreen extends StatefulWidget {
  const BaristaProfileScreen({super.key});

  @override
  State<BaristaProfileScreen> createState() => _BaristaProfileScreenState();
}

class _BaristaProfileScreenState extends State<BaristaProfileScreen> {
  bool _isLoading = true;
  String _userName = '';
  String _userEmail = '';
  Map<String, String> _userInfo = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // En una implementación real obtendríamos estos datos desde el servidor o SharedPreferences
      final userName = prefs.getString('user_name') ?? 'Barista';

      // Datos de ejemplo para simular información del perfil
      final Map<String, String> mockInfo = {
        'nombre': userName,
        'apellido': 'Rodríguez',
        'cedula': '11.222.333',
        'email': 'barista@lebrunch.com',
        'telefono': '+58 412-555-4321',
        'cargo': 'Barista Principal',
        'fecha_inicio': '15/02/2023',
        'especialidad': 'Café y bebidas especiales',
      };

      if (mounted) {
        setState(() {
          _userName = '${mockInfo['nombre']} ${mockInfo['apellido']}';
          _userEmail = mockInfo['email'] ?? '';
          _userInfo = mockInfo;
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
                    : 'B',
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
              _userInfo['cargo'] ?? 'Barista',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Información personal
            _buildSectionHeader(context, 'Información Personal'),
            _buildInfoCard(context, [
              _buildInfoRow(context, 'Cédula', _userInfo['cedula'] ?? ''),
              _buildInfoRow(context, 'Email', _userEmail),
              _buildInfoRow(context, 'Teléfono', _userInfo['telefono'] ?? ''),
            ]),

            const SizedBox(height: 20),

            // Información laboral
            _buildSectionHeader(context, 'Información Laboral'),
            _buildInfoCard(context, [
              _buildInfoRow(context, 'Cargo', _userInfo['cargo'] ?? ''),
              _buildInfoRow(
                context,
                'Fecha de inicio',
                _userInfo['fecha_inicio'] ?? '',
              ),
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

            const SizedBox(height: 20),

            // Botones de acción
            OutlinedButton.icon(
              onPressed: () {
                // En una implementación real, aquí se mostraría un diálogo para editar el perfil
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Función de editar perfil no implementada'),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Editar Perfil'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                // En una implementación real, aquí se cambiaría la contraseña
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Función de cambiar contraseña no implementada',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.lock),
              label: const Text('Cambiar Contraseña'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Bebidas preparadas',
                    '124',
                    Icons.coffee,
                    Colors.brown,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Tiempo promedio',
                    '8 min',
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Especialidades',
                    '7',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Valoración',
                    '4.9',
                    Icons.thumb_up,
                    theme.colorScheme.primary,
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
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
