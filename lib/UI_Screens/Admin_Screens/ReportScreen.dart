import 'package:flutter/material.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

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
