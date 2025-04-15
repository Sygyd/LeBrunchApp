import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isInitialized = false;
  String? _userId;
  // Almacena en memoria los carritos por usuario para evitar problemas de sincronización
  final Map<String, List<CartItem>> _userCarts = {};

  // Instancia singleton
  static final CartService _instance = CartService._internal();

  // Factory para obtener la instancia
  factory CartService() => _instance;

  // Constructor privado
  CartService._internal() {
    _initCart();
  }

  // Inicializar el carrito
  Future<void> _initCart() async {
    if (_isInitialized) return;

    try {
      // Intentar obtener el ID de usuario desde SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId != null) {
        // Si hay un ID de usuario, usarlo para cargar el carrito específico
        _userId = userId.toString();
        print('✅ CartService: Inicializado con usuario ID: $_userId');
      } else {
        // Si no hay ID de usuario, utilizar un ID de "invitado"
        _userId = 'guest';
        print('✅ CartService: Inicializado como invitado');
      }

      await loadCart();
      _isInitialized = true;
    } catch (e) {
      print('❌ Error al inicializar el carrito: $e');
      // En caso de error, inicializar con carrito vacío y ID de invitado
      _userId = 'guest';
      _items = [];
      _isInitialized = true;
    }
  }

  // Establecer el ID de usuario actual
  Future<void> setUserId(String userId) async {
    if (_userId != userId) {
      print('🔄 CartService: Cambiando de usuario: $_userId -> $userId');

      // Si hay un usuario anterior que no es "guest", guardar su carrito
      if (_userId != null && _userId != "guest") {
        _userCarts[_userId!] = List.from(_items);
        await saveCart(); // Guardar el carrito del usuario anterior
      }

      // Limpiar completamente el carrito actual ANTES de cambiar de usuario
      _items = [];

      // Cambiar al nuevo usuario
      _userId = userId;

      // Si es un invitado, siempre limpiar cualquier dato de invitado
      if (userId == "guest") {
        _userCarts[userId] = [];

        // Eliminar el carrito de invitado en SharedPreferences, si existe
        try {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.containsKey('cart_guest')) {
            await prefs.remove('cart_guest');
            print(
              '🧹 CartService: Carrito de invitado eliminado de SharedPreferences',
            );
          }
        } catch (e) {
          print('❌ Error al eliminar carrito de invitado: $e');
        }
      } else {
        // Cargar el carrito del nuevo usuario, primero desde memoria si existe
        if (_userCarts.containsKey(userId)) {
          print(
            '🛒 CartService: Cargando carrito de memoria para usuario: $userId',
          );
          _items = List.from(_userCarts[userId]!);
        } else {
          // Si no está en memoria, cargarlo desde SharedPreferences
          await loadCart();
        }
      }

      // Notificar a los listeners del cambio de carrito
      notifyListeners();
    }
  }

  // Obtener la clave de storage basada en el userId
  String get _storageKey {
    return _userId != null ? 'cart_$_userId' : 'cart';
  }

  // Obtener todos los items del carrito
  List<CartItem> get items => List.unmodifiable(_items);

  // Obtener cantidad total de items
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  // Obtener precio total del carrito
  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Verificar si un item ya está en el carrito
  bool isInCart(String itemId) {
    return _items.any((item) => item.id == itemId);
  }

  // Buscar un item por su ID
  CartItem? findById(String id) {
    try {
      return _items.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  // Agregar un item al carrito
  void addItem({
    required String id,
    required String name,
    required double price,
    required String imageUrl,
    required Map<String, dynamic> originalData,
    String? notes,
    int quantity = 1,
  }) {
    final existingItemIndex = _items.indexWhere((item) => item.id == id);

    if (existingItemIndex >= 0) {
      // Si el producto ya existe, actualizar cantidad
      _items[existingItemIndex] = _items[existingItemIndex].copyWith(
        quantity: _items[existingItemIndex].quantity + quantity,
        notes: notes ?? _items[existingItemIndex].notes,
      );
    } else {
      // Si es un producto nuevo, agregarlo
      _items.add(
        CartItem(
          id: id,
          name: name,
          price: price,
          imageUrl: imageUrl,
          quantity: quantity,
          notes: notes,
          originalData: originalData,
        ),
      );
    }

    // Actualizar la memoria caché
    if (_userId != null) {
      _userCarts[_userId!] = List.from(_items);
    }

    saveCart();
    notifyListeners();
  }

  // Actualizar la cantidad de un item
  void updateQuantity(String id, int quantity) {
    if (quantity <= 0) {
      removeItem(id);
      return;
    }

    final itemIndex = _items.indexWhere((item) => item.id == id);
    if (itemIndex >= 0) {
      _items[itemIndex] = _items[itemIndex].copyWith(quantity: quantity);

      // Actualizar la memoria caché
      if (_userId != null) {
        _userCarts[_userId!] = List.from(_items);
      }

      saveCart();
      notifyListeners();
    }
  }

  // Actualizar las notas de un item
  void updateNotes(String id, String? notes) {
    final itemIndex = _items.indexWhere((item) => item.id == id);
    if (itemIndex >= 0) {
      _items[itemIndex] = _items[itemIndex].copyWith(notes: notes);

      // Actualizar la memoria caché
      if (_userId != null) {
        _userCarts[_userId!] = List.from(_items);
      }

      saveCart();
      notifyListeners();
    }
  }

  // Remover item del carrito
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);

    // Actualizar la memoria caché
    if (_userId != null) {
      _userCarts[_userId!] = List.from(_items);
    }

    saveCart();
    notifyListeners();
  }

  // Limpiar todo el carrito
  void clear() {
    _items.clear();

    // Actualizar la memoria caché
    if (_userId != null) {
      _userCarts[_userId!] = [];
    }

    saveCart();
    notifyListeners();
  }

  // Guardar el carrito en localStorage
  Future<void> saveCart() async {
    try {
      if (_userId == null) return;

      final prefs = await SharedPreferences.getInstance();

      final cartData =
          _items
              .map(
                (item) => {
                  'id': item.id,
                  'name': item.name,
                  'price': item.price,
                  'imageUrl': item.imageUrl,
                  'quantity': item.quantity,
                  'notes': item.notes,
                  'originalData': item.originalData,
                },
              )
              .toList();

      await prefs.setString(_storageKey, jsonEncode(cartData));
      print('💾 CartService: Carrito guardado para usuario: $_userId');
    } catch (e) {
      print('❌ Error al guardar el carrito: $e');
    }
  }

  // Cargar el carrito desde localStorage
  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = prefs.getString(_storageKey);

      if (cartData != null && cartData.isNotEmpty) {
        final List<dynamic> decodedData = jsonDecode(cartData);

        _items =
            decodedData
                .map(
                  (item) => CartItem(
                    id: item['id'],
                    name: item['name'],
                    price: item['price'].toDouble(),
                    imageUrl: item['imageUrl'],
                    quantity: item['quantity'],
                    notes: item['notes'],
                    originalData: item['originalData'],
                  ),
                )
                .toList();

        // Actualizar la memoria caché
        if (_userId != null) {
          _userCarts[_userId!] = List.from(_items);
        }

        print(
          '📂 CartService: Carrito cargado para usuario: $_userId (${_items.length} items)',
        );
        notifyListeners();
      } else {
        // Si no hay datos para este usuario, iniciar con carrito vacío
        _items = [];
        if (_userId != null) {
          _userCarts[_userId!] = [];
        }
        print('📂 CartService: Carrito vacío para usuario: $_userId');
      }
    } catch (e) {
      print('❌ Error al cargar el carrito: $e');
      // En caso de error, iniciar con carrito vacío
      _items = [];
      if (_userId != null) {
        _userCarts[_userId!] = [];
      }
    }
  }

  // Limpiar todos los carritos (útil para debugging y cierre de sesión)
  Future<void> clearAllCarts() async {
    // Limpiar memoria caché
    _items = [];
    _userCarts.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList();
      int contadorEliminados = 0;

      // Eliminar específicamente las claves relacionadas con carritos
      for (final key in allKeys) {
        if (key.startsWith('cart_')) {
          await prefs.remove(key);
          contadorEliminados++;
        }
      }

      // Limpiar cualquier ID de pedido actual
      if (prefs.containsKey('current_order_id')) {
        await prefs.remove('current_order_id');
        print('🧹 ID de pedido actual eliminado');
      }

      // Marcar bandera para indicar que se ha limpiado el carrito en el cierre de sesión
      await prefs.setBool('cart_cleared_on_logout', true);

      print(
        '🧹 CartService: Se han eliminado $contadorEliminados carritos de SharedPreferences',
      );

      // Establecer usuario como invitado
      _userId = 'guest';

      notifyListeners();
    } catch (e) {
      print('❌ Error al limpiar todos los carritos: $e');
    }
  }

  // Reiniciar el servicio completo (para solucionar problemas de sincronización)
  Future<void> resetService() async {
    // Limpiar memoria caché
    _items = [];
    _userCarts.clear();

    try {
      // Obtener ID del usuario actual o establecer como invitado
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId != null) {
        _userId = userId.toString();
      } else {
        _userId = 'guest';
      }

      // Recargar el carrito para el usuario actual
      await loadCart();

      print('🔄 CartService: Servicio reiniciado para usuario: $_userId');
      notifyListeners();
    } catch (e) {
      print('❌ Error al reiniciar CartService: $e');
    }
  }
}
