import 'package:flutter/material.dart';
import 'UI_Screens/Widgets/routes.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Le Brunch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3EA69B)),
        useMaterial3: true,
      ),
      initialRoute: '/splash',
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
