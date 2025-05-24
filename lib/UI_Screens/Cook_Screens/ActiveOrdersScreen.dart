import 'package:flutter/material.dart';
import '../../../Api_services/pedidos/orders_service.dart';
import '../Shared/shared_active_orders_screen.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> {
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
      final orders = await _ordersService.getOrdersByType('comida');

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
      role: 'cook',
      title: 'Pedidos de Comida',
    );
  }
}
