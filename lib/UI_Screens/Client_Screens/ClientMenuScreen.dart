import 'package:flutter/material.dart';
import '/Api_services/menu/get_dishes_service.dart';
import '/UI_Screens/Widgets/search_bar.dart' as custom;
import '/UI_Screens/Widgets/category_carousel.dart';
import '/UI_Screens/Widgets/dish_card.dart';

class ClientMenuScreen extends StatefulWidget {
  const ClientMenuScreen({super.key});

  @override
  State<ClientMenuScreen> createState() => _ClientMenuScreenState();
}

class _ClientMenuScreenState extends State<ClientMenuScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<String>> _selectedCategories = ValueNotifier([]);
  List<Map<String, dynamic>> _dishes = [];
  String? _expandedDishId;

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

  Future<void> _fetchDishes() async {
    try {
      final data = await GetDishesService().getDishes();
      if (mounted) {
        setState(() {
          _dishes = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar menú: $e')));
      }
    }
  }

  // Método para manejar la selección de categorías
  void _toggleCategory(String category) {
    final newCategories = List<String>.from(_selectedCategories.value);
    if (newCategories.contains(category)) {
      newCategories.remove(category);
    } else {
      newCategories.add(category);
    }
    _selectedCategories.value = newCategories; // Actualiza el ValueNotifier
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        // Esto bloquea completamente el botón de retroceso
        return false;
      },
      child: Scaffold(
        body: SafeArea(
          minimum: const EdgeInsets.only(top: 0),
          child: Column(
            children: [
              const SizedBox(height: 4),

              // Barra de búsqueda
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 0.0,
                  bottom: 12.0,
                ),
                child: custom.SearchBar(controller: _searchController),
              ),

              // Carrusel de categorías
              ValueListenableBuilder<List<String>>(
                valueListenable: _selectedCategories,
                builder: (context, selectedCategories, child) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: CategoryCarousel(
                      categories: _categories,
                      selectedCategories: selectedCategories,
                      toggleCategory: _toggleCategory,
                    ),
                  );
                },
              ),

              // Lista de platos
              Expanded(
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: _selectedCategories,
                  builder: (context, selectedCategories, _) {
                    return _buildDishList(selectedCategories);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDishList(List<String> selectedCategories) {
    // Filtrar los platos según la búsqueda y las categorías seleccionadas
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

    if (filteredDishes.isEmpty) {
      return _buildEmptyState();
    }

    // Agrupar los platos por categoría
    final Map<String, List<Map<String, dynamic>>> dishesByCategory = {};

    // Primero, inicializar todas las categorías del carousel para mantener el orden
    for (var category in _categories) {
      dishesByCategory[category['name']!] = [];
    }

    // Añadir una categoría "Otros" para platos sin categoría reconocida
    dishesByCategory['Otros'] = [];

    // Agrupar los platos filtrados por categoría
    for (var dish in filteredDishes) {
      final category = dish['categoria']?.toString() ?? 'Otros';
      if (dishesByCategory.containsKey(category)) {
        dishesByCategory[category]!.add(dish);
      } else {
        dishesByCategory['Otros']!.add(dish);
      }
    }

    // Eliminar categorías vacías
    dishesByCategory.removeWhere((key, value) => value.isEmpty);

    // Si no hay categorías con platos después del filtrado
    if (dishesByCategory.isEmpty) {
      return _buildEmptyState();
    }

    // Usamos un widget que no obligue a reconstruir toda la vista
    return ListView.builder(
      key: ValueKey('dish-list-${selectedCategories.join('-')}'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 120),
      // Construir secciones para cada categoría
      itemCount: dishesByCategory.length,
      itemBuilder: (context, index) {
        // Obtener la categoría en el orden del carousel
        final categoryName = dishesByCategory.keys.toList()[index];
        final categoryDishes = dishesByCategory[categoryName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de categoría
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  // Buscar la imagen de la categoría en el carousel
                  _buildCategoryIcon(categoryName),
                  const SizedBox(width: 12),
                  Text(
                    categoryName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'LightHouse',
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Divider(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.3),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ),

            // Grid para platos de esta categoría
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _buildCategoryDishGrid(categoryDishes),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryDishGrid(List<Map<String, dynamic>> dishes) {
    // Definiendo tamaños apropiados para la cuadrícula
    final screenSize = MediaQuery.of(context).size;

    // Determinamos cuántas tarjetas por fila según el ancho de pantalla
    int crossAxisCount;
    if (screenSize.width < 600) {
      crossAxisCount = 2; // Móviles
    } else if (screenSize.width < 1024) {
      crossAxisCount = 3; // Tablets y pantallas medianas
    } else {
      crossAxisCount = 4; // Pantallas grandes
    }

    // Ajustamos el aspect ratio para que las tarjetas encajen perfectamente
    final childAspectRatio = 0.65; // Valor ajustado para evitar overflow

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 10, // Un poco más de espacio horizontal
        mainAxisSpacing: 16,
      ),
      itemCount: dishes.length,
      itemBuilder: (context, index) {
        // Pasamos userRole como 1 (cliente) para que no se muestren opciones de edición
        return DishCard(
          dish: dishes[index],
          userRole: 1, // Forzamos el rol de cliente
          initialExpanded: false,
          onToggleExpanded: (isExpanded) {
            setState(() {
              _expandedDishId =
                  isExpanded ? dishes[index]['idplato'].toString() : null;
            });
          },
        );
      },
    );
  }

  // Método para construir el ícono de la categoría
  Widget _buildCategoryIcon(String categoryName) {
    // Buscar la imagen de la categoría en el carousel
    final categoryData = _categories.firstWhere(
      (category) => category['name'] == categoryName,
      orElse: () => {'name': categoryName, 'image': 'assets/images/tablas.jpg'},
    );

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        image: DecorationImage(
          image: AssetImage(categoryData['image']!),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // Estado vacío cuando no hay platos que mostrar
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron platos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta con otra búsqueda o categoría',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              _selectedCategories.value = [];
              _fetchDishes();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Mostrar todo el menú'),
          ),
        ],
      ),
    );
  }
}
