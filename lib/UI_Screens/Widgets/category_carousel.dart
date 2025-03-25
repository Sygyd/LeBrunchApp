import 'package:flutter/material.dart';

class CategoryCarousel extends StatelessWidget {
  final List<Map<String, String>> categories;
  final List<String> selectedCategories;
  final Function(String) toggleCategory;

  const CategoryCarousel({
    Key? key,
    required this.categories,
    required this.selectedCategories,
    required this.toggleCategory,
  }) : super(key: key);

  bool _isCategoryActive(String category) {
    return selectedCategories.contains(category);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = _isCategoryActive(category['name']!);

          return GestureDetector(
            onTap: () => toggleCategory(category['name']!),
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
}
