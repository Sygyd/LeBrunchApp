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
    return _showCustomModal(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: Colors.green,
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
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18)),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  cancelText,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  confirmText,
                  style: TextStyle(
                    color:
                        confirmColor ?? Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
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
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícono
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 40),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Mensaje
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 24),

                  // Botón
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        if (onPressed != null) onPressed();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(buttonText),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
