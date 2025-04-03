import 'package:flutter/material.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
