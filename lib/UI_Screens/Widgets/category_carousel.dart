import 'package:flutter/material.dart';
import 'dart:math' as math;

class CategoryCarousel extends StatelessWidget {
  final List<Map<String, String>> categories;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryCarousel({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 120, // Altura aumentada para dar más espacio
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category['name'];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
            child: GestureDetector(
              onTap: () => onCategorySelected(category['name']!),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: isSelected ? 1 : 0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 1.0 + (value * 0.05),
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Color.lerp(
                          theme.colorScheme.surfaceVariant,
                          theme.colorScheme.primaryContainer,
                          value,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Color.lerp(
                                  theme.shadowColor.withOpacity(0.1),
                                  theme.colorScheme.primary.withOpacity(0.3),
                                  value,
                                )!,
                            blurRadius: 10 + (value * 5),
                            spreadRadius: value * 2,
                            offset: Offset(0, 4 - (value * 2)),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: 4),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Fondo circular animado
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.lerp(
                                    Colors.transparent,
                                    theme.colorScheme.primary.withOpacity(0.1),
                                    value,
                                  ),
                                ),
                              ),
                              // Imagen con efecto de rotación sutil
                              Transform.rotate(
                                angle: isSelected ? math.pi * 2 * 0.02 : 0,
                                child: Hero(
                                  tag: 'category_${category['name']}',
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.2,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Image.asset(
                                        category['image']!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Icon(
                                              Icons.fastfood,
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                              size: 28,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Indicador de selección
                              if (isSelected)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Texto con animación de color
                          Text(
                            category['name']!,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Color.lerp(
                                theme.colorScheme.onSurfaceVariant,
                                theme.colorScheme.primary,
                                value,
                              ),
                              fontWeight: FontWeight.lerp(
                                FontWeight.normal,
                                FontWeight.bold,
                                value,
                              ),
                              fontSize: 12 + (value * 1),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
