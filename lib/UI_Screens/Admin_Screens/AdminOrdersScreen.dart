import 'package:flutter/material.dart';
import '../../Api_services/pedidos/orders_service.dart';
import '../Widgets/order_detail_card.dart';
import '../Widgets/background_scaffold.dart';
import 'dart:async';
import '../../services/order_status_service.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final OrdersService _ordersService = OrdersService();
  final OrderStatusService _statusService = OrderStatusService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingOrders = [];
  Set<int> _expandedOrders = {};
  Timer? _refreshTimer;
  bool _autoRefresh = true;
  final Duration _refreshInterval = const Duration(seconds: 15);
  StreamSubscription? _orderCompletedSubscription;

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
    _startAutoRefresh();

    _orderCompletedSubscription = _statusService.onOrderCompleted.listen((
      orderId,
    ) {
      print(
        '📣 AdminOrdersScreen: Notificación recibida - Pedido #$orderId completado',
      );
      _handleOrderCompleted(orderId);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _orderCompletedSubscription?.cancel();
    super.dispose();
  }

  void _handleOrderCompleted(int orderId) {
    if (mounted) {
      setState(() {
        _pendingOrders.removeWhere((order) => order['idpedido'] == orderId);
        _expandedOrders.remove(orderId);
      });
    }
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
      final expandedOrderIds = Set<int>.from(_expandedOrders);

      final orders = await _ordersService.getOrders(estado: 'pendiente');

      List<int> ordersToComplete = [];

      print(
        '🔍 Verificando ${orders.length} pedidos pendientes para completado automático...',
      );

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

        for (var item in items) {
          final tipo = item['tipo']?.toString().toLowerCase() ?? '';

          if (tipo == 'comida') {
            hayComida = true;
            final completadoCocinero = item['completado_cocinero'] ?? false;
            if (!completadoCocinero) {
              todosItemsComidaCompletados = false;
            }
          } else if (tipo == 'bebida') {
            hayBebida = true;
            final completadoBarista = item['completado_barista'] ?? false;
            if (!completadoBarista) {
              todosItemsBebidaCompletados = false;
            }
          }
        }

        bool debeCompletarse = false;

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
        } else if (hayComida && !hayBebida) {
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
        } else if (!hayComida && hayBebida) {
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

        if (debeCompletarse) {
          ordersToComplete.add(orderId);
        }
      }

      if (ordersToComplete.isNotEmpty) {
        print(
          '🔄 Se completarán automáticamente ${ordersToComplete.length} pedidos: ${ordersToComplete.join(', ')}',
        );

        for (int orderId in ordersToComplete) {
          orders.removeWhere((order) => order['idpedido'] == orderId);

          _ordersService.updateOrderStatus(orderId, 'completado').then((
            success,
          ) {
            if (success) {
              print('✅ Pedido #$orderId completado automáticamente');
            } else {
              print('❌ Error al completar automáticamente el pedido #$orderId');
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingOrders,
            tooltip: 'Actualizar pedidos',
          ),
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
                                      // Permite al admin completar platos individuales como cocinero o barista
                                      // Refresca la pantalla cuando se marca un plato como completado
                                      onRefresh: _loadPendingOrders,
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
      if (newStatus.toLowerCase() == 'completado') {
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

          bool debeCompletarse = false;
          String mensajeError = '';

          if (hayComida && hayBebida) {
            if (todosItemsComidaCompletados && todosItemsBebidaCompletados) {
              debeCompletarse = true;
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
            debeCompletarse = todosItemsComidaCompletados;
            if (!debeCompletarse) {
              mensajeError = 'No se puede completar: Faltan ítems de comida';
            }
          } else if (!hayComida && hayBebida) {
            debeCompletarse = todosItemsBebidaCompletados;
            if (!debeCompletarse) {
              mensajeError = 'No se puede completar: Faltan ítems de bebida';
            }
          }

          if (!debeCompletarse) {
            if (mounted) {
              final theme = Theme.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mensajeError,
                          style: TextStyle(
                            fontFamily: 'MADE TOMMY',
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: theme.colorScheme.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(8),
                  elevation: 4,
                ),
              );
            }
            return;
          }
        }
      }

      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Actualizando estado del pedido...',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            elevation: 4,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final result = await _ordersService.updateOrderStatus(orderId, newStatus);

      if (result) {
        setState(() {
          _pendingOrders.removeWhere((order) => order['idpedido'] == orderId);
          _expandedOrders.remove(orderId);
        });

        if (mounted) {
          final theme = Theme.of(context);
          final isCompletado = newStatus.toLowerCase() == 'completado';
          final backgroundColor =
              isCompletado
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.errorContainer;
          final textColor =
              isCompletado
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onErrorContainer;
          final icon =
              isCompletado ? Icons.check_circle_outline : Icons.cancel_outlined;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(icon, color: textColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCompletado
                          ? 'Pedido #$orderId completado con éxito'
                          : 'Pedido #$orderId cancelado',
                      style: TextStyle(
                        fontFamily: 'MADE TOMMY',
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              elevation: 4,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          final theme = Theme.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.onError),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error al actualizar el estado del pedido #$orderId',
                      style: TextStyle(
                        fontFamily: 'MADE TOMMY',
                        color: theme.colorScheme.onError,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: theme.colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(8),
              elevation: 4,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      _loadPendingOrders();
    } catch (e) {
      print('Error al actualizar estado del pedido: $e');
      if (mounted) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.onError),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error al actualizar el estado del pedido: $e',
                    style: TextStyle(
                      fontFamily: 'MADE TOMMY',
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.error,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(8),
            elevation: 4,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
