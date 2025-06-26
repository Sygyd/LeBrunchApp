import 'package:flutter/material.dart';
import 'dart:async';
import '../../Api_services/pedidos/orders_service.dart';
import '../Shared/shared_active_orders_screen.dart';
import '../../services/order_status_service.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
  final OrdersService _ordersService = OrdersService();
  final OrderStatusService _statusService = OrderStatusService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _orders = [];
  StreamSubscription? _orderCompletedSubscription;

  @override
  void initState() {
    super.initState();
    _loadOrders();

    _orderCompletedSubscription = _statusService.onOrderCompleted.listen((
      orderData,
    ) {
      print(
        '📣 ActiveOrdersScreen (Cook): Notificación recibida - Pedido #${orderData['orderId']} completado',
      );
      _handleOrderCompleted(orderData);
    });
  }

  @override
  void dispose() {
    _orderCompletedSubscription?.cancel();
    super.dispose();
  }

  void _handleOrderCompleted(Map<String, dynamic> orderData) {
    final int orderId = orderData['orderId'];
    final String? mesa = orderData['mesa'];
    final String mensaje = orderData['mensaje'] ?? 'Pedido completado';

    if (mounted) {
      setState(() {
        _orders.removeWhere((order) => order['idpedido'] == orderId);
      });

      // Mostrar mensaje informativo con la información de mesa
      if (mounted) {
        final displayMessage =
            mesa != null
                ? 'Pedido #$orderId completado automáticamente, enviando a $mesa'
                : 'Pedido #$orderId completado automáticamente';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await _ordersService.getOrdersByType('comida');

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return SharedActiveOrdersScreen(
      orders: _orders,
      isLoading: _isLoading,
      onRefresh: _loadOrders,
      role: 'cook',
      title: 'Pedidos de Comida',
    );
  }
}
