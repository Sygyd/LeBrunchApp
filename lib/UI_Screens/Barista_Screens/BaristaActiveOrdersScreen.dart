import 'package:flutter/material.dart';
import '../../../Api_services/pedidos/orders_service.dart';
import '../Widgets/shared_active_orders_screen.dart';

class BaristaActiveOrdersScreen extends StatefulWidget {
  const BaristaActiveOrdersScreen({super.key});

  @override
  State<BaristaActiveOrdersScreen> createState() =>
      _BaristaActiveOrdersScreenState();
}

class _BaristaActiveOrdersScreenState extends State<BaristaActiveOrdersScreen> {
  final OrdersService _ordersService = OrdersService();
  bool _isLoading = false;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los pedidos: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
