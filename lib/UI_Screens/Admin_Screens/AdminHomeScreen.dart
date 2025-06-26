import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/background_scaffold.dart';
import '../../Api_services/menu/get_dishes_service.dart';
import 'package:intl/intl.dart';
import '../../Api_services/network_config_service.dart';
import '../../config.dart';
import '../../Api_services/table_identification_service.dart';
import '../../services/order_status_service.dart'; // 🆕 NUEVO: Para pruebas de notificaciones

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

  // 🆕 NUEVO: Variables para dispositivos conectados
  List<TableInfo> _connectedDevices = [];
  int _totalConnectedDevices = 0;
  final TableIdentificationService _tableService = TableIdentificationService();

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

      // 🆕 NUEVO: Cargar dispositivos conectados
      await _loadConnectedDevices();

      // Obtener platos disponibles
      final availableDishesResponse = await http.get(
        Uri.parse('$baseUrl/menu-with-corrected-urls?disponibilidad=true'),
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

      // Consultar ventas del día usando el endpoint del resumen con período 'day' (SOLO COMPLETADOS)
      final salesResponse = await http.get(
        Uri.parse('$baseUrl/pedidos/resumen?period=day&estado=completado'),
      );
      double salesAmount = 0.0;
      if (salesResponse.statusCode == 200) {
        final data = jsonDecode(salesResponse.body);
        // Usar el campo totalVentas del resumen que es más preciso y en tiempo real
        salesAmount = (data['totalVentas'] as num?)?.toDouble() ?? 0.0;
        print(
          '💰 Ventas del día actualizadas (solo completados): $salesAmount',
        );
      } else {
        // Fallback: si falla, intentar con el endpoint original
        final fallbackResponse = await http.get(
          Uri.parse('$baseUrl/pedidos/ventas/hoy'),
        );
        if (fallbackResponse.statusCode == 200) {
          final data = jsonDecode(fallbackResponse.body);
          salesAmount = (data['total'] as num?)?.toDouble() ?? 0.0;
        }
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

  // 🆕 NUEVO: Método para cargar dispositivos conectados
  Future<void> _loadConnectedDevices() async {
    try {
      print('📱 AdminHomeScreen: Cargando dispositivos conectados...');

      // 🔄 ACTUALIZADO: Usar el nuevo método que verifica estado real
      final devices = await _tableService.getTablesWithConnectionStatus();

      if (mounted) {
        setState(() {
          _connectedDevices = devices;
          _totalConnectedDevices =
              devices
                  .where((d) => d.isActive)
                  .length; // 🔄 Solo contar dispositivos activos
        });

        print(
          '📱 AdminHomeScreen: ${devices.length} dispositivos configurados',
        );
        print(
          '📱 AdminHomeScreen: ${_totalConnectedDevices} dispositivos realmente conectados',
        );
        for (final device in devices) {
          final status = device.isActive ? "✅ Conectada" : "❌ Desconectada";
          print(
            '   - Mesa ${device.tableNumber}: ${device.deviceName} - $status',
          );
        }
      }
    } catch (e) {
      print('❌ AdminHomeScreen: Error cargando dispositivos conectados: $e');
      if (mounted) {
        setState(() {
          _connectedDevices = [];
          _totalConnectedDevices = 0;
        });
      }
    }
  }

  // Método para obtener la URL del servidor usando AppConfig
  Future<String> getServerUrl() async {
    // Usar AppConfig en lugar de SharedPreferences directamente
    print('🌐 AdminHomeScreen: Usando IP centralizada: ${AppConfig.serverIp}');
    return AppConfig.serverUrl;
  }

  // 🔄 NUEVO: Método para formatear moneda de manera consistente
  String _formatCurrency(double amount) {
    if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\$${amount.toStringAsFixed(0)}';
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
          'Hoy: ${_formatCurrency(todaySales)}',
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
        _buildFeatureCard(
          context,
          'Dispositivos',
          '$_totalConnectedDevices mesas',
          Icons.devices,
          const Color(0xFF42A5F5),
          () => _showConnectedDevicesDialog(),
        ),
        _buildFeatureCard(
          context,
          'Manual de Usuario',
          'Guía del sistema',
          Icons.menu_book,
          const Color(0xFF4ECDC4),
          () => Navigator.pushNamed(context, '/user-manual'),
        ),
        _buildFeatureCard(
          context,
          'Papelera',
          'Restaurar items',
          Icons.restore_from_trash,
          const Color(0xFFE57373),
          () => Navigator.pushNamed(context, '/admin-deleted-items'),
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
    // 🔄 SIMPLIFICADO: No necesitamos formateo especial aquí ya que se maneja al llamar la función
    String displaySubtitle = subtitle;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: color.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: color.withOpacity(0.1),
            highlightColor: color.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: color.withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'MADE TOMMY',
                      fontSize: 12,
                      color: Colors.grey[800],
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (displaySubtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, // 🔄 REDUCIDO: De 8 a 6 para más espacio
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        displaySubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color.withOpacity(0.8),
                          fontSize:
                              10, // 🔄 REDUCIDO: De 11 a 10 para evitar overflow
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines:
                            1, // 🔄 REDUCIDO: De 2 a 1 para evitar overflow
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🆕 NUEVO: Mostrar diálogo con dispositivos conectados
  void _showConnectedDevicesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.devices, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estado de Mesas',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 450, // 🔄 AUMENTADO: de 400 a 450 para más espacio
            child:
                _connectedDevices.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phonelink_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No hay mesas configuradas',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontFamily: 'MADE TOMMY',
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        // 🆕 NUEVO: Header con estadísticas mejorado
                        Container(
                          padding: const EdgeInsets.all(
                            16,
                          ), // 🔄 AUMENTADO: de 12 a 16
                          margin: const EdgeInsets.only(
                            bottom: 12,
                          ), // 🔄 AUMENTADO: de 8 a 12
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // 🔄 AUMENTADO: de 8 a 12
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatColumn(
                                '${_connectedDevices.where((d) => d.isActive).length}',
                                'Conectadas',
                                Colors.green,
                              ),
                              Container(
                                width: 2, // 🔄 AUMENTADO: de 1 a 2
                                height: 40, // 🔄 AUMENTADO: de 30 a 40
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              _buildStatColumn(
                                '${_connectedDevices.where((d) => !d.isActive).length}',
                                'Sin dispositivo',
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),

                        // Lista de dispositivos con mejor espaciado
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadConnectedDevices,
                            child: ListView.separated(
                              // 🔄 CAMBIADO: de ListView.builder a ListView.separated
                              itemCount: _connectedDevices.length,
                              separatorBuilder:
                                  (context, index) => const SizedBox(
                                    height: 8,
                                  ), // 🆕 NUEVO: Separador entre items
                              itemBuilder: (context, index) {
                                final device = _connectedDevices[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ), // 🔄 REDUCIDO: margin vertical
                                  elevation: 3, // 🔄 AUMENTADO: de 2 a 3
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      12,
                                    ), // 🆕 NUEVO: Bordes redondeados
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      12,
                                    ), // 🆕 NUEVO: Padding interno
                                    child: Row(
                                      children: [
                                        // Avatar con mejor diseño
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color:
                                                device.isActive
                                                    ? Colors.green.withOpacity(
                                                      0.1,
                                                    )
                                                    : Colors.orange.withOpacity(
                                                      0.1,
                                                    ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  device.isActive
                                                      ? Colors.green
                                                      : Colors.orange,
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${device.tableNumber}',
                                              style: TextStyle(
                                                fontSize: 18, // 🔄 AUMENTADO
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    device.isActive
                                                        ? Colors.green
                                                        : Colors.orange,
                                                fontFamily: 'MADE TOMMY',
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(
                                          width: 16,
                                        ), // 🔄 AUMENTADO: de 12 a 16
                                        // Información del dispositivo
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Mesa ${device.tableNumber}',
                                                style: const TextStyle(
                                                  fontSize: 16, // 🔄 AUMENTADO
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'MADE TOMMY',
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                device.deviceName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontFamily: 'MADE TOMMY',
                                                  color: Colors.grey,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(
                                                height: 6,
                                              ), // 🔄 AUMENTADO: de 4 a 6
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'MAC: ${device.macAddress}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                    fontFamily: 'MADE TOMMY',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Estado del dispositivo
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                12, // 🔄 AUMENTADO: de 8 a 12
                                            vertical:
                                                6, // 🔄 AUMENTADO: de 4 a 6
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                device.isActive
                                                    ? Colors.green.withOpacity(
                                                      0.1,
                                                    )
                                                    : Colors.orange.withOpacity(
                                                      0.1,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ), // 🔄 AUMENTADO: de 12 a 16
                                            border: Border.all(
                                              color:
                                                  device.isActive
                                                      ? Colors.green
                                                      : Colors.orange,
                                              width:
                                                  1.5, // 🔄 AUMENTADO: de 1 a 1.5
                                            ),
                                          ),
                                          child: Text(
                                            device.isActive
                                                ? 'Conectado'
                                                : 'Sin dispositivo',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  device.isActive
                                                      ? Colors.green
                                                      : Colors.orange,
                                              fontFamily: 'MADE TOMMY',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
          actions: [
            // 🆕 NUEVO: Botón de debug para MACs
            TextButton(
              onPressed: () async {
                try {
                  final deviceInfo = await _tableService.getDeviceInfo();
                  final currentMac = await _tableService.getCurrentDeviceMac();

                  showDialog(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('🔧 Debug: MAC Info'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📱 Device ID:\n${deviceInfo['deviceId']}\n',
                              ),
                              Text(
                                '📱 Device Name:\n${deviceInfo['deviceName']}\n',
                              ),
                              Text('📱 MAC generada:\n$currentMac\n'),
                              Text(
                                '📱 Plataforma:\n${deviceInfo['platform']}\n',
                              ),
                              const Text(
                                '💡 Copia la MAC generada y agrégala al código',
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                  );
                } catch (e) {
                  print('Error obteniendo MAC: $e');
                }
              },
              child: const Text(
                'Debug MAC',
                style: TextStyle(fontFamily: 'MADE TOMMY'),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _loadConnectedDevices();
              },
              child: const Text(
                'Actualizar',
                style: TextStyle(fontFamily: 'MADE TOMMY'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cerrar',
                style: TextStyle(fontFamily: 'MADE TOMMY'),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🆕 NUEVO: Widget helper para columnas de estadísticas
  Widget _buildStatColumn(String number, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 24, // 🔄 AUMENTADO: de 20 a 24
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'MADE TOMMY',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13, // 🔄 AUMENTADO: de 12 a 13
            color: color,
            fontFamily: 'MADE TOMMY',
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
