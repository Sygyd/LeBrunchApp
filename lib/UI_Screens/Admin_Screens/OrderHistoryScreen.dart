import 'package:flutter/material.dart';
import '../Shared/shared_order_history_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  final String? startDate;
  final String? endDate;
  final String? estado;
  final String title;

  const OrderHistoryScreen({
    super.key,
    this.startDate,
    this.endDate,
    this.estado,
    this.title = 'Historial de Pedidos',
  });

  @override
  Widget build(BuildContext context) {
    return SharedOrderHistoryScreen(
      title: title,
      startDate: startDate,
      endDate: endDate,
      estado: estado,
      isAdminView: true,
      showFilters: true,
      showDatePicker: true,
      showTotal: true,
      role: 'admin',
    );
  }
}
