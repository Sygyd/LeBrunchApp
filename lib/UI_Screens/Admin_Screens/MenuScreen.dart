import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/get_dishes_service.dart';
import '/Api_services/menu/add_dish_service.dart';
import 'AddDishScreen.dart';
import '/UI_Screens/Widgets/welcome.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/UI_Screens/Widgets/custom_bottom_navigation_bar.dart';

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
  List<String> _selectedCategories = []; // Lista de categorías seleccionadas
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
      setState(() {
        _dishes = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar platos: $e')));
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

  // Método para verificar si una categoría está activa
  bool _isCategoryActive(String category) {
    return _selectedCategories.contains(category);
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plato eliminado exitosamente')),
          );
          _fetchDishes(); // Actualizar la lista de platos
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar plato: $e')));
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
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          );
        } else {
          // Mostrar un mensaje de error si el cierre de sesión falla
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error al cerrar sesión")),
          );
        }
      } catch (e) {
        // Manejar errores de conexión
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: widget.getUserRole(), // Obtener el rol del usuario
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(); // Muestra un indicador de carga
        }

        final userRole = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Menú'),
            automaticallyImplyLeading: false,
            actions: [
              if (userRole ==
                  0) // Solo muestra el botón de cerrar sesión si es admin
                IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
            ],
          ),
          body: Column(
            children: [
              _buildSearchBar(),
              _buildCategoryCarousel(),
              Expanded(child: _buildDishList(userRole)),
            ],
          ),
          floatingActionButton:
              userRole ==
                      0 // Solo muestra el botón de agregar si es admin
                  ? FloatingActionButton(
                    onPressed: _openAddDishModal,
                    child: const Icon(Icons.add),
                  )
                  : null, // Oculta el botón si no es admin
          bottomNavigationBar: CustomBottomNavigationBar(
            userRole: userRole ?? 1,
          ), // Añadir la barra de navegación inferior
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: 'Buscar plato...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryCarousel() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isActive = _isCategoryActive(category['name']!);

          return GestureDetector(
            onTap: () => _toggleCategory(category['name']!),
            child: Container(
              margin: const EdgeInsets.all(8),
              width: 120,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(category['image']!),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(10),
                border:
                    isActive
                        ? Border.all(
                          color: Colors.teal,
                          width: 3,
                        ) // Borde si está activo
                        : null, // Sin borde si no está activo
              ),
              child: Center(
                child: Text(
                  category['name']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.black45,
                  ),
                ),
              ),
            ),
          );
        },
      ),
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
        return _buildDishCard(dish, userRole);
      },
    );
  }

  Widget _buildDishCard(Map<String, dynamic> dish, int? userRole) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading:
            dish['imagen_url'] != null && dish['imagen_url'].isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: dish['imagen_url'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                )
                : const Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                ),
        title: Text(dish['nombre'] ?? 'Sin nombre'),
        subtitle: Text('Precio: \$${dish['precio']?.toString() ?? '0.00'}'),
        trailing:
            userRole == 0
                ? Row(
                  mainAxisSize:
                      MainAxisSize
                          .min, // Asegura que el Row ocupe solo el espacio necesario
                  children: [
                    Icon(
                      (dish['disponibilidad'] ?? false)
                          ? Icons.check_circle
                          : Icons.cancel,
                      color:
                          (dish['disponibilidad'] ?? false)
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(width: 8), // Espacio entre los iconos
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editDish(dish),
                    ),
                    //const SizedBox(width: 8), // Espacio entre los iconos
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDish(dish['idplato'].toString()),
                    ),
                  ],
                )
                : Icon(
                  (dish['disponibilidad'] ?? false)
                      ? Icons.check_circle
                      : Icons.cancel,
                  color:
                      (dish['disponibilidad'] ?? false)
                          ? Colors.green
                          : Colors.red,
                ), // Oculta las opciones si no es admin
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton(
      onPressed: () => _openAddDishModal(),
      child: const Icon(Icons.add),
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
