import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  print('🧹 Limpiando IPs incorrectas de SharedPreferences...');

  final prefs = await SharedPreferences.getInstance();

  // Lista de IPs incorrectas que deben ser limpiadas
  final obsoleteIPs = ['192.168.1.85', '192.168.1.121', '192.168.1.136'];

  bool foundObsoleteIp = false;

  // Verificar todas las claves posibles donde se guarda la IP
  final ipKeys = ['serverIp', 'network_server_ip', 'global_server_ip'];

  for (final key in ipKeys) {
    final currentIp = prefs.getString(key);
    if (currentIp != null && obsoleteIPs.contains(currentIp)) {
      print('🗑️ Eliminando IP obsoleta "$currentIp" de clave "$key"');
      await prefs.remove(key);
      foundObsoleteIp = true;
    } else if (currentIp != null) {
      print('✅ IP "$currentIp" en clave "$key" es válida');
    }
  }

  if (foundObsoleteIp) {
    print(
      '✅ IPs obsoletas limpiadas. La app usará la IP correcta del config.dart',
    );
    print('📋 IP correcta del servidor: 192.168.0.128');
  } else {
    print('✅ No se encontraron IPs obsoletas');
  }

  // Mostrar configuración actual
  print('\n📊 Estado actual de SharedPreferences:');
  for (final key in ipKeys) {
    final value = prefs.getString(key);
    print('   $key: ${value ?? "No configurado"}');
  }
}
