import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../Api_services/pedidos/orders_service.dart';
import 'order_detail_card.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Widget compartido para mostrar el historial de pedidos
/// Puede ser utilizado por administradores, cocineros y baristas
class SharedOrderHistoryScreen extends StatefulWidget {
  final String? startDate;
  final String? endDate;
  final String? estado;
  final String title;
  final bool showFilters;
  final bool showDatePicker;
  final bool isAdminView;
  final Function? onBackPressed;
  final bool showTotal;
  final String role;

  const SharedOrderHistoryScreen({
    super.key,
    this.startDate,
    this.endDate,
    this.estado,
    this.title = 'Historial de Pedidos',
    this.showFilters = true,
    this.showDatePicker = true,
    this.isAdminView = false,
    this.onBackPressed,
    this.showTotal = false,
    this.role = '',
  });

  @override
  State<SharedOrderHistoryScreen> createState() =>
      _SharedOrderHistoryScreenState();
}

class _SharedOrderHistoryScreenState extends State<SharedOrderHistoryScreen> {
  static const _completedOrCanceledFilter = "'completado', 'cancelado'";
  static const _validOrderStates = ['completado', 'cancelado'];

  final OrdersService _ordersService = OrdersService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  Set<int> _expandedItems = {};
  String? _filterStatus;
  String _selectedFilter = 'todos';
  bool _hasTriedWithMultipleFormats = false;
  int _debugCounter = 0;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.estado;
    _loadAllOrders();
  }

  Future<void> _loadAllOrders() async {
    _setLoading(true);
    _debugCounter++;
    developer.log(
      '📋 Iniciando carga de todos los pedidos... (intento: $_debugCounter)',
      name: 'OrderHistory',
    );

    try {
      // Primer intento con formato SQL normal
      final String estadoFilter =
          _hasTriedWithMultipleFormats
              ? "completado,cancelado"
              : "('completado','cancelado')";

      developer.log(
        '🔍 Intentando con filtro: $estadoFilter',
        name: 'OrderHistory',
      );

      final orders = await _ordersService.getOrders(estado: estadoFilter);
      developer.log(
        '📋 Pedidos recibidos desde API: ${orders.length}',
        name: 'OrderHistory',
      );

      if (orders.isEmpty && !_hasTriedWithMultipleFormats) {
        // Si no hay resultados, intentar con un formato alternativo
        setState(() {
          _hasTriedWithMultipleFormats = true;
        });
        return _loadAllOrders();
      }

      _processOrdersResponse(orders);
    } catch (e) {
      _handleLoadError(e);
    }
  }

  Future<void> _loadAllOrdersDirect() async {
    _setLoading(true);
    developer.log(
      '🚀 Intentando carga DIRECTA de pedidos...',
      name: 'OrderHistory',
    );

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intentando carga directa SQL...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
        ),
      );

      // Obtener directamente todos los pedidos completados o cancelados
      // Este método hace una consulta SQL directa a la base de datos
      final orders = await _ordersService.getOrders(
        estado: "completado", // Esto activará la consulta SQL directa
      );

      developer.log(
        '📋 Pedidos directos recibidos: ${orders.length}',
        name: 'OrderHistory',
      );
      _processOrdersResponse(orders);
    } catch (e) {
      developer.log(
        '❌ Error en carga directa: $e',
        name: 'OrderHistory',
        error: e,
      );
      _handleLoadError(e);
    }
  }

  Future<void> _loadOrders() async {
    if (widget.role == 'admin') {
      await _loadOrdersForAdmin();
    } else {
      await _loadOrdersForCookAndBarista();
    }
  }

  Future<void> _loadOrdersWithFilter(String filter) async {
    _setLoading(true);
    developer.log(
      '📅 Cargando pedidos con filtro: $filter',
      name: 'OrderHistory',
    );

    try {
      // Calcular rangos de fechas basados en el filtro
      final DateTime now = DateTime.now();
      String? startDateStr;
      String? endDateStr;
      String? whereClause;

      switch (filter) {
        case 'hoy':
          final startOfDay = DateTime(now.year, now.month, now.day);
          startDateStr = DateFormat('yyyy-MM-dd').format(startOfDay);
          endDateStr = startDateStr; // Mismo día
          whereClause = "AND DATE(p.fecha) = '$startDateStr'::date";
          break;
        case 'semana':
          // Encontrar el lunes de esta semana
          final daysToSubtract = now.weekday - 1; // Lunes es 1
          final startOfWeek = DateTime(
            now.year,
            now.month,
            now.day - daysToSubtract,
          );
          startDateStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
          endDateStr = DateFormat('yyyy-MM-dd').format(now);
          whereClause =
              "AND p.fecha >= '$startDateStr'::date AND p.fecha <= '$endDateStr'::date + interval '1 day'";
          break;
        case 'mes':
          // Primer día del mes actual
          final startOfMonth = DateTime(now.year, now.month, 1);
          startDateStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
          endDateStr = DateFormat('yyyy-MM-dd').format(now);
          whereClause =
              "AND p.fecha >= '$startDateStr'::date AND p.fecha <= '$endDateStr'::date + interval '1 day'";
          break;
        case 'todos':
        default:
          // No añadir filtro de fecha
          whereClause = "";
          break;
      }

      developer.log('📆 Filtro SQL: $whereClause', name: 'OrderHistory');

      // Ejecutar consulta SQL directa con el filtro adecuado
      final orders = await _queryOrdersWithCustomFilter(whereClause);
      developer.log(
        '📋 Pedidos recibidos con filtro: ${orders.length}',
        name: 'OrderHistory',
      );
      _processOrdersResponse(orders);
    } catch (e) {
      _handleLoadError(e);
    }
  }

  Future<List<Map<String, dynamic>>> _queryOrdersWithCustomFilter(
    String whereClause,
  ) async {
    developer.log('📊 Ejecutando consulta personalizada', name: 'OrderHistory');

    try {
      // Consulta SQL personalizada con filtro de fecha
      final sql = '''
        SELECT 
          p.idpedido, 
          p.idpersona, 
          p.estado, 
          TO_CHAR(p.fecha, 'YYYY-MM-DD') as fecha, 
          TO_CHAR(p.fecha, 'HH24:MI') as hora, 
          pe.nombre || ' ' || pe.apellido as cliente 
        FROM 
          pedidos p 
        INNER JOIN 
          personas pe ON p.idpersona = pe.idpersonas 
        WHERE 
          p.estado IN ('completado', 'cancelado') 
          $whereClause
        ORDER BY 
          p.fecha DESC
      ''';

      developer.log('🔍 SQL: $sql', name: 'OrderHistory');

      // Crear objeto para la consulta
      final query = {'query': sql};

      // Obtener URL del servidor y ejecutar la consulta
      String baseUrl = await _getServerBaseUrl();
      final uri = Uri.parse('$baseUrl/db/query');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(query),
      );

      if (response.statusCode != 200) {
        developer.log(
          '❌ Error en consulta: ${response.statusCode}',
          name: 'OrderHistory',
        );
        return [];
      }

      final data = json.decode(response.body);

      if (data['result'] == null || data['result'].isEmpty) {
        developer.log(
          '⚠️ La consulta no devolvió resultados',
          name: 'OrderHistory',
        );
        return [];
      }

      // Obtener IDs de pedidos para consultar detalles
      final pedidosIds = data['result'].map((row) => row['idpedido']).toList();

      // Consulta para obtener detalles de los pedidos
      final detallesQuery = {
        'query': '''
          SELECT 
            pd.idpedido, 
            pd.idplato, 
            pd.cantidad, 
            pd.precio_unitario, 
            m.nombre as nombre 
          FROM 
            pedido_detalle pd 
          INNER JOIN 
            menu m ON pd.idplato = m.idplato 
          WHERE 
            pd.idpedido = ANY(ARRAY[${pedidosIds.join(',')}])
        ''',
      };

      final detallesResponse = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(detallesQuery),
      );

      if (detallesResponse.statusCode != 200) {
        // Si falla la obtención de detalles, devolvemos al menos los datos básicos
        return List<Map<String, dynamic>>.from(
          data['result'].map(
            (row) => {
              'idpedido': row['idpedido'],
              'estado': row['estado'],
              'fecha': row['fecha'],
              'hora': row['hora'],
              'cliente': row['cliente'] ?? 'Cliente #${row['idpersona']}',
              'total': 0.0,
              'items': [],
            },
          ),
        );
      }

      final detallesData = json.decode(detallesResponse.body);
      final detalles = detallesData['result'] ?? [];

      // Procesar y combinar datos
      final List<Map<String, dynamic>> orders = [];

      for (final pedido in data['result']) {
        // Filtrar detalles para este pedido
        final itemsPedido =
            detalles.where((d) => d['idpedido'] == pedido['idpedido']).toList();

        // Calcular total
        double total = 0;
        for (var item in itemsPedido) {
          double cantidad =
              (item['cantidad'] is int)
                  ? item['cantidad'].toDouble()
                  : double.tryParse(item['cantidad'].toString()) ?? 1.0;

          double precioUnitario =
              (item['precio_unitario'] is num)
                  ? item['precio_unitario'] + 0.0
                  : double.tryParse(item['precio_unitario'].toString()) ?? 0.0;

          total += cantidad * precioUnitario;
        }

        // Formatear items
        final items =
            itemsPedido.map((item) {
              return {
                'nombre': item['nombre'],
                'cantidad':
                    item['cantidad'] is int
                        ? item['cantidad']
                        : int.tryParse(item['cantidad'].toString()) ?? 1,
                'precio_unitario':
                    item['precio_unitario'] is num
                        ? (item['precio_unitario'] + 0.0)
                        : double.tryParse(item['precio_unitario'].toString()) ??
                            0.0,
              };
            }).toList();

        orders.add({
          'idpedido': pedido['idpedido'],
          'estado': pedido['estado'],
          'fecha': pedido['fecha'],
          'hora': pedido['hora'],
          'cliente': pedido['cliente'] ?? 'Cliente #${pedido['idpersona']}',
          'total': total,
          'items': items,
        });
      }

      return orders;
    } catch (e) {
      developer.log(
        '❌ Error procesando consulta: $e',
        name: 'OrderHistory',
        error: e,
      );
      return [];
    }
  }

  Future<void> _loadOrdersForAdmin() async {
    _setLoading(true);
    developer.log('👤 Cargando pedidos para admin...', name: 'OrderHistory');

    try {
      developer.log(
        '📅 Fechas de filtrado: ${widget.startDate} al ${widget.endDate}',
        name: 'OrderHistory',
      );

      // Si tenemos fechas específicas, construir WHERE personalizado
      String whereClause = "";
      if (widget.startDate != null) {
        whereClause += " AND p.fecha >= '${widget.startDate}'::date";
      }
      if (widget.endDate != null) {
        whereClause +=
            " AND p.fecha <= '${widget.endDate}'::date + interval '1 day'";
      }

      final orders = await _queryOrdersWithCustomFilter(whereClause);

      developer.log(
        '📋 Admin: Pedidos recibidos desde API: ${orders.length}',
        name: 'OrderHistory',
      );
      _processOrdersResponse(orders);
    } catch (e) {
      _handleLoadError(e);
    }
  }

  Future<void> _loadOrdersForCookAndBarista() async {
    // Llamar al método general con filtro 'hoy'
    await _loadOrdersWithFilter('hoy');
  }

  void _processOrdersResponse(List<Map<String, dynamic>> orders) {
    if (!mounted) return;

    developer.log(
      '🔍 Procesando respuesta de pedidos: ${orders.length} pedidos',
      name: 'OrderHistory',
    );

    // Depurar toda la respuesta para ver qué está llegando exactamente
    developer.log(
      '📊 Datos completos recibidos: $orders',
      name: 'OrderHistory',
    );

    final filteredOrders =
        orders
            .where(
              (order) =>
                  order['estado'] != null &&
                  _validOrderStates.contains(
                    order['estado'].toString().toLowerCase(),
                  ),
            )
            .toList();

    developer.log(
      '✅ Filtrado completado: ${filteredOrders.length} pedidos válidos',
      name: 'OrderHistory',
    );

    // Depurar datos de pedidos
    if (filteredOrders.isNotEmpty) {
      developer.log(
        '📊 Primer pedido: ${filteredOrders[0]}',
        name: 'OrderHistory',
      );
    }

    setState(() {
      _orders = filteredOrders;
      _isLoading = false;
    });

    // Mostrar alerta si no hay datos
    if (filteredOrders.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontraron pedidos completados o cancelados'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  void _handleLoadError(dynamic error) {
    developer.log(
      '❌ Error al cargar órdenes: $error',
      name: 'OrderHistory',
      error: error,
    );

    if (mounted) {
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los pedidos: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _calculateTotal() {
    final total = _orders.fold<double>(
      0.0,
      (sum, order) => sum + (double.tryParse(order['total'].toString()) ?? 0.0),
    );
    return '\$${total.toStringAsFixed(2)}';
  }

  void _toggleItemExpansion(int index) {
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

    _showLoadingDialog();

    try {
      final success = await _ordersService.updateOrderStatus(
        orderId,
        newStatus,
      );

      if (mounted) Navigator.of(context).pop(); // Cerrar diálogo

      if (success) {
        _handleSuccessfulStatusUpdate(index, newStatus, orderId);
      } else {
        _showErrorSnackBar('Error al actualizar el pedido en el servidor');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Cerrar diálogo
      _showErrorSnackBar('Error al actualizar el pedido: $e');
    }
  }

  void _handleSuccessfulStatusUpdate(
    int index,
    String newStatus,
    dynamic orderId,
  ) {
    if (!mounted) return;

    setState(() {
      _orders[index]['estado'] = newStatus;

      // Si no es vista de admin y el estado no es completado o cancelado, remover el pedido
      if (!widget.isAdminView && !_validOrderStates.contains(newStatus)) {
        _orders.removeAt(index);
        _updateExpandedIndexesAfterRemoval(index);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pedido #$orderId actualizado a: $newStatus'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _updateExpandedIndexesAfterRemoval(int removedIndex) {
    if (_expandedItems.contains(removedIndex)) {
      _expandedItems.remove(removedIndex);
    }

    final newExpandedItems = <int>{};
    for (final expandedIndex in _expandedItems) {
      if (expandedIndex > removedIndex) {
        newExpandedItems.add(expandedIndex - 1);
      } else {
        newExpandedItems.add(expandedIndex);
      }
    }
    _expandedItems = newExpandedItems;
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext context) =>
              const Center(child: CircularProgressIndicator()),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == value;

    // Resaltar especialmente la opción "Todos" cuando está seleccionada
    final bool isTodosSelected = value == 'todos' && isSelected;

    return ChoiceChip(
      label: Text(
        value == 'todos'
            ? 'Todos los pedidos'
            : label, // Texto más claro para "Todos"
        style: TextStyle(
          fontSize:
              value == 'todos'
                  ? 13
                  : 12, // Texto ligeramente más grande para "Todos"
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });

          // Usar la nueva función que maneja filtros de fecha correctamente
          if (value == 'todos') {
            _loadAllOrders();
          } else {
            _loadOrdersWithFilter(value);
          }
        }
      },
      selectedColor:
          isTodosSelected
              ? theme.colorScheme.primary.withOpacity(
                0.3,
              ) // Color más intenso para "Todos" cuando está seleccionado
              : theme.colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color:
            isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: value == 'todos' ? 12 : 8,
      ), // Padding adicional para "Todos"
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.isAdminView ? 'No hay pedidos' : 'No hay pedidos procesados',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'en este período',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          // Añadir un botón para intentar carga directa
          ElevatedButton.icon(
            onPressed: _loadAllOrdersDirect,
            icon: const Icon(Icons.sync_problem),
            label: const Text('Probar carga directa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: OrderDetailCard(
            order: order,
            isExpanded: _expandedItems.contains(index),
            onTap: () => _toggleItemExpansion(index),
            onStatusChange:
                widget.isAdminView
                    ? (newStatus) => _updateOrderStatus(index, newStatus)
                    : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
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
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFF3ea69b),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 70.0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Colors.white, width: 1.5),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
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
          // Botón para cargar directamente
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Carga directa',
            onPressed: _loadAllOrdersDirect,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.showFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todos', 'todos'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Hoy', 'hoy'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Esta semana', 'semana'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Este mes', 'mes'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_orders.length} ${_orders.length == 1 ? 'pedido encontrado' : 'pedidos encontrados'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),

                if (widget.showTotal && _orders.isNotEmpty) ...[
                  Text(
                    'Total: ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _calculateTotal(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],

                IconButton(
                  icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
                  onPressed: _loadAllOrders,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
          ),

          Expanded(
            child: Stack(
              children: [
                _orders.isEmpty ? _buildEmptyState(theme) : _buildOrdersList(),

                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.1),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getServerBaseUrl() async {
    try {
      // Primero intentamos obtener un pedido para extraer la URL base del servidor
      final testOrders = await _ordersService.getOrders(estado: "completado");

      // Si llegamos aquí, hay conexión con el servidor
      final prefs = await SharedPreferences.getInstance();
      final serverIp =
          prefs.getString('serverIp') ??
          dotenv.env['NODE_SERVER_IP'] ??
          '192.168.1.121';
      final serverPort = dotenv.env['NODE_SERVER_PORT'] ?? '3000';
      return 'http://$serverIp:$serverPort';
    } catch (e) {
      // Si falla, usamos la dirección IP predeterminada
      return 'http://192.168.1.121:3000';
    }
  }
}
