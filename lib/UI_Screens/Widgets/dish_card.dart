import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DishCard extends StatelessWidget {
  final Map<String, dynamic> dish;
  final int? userRole;
  final Function(Map<String, dynamic>) editDish;
  final Function(String) deleteDish;

  const DishCard({
    Key? key,
    required this.dish,
    required this.userRole,
    required this.editDish,
    required this.deleteDish,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price =
        dish['precio'] != null
            ? double.tryParse(dish['precio'].toString()) ?? 0.0
            : 0.0;

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading:
            dish['imagen_url'] != null && dish['imagen_url'].isNotEmpty
                ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: dish['imagen_url'],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Icon(
                          Icons.fastfood,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
                : Icon(
                  Icons.image_not_supported,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        title: Text(
          dish['nombre'] ?? 'Sin nombre',
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'LightHouse', // Lighthouse para títulos
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingredientes: ${dish['ingredientes'] ?? 'No especificados'}',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '\$${price.toStringAsFixed(2)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'MADE TOMMY', // MADE TOMMY para precios
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        trailing:
            userRole == 0
                ? Row(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                      onPressed: () => editDish(dish),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: theme.colorScheme.error),
                      onPressed: () => deleteDish(dish['idplato'].toString()),
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
                ),
      ),
    );
  }
}
