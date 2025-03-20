import 'package:flutter/material.dart';
import '/UI_Screens/Widgets/custom_bottom_navigation_bar.dart';

class ClientHomeScreen extends StatelessWidget {
  final String userName;

  const ClientHomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Text('Hola, $userName', style: const TextStyle(fontSize: 24)),
      ),
      bottomNavigationBar: const CustomBottomNavigationBar(userRole: 1),
    );
  }
}
