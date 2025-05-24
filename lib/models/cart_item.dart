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

  // Factory constructor para crear una instancia desde un JSON
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      name: json['name'] as String,
      price:
          (json['price'] as num)
              .toDouble(), // Asegurar que el precio sea double
      imageUrl:
          json['imageUrl'] as String? ?? '', // Permitir imageUrl nulo o vacío
      quantity: json['quantity'] as int,
      notes: json['notes'] as String?,
      // Si originalData no siempre está, proporcionar un fallback
      originalData: json['originalData'] as Map<String, dynamic>? ?? {},
    );
  }

  // Método para convertir la instancia a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'notes': notes,
      'originalData': originalData,
    };
  }

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
