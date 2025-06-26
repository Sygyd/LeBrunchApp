import 'dart:async';

/// Clase para gestionar las notificaciones de cambios de estado de pedidos
class OrderStatusService {
  /// Singleton para acceder desde cualquier parte de la aplicación
  static final OrderStatusService _instance = OrderStatusService._internal();
  factory OrderStatusService() => _instance;
  OrderStatusService._internal();

  /// StreamController para notificar cuando un pedido cambia de 'pendiente' a 'completado'
  /// 🆕 NUEVO: Ahora envía un mapa con orderId y mesa
  final _completedOrdersController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream al que se pueden suscribir widgets para recibir notificaciones
  /// Solo se emiten eventos cuando un pedido pasa de 'pendiente' a 'completado'
  /// 🆕 NUEVO: Ahora incluye información de mesa
  Stream<Map<String, dynamic>> get onOrderCompleted =>
      _completedOrdersController.stream;

  /// Notifica que un pedido ha sido completado
  /// 🆕 NUEVO: Ahora incluye información de mesa
  void notifyOrderCompleted(int orderId, {String? mesa, String? mensaje}) {
    print(
      '🔔 OrderStatusService: Notificando que el pedido #$orderId ha sido completado${mesa != null ? ' - $mesa' : ''}',
    );
    print(
      '🔔 OrderStatusService: Stream hasListener: ${_completedOrdersController.hasListener}',
    );
    print(
      '🔔 OrderStatusService: Stream isClosed: ${_completedOrdersController.isClosed}',
    );

    final notificationData = {
      'orderId': orderId,
      'mesa': mesa,
      'mensaje': mensaje ?? 'Pedido completado',
    };

    print(
      '🔔 OrderStatusService: Enviando notificationData: $notificationData',
    );
    _completedOrdersController.add(notificationData);
    print('🔔 OrderStatusService: Notificación enviada exitosamente');
  }

  /// Liberar recursos cuando ya no se necesiten
  void dispose() {
    _completedOrdersController.close();
  }
}
