import 'package:flutter/material.dart';
import '/theme/theme.dart';
import '/UI_Screens/Widgets/welcome.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Le Brunch App',
      theme: lightMode,
      home: WelcomeScreen(),
    );
  }
}
