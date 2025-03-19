import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/Api_services/menu/get_dishes_service.dart'; // Importa el servicio correcto
import '/Api_services/menu/add_dish_service.dart'; // Importa el servicio para eliminar
import 'AddDishScreen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú')),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryCarousel(),
          Expanded(child: _buildDishList()),
          _buildAddButton(),
        ],
      ),
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
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category['name']),
            child: Container(
              margin: const EdgeInsets.all(8),
              width: 120,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(category['image']!),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.circular(10),
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

  Widget _buildDishList() {
    final filteredDishes =
        _dishes.where((dish) {
          final nameMatch = dish['nombre'].toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
          final categoryMatch =
              _selectedCategory == null ||
              dish['categoria'] == _selectedCategory;
          return nameMatch && categoryMatch;
        }).toList();

    return ListView.builder(
      itemCount: filteredDishes.length,
      itemBuilder: (context, index) {
        final dish = filteredDishes[index];
        return _buildDishCard(dish);
      },
    );
  }

  Widget _buildDishCard(Map<String, dynamic> dish) {
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
        trailing: Row(
          mainAxisSize:
              MainAxisSize
                  .min, // Asegura que el Row ocupe solo el espacio necesario
          children: [
            Icon(
              (dish['disponibilidad'] ?? false)
                  ? Icons.check_circle
                  : Icons.cancel,
              color:
                  (dish['disponibilidad'] ?? false) ? Colors.green : Colors.red,
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
        ),
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
