import 'package:flutter/material.dart';
import '../Widgets/shared_profile_screen.dart';

class BaristaProfileScreen extends StatelessWidget {
  const BaristaProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SharedProfileScreen(
      role: 'barista',
      roleTitle: 'Barista',
      roleEspecialidad: 'Café y Bebidas Especiales',
      defaultInitial: 'B',
      roleIcon: Icons.coffee,
    );
  }
}
