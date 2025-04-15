import 'package:flutter/material.dart';

/// Clase que proporciona métodos para mostrar modales personalizados
/// de información, error, éxito y confirmación.
class CustomModal {
  /// Muestra un modal de información
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'Aceptar',
    VoidCallback? onPressed,
  }) async {
    return _showCustomModal(
      context: context,
      title: title,
      message: message,
      icon: Icons.info_outline,
      iconColor: Theme.of(context).colorScheme.primary,
      buttonText: buttonText,
      onPressed: onPressed,
    );
  }

  /// Muestra un modal de error
  static Future<void> showError({
    required BuildContext context,
    String title = 'Error',
    required String message,
    String buttonText = 'Aceptar',
    VoidCallback? onPressed,
  }) async {
    return _showCustomModal(
      context: context,
      title: title,
      message: message,
      icon: Icons.error_outline,
      iconColor: Colors.red,
      buttonText: buttonText,
      onPressed: onPressed,
    );
  }

  /// Muestra un modal de éxito
  static Future<void> showSuccess({
    required BuildContext context,
    String title = '¡Éxito!',
    required String message,
    String buttonText = 'Aceptar',
    VoidCallback? onPressed,
  }) async {
    final theme = Theme.of(context);
    return _showCustomModal(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: theme.colorScheme.primary,
      buttonText: buttonText,
      onPressed: onPressed,
    );
  }

  /// Muestra un modal de advertencia
  static Future<void> showWarning({
    required BuildContext context,
    String title = 'Advertencia',
    required String message,
    String buttonText = 'Aceptar',
    VoidCallback? onPressed,
  }) async {
    return _showCustomModal(
      context: context,
      title: title,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
      buttonText: buttonText,
      onPressed: onPressed,
    );
  }

  /// Muestra un modal de confirmación con opciones de Sí/No
  static Future<bool> showConfirmation({
    required BuildContext context,
    String title = 'Confirmar',
    required String message,
    String confirmText = 'Sí',
    String cancelText = 'No',
    Color? confirmColor,
  }) async {
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: theme.colorScheme.surface,
            title: Row(
              children: [
                Icon(Icons.help_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'MADE TOMMY',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'MADE TOMMY',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  cancelText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  confirmText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: confirmColor ?? theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  /// Método base para mostrar modales personalizados
  static Future<void> _showCustomModal({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String buttonText,
    VoidCallback? onPressed,
  }) async {
    // Capturar el tema antes de la operación asíncrona para evitar problemas de contexto
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Usamos una función que recibe un nuevo BuildContext para el diálogo
      builder:
          (BuildContext dialogContext) => Theme(
            // Envolvemos con un Theme para garantizar la aplicación del tema
            data: theme,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 48),
                    ),
                    const SizedBox(height: 20),

                    // Título
                    Text(
                      title,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'MADE TOMMY',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Mensaje
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFamily: 'MADE TOMMY',
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Botón
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          if (onPressed != null) onPressed();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          buttonText,
                          style: textTheme.labelLarge?.copyWith(
                            fontFamily: 'MADE TOMMY',
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
