import 'package:flutter/material.dart';

/// Widget reutilizable que muestra los requisitos de la contraseña
/// con validación visual en tiempo real
class PasswordRequirementsWidget extends StatelessWidget {
  final String password;
  final bool showTitle;
  final double fontSize;
  final EdgeInsets padding;

  const PasswordRequirementsWidget({
    Key? key,
    required this.password,
    this.showTitle = true,
    this.fontSize = 12.0,
    this.padding = const EdgeInsets.all(12.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasMinLength = password.length >= 8;
    final bool hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final bool hasSymbol = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Requisitos de la contraseña:',
                  style: TextStyle(
                    fontSize: fontSize + 1,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    fontFamily: 'MADE TOMMY',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _buildRequirementRow('Mínimo 8 caracteres', hasMinLength, fontSize),
          const SizedBox(height: 4),
          _buildRequirementRow(
            'Al menos una mayúscula (A-Z)',
            hasUppercase,
            fontSize,
          ),
          const SizedBox(height: 4),
          _buildRequirementRow('Al menos un número (0-9)', hasNumber, fontSize),
          const SizedBox(height: 4),
          _buildRequirementRow(
            'Al menos un símbolo (!@#\$%^&*)',
            hasSymbol,
            fontSize,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isValid, double fontSize) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: isValid ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: isValid ? Colors.green[700] : Colors.grey[600],
              fontWeight: isValid ? FontWeight.w600 : FontWeight.normal,
              fontFamily: 'MADE TOMMY',
            ),
          ),
        ),
      ],
    );
  }

  /// Método estático para verificar si una contraseña cumple todos los requisitos
  static bool isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  /// Método estático para obtener el primer error de validación
  static String? getValidationError(String password) {
    if (password.isEmpty) {
      return 'La contraseña es obligatoria';
    }

    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'La contraseña debe tener al menos una mayúscula';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'La contraseña debe tener al menos un número';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'La contraseña debe tener al menos un símbolo (!@#\$%^&*(),.?":{}|<>)';
    }

    return null; // No hay errores
  }
}
