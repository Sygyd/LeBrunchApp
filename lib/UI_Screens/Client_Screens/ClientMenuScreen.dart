import 'package:flutter/material.dart';
import '../Shared/shared_menu_view.dart';
import '/UI_Screens/Widgets/background_scaffold.dart';

class ClientMenuScreen extends StatefulWidget {
  const ClientMenuScreen({super.key});

  @override
  State<ClientMenuScreen> createState() => _ClientMenuScreenState();
}

class _ClientMenuScreenState extends State<ClientMenuScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return WillPopScope(
      onWillPop: () async {
        // Esto bloquea completamente el botón de retroceso
        return false;
      },
      child: BackgroundScaffold(
        body: SafeArea(
          minimum: const EdgeInsets.only(top: 0),
          // Usar directamente el widget MenuView sin la barra superior
          child: MenuView(
            userRole: 1, // Rol de cliente
          ),
        ),
      ),
    );
  }
}
