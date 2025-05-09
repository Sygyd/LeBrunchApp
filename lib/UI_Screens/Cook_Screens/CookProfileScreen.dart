import 'package:flutter/material.dart';
import '../Widgets/shared_profile_screen.dart';

class CookProfileScreen extends StatelessWidget {
  const CookProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SharedProfileScreen(
      role: 'cook',
      roleTitle: 'Cocinero',
      roleEspecialidad: 'Alimentos y Bebidas',
      defaultInitial: 'C',
      roleIcon: Icons.restaurant,
    );
  }
}
