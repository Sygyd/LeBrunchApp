import 'package:flutter/material.dart';
import 'ChatScreen.dart';

class ClientHomeScreen extends StatelessWidget {
  final String userName;
  final String userCedula;

  const ClientHomeScreen({
    super.key,
    required this.userName,
    this.userCedula = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bienvenida y avatar
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(
                    Icons.person,
                    size: 30,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Bienvenido!', style: theme.textTheme.titleLarge),
                    Text(
                      userName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (userCedula.isNotEmpty)
                      Text(
                        'CI: $userCedula',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Botón de chat
                _buildChatButton(context, theme),
              ],
            ),

            const SizedBox(height: 24),

            // Añadir tarjeta de soporte
            _buildSupportCard(context, theme),

            const SizedBox(height: 24),

            // Resto del contenido...
          ],
        ),
      ),
    );
  }

  // Botón flotante de chat
  Widget _buildChatButton(BuildContext context, ThemeData theme) {
    return IconButton.filled(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      },
      icon: const Icon(Icons.chat),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 2,
      ),
      tooltip: 'Chat con soporte',
    );
  }

  // Tarjeta para soporte
  Widget _buildSupportCard(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
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
                  Icons.support_agent,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Necesitas ayuda?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'LightHouse',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chatea con nuestro equipo de soporte',
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
                  'Chat',
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
}
