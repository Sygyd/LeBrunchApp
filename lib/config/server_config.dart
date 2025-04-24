import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ServerConfig {
  // IP del servidor para conexiones reales
  static String get serverIP {
    // En modo web, usamos la URL del servidor directamente sin el protocolo
    if (kIsWeb) {
      return _getServerUrlForWeb();
    }

    // En modo móvil, usamos la IP del servidor
    return _getServerIpForMobile();
  }

  // Obtener la URL base del servidor para peticiones HTTP
  static String get baseUrl {
    // En desarrollo web, conectarse al backend a través del mismo origen o proxy
    if (kIsWeb) {
      return 'http://${_getServerUrlForWeb()}';
    }

    // En desarrollo móvil, usar la IP específica
    return 'http://${_getServerIpForMobile()}:3000';
  }

  // URL para las imágenes en el servidor
  static String get imageBaseUrl {
    // En desarrollo web, conectarse al backend a través del mismo origen o proxy
    if (kIsWeb) {
      return 'http://${_getServerUrlForWeb()}';
    }

    // En desarrollo móvil, usar la IP específica
    return 'http://${_getServerIpForMobile()}:3000';
  }

  // Obtener el puerto del servidor
  static int get serverPort => 3000;

  // WebSocket URL para comunicación en tiempo real (si se usa)
  static String get webSocketUrl {
    // En desarrollo web, conectarse al backend a través del mismo origen o proxy
    if (kIsWeb) {
      return 'ws://${_getServerUrlForWeb()}/ws';
    }

    // En desarrollo móvil, usar la IP específica
    return 'ws://${_getServerIpForMobile()}:3000/ws';
  }

  // URL para el servicio de chat con Gemini (si se usa)
  static String get chatServiceUrl => '$baseUrl/mcp/chat';

  // Método privado para obtener la URL del servidor en modo web
  static String _getServerUrlForWeb() {
    // Si estamos en un entorno dockerizado, usamos 'server:3000'
    // Si estamos en desarrollo local, usamos 'localhost:3000'
    return const String.fromEnvironment(
      'SERVER_URL',
      defaultValue: 'localhost:3000',
    );
  }

  // Método privado para obtener la IP del servidor en modo móvil
  static String _getServerIpForMobile() {
    // Intentar obtener la IP desde variables de entorno
    final envIP = dotenv.env['SERVER_IP'];
    if (envIP != null && envIP.isNotEmpty) {
      return envIP;
    }

    // IP predeterminada (debe ser la misma que usa tu servidor)
    return '192.168.1.121'; // Esta debe ser la IP de tu máquina en la red local
  }
}
