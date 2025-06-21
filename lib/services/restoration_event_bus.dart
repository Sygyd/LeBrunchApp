import 'dart:async';

/// Bus de eventos global para notificar restauraciones de elementos eliminados
class RestorationEventBus {
  // Singleton
  static final RestorationEventBus _instance = RestorationEventBus._internal();
  factory RestorationEventBus() => _instance;
  RestorationEventBus._internal();

  // Stream controller para eventos de restauración
  final _restorationController = StreamController<RestorationEvent>.broadcast();

  // Stream para escuchar eventos
  Stream<RestorationEvent> get onRestoration => _restorationController.stream;

  // Método para emitir eventos de restauración
  void fireRestoration(RestorationEvent event) {
    print('🔄 RestorationEventBus: ${event.type} - ${event.data}');
    _restorationController.add(event);
  }

  // Método de conveniencia para restauración de plato
  void notifyDishRestored(String dishId, String dishName) {
    fireRestoration(
      RestorationEvent(
        RestorationEventType.dishRestored,
        data: {'id': dishId, 'name': dishName},
      ),
    );
  }

  // Método de conveniencia para restauración de usuario
  void notifyUserRestored(String userId, String userName) {
    fireRestoration(
      RestorationEvent(
        RestorationEventType.userRestored,
        data: {'id': userId, 'name': userName},
      ),
    );
  }

  // Método para notificar que se necesita actualizar todo el menú
  void notifyMenuUpdateNeeded() {
    fireRestoration(RestorationEvent(RestorationEventType.menuUpdateNeeded));
  }

  // Método para notificar que se necesita actualizar la lista de usuarios
  void notifyUsersUpdateNeeded() {
    fireRestoration(RestorationEvent(RestorationEventType.usersUpdateNeeded));
  }

  // Método para notificar múltiples restauraciones al salir de la pantalla
  void notifyBatchRestorationsCompleted(
    List<String> dishIds,
    List<String> userIds,
  ) {
    if (dishIds.isNotEmpty || userIds.isNotEmpty) {
      fireRestoration(
        RestorationEvent(
          RestorationEventType.batchRestorationsCompleted,
          data: {
            'restoredDishes': dishIds,
            'restoredUsers': userIds,
            'timestamp': DateTime.now().toIso8601String(),
          },
        ),
      );
    }
  }

  // Cerrar el controller cuando ya no se necesita
  void dispose() {
    _restorationController.close();
  }
}

/// Eventos de restauración
class RestorationEvent {
  final RestorationEventType type;
  final dynamic data;

  RestorationEvent(this.type, {this.data});

  @override
  String toString() => 'RestorationEvent(type: $type, data: $data)';
}

enum RestorationEventType {
  dishRestored, // Se restauró un plato específico
  userRestored, // Se restauró un usuario específico
  menuUpdateNeeded, // Se necesita actualizar el menú general
  usersUpdateNeeded, // Se necesita actualizar la lista de usuarios
  batchRestorationsCompleted, // Se completaron múltiples restauraciones
}
