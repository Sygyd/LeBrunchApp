import 'package:flutter/material.dart';

class ClientMenuScreen extends StatelessWidget {
  const ClientMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú')),
      body: const Center(child: Text('Pantalla de Menu')),
    );
  }
}
