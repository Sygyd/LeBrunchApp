import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../Providers/le_cart_provider.dart';
import '../../Providers/auth_provider.dart';
import '../../models/cart_item.dart';
import '../../theme/theme.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    LeCartProvider? cartProvider;

    // Intentar acceder al provider de manera segura
    try {
      cartProvider = Provider.of<LeCartProvider>(context);
    } catch (e) {
      debugPrint('Error al acceder al CartProvider: $e');
    }

    // Si no podemos acceder al provider, mostrar pantalla de error
    if (cartProvider == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Carrito')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo cargar el carrito',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  );
                },
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    // Si tenemos acceso al provider, mostrar la pantalla normal
    final nonNullCartProvider = cartProvider; // Crear referencia no nula

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi Carrito',
          style: TextStyle(fontFamily: 'LightHouse'),
        ),
        actions: [
          if (!nonNullCartProvider.isEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed:
                  () => _showClearCartDialog(context, nonNullCartProvider),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                nonNullCartProvider.items.isEmpty
                    ? _buildEmptyCart(context, theme)
                    : _buildCartItems(context, nonNullCartProvider, theme),
          ),
          if (nonNullCartProvider.items.isNotEmpty)
            _buildCheckoutSection(context, nonNullCartProvider, theme),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Tu carrito está vacío',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'LightHouse',
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Añade algunos platos deliciosos',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'MADE TOMMY',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/client_menu'),
            icon: const Icon(Icons.restaurant_menu),
            label: Text(
              'Ver Menú',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'MADE TOMMY',
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItems(
    BuildContext context,
    LeCartProvider cartProvider,
    ThemeData theme,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cartProvider.items.length,
      itemBuilder:
          (ctx, index) => _buildCartItem(ctx, cartProvider.items[index], theme),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(
                        Icons.fastfood,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'LightHouse',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'MADE TOMMY',
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed:
                      () => _updateItemQuantity(
                        context,
                        item.id,
                        item.quantity - 1,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.quantity.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'MADE TOMMY',
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed:
                      () => _updateItemQuantity(
                        context,
                        item.id,
                        item.quantity + 1,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection(
    BuildContext context,
    LeCartProvider cartProvider,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total:',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'LightHouse',
                ),
              ),
              Text(
                '\$${cartProvider.getTotalPrice().toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFamily: 'MADE TOMMY',
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _confirmOrder(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Confirmar Pedido',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'LightHouse',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateItemQuantity(BuildContext context, String id, int newQuantity) {
    final cartProvider = Provider.of<LeCartProvider>(context, listen: false);
    if (newQuantity <= 0) {
      _showRemoveItemDialog(context, id, cartProvider);
    } else {
      cartProvider.updateItemQuantity(id, newQuantity);
    }
  }

  Future<void> _showRemoveItemDialog(
    BuildContext context,
    String itemId,
    LeCartProvider cartProvider,
  ) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Eliminar ítem',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'LightHouse',
              ),
            ),
            content: Text(
              '¿Estás seguro de que deseas eliminar este ítem?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'MADE TOMMY',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Eliminar',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      cartProvider.removeItem(itemId);
    }
  }

  Future<void> _showClearCartDialog(
    BuildContext context,
    LeCartProvider cartProvider,
  ) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Vaciar carrito',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'LightHouse',
              ),
            ),
            content: Text(
              '¿Estás seguro de que deseas vaciar tu carrito?',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'MADE TOMMY',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Vaciar',
                  style: TextStyle(
                    fontFamily: 'MADE TOMMY',
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      cartProvider.clearCart();
    }
  }

  Future<void> _confirmOrder(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<LeCartProvider>(context, listen: false);
    final theme = Theme.of(context);

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.121:3000/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authProvider.token}',
        },
        body: jsonEncode({
          'items': cartProvider.items.map((item) => item.toJson()).toList(),
        }),
      );

      if (!context.mounted) return;

      if (response.statusCode == 200) {
        cartProvider.clearCart();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pedido confirmado con éxito',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'MADE TOMMY',
              ),
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/client_home',
          (route) => false,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: 'MADE TOMMY',
            ),
          ),
          backgroundColor: theme.colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
