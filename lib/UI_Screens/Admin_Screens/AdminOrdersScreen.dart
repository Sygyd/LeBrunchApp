import 'package:flutter/material.dart';
import '../../Api_services/pedidos/orders_service.dart';
import '../Widgets/order_detail_card.dart';
import '../Widgets/background_scaffold.dart';
import 'dart:async';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final OrdersService _ordersService = OrdersService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingOrders = [];
  Set<int> _expandedOrders = {};
  Timer? _refreshTimer;
  bool _autoRefresh = true;
  final Duration _refreshInterval = const Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(
        _refreshInterval,
        (_) => _loadPendingOrders(),
      );
    }
  }

  Future<void> _loadPendingOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Listar IDs de los pedidos que ya están expandidos para mantenerlos así después de recargar
      final expandedOrderIds = Set<int>.from(_expandedOrders);

      // Obtener todas las órdenes pendientes
      final orders = await _ordersService.getOrders(estado: 'pendiente');

      // Lista de pedidos que deben ser actualizados automáticamente a completados
      List<int> ordersToComplete = [];

      print(
        '🔍 Verificando ${orders.length} pedidos pendientes para completado automático...',
      );

      // Verificar todos los pedidos según las reglas establecidas
      for (var order in orders) {
        final orderId = order['idpedido'];
        final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

        if (items.isEmpty) {
          print('⚠️ Pedido #$orderId no tiene ítems');
          continue;
        }

        bool hayComida = false;
        bool hayBebida = false;
        bool todosItemsComidaCompletados = true;
        bool todosItemsBebidaCompletados = true;

        // Verificar cada ítem del pedido
        for (var item in items) {
          final tipo = item['tipo']?.toString().toLowerCase() ?? '';

          if (tipo == 'comida') {
            hayComida = true;
            // Verificar si está completado por el cocinero
            final completadoCocinero = item['completado_cocinero'] ?? false;
            if (!completadoCocinero) {
              todosItemsComidaCompletados = false;
            }
          } else if (tipo == 'bebida') {
            hayBebida = true;
            // Verificar si está completado por el barista
            final completadoBarista = item['completado_barista'] ?? false;
            if (!completadoBarista) {
              todosItemsBebidaCompletados = false;
            }
          }
        }

        // Aplicar las reglas para determinar si el pedido debe completarse automáticamente
        bool debeCompletarse = false;

        // Regla 1: Si hay comida y bebida, ambas deben estar completadas
        if (hayComida && hayBebida) {
          if (todosItemsComidaCompletados && todosItemsBebidaCompletados) {
            debeCompletarse = true;
            print(
              '✅ Pedido #$orderId: Todos los ítems de comida y bebida están completados',
            );
          } else {
            print(
              'ℹ️ Pedido #$orderId mixto (comida y bebida): No todos los ítems están completados',
            );
          }
        }
        // Regla 2: Si solo hay comida, todos los ítems de comida deben estar completados
        else if (hayComida && !hayBebida) {
          if (todosItemsComidaCompletados) {
            debeCompletarse = true;
            print(
              '✅ Pedido #$orderId: Solo comida, todos los ítems completados',
            );
          } else {
            print(
              'ℹ️ Pedido #$orderId: Solo comida, faltan ítems por completar',
            );
          }
        }
        // Regla 3: Si solo hay bebida, todos los ítems de bebida deben estar completados
        else if (!hayComida && hayBebida) {
          if (todosItemsBebidaCompletados) {
            debeCompletarse = true;
            print(
              '✅ Pedido #$orderId: Solo bebida, todos los ítems completados',
            );
          } else {
            print(
              'ℹ️ Pedido #$orderId: Solo bebida, faltan ítems por completar',
            );
          }
        }

        // Si debe completarse, agregarlo a la lista
        if (debeCompletarse) {
          ordersToComplete.add(orderId);
        }
      }

      // Actualizar automáticamente los pedidos que deben completarse
      if (ordersToComplete.isNotEmpty) {
        print(
          '🔄 Se completarán automáticamente ${ordersToComplete.length} pedidos: ${ordersToComplete.join(', ')}',
        );

        // Completar cada pedido de forma asíncrona
        for (int orderId in ordersToComplete) {
          // Eliminar el pedido de la lista local para evitar parpadeos en la UI
          orders.removeWhere((order) => order['idpedido'] == orderId);

          // Actualizar el estado en la base de datos
          _ordersService.updateOrderStatus(orderId, 'completado').then((
            success,
          ) {
            if (success) {
              print('✅ Pedido #$orderId completado automáticamente');
            } else {
              print('❌ Error al completar automáticamente el pedido #$orderId');
              // Programar una recarga para intentar nuevamente
              if (mounted) {
                Future.delayed(
                  const Duration(seconds: 5),
                  () => _loadPendingOrders(),
                );
              }
            }
          });
        }
      } else {
        print('ℹ️ No se encontraron pedidos para completar automáticamente');
      }

      if (mounted) {
        setState(() {
          _pendingOrders = orders;
          _isLoading = false;

          // Restaurar los pedidos expandidos
          _expandedOrders = expandedOrderIds.intersection(
            orders.map((o) => o['idpedido'] as int).toSet(),
          );
        });
      }
    } catch (e) {
      print('❌ Error al cargar órdenes pendientes: $e');
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

  // Obtener los contadores de órdenes mixtas con diferentes estados
  Map<String, int> _getOrdersCountByStatus(List<Map<String, dynamic>> orders) {
    int totalOrders = orders.length;
    int mixedOrders = 0;
    int readyToComplete = 0;
    int waitingForCook = 0;
    int waitingForBarista = 0;
    int waitingForBoth = 0;

    for (var order in orders) {
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        order['items'] ?? [],
      );

      bool hasComida = false;
      bool hasBebida = false;
      bool allComidaCompleted = true;
      bool allBebidaCompleted = true;

      for (var item in items) {
        String tipo = item['tipo']?.toString().toLowerCase() ?? '';

        if (tipo == 'comida') {
          hasComida = true;
          if (!(item['completado_cocinero'] ?? false)) {
            allComidaCompleted = false;
          }
        } else if (tipo == 'bebida') {
          hasBebida = true;
          if (!(item['completado_barista'] ?? false)) {
            allBebidaCompleted = false;
          }
        }
      }

      if (hasComida && hasBebida) {
        mixedOrders++;

        if (allComidaCompleted && allBebidaCompleted) {
          readyToComplete++;
        } else if (!allComidaCompleted && !allBebidaCompleted) {
          waitingForBoth++;
        } else if (!allComidaCompleted) {
          waitingForCook++;
        } else if (!allBebidaCompleted) {
          waitingForBarista++;
        }
      }
    }

    return {
      'total': totalOrders,
      'mixed': mixedOrders,
      'readyToComplete': readyToComplete,
      'waitingForCook': waitingForCook,
      'waitingForBarista': waitingForBarista,
      'waitingForBoth': waitingForBoth,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderStats = _getOrdersCountByStatus(_pendingOrders);

    return BackgroundScaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Órdenes Pendientes',
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
            const SizedBox(width: 8),
            if (_isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
          ],
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
          // Botón de recargar pedidos
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingOrders,
            tooltip: 'Actualizar pedidos',
          ),
          // Botón para activar/desactivar auto-refresh
          IconButton(
            onPressed: () {
              setState(() {
                _autoRefresh = !_autoRefresh;
              });
              _startAutoRefresh();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _autoRefresh
                        ? 'Actualización automática activada'
                        : 'Actualización automática desactivada',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: _autoRefresh ? Colors.green : Colors.grey,
                ),
              );
            },
            icon: Icon(_autoRefresh ? Icons.timer : Icons.timer_off),
            tooltip:
                _autoRefresh
                    ? 'Desactivar actualización automática'
                    : 'Activar actualización automática',
          ),
        ],
      ),
      body:
          _isLoading && _pendingOrders.isEmpty
              ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadPendingOrders,
                color: theme.colorScheme.primary,
                child: Column(
                  children: [
                    // Panel de estadísticas para pedidos mixtos
                    if (orderStats['mixed']! > 0)
                      Card(
                        margin: const EdgeInsets.all(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen de pedidos mixtos',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Órdenes listas para completar
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Listos para completar',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${orderStats['readyToComplete']}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Esperando al cocinero
                              if (orderStats['waitingForCook']! > 0)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.restaurant_outlined,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Esperando al cocinero',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${orderStats['waitingForCook']}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              if (orderStats['waitingForCook']! > 0)
                                const SizedBox(height: 4),
                              // Esperando al barista
                              if (orderStats['waitingForBarista']! > 0)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.coffee_outlined,
                                      color: theme.colorScheme.secondary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Esperando al barista',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${orderStats['waitingForBarista']}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.secondary,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),

                    Expanded(
                      child:
                          _pendingOrders.isEmpty
                              ? Center(
                                child: Card(
                                  margin: const EdgeInsets.all(16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 80,
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.7),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No hay pedidos pendientes',
                                          style: TextStyle(
                                            fontFamily: 'Lighthouse',
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Todos los pedidos han sido completados',
                                          style: TextStyle(
                                            fontFamily: 'MADE TOMMY',
                                            fontSize: 14,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: _loadPendingOrders,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Actualizar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(200, 48),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _pendingOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _pendingOrders[index];
                                  final orderId = order['idpedido'];
                                  final isExpanded = _expandedOrders.contains(
                                    orderId,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: OrderDetailCard(
                                      order: order,
                                      isExpanded: isExpanded,
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedOrders.remove(orderId);
                                          } else {
                                            _expandedOrders.add(orderId);
                                          }
                                        });
                                      },
                                      onStatusChange:
                                          (newStatus) => _updateOrderStatus(
                                            order['idpedido'],
                                            newStatus,
                                          ),
                                      role: 'admin',
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
    );
  }

  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      // Si se está intentando completar la orden, primero verificamos si está realmente lista
      if (newStatus.toLowerCase() == 'completado') {
        // Buscar la orden en la lista actual
        final orderIndex = _pendingOrders.indexWhere(
          (order) => order['idpedido'] == orderId,
        );
        if (orderIndex >= 0) {
          final order = _pendingOrders[orderIndex];
          final items = List<Map<String, dynamic>>.from(order['items'] ?? []);

          bool hayComida = false;
          bool hayBebida = false;
          bool todosItemsComidaCompletados = true;
          bool todosItemsBebidaCompletados = true;

          // Verificar todos los ítems
          for (var item in items) {
            final tipo = item['tipo']?.toString().toLowerCase() ?? '';

            if (tipo == 'comida') {
              hayComida = true;
              if (!(item['completado_cocinero'] ?? false)) {
                todosItemsComidaCompletados = false;
              }
            } else if (tipo == 'bebida') {
              hayBebida = true;
              if (!(item['completado_barista'] ?? false)) {
                todosItemsBebidaCompletados = false;
              }
            }
          }

          // Aplicar las reglas definidas por el usuario:
          bool debeCompletarse = false;
          String mensajeError = '';

          // Verificar según las reglas
          if (hayComida && hayBebida) {
            // Si hay comida y bebida, verificamos reglas para ambas
            if (todosItemsComidaCompletados && todosItemsBebidaCompletados) {
              debeCompletarse =
                  true; // Regla: cook completado = true y barista completado = true
            } else {
              if (!todosItemsComidaCompletados &&
                  !todosItemsBebidaCompletados) {
                mensajeError =
                    'No se puede completar: Faltan ítems de comida y bebida';
              } else if (!todosItemsComidaCompletados) {
                mensajeError = 'No se puede completar: Faltan ítems de comida';
              } else {
                mensajeError = 'No se puede completar: Faltan ítems de bebida';
              }
            }
          } else if (hayComida && !hayBebida) {
            // Si solo hay comida
            debeCompletarse =
                todosItemsComidaCompletados; // Regla: Solo comida y completada
            if (!debeCompletarse) {
              mensajeError = 'No se puede completar: Faltan ítems de comida';
            }
          } else if (!hayComida && hayBebida) {
            // Si solo hay bebida
            debeCompletarse =
                todosItemsBebidaCompletados; // Regla: Solo bebida y completada
            if (!debeCompletarse) {
              mensajeError = 'No se puede completar: Faltan ítems de bebida';
            }
          }

          // Si no debe completarse, mostrar mensaje de error y salir
          if (!debeCompletarse) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(mensajeError),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return; // No continuar con la actualización
          }
        }
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Text('Actualizando estado del pedido...'),
              ],
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // Actualizar el estado de la orden
      final result = await _ordersService.updateOrderStatus(orderId, newStatus);

      if (result) {
        // Eliminar de la lista de órdenes pendientes
        setState(() {
          _pendingOrders.removeWhere((order) => order['idpedido'] == orderId);
          _expandedOrders.remove(orderId);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus.toLowerCase() == 'completado'
                    ? 'Pedido #$orderId completado con éxito'
                    : 'Pedido #$orderId cancelado',
              ),
              backgroundColor:
                  newStatus.toLowerCase() == 'completado'
                      ? Colors.green
                      : Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al actualizar el estado del pedido #$orderId',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // Recargar órdenes pendientes
      _loadPendingOrders();
    } catch (e) {
      print('Error al actualizar estado del pedido: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el estado del pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
