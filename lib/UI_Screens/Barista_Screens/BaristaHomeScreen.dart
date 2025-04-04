import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BaristaHomeScreen extends StatefulWidget {
  const BaristaHomeScreen({super.key});

  @override
  State<BaristaHomeScreen> createState() => _BaristaHomeScreenState();
}

class _BaristaHomeScreenState extends State<BaristaHomeScreen> {
  String _userName = 'Barista';
  bool _isLoading = true;
  int _activeOrders = 0;
  int _completedOrders = 0;
  String _userCedula = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchOrdersData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? 'Barista';
      final cedula = prefs.getString('user_cedula') ?? '';

      if (mounted) {
        setState(() {
          _userName = name;
          _userCedula = cedula;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos del usuario: $e');
    }
  }

  Future<void> _fetchOrdersData() async {
    // En una implementación real, aquí se obtendría la información
    // de pedidos activos y completados desde el servidor

    try {
      // Simular petición a la API con un delay
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        setState(() {
          _activeOrders = 3; // Valores de ejemplo
          _completedOrders = 36;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de pedidos: $e');
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bienvenida y avatar
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Bienvenido!', style: theme.textTheme.titleLarge),
                    Text(
                      _userName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_userCedula.isNotEmpty)
                      Text(
                        'CI: $_userCedula',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tarjetas de resumen
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    Icons.coffee,
                    'Bebidas Pendientes',
                    _activeOrders.toString(),
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    Icons.done_all,
                    'Completadas Hoy',
                    _completedOrders.toString(),
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Título de la sección
            Text(
              'Estado de la barra',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Estado de la barra
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.notifications_active,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Avisos importantes'),
                      subtitle: const Text(
                        'Revisar stock de café y leche de almendras',
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(
                        Icons.schedule,
                        color: theme.colorScheme.primary,
                      ),
                      title: const Text('Tiempo estimado'),
                      subtitle: const Text(
                        'Tiempo promedio por bebida: 8 minutos',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Inventario
            Text(
              'Inventario',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Tarjetas de inventario
            Card(
              elevation: 2,
              child: Column(
                children: [
                  _buildInventoryItem(
                    context,
                    'Café en grano',
                    0.7,
                    '700g disponibles',
                  ),
                  const Divider(height: 1),
                  _buildInventoryItem(
                    context,
                    'Leche entera',
                    0.85,
                    '3.4 litros disponibles',
                  ),
                  const Divider(height: 1),
                  _buildInventoryItem(
                    context,
                    'Leche de almendras',
                    0.3,
                    '900ml disponibles',
                  ),
                  const Divider(height: 1),
                  _buildInventoryItem(
                    context,
                    'Chocolate',
                    0.6,
                    '600g disponibles',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Atajo a pedidos activos
            ElevatedButton.icon(
              onPressed: () {
                // Navegar a la pantalla de pedidos activos
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Navegar a pedidos activos'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Ver pedidos activos'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    IconData icon,
    String title,
    String value,
    Color iconColor,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(
    BuildContext context,
    String name,
    double level,
    String description,
  ) {
    final theme = Theme.of(context);

    // Determine color based on level
    Color levelColor = Colors.green;
    if (level < 0.3) {
      levelColor = Colors.red;
    } else if (level < 0.6) {
      levelColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: theme.textTheme.titleMedium)),
              Text(
                '${(level * 100).toInt()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: levelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: level,
            backgroundColor: theme.colorScheme.onSurface.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(levelColor),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
