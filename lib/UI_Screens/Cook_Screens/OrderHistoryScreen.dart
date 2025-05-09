import 'package:flutter/material.dart';
import '../Widgets/shared_order_history_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SharedOrderHistoryScreen(
      title: 'Historial de Pedidos',
      isAdminView: false,
      showFilters: true,
      showDatePicker: true,
      showTotal: false,
      hideAppBar: true,
      role: 'cook',
    );
  }
}
