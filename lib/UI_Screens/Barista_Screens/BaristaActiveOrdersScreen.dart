import 'package:flutter/material.dart';
import 'dart:async';
import '../../../Api_services/pedidos/orders_service.dart';
import '../Shared/shared_active_orders_screen.dart';
import '../../services/order_status_service.dart';

class BaristaActiveOrdersScreen extends StatefulWidget {
  const BaristaActiveOrdersScreen({super.key});

  @override
  State<BaristaActiveOrdersScreen> createState() =>
      _BaristaActiveOrdersScreenState();
}

class _BaristaActiveOrdersScreenState extends State<BaristaActiveOrdersScreen> {
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
      orderId,
    ) {
      print(
        '📣 BaristaActiveOrdersScreen: Notificación recibida - Pedido #$orderId completado',
      );
      _handleOrderCompleted(orderId);
    });
  }

  @override
  void dispose() {
    _orderCompletedSubscription?.cancel();
    super.dispose();
  }

  void _handleOrderCompleted(int orderId) {
    if (mounted) {
      setState(() {
        _orders.removeWhere((order) => order['idpedido'] == orderId);
      });
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await _ordersService.getOrdersByType('bebida');

      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
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
      role: 'barista',
      title: 'Pedidos de Bebidas',
    );
  }
}
