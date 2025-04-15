import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CookHomeScreen extends StatefulWidget {
  final String userName;

  const CookHomeScreen({super.key, required this.userName});

  @override
  State<CookHomeScreen> createState() => _CookHomeScreenState();
}

class _CookHomeScreenState extends State<CookHomeScreen> {
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
      final cedula = prefs.getString('user_cedula') ?? '';

      if (mounted) {
        setState(() {
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
          _activeOrders = 5; // Valores de ejemplo
          _completedOrders = 42;
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
            // Información del cocinero - mostramos solo la cédula
            if (_userCedula.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primary,
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'CI: $_userCedula',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

            // Tarjetas de resumen
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    Icons.lunch_dining,
                    'Pedidos Activos',
                    _activeOrders.toString(),
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    Icons.done_all,
                    'Completados Hoy',
                    _completedOrders.toString(),
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Título de la sección
            Text(
              'Estado de la cocina',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Estado de la cocina
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
                        'No hay avisos pendientes en este momento',
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
                        'Tiempo promedio por pedido: 15 minutos',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Atajo a pedidos activos
            ElevatedButton.icon(
              onPressed: () {
                // Navegar a la pantalla de pedidos activos
                // Aquí solo mostramos un mensaje, ya que no podemos
                // acceder directamente al PageView desde esta clase
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
}
