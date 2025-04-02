import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme.dart';
import 'package:flutter/services.dart';
import 'UI_Screens/Widgets/routes.dart';
import 'Providers/le_cart_provider.dart';
import 'Providers/auth_provider.dart';
import 'Providers/chat_provider.dart';

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => LeCartProvider()),
        ChangeNotifierProvider(create: (context) => ChatProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Le Brunch App',
        theme: lightMode,
        darkTheme: darkMode,
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
      ),
    );
  }
}
