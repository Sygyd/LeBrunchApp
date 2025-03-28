import 'package:flutter/material.dart';

class RegistersScreen extends StatelessWidget {
  const RegistersScreen({super.key});

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
