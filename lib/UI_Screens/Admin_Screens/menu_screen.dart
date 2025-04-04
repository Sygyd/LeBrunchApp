import 'package:flutter/material.dart';
import '/Api_services/menu/get_dishes_service.dart';
import '/Api_services/menu/add_dish_service.dart';
import 'add_dish_modal.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/search_bar.dart' as custom;
import '/UI_Screens/Widgets/category_carousel.dart';
import '/UI_Screens/Widgets/dish_card.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  Future<int?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_rol'); // Devuelve el rol del usuario (0 o 1)
  }

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<String>> _selectedCategories = ValueNotifier([]);
  List<Map<String, dynamic>> _dishes = [];
  int _selectedIndex = 0;
  // Guarda el ID del plato expandido actualmente (si existe)
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
        ).showSnackBar(SnackBar(content: Text('Error al cargar platos: $e')));
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

  Future<void> _deleteDish(String id) async {
    // Mostrar un diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Plato'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este plato?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    // Si el usuario confirma la eliminación
    if (confirm == true) {
      try {
        final addDishService = AddDishService();
        final isSuccess = await addDishService.deleteDish(id);

        if (isSuccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Plato eliminado exitosamente')),
            );
            _fetchDishes(); // Actualizar la lista de platos
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar plato: $e')),
          );
        }
      }
    }
  }

  void _logout() async {
    // Diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // 1. Llamar al endpoint de logout en el backend
        final response = await http.post(
          Uri.parse('http://192.168.1.121:3000/logout'),
          headers: {"Content-Type": "application/json"},
        );

        if (response.statusCode == 200) {
          // 2. Limpiar todos los datos locales de forma segura
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token'); // Token específico
          await prefs.remove('user_rol'); // Rol del usuario
          await prefs.remove('user_name'); // Nombre del usuario

          // 3. Redirección segura a WelcomeScreen
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (Route<dynamic> route) =>
                  false, // Elimina toda la pila de navegación
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Error al cerrar sesión en el servidor"),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error de conexión: ${e.toString()}")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        // Esto bloquea completamente el botón de retroceso
        return false;
      },
      child: FutureBuilder<int?>(
        future: widget.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          final userRole = snapshot.data;

          return Scaffold(
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
                        return _buildDishList(userRole, selectedCategories);
                      },
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton:
                userRole == 0
                    ? FloatingActionButton(
                      onPressed: _openAddDishModal,
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.add, size: 28),
                    )
                    : null,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }

  Widget _buildDishList(int? userRole, List<String> selectedCategories) {
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
              child: _buildCategoryDishGrid(categoryDishes, userRole),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryDishGrid(
    List<Map<String, dynamic>> dishes,
    int? userRole,
  ) {
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
    // basado en la altura de la imagen (140px) y el contenido
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
        return DishCard(
          dish: dishes[index],
          userRole: userRole,
          editDish: _editDish,
          deleteDish: _deleteDish,
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
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          categoryData['image']!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.restaurant,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

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
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _openAddDishModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddDishModal(onSuccess: _fetchDishes);
      },
    );
  }

  void _editDish(Map<String, dynamic> dish) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddDishModal(dish: dish, onSuccess: _fetchDishes);
      },
    );
  }
}
