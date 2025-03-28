import 'package:flutter/material.dart';

class WelcomeButton extends StatelessWidget {
  final String buttonText;
  final VoidCallback onTap;

  const WelcomeButton({required this.buttonText, required this.onTap, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent, // Fondo transparente
        foregroundColor: Colors.white, // Texto blanco
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.primary, // Borde verde (#3EA69B)
            width: 2,
          ),
        ),
        elevation: 0,
      ),
      child: Stack(
        children: [
          // Texto con borde verde
          Text(
            buttonText,
            style: TextStyle(
              fontFamily: 'LightHouse',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              foreground:
                  Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..color = theme.colorScheme.primary,
            ),
          ),
          // Texto blanco
          Text(
            buttonText,
            style: TextStyle(
              fontFamily: 'LightHouse',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
