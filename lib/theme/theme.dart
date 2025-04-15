import 'package:flutter/material.dart';

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF3EA69B), // Verde principal (original #3EA69B)
  onPrimary: Color(0xFFFFFFFF), // Texto blanco sobre primary
  primaryContainer: Color(0xFF2D8A80), // Variante más oscura
  secondary: Color(0xFF94C7C0), // Verde claro (original #94C7C0)
  onSecondary: Color(0xFF000000), // Texto negro sobre secondary
  error: Color(0xFFBA1A1A), // Rojo para errores (puedes cambiarlo)
  onError: Color(0xFFFFFFFF), // Texto blanco sobre error
  surface: Color(0xFFFFFFFF), // White surfaces (cards, sheets)
  onSurface: Color(0xFF444444), // Medium gray text
  outline: Color(0xFFC2C8BC), // Bordes sutiles
  shadow: Color(0x40000000), // Sombra semi-transparente
);

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF94C7C0), // Verde claro como primary en oscuro
  onPrimary: Color(0xFF000000), // Texto negro sobre primary
  primaryContainer: Color(0xFF3EA69B), // Original como variante
  secondary: Color(0xFF5D9C94), // Verde intermedio
  onSecondary: Color(0xFFFFFFFF), // Texto blanco sobre secondary
  error: Color(0xFFEF5350), // Rojo vibrante para oscuro
  onError: Color(0xFF000000), // Texto negro sobre error
  surface: Color(0xFF1E1E1E), // Superficies oscuras (cards, sheets)
  onSurface: Color(0xFFE0E0E0), // Texto claro sobre fondo oscuro
  outline: Color(0xFF424242), // Bordes en modo oscuro
  shadow: Color(0x80FFFFFF), // Sombra clara semi-transparente
);

// TextTheme personalizado para modo claro
final _lightTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 57,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  displayMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 45,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  displaySmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 36,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  headlineLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 32,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 28,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  headlineSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 24,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  titleLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 22,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  titleMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: lightColorScheme.onSurface,
  ),
  titleSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: lightColorScheme.onSurface,
  ),
  bodyLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  bodyMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  bodySmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: lightColorScheme.onSurface,
  ),
  labelLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: lightColorScheme.onSurface,
  ),
  labelMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: lightColorScheme.onSurface,
  ),
  labelSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: lightColorScheme.onSurface,
  ),
);

// TextTheme personalizado para modo oscuro
final _darkTextTheme = TextTheme(
  displayLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 57,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  displayMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 45,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  displaySmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 36,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  headlineLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 32,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 28,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  headlineSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 24,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  titleLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 22,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  titleMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: darkColorScheme.onSurface,
  ),
  titleSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: darkColorScheme.onSurface,
  ),
  bodyLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  bodyMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  bodySmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: darkColorScheme.onSurface,
  ),
  labelLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: darkColorScheme.onSurface,
  ),
  labelMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: darkColorScheme.onSurface,
  ),
  labelSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: darkColorScheme.onSurface,
  ),
);

final lightMode = ThemeData(
  colorScheme: lightColorScheme,
  fontFamily: 'MADE TOMMY',
  textTheme: _lightTextTheme,
  brightness: Brightness.light,
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.white,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: MaterialStateProperty.all<Color>(
        lightColorScheme.primary,
      ),
      foregroundColor: MaterialStateProperty.all<Color>(
        lightColorScheme.onPrimary,
      ),
      textStyle: MaterialStateProperty.all<TextStyle>(
        const TextStyle(fontFamily: 'MADE TOMMY', fontSize: 18),
      ),
    ),
  ),
);

final darkMode = ThemeData(
  colorScheme: darkColorScheme,
  fontFamily: 'MADE TOMMY',
  textTheme: _darkTextTheme,
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: darkColorScheme.surface,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: MaterialStateProperty.all<Color>(
        darkColorScheme.primary,
      ),
      foregroundColor: MaterialStateProperty.all<Color>(
        darkColorScheme.onPrimary,
      ),
      textStyle: MaterialStateProperty.all<TextStyle>(
        const TextStyle(fontFamily: 'MADE TOMMY', fontSize: 18),
      ),
    ),
  ),
);
