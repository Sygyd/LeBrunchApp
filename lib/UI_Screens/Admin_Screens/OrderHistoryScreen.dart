import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';
import '../Widgets/order_detail_card.dart';

class OrderHistoryScreen extends StatefulWidget {
  final String? startDate;
  final String? endDate;
  final String? estado;
  final String title;

  const OrderHistoryScreen({
    super.key,
    this.startDate,
    this.endDate,
    this.estado,
    this.title = 'Historial de Pedidos',
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final OrdersService _ordersService = OrdersService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  Set<int> _expandedItems = {}; // Conjunto de índices de items expandidos
  String? _filterStatus; // Para filtrar por estado

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.estado;
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print(
        'Cargando órdenes con filtro: ${_filterStatus ?? "TODOS"}',
      ); // Log para debug

      final orders = await _ordersService.getOrders(
        startDate: widget.startDate,
        endDate: widget.endDate,
        estado: _filterStatus,
      );

      print('Órdenes obtenidas: ${orders.length}');

      // Debug: mostrar estados de las órdenes recibidas
      if (orders.isNotEmpty) {
        print('Estados de las órdenes:');
        for (var order in orders) {
          print('Pedido #${order['idpedido']} - Estado: ${order['estado']}');
        }
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar órdenes: $e'); // Log para debug

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los pedidos: $e')),
        );
      }
    }
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedItems.contains(index)) {
        _expandedItems.remove(index);
      } else {
        _expandedItems.add(index);
      }
    });
  }

  Future<void> _updateOrderStatus(int index, String newStatus) async {
    final orderId = _orders[index]['idpedido'];

    // Mostrar indicador de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Llamar al servicio para actualizar el estado en el servidor
      final success = await _ordersService.updateOrderStatus(
        orderId,
        newStatus,
      );

      // Cerrar diálogo de progreso
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // Actualizar localmente si el servidor respondió bien
        if (mounted) {
          setState(() {
            _orders[index]['estado'] = newStatus;
          });
        }

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido #$orderId actualizado a: $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Mostrar error si el servidor no actualizó
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el pedido en el servidor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de progreso
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Mostrar error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar el pedido: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        automaticallyImplyLeading: true,
        actions: [
          // Botón para actualizar la lista
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: 'Actualizar',
          ),

          // Botón para filtrar por estado
          PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_list,
              color: _filterStatus != null ? Colors.amber : Colors.white,
            ),
            tooltip: 'Filtrar por estado',
            onSelected: (value) {
              setState(() {
                _filterStatus = value == 'todos' ? null : value;
              });
              _loadOrders();
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'todos',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              _filterStatus == null
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('Todos los estados'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pendiente',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              _filterStatus == 'pendiente'
                                  ? Colors.orange
                                  : Colors.transparent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('Pendientes'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'completado',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              _filterStatus == 'completado'
                                  ? Colors.green
                                  : Colors.transparent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('Completados'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'cancelado',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              _filterStatus == 'cancelado'
                                  ? Colors.red
                                  : Colors.transparent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text('Cancelados'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
              : _orders.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se encontraron pedidos',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prueba con otros filtros o fechas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                      onPressed: _loadOrders,
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  // Información de filtros aplicados
                  if (widget.startDate != null ||
                      widget.endDate != null ||
                      _filterStatus != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtros aplicados:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (widget.startDate != null &&
                                  widget.endDate != null)
                                Chip(
                                  label: Text(
                                    'Período: ${_formatDate(widget.startDate!)} - ${_formatDate(widget.endDate!)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  backgroundColor: theme.colorScheme.primary
                                      .withOpacity(0.2),
                                  visualDensity: VisualDensity.compact,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    // Aquí iría el código para eliminar este filtro
                                  },
                                ),
                              if (_filterStatus != null)
                                Chip(
                                  avatar: Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: _getStatusColor(
                                      _filterStatus!,
                                      theme,
                                    ),
                                  ),
                                  label: Text(
                                    'Estado: ${_capitalizeFirstLetter(_filterStatus!)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  backgroundColor: _getStatusColor(
                                    _filterStatus!,
                                    theme,
                                  ).withOpacity(0.2),
                                  visualDensity: VisualDensity.compact,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      _filterStatus = null;
                                    });
                                    _loadOrders();
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Contador de pedidos
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Text(
                          '${_orders.length} pedidos encontrados',
                          style: theme.textTheme.titleSmall,
                        ),
                        const Spacer(),
                        if (_orders.isNotEmpty) ...[
                          Text('Total: ', style: theme.textTheme.bodyMedium),
                          Text(
                            _formatCurrency(_calculateTotal()),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Lista de pedidos
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        // Comprobar si tenemos detalles completos o estamos en modo fallback
                        final bool isLimitedData =
                            order['items'] == null ||
                            (order['items'] as List).isEmpty;

                        if (isLimitedData) {
                          // Para pedidos sin detalles completos (modo fallback), mostrar tarjeta simplificada
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 0,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(
                                  order['estado'] ?? 'pendiente',
                                  theme,
                                ),
                                child: Icon(
                                  Icons.receipt_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    'Pedido #${order['idpedido']}',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      _getStatusText(
                                        order['estado'] ?? 'pendiente',
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    backgroundColor: _getStatusColor(
                                      order['estado'] ?? 'pendiente',
                                      theme,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cliente: ${order['cliente'] ?? 'Cliente'}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fecha: ${order['fecha'] ?? ''} ${order['hora'] ?? ''}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.refresh_outlined),
                                tooltip: 'Actualizar detalles',
                                onPressed: _loadOrders,
                              ),
                            ),
                          );
                        }

                        // Para pedidos con detalles completos, mostrar tarjeta completa
                        return OrderDetailCard(
                          order: order,
                          isExpanded: _expandedItems.contains(index),
                          onTap: () => _toggleExpanded(index),
                          onStatusChange:
                              (newStatus) =>
                                  _updateOrderStatus(index, newStatus),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final formatter = DateFormat('dd/MM/yyyy');
      final date = DateTime.parse(dateStr);
      return formatter.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text.substring(0, 1).toUpperCase() + text.substring(1);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: '\$');
    return formatter.format(amount);
  }

  double _calculateTotal() {
    double total = 0.0;
    for (final order in _orders) {
      total += order['total'] ?? 0.0;
    }
    return total;
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'completado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'completado':
        return 'COMPLETADO';
      case 'cancelado':
        return 'CANCELADO';
      default:
        return status.toUpperCase();
    }
  }
}
