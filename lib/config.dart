// 🔧 CONFIGURACIÓN GLOBAL DEL PROYECTO
// ================================
// CAMBIA SOLO ESTA LÍNEA PARA CONFIGURAR LA IP DEL SERVIDOR:

const String SERVER_IP = "192.168.1.85"; // 👈 CAMBIA AQUÍ TU IP

// ================================
// NO TOCAR NADA MÁS ABAJO
const String SERVER_PORT = "3000";
const String SERVER_URL = "http://$SERVER_IP:$SERVER_PORT";

class AppConfig {
  static const String serverIp = SERVER_IP;
  static const String serverPort = SERVER_PORT;
  static const String serverUrl = SERVER_URL;

  // URLs completas para endpoints comunes
  static const String menuUrl = "$SERVER_URL/menu";
  static const String loginUrl = "$SERVER_URL/auth/login";
  static const String registerUrl = "$SERVER_URL/auth/register";
  static const String statusUrl = "$SERVER_URL/status";
  static const String discoverUrl = "$SERVER_URL/discover";
}
