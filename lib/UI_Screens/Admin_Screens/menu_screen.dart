import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/get_dishes_service.dart';
import '/Api_services/menu/add_dish_service.dart';
import 'add_dish_screen.dart';
import '/UI_Screens/Widgets/welcome.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/custom_bottom_navigation_bar.dart';
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

class _MenuScreenState extends State<MenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<List<String>> _selectedCategories = ValueNotifier([]);
  List<Map<String, dynamic>> _dishes = [];

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
            // Añadimos un AppBar mínimo sin botón de retroceso
            appBar: AppBar(
              automaticallyImplyLeading: false, // Oculta el botón "Atrás"
              title: const Text('Menú'),
              actions: [
                if (userRole == 0)
                  IconButton(
                    icon: Icon(Icons.add, color: theme.colorScheme.primary),
                    onPressed: _openAddDishModal,
                  ),
              ],
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: custom.SearchBar(controller: _searchController),
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<List<String>>(
                  valueListenable: _selectedCategories,
                  builder: (context, categories, _) {
                    return CategoryCarousel(
                      categories: _categories,
                      selectedCategories: categories,
                      toggleCategory: _toggleCategory,
                    );
                  },
                ),
                const SizedBox(height: 16),
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
          );
        },
      ),
    );
  }

  Widget _buildDishList(int? userRole, List<String> selectedCategories) {
    final filteredDishes =
        _dishes.where((dish) {
          final nameMatch = dish['nombre'].toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
          final categoryMatch =
              selectedCategories.isEmpty ||
              selectedCategories.contains(dish['categoria']);
          return nameMatch && categoryMatch;
        }).toList();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child:
          filteredDishes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                key: ValueKey(selectedCategories),
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filteredDishes.length,
                itemBuilder: (context, index) {
                  final dish = filteredDishes[index];
                  return DishCard(
                    dish: dish,
                    userRole: userRole,
                    editDish: _editDish,
                    deleteDish: _deleteDish,
                  );
                },
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDishScreen()),
    ).then((value) {
      if (value == true) {
        _fetchDishes();
      }
    });
  }

  void _editDish(Map<String, dynamic> dish) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddDishScreen(dish: dish)),
    ).then((value) {
      if (value == true) {
        _fetchDishes();
      }
    });
  }
}
