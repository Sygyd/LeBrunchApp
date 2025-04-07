import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  List<CartItem> _items = [];
  bool _isInitialized = false;
  String? _userId;

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
      await loadCart();
      _isInitialized = true;
    } catch (e) {
      print('Error al inicializar el carrito: $e');
    }
  }

  // Establecer el ID de usuario actual
  void setUserId(String userId) async {
    if (_userId != userId) {
      // Si el usuario cambia, guardamos el carrito actual y cargamos el del nuevo usuario
      _userId = userId;
      await loadCart(); // Cargar el carrito del nuevo usuario
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
      saveCart();
      notifyListeners();
    }
  }

  // Actualizar las notas de un item
  void updateNotes(String id, String? notes) {
    final itemIndex = _items.indexWhere((item) => item.id == id);
    if (itemIndex >= 0) {
      _items[itemIndex] = _items[itemIndex].copyWith(notes: notes);
      saveCart();
      notifyListeners();
    }
  }

  // Remover item del carrito
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    saveCart();
    notifyListeners();
  }

  // Limpiar todo el carrito
  void clear() {
    _items.clear();
    saveCart();
    notifyListeners();
  }

  // Guardar el carrito en localStorage
  Future<void> saveCart() async {
    try {
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
    } catch (e) {
      print('Error al guardar el carrito: $e');
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

        notifyListeners();
      } else {
        // Si no hay datos para este usuario, iniciar con carrito vacío
        _items = [];
      }
    } catch (e) {
      print('Error al cargar el carrito: $e');
      // En caso de error, iniciar con carrito vacío
      _items = [];
    }
  }
}
