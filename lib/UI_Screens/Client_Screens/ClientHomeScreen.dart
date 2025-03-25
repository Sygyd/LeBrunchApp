import 'package:flutter/material.dart';

class ClientHomeScreen extends StatelessWidget {
  final String userName;

  const ClientHomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Bienvenido, $userName'));
  }
}
