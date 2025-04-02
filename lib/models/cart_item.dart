// models/cart_item.dart
class CartItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.quantity = 1,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'].toString(),
      name: json['name'],
      price: double.parse(json['price'].toString()),
      imageUrl: json['imageUrl'],
      category: json['category'],
      quantity: json['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'imageUrl': imageUrl,
    'category': category,
    'quantity': quantity,
  };

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? category,
    int? quantity,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
    );
  }
}
