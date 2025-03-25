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
  final List<String> _selectedCategories =
      []; // Lista de categorías seleccionadas
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
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category); // Desactivar la categoría
      } else {
        _selectedCategories.add(category); // Activar la categoría
      }
    });
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
    // Mostrar un diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.pop(context, false), // No cerrar sesión
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Cerrar sesión
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    // Si el usuario confirma el cierre de sesión
    if (confirm == true) {
      try {
        // Llamar al backend para cerrar sesión
        final response = await http.post(
          Uri.parse('http://192.168.1.121:3000/logout'),
          headers: {"Content-Type": "application/json"},
        );

        if (response.statusCode == 200) {
          // Limpiar el estado local (por ejemplo, eliminar el token de autenticación)
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token'); // Elimina el token almacenado

          // Redirigir al usuario a la pantalla de bienvenida
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            );
          }
        } else {
          // Mostrar un mensaje de error si el cierre de sesión falla
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error al cerrar sesión")),
            );
          }
        }
      } catch (e) {
        // Manejar errores de conexión
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: widget.getUserRole(), // Obtener el rol del usuario
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          ); // Muestra un indicador de carga
        }

        final userRole = snapshot.data;

        return Material(
          child: Column(
            children: [
              AppBar(
                title: const Text('Menú'),
                automaticallyImplyLeading: false,
                actions: [
                  if (userRole ==
                      0) // Solo muestra el botón de agregar si es admin
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _openAddDishModal,
                    ),
                  if (userRole ==
                      0) // Solo muestra el botón de cerrar sesión si es admin
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: _logout,
                    ),
                ],
              ),
              custom.SearchBar(controller: _searchController),
              CategoryCarousel(
                categories: _categories,
                selectedCategories: _selectedCategories,
                toggleCategory: _toggleCategory,
              ),
              Expanded(child: _buildDishList(userRole)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDishList(int? userRole) {
    final filteredDishes =
        _dishes.where((dish) {
          final nameMatch = dish['nombre'].toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );

          // Si no hay categorías seleccionadas o están todas seleccionadas, mostrar todos los platos
          final categoryMatch =
              _selectedCategories.isEmpty ||
              _selectedCategories.contains(dish['categoria']);

          return nameMatch && categoryMatch;
        }).toList();

    return ListView.builder(
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
