import 'package:flutter/material.dart';
import '../../Api_services/cart_service.dart';
import '../../Api_services/gemini_service.dart';
import '../../models/cart_item.dart';
import '../Widgets/cart_item_card.dart';
import '../Widgets/custom_modal.dart';
import '../../Api_services/pedidos/create_order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartScreen extends StatefulWidget {
  final bool isEmbedded;
  final Function(int)? onTabChange;

  const CartScreen({super.key, this.isEmbedded = false, this.onTabChange});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final GeminiService _geminiService = GeminiService();
  List<CartItem> _cartItems = [];
  List<Map<String, dynamic>> _recommendedDishes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshCart();
  }

  Future<void> _refreshCart() async {
    setState(() {
      _isLoading = true;
    });

    // Obtener los items del carrito
    final items = _cartService.items;

    // Obtener recomendaciones si el carrito no está vacío
    List<Map<String, dynamic>> recommendations = [];
    if (items.isNotEmpty) {
      try {
        final prefs = await _geminiService.getUserPreferences();
        final menuItems = await _geminiService.fetchMenu();
        // Obtener el último plato pedido y los platos más frecuentes
        final lastOrderedDish = prefs['lastOrderedDish'];
        final dishCounts = prefs['dishCounts'] ?? {};

        if (lastOrderedDish != null || dishCounts.isNotEmpty) {
          recommendations = await _getRecommendedDishes(
            menuItems,
            lastOrderedDish,
            dishCounts,
          );
        }
      } catch (e) {
        print('Error al obtener recomendaciones: $e');
      }
    }

    setState(() {
      _cartItems = List.from(items);
      _recommendedDishes = recommendations;
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _getRecommendedDishes(
    List<dynamic> menuItems,
    String? lastOrderedDish,
    Map<String, dynamic> dishCounts,
  ) async {
    // Filtrar platos que ya están en el carrito
    final cartItemNames =
        _cartItems.map((item) => item.name.toLowerCase()).toSet();

    // Convertir dishCounts a una lista ordenada
    List<MapEntry<String, dynamic>> popularDishes = [];
    if (dishCounts.isNotEmpty) {
      popularDishes =
          dishCounts.entries.toList()
            ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    }

    // Lista de posibles recomendaciones
    List<Map<String, dynamic>> recommendations = [];

    // Añadir platos de la misma categoría que el último ordenado
    if (lastOrderedDish != null) {
      // Buscar la categoría del último plato
      final lastDishInfo = menuItems.firstWhere(
        (dish) =>
            dish['nombre']?.toLowerCase() == lastOrderedDish.toLowerCase(),
        orElse: () => null,
      );

      if (lastDishInfo != null && lastDishInfo['categoria'] != null) {
        final similarCategory =
            menuItems
                .where(
                  (dish) =>
                      dish['categoria'] == lastDishInfo['categoria'] &&
                      !cartItemNames.contains(dish['nombre']?.toLowerCase()),
                )
                .toList();

        // Añadir hasta 2 recomendaciones de la misma categoría
        if (similarCategory.isNotEmpty) {
          recommendations.addAll(
            similarCategory.take(2).map((dish) => dish as Map<String, dynamic>),
          );
        }
      }
    }

    // Añadir platos populares basados en el historial
    if (popularDishes.isNotEmpty) {
      for (var entry in popularDishes.take(3)) {
        final dishName = entry.key;
        final dishInfo = menuItems.firstWhere(
          (dish) => dish['nombre']?.toLowerCase() == dishName.toLowerCase(),
          orElse: () => null,
        );

        if (dishInfo != null &&
            !cartItemNames.contains(dishInfo['nombre']?.toLowerCase()) &&
            !recommendations.any(
              (rec) => rec['nombre'] == dishInfo['nombre'],
            )) {
          recommendations.add(dishInfo);
          if (recommendations.length >= 3) break;
        }
      }
    }

    // Si necesitamos más recomendaciones, añadir platos aleatorios
    if (recommendations.length < 3) {
      menuItems.shuffle();
      for (var dish in menuItems) {
        if (!cartItemNames.contains(dish['nombre']?.toLowerCase()) &&
            !recommendations.any((rec) => rec['nombre'] == dish['nombre'])) {
          recommendations.add(dish);
          if (recommendations.length >= 3) break;
        }
      }
    }

    return recommendations.take(3).toList();
  }

  void _addRecommendedDishToCart(Map<String, dynamic> dish) async {
    try {
      final name = dish['nombre'] as String;
      final price = double.parse(dish['precio'].toString());
      final imageUrl = dish['imagen_url'] as String?;
      final id =
          dish['idplato']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      // Usar los parámetros nombrados correctamente según el método en CartService
      _cartService.addItem(
        id: id,
        name: name,
        price: price,
        imageUrl: imageUrl ?? '',
        quantity: 1,
        originalData: dish,
      );

      // Actualizar preferencias del usuario
      await _geminiService.updateUserPreferences(name);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('¡$name añadido al carrito!')));

      _refreshCart();
    } catch (e) {
      print('Error al añadir plato recomendado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo añadir el plato al carrito.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      drawerEdgeDragWidth: MediaQuery.of(context).size.width,
      drawerEnableOpenDragGesture: true,
      body: WillPopScope(
        onWillPop: () async {
          if (widget.isEmbedded && widget.onTabChange != null) {
            widget.onTabChange!(0);
            return false;
          }
          return true;
        },
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              if (widget.isEmbedded && widget.onTabChange != null) {
                widget.onTabChange!(0);
              } else {
                Navigator.of(context).pop();
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/fondolb.jpg"),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child:
                        _cartItems.isEmpty
                            ? _buildEmptyCart()
                            : _buildCartList(),
                  ),
                  if (_recommendedDishes.isNotEmpty && _cartItems.isNotEmpty)
                    _buildRecommendations(),
                  if (_cartItems.isNotEmpty) _buildCheckoutSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Recomendaciones para ti',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedDishes.length,
              itemBuilder: (context, index) {
                final dish = _recommendedDishes[index];
                return GestureDetector(
                  onTap: () => _addRecommendedDishToCart(dish),
                  child: Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: Image.network(
                            dish['imagen_url'] ??
                                'https://via.placeholder.com/120',
                            height: 70,
                            width: 120,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => Container(
                                  height: 70,
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.restaurant,
                                    color: Colors.grey[600],
                                  ),
                                ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dish['nombre'] ?? 'Plato',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '\$${dish['precio'] ?? '0.00'}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'LightHouse',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega productos desde el menú o pide recomendaciones a Brunchy',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              if (widget.isEmbedded && widget.onTabChange != null) {
                widget.onTabChange!(1);
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Ver menú'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return CartItemCard(
          key: ValueKey(item.id),
          item: item,
          onIncrease: () {
            _cartService.updateQuantity(item.id, item.quantity + 1);
            _refreshCart();
          },
          onDecrease: () {
            if (item.quantity > 1) {
              _cartService.updateQuantity(item.id, item.quantity - 1);
            } else {
              _showRemoveItemConfirmation(item);
            }
            _refreshCart();
          },
          onRemove: () => _showRemoveItemConfirmation(item),
          onUpdateNotes: (notes) {
            _cartService.updateNotes(item.id, notes);
            _refreshCart();
          },
        );
      },
    );
  }

  Widget _buildCheckoutSection() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total (${_cartService.itemCount} items)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '\$${_cartService.totalAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmOrder,
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirmar Pedido'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRemoveItemConfirmation(CartItem item) async {
    final confirm = await CustomModal.showConfirmation(
      context: context,
      title: 'Eliminar ${item.name}',
      message:
          '¿Estás seguro de que quieres eliminar este producto de tu pedido?',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirm) {
      _cartService.removeItem(item.id);
      _refreshCart();
    }
  }

  Future<void> _confirmOrder() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (BuildContext dialogContext) =>
                const Center(child: CircularProgressIndicator()),
      );

      final cartItems = _cartService.items;

      if (cartItems.isEmpty) {
        if (context.mounted) {
          Navigator.of(context).pop();
          await CustomModal.showError(
            context: context,
            title: 'Carrito Vacío',
            message: 'No hay productos en el carrito para confirmar el pedido.',
            buttonText: 'Entendido',
          );
        }
        return;
      }

      final createOrderService = CreateOrderService();
      final result = await createOrderService.createOrder(cartItems);

      if (!context.mounted) return;

      Navigator.of(context).pop();

      if (result['success']) {
        final orderId = result['orderData']?['idpedido'];
        if (orderId != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('current_order_id', orderId);
          } catch (e) {
            print('Error al guardar el ID del pedido: $e');
          }
        }

        // Actualizar las preferencias del usuario con los platos ordenados
        try {
          final geminiService = GeminiService();
          for (var item in cartItems) {
            await geminiService.updateUserPreferences(item.name);
          }
          print('✅ Preferencias de usuario actualizadas correctamente');
        } catch (e) {
          print('❌ Error al actualizar preferencias de usuario: $e');
        }

        _cartService.clear();
        _refreshCart();

        if (context.mounted) {
          await CustomModal.showSuccess(
            context: context,
            title: '¡Pedido Confirmado!',
            message:
                'Tu pedido ${orderId != null ? "#$orderId" : ""} ha sido confirmado con éxito.',
            buttonText: 'Aceptar',
            onPressed: () {},
          );

          if (widget.isEmbedded && widget.onTabChange != null) {
            widget.onTabChange!(0);
          } else if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      } else {
        if (context.mounted) {
          await CustomModal.showError(
            context: context,
            title: 'Error al Confirmar Pedido',
            message: result['message'] ?? 'No se pudo crear el pedido',
            buttonText: 'Entendido',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();

        await CustomModal.showError(
          context: context,
          title: 'Error Inesperado',
          message: 'Ocurrió un error al procesar tu pedido: $e',
          buttonText: 'Entendido',
        );
      }
    }
  }

  Widget _buildLoadingScreen() {
    return const Center(child: CircularProgressIndicator());
  }
}
