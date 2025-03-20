import 'package:flutter/material.dart';

class RegistersScreen extends StatelessWidget {
  const RegistersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registros')),
      body: const Center(child: Text('Pantalla de Registros')),
    );
  }
}
