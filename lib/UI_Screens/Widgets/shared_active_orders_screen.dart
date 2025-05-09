import 'package:flutter/material.dart';
import 'dart:async';
import '../../Api_services/pedidos/orders_service.dart';
import 'order_detail_card.dart';

/// Pantalla de Órdenes Activas compartida que puede ser usada tanto por Cocinero como por Barista
/// Personalizable con parámetros según el rol
class SharedActiveOrdersScreen extends StatefulWidget {
  final String role; // 'cook' o 'barista'
  final String title;
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const SharedActiveOrdersScreen({
    super.key,
    required this.role,
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    this.title = 'Órdenes Activas',
  });

  @override
  State<SharedActiveOrdersScreen> createState() =>
      _SharedActiveOrdersScreenState();
}

class _SharedActiveOrdersScreenState extends State<SharedActiveOrdersScreen> {
  Timer? _refreshTimer;
  late final OrdersService _ordersService;

  @override
  void initState() {
    super.initState();
    _ordersService = OrdersService();

    // Configurar un temporizador para actualizar los pedidos cada 30 segundos
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => widget.onRefresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateOrderStatus(int index, String newStatus) async {
    try {
      final order = widget.orders[index];
      final success = await _ordersService.updateOrderStatus(
        order['idpedido'],
        newStatus,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Estado actualizado a: $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body:
          widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : widget.orders.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No hay pedidos activos',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.orders.length,
                  itemBuilder: (context, index) {
                    final order = widget.orders[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OrderDetailCard(
                        order: order,
                        isExpanded: true,
                        onTap: null,
                        onStatusChange:
                            (newStatus) => _updateOrderStatus(index, newStatus),
                        role: widget.role,
                        onRefresh: widget.onRefresh,
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
