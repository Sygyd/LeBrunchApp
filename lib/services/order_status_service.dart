import 'dart:async';

/// Clase para gestionar las notificaciones de cambios de estado de pedidos
class OrderStatusService {
  /// Singleton para acceder desde cualquier parte de la aplicación
  static final OrderStatusService _instance = OrderStatusService._internal();
  factory OrderStatusService() => _instance;
  OrderStatusService._internal();

  /// StreamController para notificar cuando un pedido cambia de 'pendiente' a 'completado'
  final _completedOrdersController = StreamController<int>.broadcast();

  /// Stream al que se pueden suscribir widgets para recibir notificaciones
  /// Solo se emiten eventos cuando un pedido pasa de 'pendiente' a 'completado'
  Stream<int> get onOrderCompleted => _completedOrdersController.stream;

  /// Notifica que un pedido ha sido completado
  void notifyOrderCompleted(int orderId) {
    print(
      '🔔 OrderStatusService: Notificando que el pedido #$orderId ha sido completado',
    );
    _completedOrdersController.add(orderId);
  }

  /// Liberar recursos cuando ya no se necesiten
  void dispose() {
    _completedOrdersController.close();
  }
}
