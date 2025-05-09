import 'package:flutter/material.dart';
import '../Widgets/shared_home_screen.dart';

class BaristaHomeScreen extends StatelessWidget {
  final String userName;
  final Function(int)? onNavigate;

  const BaristaHomeScreen({super.key, required this.userName, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SharedHomeScreen(
      userName: userName,
      onNavigate: onNavigate,
      role: 'barista',
      primaryIcon: Icons.coffee,
      roleTitle: 'Barista',
    );
  }
}
