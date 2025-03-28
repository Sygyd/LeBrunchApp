import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CategoryCarousel extends StatelessWidget {
  final List<Map<String, String>> categories;
  final List<String> selectedCategories;
  final Function(String) toggleCategory;

  const CategoryCarousel({
    super.key,
    required this.categories,
    required this.selectedCategories,
    required this.toggleCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 110, // Altura ligeramente mayor para mejor visualización
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategories.contains(category['name']);

          return GestureDetector(
            onTap: () => toggleCategory(category['name']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 80, // Ancho fijo para consistencia
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color:
                    isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceVariant,
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: category['image']!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder:
                          (_, __) => Container(
                            color: theme.colorScheme.surfaceVariant,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      errorWidget:
                          (_, __, ___) => Icon(
                            Icons.fastfood,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                      fadeInDuration: const Duration(
                        milliseconds: 300,
                      ), // Animación suave
                      fadeInCurve: Curves.easeInOut,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category['name']!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color:
                          isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
