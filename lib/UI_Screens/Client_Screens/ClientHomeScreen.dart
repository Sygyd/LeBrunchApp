import 'package:flutter/material.dart';

class ClientHomeScreen extends StatelessWidget {
  final String userName;

  const ClientHomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Evita que el botón atrás funcione
        return false;
      },
      child: Scaffold(
        // ... tu contenido normal
      ),
    );
  }
}
