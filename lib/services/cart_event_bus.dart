import 'dart:async';

/// Bus de eventos global para sincronizar carrito entre diferentes pantallas
class CartEventBus {
  // Singleton
  static final CartEventBus _instance = CartEventBus._internal();
  factory CartEventBus() => _instance;
  CartEventBus._internal();

  // Stream controller para eventos del carrito
  final _cartUpdateController = StreamController<CartEvent>.broadcast();

  // Stream para escuchar eventos
  Stream<CartEvent> get onCartUpdate => _cartUpdateController.stream;

  // Método para emitir eventos
  void fireCartUpdate(CartEvent event) {
    // Agregar logs para el evento navToCartFromChat para depuración
    if (event.type == CartEventType.navToCartFromChat) {
      print('🔄 CartEventBus: Enviando evento de navegación Chat -> Cart');
    }

    _cartUpdateController.add(event);
  }

  // Cerramos el controller cuando ya no se necesita
  void dispose() {
    _cartUpdateController.close();
  }
}

/// Eventos del carrito
class CartEvent {
  final CartEventType type;
  final dynamic data;

  CartEvent(this.type, {this.data});

  @override
  String toString() => 'CartEvent(type: $type, data: $data)';
}

enum CartEventType {
  itemAdded,
  itemRemoved,
  itemUpdated,
  cartCleared,
  cartLoaded,
  forceRefresh,
  navToCartFromChat, // Evento especial para navegación desde Chat a Cart
}
