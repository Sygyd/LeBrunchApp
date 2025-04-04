import 'package:flutter/material.dart';
import 'dart:async';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeOrders = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchActiveOrders();

    // Configurar un temporizador para actualizar los pedidos cada 30 segundos
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchActiveOrders(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchActiveOrders() async {
    // En una implementación real, aquí obtendrías los pedidos activos desde el servidor
    try {
      // Simular una petición a la API
      await Future.delayed(const Duration(seconds: 1));

      // Datos de ejemplo
      final List<Map<String, dynamic>> mockOrders = [
        {
          'id': '1',
          'mesa': '5',
          'hora': '10:15 AM',
          'estado': 'preparando',
          'tiempo_estimado': '10 min',
          'platos': [
            {
              'nombre': 'Panquecas con frutos rojos',
              'cantidad': 2,
              'estado': 'preparando',
            },
            {
              'nombre': 'Tostadas francesas',
              'cantidad': 1,
              'estado': 'preparando',
            },
          ],
        },
        {
          'id': '2',
          'mesa': '3',
          'hora': '10:20 AM',
          'estado': 'en cola',
          'tiempo_estimado': '15 min',
          'platos': [
            {
              'nombre': 'Omelette vegetariano',
              'cantidad': 1,
              'estado': 'en cola',
            },
            {'nombre': 'Tabla de desayuno', 'cantidad': 1, 'estado': 'en cola'},
          ],
        },
        {
          'id': '3',
          'mesa': '8',
          'hora': '10:05 AM',
          'estado': 'preparando',
          'tiempo_estimado': '5 min',
          'platos': [
            {
              'nombre': 'Gofres con frutas',
              'cantidad': 2,
              'estado': 'preparando',
            },
          ],
        },
      ];

      if (mounted) {
        setState(() {
          _activeOrders = mockOrders;
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
      ).showSnackBar(SnackBar(content: Text('Error al cargar pedidos: $e')));
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    // En una implementación real, aquí actualizarías el estado del pedido en el servidor
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Simular petición a la API
      await Future.delayed(const Duration(seconds: 1));

      // Actualizar lista local
      if (mounted) {
        setState(() {
          for (var i = 0; i < _activeOrders.length; i++) {
            if (_activeOrders[i]['id'] == orderId) {
              _activeOrders[i]['estado'] = newStatus;

              // Si el pedido está completado, eliminarlo de la lista después de un tiempo
              if (newStatus == 'completado') {
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _activeOrders.removeAt(i);
                    });
                  }
                });
              }
              break;
            }
          }
        });
      }

      // Cerrar diálogo de carga
      if (mounted) Navigator.of(context).pop();

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido #$orderId actualizado a: $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Cerrar diálogo de carga
      if (mounted) Navigator.of(context).pop();

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

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No hay pedidos activos', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchActiveOrders,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchActiveOrders,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _activeOrders.length,
        itemBuilder: (context, index) {
          final order = _activeOrders[index];
          return _buildOrderCard(context, order);
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final theme = Theme.of(context);
    final orderId = order['id'];
    final estado = order['estado'];

    // Determinar el color según el estado
    Color statusColor;
    switch (estado) {
      case 'en cola':
        statusColor = Colors.orange;
        break;
      case 'preparando':
        statusColor = Colors.blue;
        break;
      case 'completado':
        statusColor = Colors.green;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado del pedido
          Container(
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pedido #${order['id']}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              estado.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mesa ${order['mesa']} • ${order['hora']}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        'Tiempo estimado: ${order['tiempo_estimado']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.timer, color: statusColor, size: 28),
              ],
            ),
          ),

          // Lista de platos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platos a preparar:', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ...List.generate(
                  order['platos'].length,
                  (index) => _buildDishItem(
                    context,
                    order['platos'][index],
                    statusColor,
                  ),
                ),
              ],
            ),
          ),

          // Botones de acción
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (estado == 'en cola') ...[
                  OutlinedButton(
                    onPressed: () => _updateOrderStatus(orderId, 'cancelado'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _updateOrderStatus(orderId, 'preparando'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Preparar'),
                  ),
                ] else if (estado == 'preparando') ...[
                  ElevatedButton(
                    onPressed: () => _updateOrderStatus(orderId, 'completado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Completar'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishItem(
    BuildContext context,
    Map<String, dynamic> dish,
    Color statusColor,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.lunch_dining, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(dish['nombre'], style: theme.textTheme.bodyMedium),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'x${dish['cantidad']}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
