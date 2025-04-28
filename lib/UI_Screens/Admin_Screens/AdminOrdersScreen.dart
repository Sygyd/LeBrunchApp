import 'package:flutter/material.dart';
import '../../Api_services/pedidos/orders_service.dart';
import '../Widgets/order_detail_card.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final OrdersService _ordersService = OrdersService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingOrders = [];

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  Future<void> _loadPendingOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar solamente órdenes con estado "pendiente"
      final orders = await _ordersService.getOrders(estado: 'pendiente');

      if (mounted) {
        setState(() {
          _pendingOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar órdenes pendientes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los pedidos: $e')),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(int index, String newStatus) async {
    final orderId = _pendingOrders[index]['idpedido'];

    // Mostrar indicador de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      // Llamar al servicio para actualizar el estado en el servidor
      final success = await _ordersService.updateOrderStatus(
        orderId,
        newStatus,
      );

      // Cerrar diálogo de progreso
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success) {
        // Actualizar localmente si el servidor respondió bien
        if (mounted) {
          setState(() {
            if (newStatus != 'pendiente') {
              // Si ya no está pendiente, quitar de la lista
              _pendingOrders.removeAt(index);
            } else {
              // Actualizar el estado si sigue pendiente
              _pendingOrders[index]['estado'] = newStatus;
            }
          });
        }

        // Mostrar confirmación
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido #$orderId actualizado a: $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Mostrar error si el servidor no actualizó
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el pedido en el servidor'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de progreso
      if (mounted) {
        Navigator.of(context).pop();
      }

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
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
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFF3ea69b),
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 70.0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.white, width: 1.5),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
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
          // Botón para actualizar la lista
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingOrders,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
              : _pendingOrders.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay órdenes pendientes',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Todas las órdenes han sido procesadas',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                      onPressed: _loadPendingOrders,
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _pendingOrders.length,
                itemBuilder: (context, index) {
                  final order = _pendingOrders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OrderDetailCard(
                      order: order,
                      isExpanded: true,
                      onTap: null,
                      onStatusChange:
                          (newStatus) => _updateOrderStatus(index, newStatus),
                    ),
                  );
                },
              ),
    );
  }
}
