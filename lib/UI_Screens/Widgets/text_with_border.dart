import 'package:flutter/material.dart';

class TextWithBorder extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color borderColor;
  final double borderWidth;

  const TextWithBorder({
    required this.text,
    this.fontSize = 30,
    this.fontWeight = FontWeight.normal,
    this.borderColor = const Color(0xFF3EA69B), // Verde de tu tema
    this.borderWidth = 2.0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Texto borde (verde)
        Text(
          text,
          style: TextStyle(
            fontFamily: 'LightHouse', // Fuente LightHouse
            fontSize: fontSize,
            fontWeight: fontWeight,
            foreground:
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = borderWidth
                  ..color = borderColor,
          ),
          textAlign: TextAlign.center,
        ),
        // Texto relleno (blanco)
        Text(
          text,
          style: TextStyle(
            fontFamily: 'LightHouse', // Fuente LightHouse
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
