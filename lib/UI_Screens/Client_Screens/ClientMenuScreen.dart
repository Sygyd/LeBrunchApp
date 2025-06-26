import 'package:flutter/material.dart';
import '../Shared/shared_menu_view.dart';
import '/UI_Screens/Widgets/background_scaffold.dart';
import '../../services/client_notification_service.dart';

class ClientMenuScreen extends StatefulWidget {
  const ClientMenuScreen({super.key});

  @override
  State<ClientMenuScreen> createState() => _ClientMenuScreenState();
}

class _ClientMenuScreenState extends State<ClientMenuScreen>
    with AutomaticKeepAliveClientMixin {
  final ClientNotificationService _notificationService =
      ClientNotificationService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 🆕 NUEVO: Inicializar servicio de notificaciones
    _notificationService.initialize(context);
    // 🆕 NUEVO: Actualizar contexto para notificaciones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.updateContext(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 🆕 NUEVO: Actualizar contexto del servicio de notificaciones
    _notificationService.updateContext(context);

    final theme = Theme.of(context);

    return BackgroundScaffold(
      body: SafeArea(
        minimum: const EdgeInsets.only(top: 0),
        // Usar directamente el widget MenuView sin la barra superior
        child: MenuView(
          userRole: 1, // Rol de cliente
        ),
      ),
    );
  }
}
