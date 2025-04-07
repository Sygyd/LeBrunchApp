import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final int quantity;
  final String? notes;
  final Map<String, dynamic> originalData;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    this.notes,
    required this.originalData,
  });

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    int? quantity,
    String? notes,
    Map<String, dynamic>? originalData,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      originalData: originalData ?? this.originalData,
    );
  }

  double get totalPrice => price * quantity;

  @override
  String toString() {
    return 'CartItem(id: $id, name: $name, price: $price, quantity: $quantity, notes: $notes)';
  }
}
