import 'package:flutter/material.dart';
import '../../Api_services/cart_service.dart';
import '../../models/cart_item.dart';
import '../Widgets/cart_item_card.dart';
import '../Widgets/custom_modal.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();

  @override
  void initState() {
    super.initState();
    // Asegurarse de que el carrito se ha inicializado
    _refreshCart();
  }

  // Actualizar la vista cuando cambie el carrito
  void _refreshCart() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = _cartService.items;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mi Pedido',
          style: TextStyle(
            fontFamily: 'LightHouse',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              tooltip: 'Vaciar carrito',
              onPressed: _showClearCartConfirmation,
            ),
        ],
      ),
      body:
          cartItems.isEmpty
              ? _buildEmptyCart(theme)
              : _buildCartItemsList(cartItems, theme),
      bottomNavigationBar: cartItems.isEmpty ? null : _buildBottomBar(theme),
    );
  }

  // Mostrar carrito vacío
  Widget _buildEmptyCart(ThemeData theme) {
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
              // Navegar al menú
              Navigator.of(context).pop();
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

  // Construir lista de items en el carrito
  Widget _buildCartItemsList(List<CartItem> cartItems, ThemeData theme) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: cartItems.length,
      itemBuilder: (context, index) {
        final item = cartItems[index];
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

  // Construir barra inferior con total y botón de confirmar
  Widget _buildBottomBar(ThemeData theme) {
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
            // Resumen del pedido
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
            // Botón de confirmar
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

  // Diálogo de confirmación para eliminar un item
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

  // Diálogo de confirmación para vaciar carrito
  Future<void> _showClearCartConfirmation() async {
    final confirm = await CustomModal.showConfirmation(
      context: context,
      title: 'Vaciar carrito',
      message:
          '¿Estás seguro de que quieres eliminar todos los productos de tu pedido?',
      confirmText: 'Vaciar',
      cancelText: 'Cancelar',
      confirmColor: Theme.of(context).colorScheme.error,
    );

    if (confirm) {
      _cartService.clear();
      _refreshCart();
    }
  }

  // Confirmar pedido
  Future<void> _confirmOrder() async {
    // Aquí iría la lógica para confirmar el pedido
    // Por ahora solo mostramos un mensaje de éxito
    await CustomModal.showSuccess(
      context: context,
      title: '¡Pedido Confirmado!',
      message:
          'Tu pedido ha sido confirmado con éxito. Puedes seguir su estado en la sección de pedidos activos.',
      buttonText: 'Aceptar',
    );

    // Después de confirmar, limpiamos el carrito
    _cartService.clear();
    _refreshCart();
  }
}
