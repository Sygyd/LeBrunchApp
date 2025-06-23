import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config.dart';

/// Utilidades de validación para formularios de autenticación
class ValidationUtils {
  // =====================================================
  // VALIDACIONES PARA LOGIN
  // =====================================================

  /// Validar formato de email robusto
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El email es obligatorio';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Ingresa un email válido (ej: usuario@dominio.com)';
    }

    return null;
  }

  /// Validar contraseña para login (menos estricta)
  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }

    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    return null;
  }

  // =====================================================
  // VALIDACIONES PARA REGISTRO
  // =====================================================

  /// Capitalizar primera letra y convertir el resto a minúsculas
  static String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Validar que el texto no contenga números
  static bool containsNumbers(String text) {
    return RegExp(r'\d').hasMatch(text);
  }

  /// Validar cédula (solo números positivos, desde 1 hasta infinito)
  static String? validateCedula(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La cédula es obligatoria';
    }

    // Solo permitir números
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'La cédula solo puede contener números';
    }

    final cedulaNumber = int.tryParse(value.trim());
    if (cedulaNumber == null || cedulaNumber < 1) {
      return 'La cédula debe ser un número positivo mayor a 0';
    }

    return null;
  }

  /// Validar contraseña robusta para registro
  static String? validateRegisterPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria';
    }

    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    // Verificar que tenga al menos una mayúscula
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'La contraseña debe tener al menos una mayúscula';
    }

    // Verificar que tenga al menos un número
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'La contraseña debe tener al menos un número';
    }

    // Verificar que tenga al menos un símbolo
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'La contraseña debe tener al menos un símbolo (!@#\$%^&*(),.?":{}|<>)';
    }

    return null;
  }

  /// Validar nombre/apellido
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'El $fieldName es obligatorio';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length < 2) {
      return 'El $fieldName debe tener al menos 2 caracteres';
    }

    if (containsNumbers(trimmedValue)) {
      return 'El $fieldName no puede contener números';
    }

    // Validar que solo contenga letras y espacios
    if (!RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$').hasMatch(trimmedValue)) {
      return 'El $fieldName solo puede contener letras y espacios';
    }

    return null;
  }

  /// Validar confirmación de contraseña
  static String? validatePasswordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }

    if (value != password) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  // =====================================================
  // VALIDACIONES ASÍNCRONAS (UNICIDAD)
  // =====================================================

  /// Verificar si el email ya está registrado
  static Future<bool> isEmailUnique(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/auth/check-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] == true;
      }

      return true; // Si hay error, asumir que está disponible y dejar que el servidor maneje la validación
    } catch (e) {
      print('Error verificando email único: $e');
      return true; // Si hay error, asumir que está disponible
    }
  }

  /// Verificar si la cédula ya está registrada
  static Future<bool> isCedulaUnique(String cedula) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/auth/check-cedula'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cedula': cedula.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] == true;
      }

      return true; // Si hay error, asumir que está disponible
    } catch (e) {
      print('Error verificando cédula única: $e');
      return true; // Si hay error, asumir que está disponible
    }
  }

  // =====================================================
  // MENSAJES DE ERROR ESPECÍFICOS PARA RESPUESTAS DEL SERVIDOR
  // =====================================================

  /// Obtener mensaje de error específico basado en la respuesta del servidor
  static String getServerErrorMessage(
    int statusCode,
    String? serverMessage, {
    String? errorCode,
  }) {
    // 🆕 NUEVO: Manejo específico para usuarios eliminados/baneados
    if (statusCode == 403 && errorCode == 'usuario_eliminado') {
      return serverMessage?.isNotEmpty == true
          ? serverMessage!
          : "Esta cuenta ha sido eliminada o suspendida. Contacta al administrador para más información.";
    }

    switch (statusCode) {
      case 401:
        if (errorCode == 'credenciales_invalidas') {
          return serverMessage?.isNotEmpty == true
              ? serverMessage!
              : "Email o contraseña incorrectos";
        }
        return "Email o contraseña incorrectos";
      case 403:
        if (serverMessage?.toLowerCase().contains('eliminado') == true ||
            serverMessage?.toLowerCase().contains('deleted') == true ||
            serverMessage?.toLowerCase().contains('suspendida') == true) {
          return serverMessage?.isNotEmpty == true
              ? serverMessage!
              : "Esta cuenta ha sido eliminada o suspendida. Contacta al administrador.";
        } else {
          return "Acceso denegado. Tu cuenta puede estar inactiva.";
        }
      case 404:
        return "No existe una cuenta con este email";
      case 409:
        if (serverMessage?.toLowerCase().contains('email') == true) {
          return "Este email ya está registrado. Usa otro email o inicia sesión.";
        } else if (serverMessage?.toLowerCase().contains('cedula') == true ||
            serverMessage?.toLowerCase().contains('cédula') == true) {
          return "Esta cédula ya está registrada. Verifica tu información.";
        } else {
          return "Los datos proporcionados ya están en uso.";
        }
      case 422:
        return "Datos inválidos. Verifica la información proporcionada.";
      case 429:
        return "Demasiados intentos. Espera unos minutos.";
      case 500:
        return "Error interno del servidor. Intenta más tarde.";
      default:
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : "Error en el servidor ($statusCode)";
    }
  }

  /// Obtener mensaje de error específico para excepciones de conexión
  static String getConnectionErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('SocketException') ||
        errorString.contains('NetworkException')) {
      return "Sin conexión al servidor. Verifica tu internet y que el servidor esté funcionando.";
    } else if (errorString.contains('TimeoutException')) {
      return "Tiempo de espera agotado. Verifica tu conexión a internet.";
    } else if (errorString.contains('FormatException')) {
      return "Error en la respuesta del servidor. Intenta más tarde.";
    } else {
      return "Error de conexión: $errorString";
    }
  }
}
