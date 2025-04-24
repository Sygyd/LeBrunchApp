import 'package:flutter/material.dart';
import '/Api_services/menu/get_dishes_service.dart';
import '/Api_services/menu/add_dish_service.dart';
import './add_dish_modal.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/search_bar.dart' as custom;
import '/UI_Screens/Widgets/category_carousel.dart';
import '/UI_Screens/Widgets/dish_card.dart';
import 'dart:async';
import '/UI_Screens/Widgets/background_scaffold.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedCategory = '';
  List<Map<String, dynamic>> _filteredDishes = [];
  bool _isLoading = false;
  // Crear el FocusNode al declararlo para evitar problemas de inicialización
  final FocusNode _searchFocusNode = FocusNode();

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
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDishes() async {
    try {
      final data = await GetDishesService().getDishes();
      if (mounted) {
        setState(() {
          _dishes = data;
          _filteredDishes = data;
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
        // Obtener la dirección del servidor
        final prefs = await SharedPreferences.getInstance();
        final serverIp =
            prefs.getString('serverIp') ??
            dotenv.env['NODE_SERVER_IP'] ??
            'server'; // Cambiado para Docker
        final serverPort = dotenv.env['NODE_SERVER_PORT'] ?? '3000';
        final baseUrl = 'http://$serverIp:$serverPort';

        // 1. Llamar al endpoint de logout en el backend
        final response = await http.post(
          Uri.parse('$baseUrl/logout'),
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
    super.build(context);

    return BackgroundScaffold(
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _fetchDishes,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: custom.SearchBar(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                                _applyFilters();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Carrusel de categorías
                  ValueListenableBuilder<List<String>>(
                    valueListenable: _selectedCategories,
                    builder: (context, selectedCategories, child) {
                      return CategoryCarousel(
                        categories: _categories,
                        selectedCategory: _selectedCategory,
                        onCategorySelected: (category) {
                          setState(() {
                            if (_selectedCategory == category) {
                              _selectedCategory = '';
                            } else {
                              _selectedCategory = category;
                            }
                            _applyFilters();
                          });
                        },
                      );
                    },
                  ),
                  // Lista de platos
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _buildDishList(),
                  ),
                  // Espacio de 0 para pegarse a la barra
                  SizedBox(height: 0),
                ],
              ),
            ),
            // Botón de agregar plato optimizado
            Positioned(
              right: 20,
              bottom:
                  20, // Reducido para acercarse más a la barra de navegación
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  shape: BoxShape.circle,
                ),
                child: FloatingActionButton(
                  onPressed: () async {
                    // Mostrar el modal para agregar plato
                    final result = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (context) => AddDishModal(
                            onSuccess: () {
                              _fetchDishes();
                            },
                          ),
                    );

                    // Si se agregó un plato exitosamente, actualizar la lista
                    if (result == true) {
                      _fetchDishes();
                    }
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: const CircleBorder(),
                  elevation: 4.0,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilters() {
    final query = _searchQuery.toLowerCase();
    setState(() {
      _filteredDishes =
          _dishes.where((dish) {
            final nameMatch = dish['nombre'].toString().toLowerCase().contains(
              query,
            );
            final categoryMatch =
                _selectedCategory.isEmpty ||
                dish['categoria'] == _selectedCategory;
            return nameMatch && categoryMatch;
          }).toList();
    });
  }

  Widget _buildDishList() {
    // Filtrar los platos según la búsqueda y las categorías seleccionadas
    final filteredDishes =
        _dishes.where((dish) {
          final nameMatch = dish['nombre'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
          final categoryMatch =
              _selectedCategory.isEmpty ||
              dish['categoria'] == _selectedCategory;
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
      physics: const BouncingScrollPhysics(),
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
                      fontFamily: 'MADE TOMMY',
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
      crossAxisCount = 3; // Móviles - 3 tarjetas por fila
    } else if (screenSize.width < 1024) {
      crossAxisCount = 4; // Tablets y pantallas medianas
    } else {
      crossAxisCount = 5; // Pantallas grandes
    }

    // Ajustamos el aspect ratio para que las tarjetas encajen perfectamente
    final childAspectRatio =
        0.66; // Valor ajustado para tarjetas más proporcionales

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 6, // Menos espacio horizontal
        mainAxisSpacing: 10, // Menos espacio vertical
      ),
      itemCount: dishes.length,
      itemBuilder: (context, index) {
        return FutureBuilder<int?>(
          future: widget.getUserRole(),
          builder: (context, snapshot) {
            // Mientras se carga, usamos 0 por defecto
            final userRole = snapshot.data ?? 0;
            return DishCard(
              dish: dishes[index],
              userRole: userRole,
              initialExpanded:
                  _expandedDishId == dishes[index]['idplato'].toString(),
              onToggleExpanded: (isExpanded) {
                setState(() {
                  _expandedDishId =
                      isExpanded ? dishes[index]['idplato'].toString() : null;
                });
              },
              editDish: (dish) {
                // Mostrar el modal para editar el plato
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder:
                      (context) => AddDishModal(
                        onSuccess: () {
                          _fetchDishes();
                        },
                        dish: dish,
                      ),
                );
              },
              deleteDish: (id) => _deleteDish(id),
            );
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'MADE TOMMY',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta con otra búsqueda o categoría',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'MADE TOMMY',
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedCategory = '';
                _searchQuery = '';
                _filteredDishes = _dishes;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Mostrar todo el menú',
              style: TextStyle(fontFamily: 'MADE TOMMY'),
            ),
          ),
        ],
      ),
    );
  }
}
