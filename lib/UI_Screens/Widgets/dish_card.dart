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
                      onPressed: () => editDish(dish),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
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
                ), // Oculta las opciones si no es admin
      ),
    );
  }
}
