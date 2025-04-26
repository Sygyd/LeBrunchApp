import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/background_scaffold.dart';
import '../../Api_services/menu/get_dishes_service.dart';

class AdminHomeScreen extends StatefulWidget {
  final String userName;
  final Function(int)? onNavigate;

  const AdminHomeScreen({super.key, required this.userName, this.onNavigate});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // Variables de estado para las métricas
  int pendingOrders = 0;
  int totalUsers = 0;
  int activeDishes = 0;
  double todaySales = 0.0;
  bool _isLoading = false;
  int totalAvailableDishes = 0;
  int totalAdmin = 0;
  int totalChef = 0;
  int totalWaiter = 0;
  int totalCustomer = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final baseUrl = await getServerUrl();
      print('Server URL: $baseUrl');

      // Obtener platos disponibles
      final availableDishesResponse = await http.get(
        Uri.parse('$baseUrl/menu?disponibilidad=true'),
      );

      if (availableDishesResponse.statusCode == 200) {
        final dishesList = jsonDecode(availableDishesResponse.body);
        if (dishesList is List) {
          setState(() {
            totalAvailableDishes = dishesList.length;
            activeDishes = dishesList.length;
          });
        }
      }

      // Obtener métricas de usuarios por rol
      final userMetricsResponse = await http.get(
        Uri.parse('$baseUrl/users/metrics'),
      );

      if (userMetricsResponse.statusCode == 200) {
        final userMetrics = jsonDecode(userMetricsResponse.body);
        setState(() {
          totalUsers = userMetrics['total'] ?? 0;

          // Mapear los roles según la estructura que devuelve el endpoint
          if (userMetrics.containsKey('byRole')) {
            totalAdmin = userMetrics['byRole']['admins'] ?? 0;
            totalCustomer = userMetrics['byRole']['clients'] ?? 0;
            totalChef = userMetrics['byRole']['cooks'] ?? 0;
            totalWaiter = userMetrics['byRole']['baristas'] ?? 0;
          }
        });
      }

      // Consultar órdenes pendientes
      final ordersResponse = await http.get(
        Uri.parse('$baseUrl/pedidos/pendientes/count'),
      );
      int pendingOrdersCount = 0;
      if (ordersResponse.statusCode == 200) {
        final data = jsonDecode(ordersResponse.body);
        pendingOrdersCount = data['count'] ?? 0;
      }

      // Consultar ventas del día
      final salesResponse = await http.get(
        Uri.parse('$baseUrl/pedidos/ventas/hoy'),
      );
      double salesAmount = 0.0;
      if (salesResponse.statusCode == 200) {
        final data = jsonDecode(salesResponse.body);
        salesAmount = (data['total'] as num?)?.toDouble() ?? 0.0;
      }

      // Actualizar el estado con datos reales
      if (mounted) {
        setState(() {
          pendingOrders = pendingOrdersCount;
          todaySales = salesAmount;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error general al cargar métricas: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para obtener la URL del servidor
  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final serverIp = prefs.getString('serverIp') ?? '192.168.1.121';
    return 'http://$serverIp:3000';
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMetrics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Métricas del restaurante
                Text(
                  'Métricas del Restaurante',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
                const SizedBox(height: 12),

                // Dashboard con métricas
                _buildMetricsGrid(),
                const SizedBox(height: 30),

                // Features section
                Text(
                  'Gestión del Restaurante',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
                const SizedBox(height: 12),

                // Features grid
                _buildFeaturesGrid(),

                const SizedBox(height: 100), // Espacio para bottom nav bar
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          context,
          'Órdenes Pendientes',
          '$pendingOrders',
          Icons.access_time,
          Colors.orange,
        ),
        _buildMetricCard(
          context,
          'Total Usuarios',
          '$totalUsers',
          Icons.people,
          Colors.blue,
        ),
        _buildMetricCard(
          context,
          'Platillos Activos',
          '$activeDishes',
          Icons.restaurant,
          Colors.green,
        ),
        _buildMetricCard(
          context,
          'Ventas Hoy',
          '\$$todaySales',
          Icons.monetization_on,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid() {
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.0,
      children: [
        _buildFeatureCard(
          context,
          'Órdenes',
          'Pendientes: $pendingOrders',
          Icons.receipt_long,
          const Color(0xFFFF9800),
          () => Navigator.pushNamed(context, '/admin-orders'),
        ),
        _buildFeatureCard(
          context,
          'Historial de Pedidos',
          '',
          Icons.history,
          const Color(0xFF64B5F6),
          () => Navigator.pushNamed(context, '/admin-order-history'),
        ),
        _buildFeatureCard(
          context,
          'Reportes',
          'Ventas hoy: \$${todaySales.toStringAsFixed(2)}',
          Icons.bar_chart,
          const Color(0xFF81C784),
          () => Navigator.pushNamed(context, '/admin-reports'),
        ),
        _buildFeatureCard(
          context,
          'Platos Populares',
          '',
          Icons.trending_up,
          const Color(0xFFBA68C8),
          () => Navigator.pushNamed(context, '/admin-popular-dishes'),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.7), color],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'MADE TOMMY',
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'MADE TOMMY',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
