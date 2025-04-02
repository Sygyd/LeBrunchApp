import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Api_services/menu/get_dishes_service.dart';
import '../../UI_Screens/Widgets/category_carousel.dart';
import '../../UI_Screens/Widgets/custom_scaffold.dart';
import '../../UI_Screens/Widgets/dish_card.dart';
import '../../Providers/le_cart_provider.dart';
import '../../models/cart_item.dart';
import '../../theme/theme.dart';

class ClientMenuScreen extends StatefulWidget {
  const ClientMenuScreen({super.key});

  @override
  State<ClientMenuScreen> createState() => _ClientMenuScreenState();
}

class _ClientMenuScreenState extends State<ClientMenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<String>> _selectedCategories = ValueNotifier([]);
  List<Map<String, dynamic>> _dishes = [];
  bool _isLoading = true;

  final List<Map<String, String>> _categories = [
    {'name': 'Tablas', 'image': 'assets/images/tablas.jpg'},
    {'name': 'Panquecas', 'image': 'assets/images/panquecas.jpg'},
    {'name': 'Tostadas francesas', 'image': 'assets/images/tostadas.jpg'},
    {'name': 'Gofres', 'image': 'assets/images/gofres.jpg'},
    {'name': 'Omelettes', 'image': 'assets/images/omelettes.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDishes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _selectedCategories.dispose();
    super.dispose();
  }

  Future<void> _fetchDishes() async {
    try {
      final data = await GetDishesService().getDishes();
      if (mounted) {
        setState(() {
          _dishes = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar platos: $e',
              style: const TextStyle(fontFamily: 'MADE TOMMY'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleCategory(String category) {
    final newCategories = List<String>.from(_selectedCategories.value);
    if (newCategories.contains(category)) {
      newCategories.remove(category);
    } else {
      newCategories.add(category);
    }
    _selectedCategories.value = newCategories;
  }

  void _addToCart(BuildContext context, Map<String, dynamic> dish) {
    if (!dish['disponibilidad']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Este plato no está disponible en este momento',
            style: const TextStyle(fontFamily: 'MADE TOMMY'),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      final cartProvider = Provider.of<LeCartProvider>(context, listen: false);
      final price = double.tryParse(dish['precio'].toString()) ?? 0.0;

      cartProvider.addItem(
        CartItem(
          id: dish['idplato'].toString(),
          name: dish['nombre'],
          price: price,
          quantity: 1,
          imageUrl: dish['imagen_url'],
          category: dish['categoria'],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Plato agregado al carrito',
            style: const TextStyle(fontFamily: 'MADE TOMMY'),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al agregar al carrito: $e',
            style: const TextStyle(fontFamily: 'MADE TOMMY'),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CustomScaffold(
      showAppBar: true,
      showTitle: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar platos...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<List<String>>(
            valueListenable: _selectedCategories,
            builder: (context, selectedCategories, _) {
              return CategoryCarousel(
                categories: _categories,
                selectedCategories: selectedCategories,
                toggleCategory: _toggleCategory,
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ValueListenableBuilder<List<String>>(
                      valueListenable: _selectedCategories,
                      builder: (context, selectedCategories, _) {
                        return _buildDishList(selectedCategories, theme);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishList(List<String> selectedCategories, ThemeData theme) {
    final filteredDishes =
        _dishes.where((dish) {
          final nameMatch = dish['nombre'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
          final categoryMatch =
              selectedCategories.isEmpty ||
              selectedCategories.contains(dish['categoria']);
          return nameMatch && categoryMatch;
        }).toList();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child:
          filteredDishes.isEmpty
              ? _buildEmptyState(theme)
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredDishes.length,
                itemBuilder: (context, index) {
                  final dish = filteredDishes[index];
                  return DishCard(
                    dish: dish,
                    userRole: 1, // Cliente
                    editDish: (_) {}, // Función vacía para clientes
                    deleteDish: (_) {}, // Función vacía para clientes
                    onAddToCart: () => _addToCart(context, dish),
                  );
                },
              ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron platos',
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'LightHouse',
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
