import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/menu_view.dart';
import '/UI_Screens/Widgets/background_scaffold.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  Future<int?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_rol'); // Devuelve el rol del usuario (0 o 1)
  }

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BackgroundScaffold(
      body: SafeArea(
        minimum: const EdgeInsets.only(top: 0),
        child: MenuView(
          userRole: 0, // Rol de administrador
          onRefresh: () {
            // Opcional: Acciones adicionales al refrescar
            setState(() {});
          },
        ),
      ),
    );
  }
}
