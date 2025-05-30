import 'package:flutter/material.dart';
import 'ChatScreen.dart';
import '../Widgets/background_scaffold.dart';
import '../Widgets/recommendations_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClientHomeScreen extends StatelessWidget {
  final String userName;
  final String userCedula;
  final Function(int)? onNavigate;

  const ClientHomeScreen({
    super.key,
    required this.userName,
    this.userCedula = '',
    this.onNavigate,
  });

  Future<int?> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('user_id');
    } catch (e) {
      print('Error al obtener ID del usuario: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BackgroundScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado con título del restaurante
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0, top: 8.0),
                  child: Center(
                    child: Image.asset(
                      'assets/logos/logo_lebrunch.png',
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error al cargar logo: $error');
                        // Mostrar texto como fallback en caso de error
                        return Text(
                          'Le Brunch',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontFamily: 'LightHouse',
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Eliminamos la bienvenida que ya está en el AppBar
                // y mostramos solo información adicional como la cédula
                if (userCedula.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: theme.colorScheme.primary,
                          child: Icon(
                            Icons.person,
                            size: 24,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'CI: $userCedula',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Añadir tarjeta de Brunchy
                _buildBrunchyCard(context, theme),

                const SizedBox(height: 24),

                // Widget de recomendaciones personalizadas
                FutureBuilder<int?>(
                  future: _getCurrentUserId(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return Column(
                        children: [
                          RecommendationsWidget(clientId: snapshot.data!),
                          const SizedBox(height: 24),
                        ],
                      );
                    } else {
                      // Si no hay usuario logueado, no mostrar recomendaciones
                      return const SizedBox(height: 8);
                    }
                  },
                ),

                // Sección de promociones
                Text(
                  'Promociones del día',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFamily: 'MADE TOMMY',
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 16),

                // Tarjeta de promoción
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildPromoImage(theme),
                  ),
                ),

                const SizedBox(height: 24),

                // Resto del contenido...
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tarjeta para Brunchy
  Widget _buildBrunchyCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          // Navegar a la pantalla de chat
          if (onNavigate != null) {
            // El índice 2 corresponde a la pestaña de Chat en la barra de navegación del cliente
            onNavigate!(2);
            print('🎯 Navegando a ChatScreen usando onNavigate con índice 2');
          } else {
            // Fallback: navegar directamente si no hay callback de navegación
            print('⚠️ onNavigate no disponible, usando navegación directa');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatScreen()),
            );
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                radius: 24,
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Hola! Soy Brunchy',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'LightHouse',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu mesero virtual para atenderte',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontFamily: 'MADE TOMMY',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Chatear',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método para construir la imagen de promoción con manejo de errores
  Widget _buildPromoImage(ThemeData theme) {
    return Image.asset(
      'assets/images/promo.jpg',
      fit: BoxFit.cover,
      height: 180,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        print('Error al cargar imagen de promoción: $error');
        // Mostrar un contenedor decorativo en caso de error
        return Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.7),
                theme.colorScheme.primary,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_offer,
                  size: 50,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  '¡Ofertas Especiales!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consulta nuestras promociones diarias',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
