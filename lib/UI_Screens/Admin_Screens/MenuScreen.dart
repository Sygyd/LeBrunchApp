import 'package:flutter/material.dart';
//import '/Api_services/menu/get_dishes_service.dart';
import '/Api_services/menu/menu_service.dart';
import 'dart:convert';

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
    {'name': 'Tablas', 'image': 'assets/tablas.jpg'},
    {'name': 'Panquecas', 'image': 'assets/panquecas.jpg'},
    {'name': 'Tostadas francesas', 'image': 'assets/tostadas.jpg'},
    {'name': 'Gofres', 'image': 'assets/gofres.jpg'},
    {'name': 'Omelettes', 'image': 'assets/omelettes.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchDishes();
  }

  Future<void> _fetchDishes() async {
    final data = await MenuService().getDishes();
    setState(() {
      _dishes = data;
    });
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
    final filteredDishes = _dishes.where((dish) {
      final nameMatch = dish['nombre']
          .toLowerCase()
          .contains(_searchController.text.toLowerCase());
      final categoryMatch = _selectedCategory == null ||
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
        leading: Image.network(dish['imagen_url'], width: 50, height: 50),
        title: Text(dish['nombre']),
        subtitle: Text('Precio: \$${dish['precio']}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              dish['disponibilidad'] ? Icons.check_circle : Icons.cancel,
              color: dish['disponibilidad'] ? Colors.green : Colors.red,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editDish(dish),
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
