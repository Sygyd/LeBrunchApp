import 'dart:convert';
import 'package:http/http.dart' as http;
import 'global_config_service.dart';
import 'pedidos/orders_service.dart';
import 'pedidos/popular_dishes_service.dart';

class AdminChatService {
  static final AdminChatService _instance = AdminChatService._internal();
  factory AdminChatService() => _instance;
  AdminChatService._internal();

  final GlobalConfigService _globalConfig = GlobalConfigService();
  final OrdersService _ordersService = OrdersService();
  final PopularDishesService _popularDishesService = PopularDishesService();

  // Comandos especiales del admin
  final Map<String, String> _adminCommands = {
    '/config': 'Mostrar configuración actual del sistema',
    '/ip': 'Cambiar IP del servidor (ej: /ip 192.168.1.100)',
    '/model': 'Cambiar modelo de Gemini (ej: /model gemini-2.0-flash)',
    '/reports': 'Activar/desactivar reportes (ej: /reports on/off)',
    '/popular': 'Activar/desactivar platos populares (ej: /popular on/off)',
    '/debug': 'Activar/desactivar modo debug (ej: /debug on/off)',
    '/status': 'Mostrar estado del servidor y conexiones',
    '/help': 'Mostrar todos los comandos disponibles',
    '/test': 'Probar conexión con el servidor',
    '/reload': 'Recargar configuración del servidor',
  };

  // Procesar mensaje del admin
  Future<Map<String, dynamic>> processAdminMessage(String message) async {
    final trimmedMessage = message.trim();

    // Si es un comando especial
    if (trimmedMessage.startsWith('/')) {
      return await _processCommand(trimmedMessage);
    }

    // Si no es comando, enviar al chat normal pero con capacidades especiales
    return await _processNormalMessage(trimmedMessage);
  }

  // Procesar comandos especiales
  Future<Map<String, dynamic>> _processCommand(String command) async {
    final parts = command.split(' ');
    final cmd = parts[0].toLowerCase();

    switch (cmd) {
      case '/help':
        return _buildHelpResponse();

      case '/config':
        return await _buildConfigResponse();

      case '/ip':
        if (parts.length < 2) {
          return _buildErrorResponse(
            'Uso: /ip <nueva_ip>\nEjemplo: /ip 192.168.1.100',
          );
        }
        return await _changeServerIp(parts[1]);

      case '/model':
        if (parts.length < 2) {
          return _buildErrorResponse(
            'Uso: /model <nombre_modelo>\nEjemplo: /model gemini-2.0-flash',
          );
        }
        return await _changeGeminiModel(parts[1]);

      case '/reports':
        if (parts.length < 2) {
          return _buildErrorResponse(
            'Uso: /reports <on|off>\nEjemplo: /reports on',
          );
        }
        return await _toggleReports(parts[1].toLowerCase() == 'on');

      case '/popular':
        if (parts.length < 2) {
          return _buildErrorResponse(
            'Uso: /popular <on|off>\nEjemplo: /popular on',
          );
        }
        return await _togglePopularDishes(parts[1].toLowerCase() == 'on');

      case '/debug':
        if (parts.length < 2) {
          return _buildErrorResponse(
            'Uso: /debug <on|off>\nEjemplo: /debug on',
          );
        }
        return await _toggleDebugMode(parts[1].toLowerCase() == 'on');

      case '/status':
        return await _buildStatusResponse();

      case '/test':
        return await _testConnection();

      case '/reload':
        return await _reloadServerConfig();

      default:
        return _buildErrorResponse(
          'Comando no reconocido. Usa /help para ver comandos disponibles.',
        );
    }
  }

  // Procesar mensaje normal con capacidades especiales
  Future<Map<String, dynamic>> _processNormalMessage(String message) async {
    try {
      // Detectar si el mensaje solicita información especial
      final lowerMessage = message.toLowerCase();

      if (lowerMessage.contains('reporte') ||
          lowerMessage.contains('ventas') ||
          lowerMessage.contains('estadística')) {
        return await _handleReportsRequest(message);
      }

      if (lowerMessage.contains('popular') ||
          lowerMessage.contains('más vendido') ||
          lowerMessage.contains('favorito')) {
        return await _handlePopularDishesRequest(message);
      }

      if (lowerMessage.contains('configuración') ||
          lowerMessage.contains('config') ||
          lowerMessage.contains('estado del sistema')) {
        return await _buildConfigResponse();
      }

      // Si no es una solicitud especial, enviar al chat normal con contexto de admin
      return await _sendToNormalChat(message);
    } catch (e) {
      print('❌ Error procesando mensaje del admin: $e');
      return _buildErrorResponse('Error al procesar el mensaje: $e');
    }
  }

  // Manejar solicitudes de reportes
  Future<Map<String, dynamic>> _handleReportsRequest(String message) async {
    if (!_globalConfig.enableReports) {
      return _buildErrorResponse(
        'Los reportes están desactivados. Usa /reports on para activarlos.',
      );
    }

    try {
      // Obtener datos de ventas del día y pedidos pendientes usando endpoints directos
      final todaySales = await _getTodaySales();
      final pendingOrders = await _getPendingOrdersCount();

      final reportText = '''📊 **REPORTE DE HOY** ✨

💰 **Ventas del día:** \$${todaySales.toStringAsFixed(2)} 🤑
📋 **Pedidos pendientes:** $pendingOrders ${pendingOrders > 0 ? '⏳' : '✅'}
🕒 **Actualizado:** ${DateTime.now().toString().substring(11, 16)} 

${todaySales > 100 ? '¡Qué día tan productivo! 🎉' : '¡Vamos por más ventas! 💪'} ¿Necesitas más detalles? 😊''';

      return {
        'text_response': reportText,
        'type': 'admin_report',
        'data': {
          'todaySales': todaySales,
          'pendingOrders': pendingOrders,
          'timestamp': DateTime.now().toIso8601String(),
        },
      };
    } catch (e) {
      return _buildErrorResponse('Error al generar reporte: $e');
    }
  }

  // Obtener ventas del día actual
  Future<double> _getTodaySales() async {
    try {
      final url = Uri.parse(
        'http://${_globalConfig.serverIp}:3000/pedidos/ventas/hoy',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['total'] ?? 0.0).toDouble();
      } else {
        print('❌ Error al obtener ventas del día: ${response.statusCode}');
        return 0.0;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener ventas: $e');
      return 0.0;
    }
  }

  // Obtener conteo de pedidos pendientes
  Future<int> _getPendingOrdersCount() async {
    try {
      final url = Uri.parse(
        'http://${_globalConfig.serverIp}:3000/pedidos/pendientes/count',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['count'] ?? 0).toInt();
      } else {
        print('❌ Error al obtener pedidos pendientes: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('❌ Error de conexión al obtener pedidos pendientes: $e');
      return 0;
    }
  }

  // Manejar solicitudes de platos populares
  Future<Map<String, dynamic>> _handlePopularDishesRequest(
    String message,
  ) async {
    if (!_globalConfig.enablePopularDishes) {
      return _buildErrorResponse(
        'La información de platos populares está desactivada. Usa /popular on para activarla.',
      );
    }

    try {
      final popularDishes = await _popularDishesService.getPopularDishes(
        limit: 5,
      );

      if (popularDishes.isEmpty) {
        return {
          'text_response':
              '📊 No hay datos de platos populares disponibles en este momento.',
          'type': 'admin_popular_dishes',
        };
      }

      String dishesText = '🏆 **PLATOS MÁS POPULARES** ✨\n\n';
      for (int i = 0; i < popularDishes.length; i++) {
        final dish = popularDishes[i];
        final emoji =
            i == 0
                ? '👑'
                : i == 1
                ? '🥈'
                : i == 2
                ? '🥉'
                : '⭐';
        dishesText += '$emoji **${dish['nombre']}**\n';
        dishesText +=
            '   📊 ${dish['cantidad_vendida']} vendidos • \$${dish['precio']} 💰\n\n';
      }
      dishesText +=
          '${popularDishes.length > 3 ? '¡Los favoritos de nuestros clientes! 😍' : '¡Estos son los consentidos! 🤤'}';

      return {
        'text_response': dishesText,
        'type': 'admin_popular_dishes',
        'data': popularDishes,
      };
    } catch (e) {
      return _buildErrorResponse('Error al obtener platos populares: $e');
    }
  }

  // Enviar al chat normal con contexto de admin
  Future<Map<String, dynamic>> _sendToNormalChat(String message) async {
    try {
      final url = Uri.parse('http://${_globalConfig.serverIp}:3000/chat');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'sessionId': 'admin_session_${DateTime.now().millisecondsSinceEpoch}',
          'isAdmin': true,
          'adminCapabilities': {
            'reports': _globalConfig.enableReports,
            'popularDishes': _globalConfig.enablePopularDishes,
            'menuManagement': _globalConfig.enableMenuManagement,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return _buildErrorResponse(
          'Error del servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      return _buildErrorResponse('Error de conexión: $e');
    }
  }

  // Cambiar IP del servidor
  Future<Map<String, dynamic>> _changeServerIp(String newIp) async {
    // Validar formato IP básico
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(newIp)) {
      return _buildErrorResponse(
        'Formato de IP inválido. Ejemplo: 192.168.1.100',
      );
    }

    final success = await _globalConfig.updateServerConfig(serverIp: newIp);

    if (success) {
      return {
        'text_response':
            '✅ IP del servidor cambiada exitosamente a: $newIp\n\nProbando conexión...',
        'type': 'admin_config_change',
        'action': 'test_connection',
      };
    } else {
      return _buildErrorResponse('Error al cambiar la IP del servidor');
    }
  }

  // Cambiar modelo de Gemini
  Future<Map<String, dynamic>> _changeGeminiModel(String model) async {
    final success = await _globalConfig.updateServerConfig(model: model);

    if (success) {
      return {
        'text_response':
            '✅ **¡Modelo actualizado!** 🤖✨\n\n🔄 **Nuevo modelo:** $model\n💬 Todos los chats ahora usarán este modelo súper inteligente 🧠💫',
        'type': 'admin_config_change',
        'data': {'newModel': model},
      };
    } else {
      return _buildErrorResponse(
        'No se pudo cambiar el modelo. Verifica que sea válido.',
      );
    }
  }

  // Activar/desactivar reportes
  Future<Map<String, dynamic>> _toggleReports(bool enable) async {
    final success = await _globalConfig.updateServerConfig(
      enableReports: enable,
    );

    if (success) {
      final status = enable ? 'activados' : 'desactivados';
      final emoji = enable ? '📊✅' : '📊❌';
      return {
        'text_response':
            '$emoji **¡Reportes $status!**\n\n${enable ? '🎉 Los clientes ahora pueden pedir reportes de ventas 📈' : '🔒 Los clientes ya no pueden acceder a reportes'}',
        'type': 'admin_config_change',
        'data': {'reportsEnabled': enable},
      };
    } else {
      return _buildErrorResponse(
        'No se pudo cambiar la configuración de reportes',
      );
    }
  }

  // Activar/desactivar platos populares
  Future<Map<String, dynamic>> _togglePopularDishes(bool enable) async {
    final success = await _globalConfig.updateServerConfig(
      enablePopularDishes: enable,
    );

    if (success) {
      final status = enable ? 'activados' : 'desactivados';
      return {
        'text_response':
            '✅ **Platos populares $status**\n\n${enable ? 'Los clientes pueden preguntar por platos favoritos.' : 'Los clientes no pueden ver platos populares.'}',
        'type': 'admin_config_change',
        'data': {'popularDishesEnabled': enable},
      };
    } else {
      return _buildErrorResponse(
        'No se pudo cambiar la configuración de platos populares',
      );
    }
  }

  // Activar/desactivar modo debug
  Future<Map<String, dynamic>> _toggleDebugMode(bool enable) async {
    final success = await _globalConfig.updateServerConfig(debugMode: enable);

    if (success) {
      final status = enable ? 'activado' : 'desactivado';
      return {
        'text_response':
            '✅ Modo debug $status exitosamente.\n\n${enable ? 'Se mostrarán mensajes de debug adicionales.' : 'Los mensajes de debug están ocultos.'}',
        'type': 'admin_config_change',
        'data': {'debugMode': enable},
      };
    } else {
      return _buildErrorResponse('Error al cambiar modo debug');
    }
  }

  // Construir respuesta de ayuda
  Map<String, dynamic> _buildHelpResponse() {
    String helpText = '''🔧 **COMANDOS DISPONIBLES** ✨

**📊 Información:**
• `/config` - Ver configuración actual 🔍
• `/status` - Estado del servidor 🌐

**⚙️ Configuración:**
• `/ip 192.168.1.100` - Cambiar IP del servidor 🔗
• `/model gemini-2.0-flash` - Cambiar modelo de IA 🤖
• `/reports on/off` - Activar/desactivar reportes 📈
• `/popular on/off` - Activar/desactivar platos populares 🏆

**🔧 Utilidades:**
• `/test` - Probar conexión 🔌
• `/reload` - Recargar configuración 🔄

💡 **¡Tip!** También puedes preguntar sobre reportes o platos populares directamente, ¡soy súper inteligente! 😊✨''';

    return {'text_response': helpText, 'type': 'admin_help'};
  }

  // Construir respuesta de configuración
  Future<Map<String, dynamic>> _buildConfigResponse() async {
    final serverStatus = await _globalConfig.getServerStatus();
    final isConnected = await _globalConfig.testConnection();

    String configText = '''⚙️ **CONFIGURACIÓN ACTUAL**

**🌐 Servidor:**
• IP: ${_globalConfig.serverIp}
• Estado: ${isConnected ? '🟢 Conectado' : '🔴 Desconectado'}

**🤖 Asistente:**
• Modelo: ${_globalConfig.currentModel}
• Reportes: ${_globalConfig.enableReports ? '✅ ON' : '❌ OFF'}
• Platos Populares: ${_globalConfig.enablePopularDishes ? '✅ ON' : '❌ OFF'}

**🔧 Sistema:**
• Debug: ${_globalConfig.debugMode ? '✅ ON' : '❌ OFF'}''';

    if (serverStatus != null && serverStatus['version'] != null) {
      configText += '\n• Versión: ${serverStatus['version']}';
    }

    return {
      'text_response': configText,
      'type': 'admin_config',
      'data': {'config': _globalConfig.toMap(), 'serverStatus': serverStatus},
    };
  }

  // Construir respuesta de estado
  Future<Map<String, dynamic>> _buildStatusResponse() async {
    final serverStatus = await _globalConfig.getServerStatus();
    final isConnected = await _globalConfig.testConnection();

    String statusText = '''📊 **ESTADO DEL SISTEMA**

🔗 **Conexión:** ${isConnected ? '🟢 Conectado' : '🔴 Desconectado'}''';

    if (serverStatus != null) {
      final dbConnected = serverStatus['database']?['connected'] == true;
      final availableDishes = serverStatus['database']?['availableDishes'] ?? 0;

      statusText += '''

🗄️ **Base de Datos:** ${dbConnected ? '🟢 Activa' : '🔴 Inactiva'}
🍽️ **Platos Disponibles:** $availableDishes
🤖 **Modelo Activo:** ${_globalConfig.currentModel}''';
    } else {
      statusText += '\n\n❌ No se pudo obtener información del servidor';
    }

    return {
      'text_response': statusText,
      'type': 'admin_status',
      'data': {'isConnected': isConnected, 'serverStatus': serverStatus},
    };
  }

  // Probar conexión
  Future<Map<String, dynamic>> _testConnection() async {
    final isConnected = await _globalConfig.testConnection();

    if (isConnected) {
      return {
        'text_response':
            '✅ Conexión exitosa con el servidor en ${_globalConfig.serverIp}:3000',
        'type': 'admin_test',
        'data': {'connected': true},
      };
    } else {
      return {
        'text_response':
            '❌ No se pudo conectar con el servidor en ${_globalConfig.serverIp}:3000\n\nVerifica que:\n- La IP sea correcta\n- El servidor esté ejecutándose\n- No haya problemas de red',
        'type': 'admin_test',
        'data': {'connected': false},
      };
    }
  }

  // Recargar configuración del servidor
  Future<Map<String, dynamic>> _reloadServerConfig() async {
    try {
      await _globalConfig.loadConfig();
      return {
        'text_response':
            '✅ Configuración recargada exitosamente desde el almacenamiento local.',
        'type': 'admin_reload',
      };
    } catch (e) {
      return _buildErrorResponse('Error al recargar configuración: $e');
    }
  }

  // Construir respuesta de error
  Map<String, dynamic> _buildErrorResponse(String error) {
    return {'text_response': '❌ **Error:** $error', 'type': 'admin_error'};
  }
}
