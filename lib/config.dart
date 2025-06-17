// 🔧 CONFIGURACIÓN GLOBAL DEL PROYECTO - VERSIÓN DINÁMICA
// ================================
// IP POR DEFECTO (se puede cambiar desde el modal de configuración):

const String DEFAULT_SERVER_IP = "192.168.1.85"; // 👈 IP por defecto
const String SERVER_PORT = "3000";

// ================================
// CONFIGURACIÓN DINÁMICA
class AppConfig {
  static String _currentServerIp = DEFAULT_SERVER_IP;
  static const String serverPort = SERVER_PORT;

  // Getters que permiten cambios dinámicos
  static String get serverIp => _currentServerIp;
  static String get serverUrl => "http://$_currentServerIp:$SERVER_PORT";

  // URLs completas para endpoints comunes (ahora dinámicas)
  static String get menuUrl => "$serverUrl/menu";
  static String get loginUrl => "$serverUrl/auth/login";
  static String get registerUrl => "$serverUrl/auth/register";
  static String get statusUrl => "$serverUrl/status";
  static String get discoverUrl => "$serverUrl/discover";

  // Método para actualizar la IP dinámicamente
  static void updateServerIp(String newIp) {
    if (_isValidIp(newIp)) {
      _currentServerIp = newIp;
      print('🔄 AppConfig: IP actualizada a $_currentServerIp');
    } else {
      print('❌ AppConfig: IP inválida, manteniendo: $_currentServerIp');
    }
  }

  // Método para resetear a la IP por defecto
  static void resetToDefaultIp() {
    _currentServerIp = DEFAULT_SERVER_IP;
    print('🔄 AppConfig: IP reseteada a defecto: $_currentServerIp');
  }

  // Validación básica de IP
  static bool _isValidIp(String ip) {
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) return false;

    final parts = ip.split('.');
    return parts.every((part) {
      final num = int.tryParse(part);
      return num != null && num >= 0 && num <= 255;
    });
  }

  // Información de configuración actual
  static Map<String, dynamic> getConfigInfo() {
    return {
      'currentIp': _currentServerIp,
      'defaultIp': DEFAULT_SERVER_IP,
      'serverPort': SERVER_PORT,
      'serverUrl': serverUrl,
      'isUsingDefault': _currentServerIp == DEFAULT_SERVER_IP,
    };
  }
}
