import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';
import '../Widgets/background_scaffold.dart';
import '../Widgets/order_detail_card.dart';
import '../Widgets/date_filter_bar.dart';

class OrderHistoryScreen extends StatefulWidget {
  final String? title;
  final String? startDate;
  final String? endDate;
  final String? estado;

  const OrderHistoryScreen({
    super.key,
    this.title,
    this.startDate,
    this.endDate,
    this.estado,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrdersService _ordersService = OrdersService();
  final GlobalKey<DateFilterBarState> _dateFilterKey =
      GlobalKey<DateFilterBarState>();

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String _currentPeriod = 'todos';
  String? _customStartDate;
  String? _customEndDate;
  Set<int> _expandedOrders = {};

  // 🔄 NUEVO: Variable para debugging del estado
  String _debugEstado = 'completado';

  @override
  void initState() {
    super.initState();

    if (widget.startDate != null && widget.endDate != null) {
      _customStartDate = widget.startDate;
      _customEndDate = widget.endDate;
      _currentPeriod = 'personalizado';
    }

    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? servicePeriod = _convertPeriodToServiceFormat(_currentPeriod);
      String? status = widget.estado; // Usar el estado del widget si existe

      print('🔍 [OrderHistory] Cargando pedidos con filtros:');
      print('  📅 Período: $_currentPeriod -> $servicePeriod');
      print('  📦 Estado inicial: $status');
      print('  📆 Fechas custom: $_customStartDate - $_customEndDate');

      // 🔄 NUEVO: Si no se especifica estado, usar el estado de debug
      final finalStatus = status ?? _debugEstado;
      print('  📦 Estado final aplicado: $finalStatus');

      final orders = await _ordersService.getOrders(
        startDate: _customStartDate,
        endDate: _customEndDate,
        estado: finalStatus,
      );

      print('📊 [OrderHistory] Pedidos recibidos: ${orders.length}');

      if (mounted) {
        setState(() {
          _orders = orders;
          _filteredOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error al cargar el historial de pedidos: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar los pedidos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _convertPeriodToServiceFormat(String period) {
    switch (period) {
      case 'hoy':
        return 'day';
      case 'semana':
        return 'week';
      case 'mes':
        return 'month';
      case 'año':
        return 'year';
      case 'personalizado':
        return 'custom';
      case 'todos':
        return 'all';
      default:
        return 'all';
    }
  }

  String _convertFilterToPeriod(String filter) {
    switch (filter) {
      case 'Hoy':
      case 'hoy':
        return 'hoy';
      case 'Esta semana':
      case 'semana':
        return 'semana';
      case 'Este mes':
      case 'mes':
        return 'mes';
      case 'Este año':
      case 'año':
        return 'año';
      case 'Todos los pedidos':
      case 'todos':
        return 'todos';
      case 'Personalizado':
      case 'personalizado':
        return 'personalizado';
      default:
        return 'todos';
    }
  }

  String _convertPeriodToFilter(String period) {
    switch (period) {
      case 'hoy':
        return 'hoy';
      case 'semana':
        return 'semana';
      case 'mes':
        return 'mes';
      case 'año':
        return 'año';
      case 'todos':
        return 'todos';
      case 'personalizado':
        return 'personalizado';
      default:
        return 'todos';
    }
  }

  void _handleDateFilter(String filter) {
    setState(() {
      _currentPeriod = _convertFilterToPeriod(filter);

      // Calcular fechas según el período seleccionado
      final now = DateTime.now();
      switch (filter) {
        case 'Hoy':
        case 'hoy':
          final startDate = DateTime(now.year, now.month, now.day);
          final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          _customStartDate = startDate.toIso8601String().split('T')[0];
          _customEndDate = endDate.toIso8601String().split('T')[0];
          break;
        case 'Esta semana':
        case 'semana':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startDate = DateTime(
            startOfWeek.year,
            startOfWeek.month,
            startOfWeek.day,
          );
          final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          _customStartDate = startDate.toIso8601String().split('T')[0];
          _customEndDate = endDate.toIso8601String().split('T')[0];
          break;
        case 'Este mes':
        case 'mes':
          final startDate = DateTime(now.year, now.month, 1);
          final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          _customStartDate = startDate.toIso8601String().split('T')[0];
          _customEndDate = endDate.toIso8601String().split('T')[0];
          break;
        case 'Este año':
        case 'año':
          final startDate = DateTime(now.year, 1, 1);
          final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          _customStartDate = startDate.toIso8601String().split('T')[0];
          _customEndDate = endDate.toIso8601String().split('T')[0];
          break;
        case 'Todos los pedidos':
        case 'todos':
        default:
          _customStartDate = null;
          _customEndDate = null;
          break;
      }
    });
    _loadOrders();
  }

  void _handleCustomDateRange(String startDate, String endDate) {
    setState(() {
      _customStartDate = startDate;
      _customEndDate = endDate;
      _currentPeriod = 'personalizado';
    });
    _loadOrders();
  }

  String _getScreenTitle() {
    if (widget.title != null) return widget.title!;
    return 'Historial de Pedidos';
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundScaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial de Pedidos',
              style: TextStyle(
                fontFamily: 'Lighthouse',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            Text(
              'Gestión y seguimiento',
              style: TextStyle(
                fontFamily: 'Lighthouse',
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white.withOpacity(0.9),
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3ea69b),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 70.0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.white, width: 1.5),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF3ea69b),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            image: DecorationImage(
              image: AssetImage('assets/images/fondo-flores-2.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOrders,
            tooltip: 'Actualizar',
          ),
          // 🧪 BOTÓN TEMPORAL DE DEBUG - ELIMINAR DESPUÉS
          PopupMenuButton<String>(
            icon: Icon(Icons.bug_report, color: Colors.white),
            onSelected: (String estado) {
              setState(() {
                _debugEstado = estado;
              });
              _loadOrders();
            },
            itemBuilder:
                (BuildContext context) => [
                  PopupMenuItem(value: 'todos', child: Text('Todos')),
                  PopupMenuItem(value: 'pendiente', child: Text('Pendientes')),
                  PopupMenuItem(
                    value: 'completado',
                    child: Text('Completados'),
                  ),
                  PopupMenuItem(value: 'cancelado', child: Text('Cancelados')),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de filtros de fecha
          DateFilterBar(
            key: _dateFilterKey,
            initialFilter: _convertPeriodToFilter(_currentPeriod),
            onFilterChanged: _handleDateFilter,
            onCustomDateRangeSelected: _handleCustomDateRange,
          ),

          // Lista de pedidos
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF3ea69b)),
                          SizedBox(height: 16),
                          Text(
                            'Cargando historial...',
                            style: TextStyle(color: Color(0xFF3ea69b)),
                          ),
                        ],
                      ),
                    )
                    : _filteredOrders.isEmpty
                    ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.history,
                              size: 64,
                              color: Color(0xFF3ea69b),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay pedidos',
                              style: TextStyle(
                                color: Color(0xFF3ea69b),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No se encontraron pedidos con los filtros seleccionados',
                              style: TextStyle(
                                color: Color(0xFF3ea69b).withOpacity(0.8),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadOrders,
                      color: const Color(0xFF3ea69b),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _filteredOrders.length,
                        itemBuilder: (context, index) {
                          final order = _filteredOrders[index];
                          final orderId = order['idpedido'];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: OrderDetailCard(
                              order: order,
                              isExpanded: _expandedOrders.contains(orderId),
                              onTap: () {
                                setState(() {
                                  if (_expandedOrders.contains(orderId)) {
                                    _expandedOrders.remove(orderId);
                                  } else {
                                    _expandedOrders.add(orderId);
                                  }
                                });
                              },
                              onStatusChange:
                                  null, // No cambiar estado en historial
                              role: 'admin',
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal() {
    return _filteredOrders.fold(0.0, (sum, order) {
      final total = order['total'];
      if (total is num) {
        return sum + total.toDouble();
      } else if (total is String) {
        return sum + (double.tryParse(total) ?? 0.0);
      }
      return sum;
    });
  }
}
