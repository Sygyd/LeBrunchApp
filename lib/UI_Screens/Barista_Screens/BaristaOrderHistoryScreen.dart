import 'package:flutter/material.dart';
import '../Widgets/shared_order_history_screen.dart';

class BaristaOrderHistoryScreen extends StatelessWidget {
  const BaristaOrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SharedOrderHistoryScreen(
      title: 'Historial de Pedidos',
      isAdminView: false,
      showFilters: true,
      showDatePicker: true,
      showTotal: false,
      hideAppBar: true,
      role: 'barista',
    );
  }
}
