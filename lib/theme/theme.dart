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

// TextTheme personalizado
final _lightTextTheme = TextTheme(
  // Lighthouse para títulos y subtítulos
  displayLarge: TextStyle(
    fontFamily: 'LightHouse',
    fontSize: 57,
    fontWeight: FontWeight.normal,
  ),
  displayMedium: TextStyle(
    fontFamily: 'LightHouse',
    fontSize: 45,
    fontWeight: FontWeight.normal,
  ),
  displaySmall: TextStyle(
    fontFamily: 'LightHouse',
    fontSize: 36,
    fontWeight: FontWeight.normal,
  ),
  headlineLarge: TextStyle(
    fontFamily: 'LightHouse',
    fontSize: 32,
    fontWeight: FontWeight.normal,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'LightHouse',
    fontSize: 28,
    fontWeight: FontWeight.normal,
  ),
  headlineSmall: TextStyle(
    fontFamily: 'LightHouse',
    fontSize: 24,
    fontWeight: FontWeight.normal,
  ),
  titleLarge: TextStyle(
    fontFamily: 'LightHouse',
    fontSize: 22,
    fontWeight: FontWeight.normal,
  ),

  // MADE TOMMY para todo lo demás
  titleMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 16,
    fontWeight: FontWeight.w500,
  ),
  titleSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.w500,
  ),
  bodyLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 16,
    fontWeight: FontWeight.normal,
  ),
  bodyMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.normal,
  ),
  bodySmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 12,
    fontWeight: FontWeight.normal,
  ),
  labelLarge: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 14,
    fontWeight: FontWeight.w500,
  ),
  labelMedium: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 12,
    fontWeight: FontWeight.w500,
  ),
  labelSmall: TextStyle(
    fontFamily: 'MADE TOMMY',
    fontSize: 11,
    fontWeight: FontWeight.w500,
  ),
);

ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: lightColorScheme,
  fontFamily: 'LightHouse', // Fuente principal
  textTheme: _lightTextTheme,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(
        lightColorScheme.primary,
      ), // Verde
      foregroundColor: WidgetStateProperty.all<Color>(
        lightColorScheme.onPrimary,
      ), // Blanco
      textStyle: WidgetStateProperty.all<TextStyle>(
        const TextStyle(
          fontFamily: 'LightHouse', // Fuente aplicada aquí
          fontSize: 18,
        ),
      ),
      // ... (otros parámetros como padding, shape, etc.)
    ),
  ),
  // Añade estilos adicionales para otros componentes si es necesario
);

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: darkColorScheme,
  fontFamily: 'LightHouse', // Fuente principal
  textTheme: _lightTextTheme.apply(
    displayColor: darkColorScheme.onSurface,
    bodyColor: darkColorScheme.onSurface,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all<Color>(
        lightColorScheme.primary,
      ), // Verde
      foregroundColor: WidgetStateProperty.all<Color>(
        lightColorScheme.onPrimary,
      ), // White
      textStyle: WidgetStateProperty.all<TextStyle>(
        const TextStyle(
          fontFamily: 'LightHouse', // Fuente aplicada aquí
          fontSize: 18,
        ),
      ),
      // ... (otros parámetros como padding, shape, etc.)
    ),
  ),
);
