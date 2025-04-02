import 'package:flutter/material.dart';
import '/UI_Screens/Widgets/custom_scaffold.dart';
import '/theme/theme.dart';

class ClientHomeScreen extends StatelessWidget {
  final String userName;

  const ClientHomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScaffold(
      showAppBar: true,
      showTitle: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de bienvenida
            Text(
              '¡Hola, $userName!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFamily: 'LightHouse',
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Qué deseas ordenar hoy?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'MADE TOMMY',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Sección de destacados
            Text(
              'Recomendaciones del Chef',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'LightHouse',
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFeaturedItem(
                    context,
                    'Pancake Especial',
                    '\$12.99',
                    'assets/images/pancake.jpg',
                  ),
                  const SizedBox(width: 16),
                  _buildFeaturedItem(
                    context,
                    'Brunch Completo',
                    '\$18.50',
                    'assets/images/brunch.jpg',
                  ),
                  const SizedBox(width: 16),
                  _buildFeaturedItem(
                    context,
                    'Tostadas Francesas',
                    '\$10.99',
                    'assets/images/french_toast.jpg',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Acciones rápidas
            Text(
              'Acciones Rápidas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: 'LightHouse',
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildActionCard(
                  context,
                  Icons.menu,
                  'Ver Menú',
                  () => Navigator.pushNamed(context, '/client_menu'),
                ),
                _buildActionCard(
                  context,
                  Icons.chat,
                  'Chat de Ayuda',
                  () => Navigator.pushNamed(context, '/chat'),
                ),
                _buildActionCard(
                  context,
                  Icons.history,
                  'Mis Pedidos',
                  () {}, // Navegar a historial
                ),
                _buildActionCard(
                  context,
                  Icons.star,
                  'Favoritos',
                  () {}, // Navegar a favoritos
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedItem(
    BuildContext context,
    String name,
    String price,
    String imagePath,
  ) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 160,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Image.asset(
                imagePath,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      height: 120,
                      child: Icon(
                        Icons.fastfood,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'LightHouse',
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    price,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'MADE TOMMY',
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'MADE TOMMY',
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
