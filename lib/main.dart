import 'package:flutter/material.dart';
import '/theme/theme.dart';
import 'package:flutter/services.dart';
import '/UI_Screens/Widgets/routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((
    _,
  ) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Le Brunch App',
      theme: lightMode,
      initialRoute: '/splash',
      onGenerateRoute: AppRoutes.generateRoute,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: child,
        );
      },
    );
  }
}
