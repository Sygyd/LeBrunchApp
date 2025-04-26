import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
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
  DateTime _selectedDate =
      DateTime.now(); // Fecha seleccionada, inicialmente hoy
  bool _isAscendingOrder = false; // Orden ascendente o descendente

  // Variables para el rango de fechas
  DateTime? _rangeStartDate;
  DateTime? _rangeEndDate;
  bool _isDateRangeActive = false;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.estado;

    // Si no se proporciona fecha de inicio/fin, cargar todas las órdenes
    if (widget.startDate == null && widget.endDate == null) {
      _loadOrders(); // Cargar todas las órdenes sin filtro de fecha
    } else {
      _loadOrders(); // Cargar órdenes con los filtros proporcionados
    }
  }

  // Método para cargar las órdenes de una fecha específica
  Future<void> _loadOrdersForDate(DateTime date) async {
    final formatter = DateFormat('yyyy-MM-dd');
    final formattedDate = formatter.format(date);

    setState(() {
      _isLoading = true;
      _selectedDate = date; // Actualizar la fecha seleccionada
      _isDateRangeActive = false; // Desactivar el rango de fechas
      _rangeStartDate = null;
      _rangeEndDate = null;
    });

    try {
      // Explícitamente establecer _filterStatus para mantener el filtro actual
      final orders = await _ordersService.getOrders(
        startDate: formattedDate,
        endDate: formattedDate,
        estado: _filterStatus,
      );

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar órdenes por fecha: $e');
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

  // Método unificado para seleccionar fecha o rango de fechas
  Future<void> _showCalendarPicker(BuildContext context) async {
    final config = CalendarDatePicker2WithActionButtonsConfig(
      calendarType: CalendarDatePicker2Type.range,
      selectedDayHighlightColor: Theme.of(context).colorScheme.primary,
      weekdayLabels: ['Do', 'Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sa'],
      weekdayLabelTextStyle: const TextStyle(
        fontFamily: 'MADE TOMMY',
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      firstDayOfWeek: 1, // Lunes
      controlsHeight: 50,
      controlsTextStyle: const TextStyle(
        fontFamily: 'MADE TOMMY',
        color: Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      dayTextStyle: const TextStyle(
        fontFamily: 'MADE TOMMY',
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
      selectedDayTextStyle: const TextStyle(
        fontFamily: 'MADE TOMMY',
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      yearTextStyle: const TextStyle(
        fontFamily: 'MADE TOMMY',
        color: Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );

    // Preparar los valores iniciales
    List<DateTime?> initialValues = [];
    if (_isDateRangeActive && _rangeStartDate != null) {
      // Si hay un rango activo, mostrar el rango
      initialValues = [_rangeStartDate, _rangeEndDate];
    } else {
      // Si no hay rango, mostrar la fecha seleccionada
      initialValues = [_selectedDate];
    }

    final results = await showCalendarDatePicker2Dialog(
      context: context,
      config: config,
      dialogSize: const Size(325, 400),
      borderRadius: BorderRadius.circular(15),
      value: initialValues,
      dialogBackgroundColor: Colors.white,
    );

    // Procesar resultados
    if (results != null && results.isNotEmpty) {
      setState(() {
        _isLoading = true;

        if (results.length > 1 && results[1] != null) {
          // Es un rango de fechas
          _isDateRangeActive = true;
          _rangeStartDate = results[0];
          _rangeEndDate = results[1];
        } else {
          // Es una fecha individual
          _isDateRangeActive = false;
          _selectedDate = results[0] ?? DateTime.now();
          _rangeStartDate = null;
          _rangeEndDate = null;
        }
      });

      // Cargar las órdenes con los nuevos parámetros
      await _loadOrdersWithDates();
    }
  }

  // Método para cargar órdenes con las fechas actuales (ya sea rango o fecha individual)
  Future<void> _loadOrdersWithDates() async {
    final formatter = DateFormat('yyyy-MM-dd');
    String? startDate;
    String? endDate;

    if (_isDateRangeActive && _rangeStartDate != null) {
      // Usar rango de fechas
      startDate = formatter.format(_rangeStartDate!);
      endDate =
          _rangeEndDate != null ? formatter.format(_rangeEndDate!) : startDate;
    } else {
      // Usar fecha individual
      startDate = formatter.format(_selectedDate);
      endDate = startDate;
    }

    try {
      final orders = await _ordersService.getOrders(
        startDate: startDate,
        endDate: endDate,
        estado: _filterStatus,
      );

      if (mounted) {
        setState(() {
          _orders = _sortOrders(orders);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar órdenes: $e');
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

  // Método principal para cargar órdenes con los filtros actuales
  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Construir los posibles parámetros de consulta
      String? startDate = widget.startDate;
      String? endDate = widget.endDate;

      // Si hay un rango de fechas activo, usar esas fechas
      if (_isDateRangeActive && _rangeStartDate != null) {
        final formatter = DateFormat('yyyy-MM-dd');
        startDate = formatter.format(_rangeStartDate!);
        endDate =
            _rangeEndDate != null
                ? formatter.format(_rangeEndDate!)
                : startDate;
      }
      // Si no hay rango pero hay fecha seleccionada (y no hay parámetros de widget), usar esa fecha
      else if (startDate == null && endDate == null) {
        final formatter = DateFormat('yyyy-MM-dd');
        startDate = formatter.format(_selectedDate);
        endDate = startDate;
      }

      print(
        'Cargando órdenes con filtro: ${_filterStatus ?? "TODOS"}, ' +
            'Fecha: ${startDate ?? "Todas"} - ${endDate ?? "Todas"}',
      );

      final orders = await _ordersService.getOrders(
        startDate: startDate,
        endDate: endDate,
        estado: _filterStatus,
      );

      // Ordenar las órdenes según la preferencia del usuario
      final sortedOrders = _sortOrders(orders);

      if (mounted) {
        setState(() {
          _orders = sortedOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar órdenes: $e');

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

  // Método para cambiar el orden
  void _toggleSortOrder() {
    setState(() {
      _isAscendingOrder = !_isAscendingOrder;
      _orders = _sortOrders(_orders);
    });
  }

  // Método para ordenar las órdenes
  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    // Crear una copia para no modificar la original
    final sortedOrders = List<Map<String, dynamic>>.from(orders);

    // Ordenar por fecha y hora
    sortedOrders.sort((a, b) {
      // Construir DateTime completo con fecha y hora
      final aDateStr = a['fecha'] ?? '';
      final aTimeStr = a['hora'] ?? '';
      final bDateStr = b['fecha'] ?? '';
      final bTimeStr = b['hora'] ?? '';

      DateTime aDateTime, bDateTime;

      try {
        // Intentar parsear fechas y horas
        aDateTime = DateTime.parse('${aDateStr}T${aTimeStr}:00');
      } catch (e) {
        // Si hay error, usar fecha actual pero muy antigua
        aDateTime = DateTime(1900);
      }

      try {
        bDateTime = DateTime.parse('${bDateStr}T${bTimeStr}:00');
      } catch (e) {
        bDateTime = DateTime(1900);
      }

      // Comparar según el orden seleccionado
      return _isAscendingOrder
          ? aDateTime.compareTo(bDateTime)
          : bDateTime.compareTo(aDateTime);
    });

    return sortedOrders;
  }

  // Método para formatear el rango de fechas para mostrar
  String _formatDateRange() {
    if (_rangeStartDate == null) return '';

    final formatter = DateFormat('dd/MM/yyyy');
    final start = formatter.format(_rangeStartDate!);

    if (_rangeEndDate == null ||
        _rangeEndDate!.isAtSameMomentAs(_rangeStartDate!)) {
      return start;
    }

    final end = formatter.format(_rangeEndDate!);
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Ordenar y agrupar las órdenes por estado
    Map<String, List<Map<String, dynamic>>> groupedOrders = {
      'pendiente': [],
      'completado': [],
      'cancelado': [],
      'otro': [],
    };

    // Organizar las órdenes por estado
    for (var order in _orders) {
      String status = (order['estado'] ?? 'otro').toLowerCase();
      if (groupedOrders.containsKey(status)) {
        groupedOrders[status]!.add(order);
      } else {
        groupedOrders['otro']!.add(order);
      }
    }

    // Formatear la fecha o rango de fechas seleccionado
    String formattedSelectedDate = '';
    if (_isDateRangeActive && _rangeStartDate != null) {
      formattedSelectedDate = _formatDateRange();
    } else if (widget.startDate == null && widget.endDate == null) {
      formattedSelectedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);
    } else if (widget.startDate != null && widget.endDate == widget.startDate) {
      formattedSelectedDate = DateFormat(
        'dd/MM/yyyy',
      ).format(DateFormat('yyyy-MM-dd').parse(widget.startDate!));
    } else if (widget.startDate != null && widget.endDate != null) {
      final start = DateFormat(
        'dd/MM/yyyy',
      ).format(DateFormat('yyyy-MM-dd').parse(widget.startDate!));
      final end = DateFormat(
        'dd/MM/yyyy',
      ).format(DateFormat('yyyy-MM-dd').parse(widget.endDate!));
      formattedSelectedDate = '$start - $end';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontFamily: 'MADE TOMMY',
                fontWeight: FontWeight.bold,
              ),
            ),
            if (formattedSelectedDate.isNotEmpty)
              Text(
                formattedSelectedDate,
                style: const TextStyle(fontSize: 12, fontFamily: 'MADE TOMMY'),
              ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        automaticallyImplyLeading: true,
        actions: [
          // Botón para cambiar el orden (ascendente/descendente)
          IconButton(
            icon: Icon(
              _isAscendingOrder ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            onPressed: _toggleSortOrder,
            tooltip:
                _isAscendingOrder
                    ? 'Ordenar descendente'
                    : 'Ordenar ascendente',
          ),

          // Botón unificado para calendario (fecha o rango)
          IconButton(
            icon: Icon(
              Icons.calendar_month,
              color: _isDateRangeActive ? Colors.amber : null,
            ),
            onPressed: () => _showCalendarPicker(context),
            tooltip: 'Seleccionar fecha o rango',
          ),

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
              widget.startDate == null && widget.endDate == null
                  ? _loadOrdersWithDates()
                  : _loadOrders();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem<String?>(
                    value: 'todos',
                    child: Text('Mostrar todos'),
                  ),
                  const PopupMenuItem<String?>(
                    value: 'pendiente',
                    child: Text('Pendientes'),
                  ),
                  const PopupMenuItem<String?>(
                    value: 'completado',
                    child: Text('Completados'),
                  ),
                  const PopupMenuItem<String?>(
                    value: 'cancelado',
                    child: Text('Cancelados'),
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
                          if (_filterStatus != null)
                            Chip(
                              label: Text(
                                'Estado: ${_capitalizeFirstLetter(_filterStatus!)}',
                              ),
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
                    ),

                  // Pedidos encontrados y valor total
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: theme.colorScheme.secondaryContainer.withOpacity(
                      0.5,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${_orders.length} pedidos encontrados',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Total: ${_formatCurrency(_calculateTotal())}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de pedidos agrupados por estado
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // 1. Primero mostrar pedidos pendientes
                        if (groupedOrders['pendiente']!.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Pendientes',
                            Colors.orange,
                            theme,
                          ),
                          ...groupedOrders['pendiente']!
                              .map((order) => _buildOrderCard(order, theme))
                              .toList(),
                          const SizedBox(height: 16),
                        ],

                        // 2. Luego mostrar pedidos completados
                        if (groupedOrders['completado']!.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Completados',
                            Colors.green,
                            theme,
                          ),
                          ...groupedOrders['completado']!
                              .map((order) => _buildOrderCard(order, theme))
                              .toList(),
                          const SizedBox(height: 16),
                        ],

                        // 3. Finalmente pedidos cancelados
                        if (groupedOrders['cancelado']!.isNotEmpty) ...[
                          _buildSectionHeader('Cancelados', Colors.red, theme),
                          ...groupedOrders['cancelado']!
                              .map((order) => _buildOrderCard(order, theme))
                              .toList(),
                          const SizedBox(height: 16),
                        ],

                        // 4. Si hay pedidos con otros estados
                        if (groupedOrders['otro']!.isNotEmpty) ...[
                          _buildSectionHeader(
                            'Otros estados',
                            Colors.grey,
                            theme,
                          ),
                          ...groupedOrders['otro']!
                              .map((order) => _buildOrderCard(order, theme))
                              .toList(),
                          const SizedBox(height: 16),
                        ],

                        // Espacio extra al final para evitar que el FAB tape contenido
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  // Widget para construir los encabezados de sección
  Widget _buildSectionHeader(String title, Color color, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'completado':
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return theme.colorScheme.secondary;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'completado':
      case 'entregado':
        return 'COMPLETADO';
      case 'cancelado':
        return 'CANCELADO';
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order, ThemeData theme) {
    final orderIndex = _orders.indexOf(order);

    // Si es un pedido con datos incompletos, mostrar vista simplificada
    if (!order.containsKey('items') ||
        order['items'] == null ||
        (order['items'] as List).isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order['estado'] ?? '', theme),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _getStatusText(order['estado'] ?? ''),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Pedido #${order['idpedido']}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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

    // Para pedidos con detalles completos, siempre mostrar expandido
    return OrderDetailCard(
      order: order,
      isExpanded: true, // Siempre expandido
      onTap: null, // Desactivar toggle al tocar
      onStatusChange: (newStatus) => _updateOrderStatus(orderIndex, newStatus),
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
}
