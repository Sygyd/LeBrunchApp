import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Api_services/pedidos/orders_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../config.dart';
import 'dart:async';

/// Pantalla de inicio compartida que puede ser usada tanto por Cocinero como por Barista
/// Recibe parámetros para personalizar la apariencia y comportamiento según el rol
class SharedHomeScreen extends StatefulWidget {
  final String userName;
  final Function(int)? onNavigate;
  final String role; // 'cook' o 'barista'
  final IconData primaryIcon;
  final String roleTitle;

  const SharedHomeScreen({
    super.key,
    required this.userName,
    this.onNavigate,
    required this.role,
    this.primaryIcon = Icons.restaurant,
    this.roleTitle = 'Personal',
  });

  @override
  State<SharedHomeScreen> createState() => _SharedHomeScreenState();
}

class _SharedHomeScreenState extends State<SharedHomeScreen> {
  bool _isLoading = true;
  int _activeOrders = 0;
  int _completedOrders = 0;
  String _userCedula = '';
  String? _averageProcessingTime;
  final OrdersService _ordersService = OrdersService();
  Timer? _refreshTimer;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchOrdersData();

    // Configurar un temporizador para actualizar los datos cada 30 segundos
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchOrdersData(showLoadingIndicator: false),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cedula = prefs.getString('user_cedula') ?? '';

      if (mounted) {
        setState(() {
          _userCedula = cedula;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos del usuario: $e');
    }
  }

  Future<void> _fetchOrdersData({bool showLoadingIndicator = true}) async {
    try {
      if (showLoadingIndicator && mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Obtener pedidos activos (solo pendientes)
      final activeOrders = await _ordersService.getOrders(estado: 'pendiente');

      // SIMPLIFICADO: Usar configuración centralizada de AppConfig
      final baseUrl = AppConfig.serverUrl;
      debugPrint('🌐 🧑‍🍳🧋 Usando servidor desde AppConfig: $baseUrl');

      // Usar consulta directa para obtener conteo de órdenes completadas hoy
      final completedTodayQuery = {
        'query': '''
          SELECT COUNT(*) as count 
          FROM pedidos 
          WHERE estado = 'completado' 
          AND DATE(fecha) = CURRENT_DATE
        ''',
      };

      final uri = Uri.parse('$baseUrl/db/query');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(completedTodayQuery),
      );

      int completedToday = 0;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        completedToday =
            int.tryParse(data['result']?[0]?['count']?.toString() ?? '0') ?? 0;
        debugPrint('📊 Pedidos completados hoy: $completedToday');
      }

      // Obtener tiempo promedio de procesamiento del día con método mejorado
      String avgTime;
      if (completedToday > 0) {
        // Si hay pedidos completados hoy, obtener el promedio del día
        avgTime = await _getAverageTimeWithFallback();
      } else {
        // Si no hay pedidos hoy, obtener promedio histórico
        avgTime = await _getHistoricalAverage();
      }

      if (mounted) {
        setState(() {
          _activeOrders = activeOrders.length;
          _completedOrders = completedToday;
          _averageProcessingTime = avgTime;
          _lastUpdated = DateTime.now();
          if (showLoadingIndicator) {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de pedidos: $e');
      if (mounted && showLoadingIndicator) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Método para obtener tiempo promedio con fallback
  Future<String> _getAverageTimeWithFallback() async {
    try {
      // Intentar obtener el tiempo promedio desde el servicio
      final avgTimeFromService =
          await _ordersService.getAverageProcessingTimeByDay();

      // Si tenemos datos, usarlos
      if (avgTimeFromService != null &&
          avgTimeFromService.isNotEmpty &&
          !avgTimeFromService.contains("No hay datos")) {
        return avgTimeFromService;
      }

      // Si no hay datos, usar valor predeterminado
      return '5 min 0 seg (estimado)';
    } catch (e) {
      debugPrint('⚠️ Error al obtener tiempo promedio: $e');
      return '5 min 0 seg (estimado)';
    }
  }

  // Método para obtener promedio histórico
  Future<String> _getHistoricalAverage() async {
    try {
      // SIMPLIFICADO: Usar configuración centralizada de AppConfig
      final baseUrl = AppConfig.serverUrl;
      debugPrint(
        '🌐 🧑‍🍳🧋 Calculando promedio histórico con servidor: $baseUrl',
      );

      // Consulta SQL para obtener promedio histórico
      final query = {
        'query': '''
          SELECT 
            COUNT(*) as count,
            EXTRACT(EPOCH FROM AVG(
              CASE 
                WHEN tiempo_procesamiento IS NOT NULL THEN tiempo_procesamiento
                ELSE interval '5 minutes'
              END
            )) as avg_seconds
          FROM 
            pedidos
          WHERE 
            estado = 'completado'
        ''',
      };

      final uri = Uri.parse('$baseUrl/db/query');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(query),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final count =
            int.tryParse(data['result']?[0]?['count']?.toString() ?? '0') ?? 0;
        final avgSeconds =
            double.tryParse(
              data['result']?[0]?['avg_seconds']?.toString() ?? '0',
            ) ??
            0;

        if (count > 0 && avgSeconds > 0) {
          final minutes = (avgSeconds / 60).floor();
          final seconds = (avgSeconds % 60).round();
          return '$minutes min $seconds seg (histórico)';
        }
      }

      return '5 min 0 seg (estimado)';
    } catch (e) {
      debugPrint('⚠️ Error al calcular tiempo histórico: $e');
      return '5 min 0 seg (estimado)';
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

    return RefreshIndicator(
      onRefresh: () => _fetchOrdersData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del usuario
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenido, ${widget.userName}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_userCedula.isNotEmpty)
                            Text(
                              'CI: $_userCedula',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                        ],
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
                      widget.primaryIcon,
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
                widget.role == 'barista'
                    ? 'Estado de la barra'
                    : 'Estado de la cocina',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Estado de operaciones
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
                        subtitle: Text(
                          _activeOrders > 0
                              ? 'Tienes $_activeOrders pedido${_activeOrders == 1 ? '' : 's'} pendiente${_activeOrders == 1 ? '' : 's'} de preparación'
                              : 'No hay pedidos pendientes en este momento',
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(
                          Icons.schedule,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Tiempo promedio de preparación'),
                        subtitle: Text(
                          _averageProcessingTime != null
                              ? 'Tiempo promedio: $_averageProcessingTime'
                              : 'Calculando tiempo promedio...',
                        ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Actualizado: ${_formatLastUpdated()}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Atajo a pedidos activos
              ElevatedButton.icon(
                onPressed: () {
                  // Navegar a la pantalla de pedidos activos usando el PageView
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(
                      1,
                    ); // Índice 1 corresponde a la pantalla de pedidos activos
                  }
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
      ),
    );
  }

  String _formatLastUpdated() {
    final now = DateTime.now();
    final difference = now.difference(_lastUpdated);

    if (difference.inSeconds < 60) {
      return 'hace ${difference.inSeconds} segundos';
    } else if (difference.inMinutes < 60) {
      return 'hace ${difference.inMinutes} minutos';
    } else {
      return 'hace ${difference.inHours} horas';
    }
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
