import 'package:flutter/material.dart';
import '../Widgets/shared_home_screen.dart';

class CookHomeScreen extends StatelessWidget {
  final String userName;
  final Function(int)? onNavigate;

  const CookHomeScreen({super.key, required this.userName, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SharedHomeScreen(
      userName: userName,
      onNavigate: onNavigate,
      role: 'cook',
      primaryIcon: Icons.restaurant,
      roleTitle: 'Cocinero',
    );
  }
}
