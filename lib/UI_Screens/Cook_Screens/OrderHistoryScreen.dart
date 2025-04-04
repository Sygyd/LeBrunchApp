import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedOrders = [];
  String _selectedFilter = 'hoy'; // 'hoy', 'semana', 'mes'

  @override
  void initState() {
    super.initState();
    _fetchCompletedOrders();
  }

  Future<void> _fetchCompletedOrders() async {
    // En una implementación real, aquí obtendría los pedidos completados desde el servidor
    try {
      // Simular una petición a la API
      await Future.delayed(const Duration(seconds: 1));

      // Obtener la fecha actual para los filtros
      final now = DateTime.now();

      // Datos de ejemplo
      final List<Map<String, dynamic>> mockOrders = [
        {
          'id': '15',
          'mesa': '7',
          'hora':
              '${DateFormat('HH:mm').format(now.subtract(const Duration(hours: 1)))}',
          'fecha': '${DateFormat('dd/MM/yyyy').format(now)}',
          'estado': 'completado',
          'tiempo_preparacion': '18 min',
          'platos': [
            {'nombre': 'Omelette jamón y queso', 'cantidad': 2},
            {'nombre': 'Tostadas de aguacate', 'cantidad': 1},
          ],
        },
        {
          'id': '14',
          'mesa': '3',
          'hora':
              '${DateFormat('HH:mm').format(now.subtract(const Duration(hours: 2)))}',
          'fecha': '${DateFormat('dd/MM/yyyy').format(now)}',
          'estado': 'completado',
          'tiempo_preparacion': '12 min',
          'platos': [
            {'nombre': 'Panquecas con frutos rojos', 'cantidad': 2},
          ],
        },
        {
          'id': '10',
          'mesa': '5',
          'hora': '10:30',
          'fecha':
              '${DateFormat('dd/MM/yyyy').format(now.subtract(const Duration(days: 1)))}',
          'estado': 'completado',
          'tiempo_preparacion': '15 min',
          'platos': [
            {'nombre': 'Gofres con chocolate', 'cantidad': 1},
            {'nombre': 'Tabla de desayuno', 'cantidad': 1},
          ],
        },
        {
          'id': '8',
          'mesa': '2',
          'hora': '09:15',
          'fecha':
              '${DateFormat('dd/MM/yyyy').format(now.subtract(const Duration(days: 1)))}',
          'estado': 'completado',
          'tiempo_preparacion': '10 min',
          'platos': [
            {'nombre': 'Tostadas francesas', 'cantidad': 2},
          ],
        },
        {
          'id': '5',
          'mesa': '8',
          'hora': '11:20',
          'fecha':
              '${DateFormat('dd/MM/yyyy').format(now.subtract(const Duration(days: 2)))}',
          'estado': 'completado',
          'tiempo_preparacion': '20 min',
          'platos': [
            {'nombre': 'Panquecas con dulce de leche', 'cantidad': 2},
            {'nombre': 'Omelette vegetariano', 'cantidad': 1},
          ],
        },
      ];

      if (mounted) {
        setState(() {
          _completedOrders = mockOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      // Mostrar error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar historial: $e')));
    }
  }

  List<Map<String, dynamic>> _getFilteredOrders() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedFilter) {
      case 'hoy':
        return _completedOrders.where((order) {
          final parts = order['fecha'].split('/');
          final orderDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
          return orderDate.isAtSameMomentAs(today);
        }).toList();
      case 'semana':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        return _completedOrders.where((order) {
          final parts = order['fecha'].split('/');
          final orderDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
          return orderDate.isAfter(
                weekStart.subtract(const Duration(days: 1)),
              ) ||
              orderDate.isAtSameMomentAs(weekStart);
        }).toList();
      case 'mes':
        final monthStart = DateTime(now.year, now.month, 1);
        return _completedOrders.where((order) {
          final parts = order['fecha'].split('/');
          final orderDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
          return orderDate.isAfter(
                monthStart.subtract(const Duration(days: 1)),
              ) ||
              orderDate.isAtSameMomentAs(monthStart);
        }).toList();
      default:
        return _completedOrders;
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

    final filteredOrders = _getFilteredOrders();

    return Column(
      children: [
        // Filtro por periodo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFilterChip('Hoy', 'hoy'),
                  _buildFilterChip('Esta semana', 'semana'),
                  _buildFilterChip('Este mes', 'mes'),
                ],
              ),
            ),
          ),
        ),

        // Contador de pedidos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${filteredOrders.length} pedidos completados',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchCompletedOrders,
                tooltip: 'Actualizar',
              ),
            ],
          ),
        ),

        // Lista de pedidos
        Expanded(
          child:
              filteredOrders.isEmpty
                  ? Center(
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
                          'No hay pedidos completados',
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
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderHistoryCard(context, order);
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color:
            isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildOrderHistoryCard(
    BuildContext context,
    Map<String, dynamic> order,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Row(
          children: [
            Text(
              'Pedido #${order['id']}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                'COMPLETADO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Mesa ${order['mesa']} • ${order['fecha']} ${order['hora']}',
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              'Tiempo de preparación: ${order['tiempo_preparacion']}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.expand_more),
        children: [
          const Divider(),
          Text('Platos preparados:', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ...order['platos']
              .map<Widget>(
                (plato) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${plato['nombre']} (x${plato['cantidad']})',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }
}
