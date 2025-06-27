import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_status_service.dart';
import '../UI_Screens/Widgets/custom_modal.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../Api_services/table_identification_service.dart';
import '../config.dart';

/// Servicio de notificaciones específico para clientes
/// Se suscribe al OrderStatusService Y al servidor WebSocket para recibir notificaciones cuando pedidos están listos
class ClientNotificationService {
  static final ClientNotificationService _instance =
      ClientNotificationService._internal();
  factory ClientNotificationService() => _instance;
  ClientNotificationService._internal();

  final OrderStatusService _orderStatusService = OrderStatusService();
  final TableIdentificationService _tableService = TableIdentificationService();
  StreamSubscription? _orderCompletedSubscription;
  int? _currentUserId;
  BuildContext? _context;

  // 🆕 NUEVO: Variables para WebSocket
  io.Socket? _socket;
  bool _isSocketConnected = false;
  String? _currentTableNumber;
  String? _currentDeviceMac;

  /// Inicializar el servicio con el contexto de la aplicación
  void initialize(BuildContext context) async {
    _context = context;
    await _loadCurrentUser();

    // Verificar y establecer la suscripción
    if (_orderCompletedSubscription == null ||
        _orderCompletedSubscription!.isPaused) {
      _startListening();
    }

    // Inicializar WebSocket
    await _initializeWebSocket();
  }

  /// Cargar el ID del usuario actual desde SharedPreferences
  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('user_id');
    } catch (e) {
      print('❌ Error al cargar usuario actual: $e');
    }
  }

  /// Comenzar a escuchar notificaciones de pedidos completados
  void _startListening() {
    // Cancelar cualquier suscripción anterior
    if (_orderCompletedSubscription != null) {
      _orderCompletedSubscription!.cancel();
      _orderCompletedSubscription = null;
    }

    // Crear nueva suscripción
    _orderCompletedSubscription = _orderStatusService.onOrderCompleted.listen(
      (orderData) {
        _handleOrderCompleted(orderData);
      },
      onError: (error) {
        print('❌ ClientNotificationService: Error en stream: $error');
      },
    );
  }

  /// Manejar notificación de pedido completado
  Future<void> _handleOrderCompleted(Map<String, dynamic> orderData) async {
    try {
      final int orderId = orderData['orderId'];
      final String? mesa = orderData['mesa'];
      final String mensaje = orderData['mensaje'] ?? 'Pedido completado';

      // Verificar si este pedido pertenece al usuario actual
      final bool isPedidoDelUsuario = await _isPedidoDelUsuarioActual(orderId);

      if (isPedidoDelUsuario && _context != null && _context!.mounted) {
        await _showOrderCompletedNotification(orderId, mesa, mensaje);
      }
    } catch (e) {
      print('❌ Error al manejar notificación de pedido completado: $e');
    }
  }

  /// Verificar si un pedido pertenece al usuario actual
  Future<bool> _isPedidoDelUsuarioActual(int orderId) async {
    try {
      // En desarrollo: Mostrar notificaciones a todos los clientes
      return true;

      // 🔄 CÓDIGO ORIGINAL (comentado para pruebas):
      /*
      if (_currentUserId == null) {
        await _loadCurrentUser();
        if (_currentUserId == null) {
          print(
            '⚠️ No hay usuario autenticado, mostrando notificación a todos',
          );
          return true; // Si no hay usuario, mostrar a todos (modo demo)
        }
      }

      // Verificar realmente si el pedido pertenece al usuario
      try {
        final prefs = await SharedPreferences.getInstance();
        final serverIp = prefs.getString('serverIp') ?? 
                        prefs.getString('network_server_ip') ?? 
                        prefs.getString('global_server_ip') ?? 
                        AppConfig.serverIp;
        final url = Uri.parse('http://$serverIp:3000/db/query');

        final query = '''
          SELECT idpersona 
          FROM pedidos 
          WHERE idpedido = $orderId
        ''';

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': query}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['result'] as List?;

          if (results != null && results.isNotEmpty) {
            final pedidoUserId = results[0]['idpersona'];
            final belongsToUser = pedidoUserId == _currentUserId;

            print('🔍 Verificación de propiedad del pedido #$orderId:');
            print('   - Usuario del pedido: $pedidoUserId');
            print('   - Usuario actual: $_currentUserId');
            print('   - Pertenece al usuario: $belongsToUser');

            return belongsToUser;
          }
        }
      } catch (e) {
        print('❌ Error verificando propietario del pedido via servidor: $e');
      }

      // FALLBACK: Si falla la verificación por servidor, mostrar a todos los clientes
      print('🔄 Fallback: Mostrando notificación a todos los clientes');
      return true;
      */
    } catch (e) {
      print('❌ Error al verificar propietario del pedido: $e');
      return true; // En caso de error, mostrar notificación
    }
  }

  /// Mostrar notificación visual al cliente de que su pedido está listo
  Future<void> _showOrderCompletedNotification(
    int orderId,
    String? mesa,
    String mensaje,
  ) async {
    if (_context == null || !_context!.mounted) {
      return;
    }

    try {
      // Primero mostrar SnackBar para notificación inmediata
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¡Tu pedido está listo!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      mesa != null
                          ? 'Pedido #$orderId - $mesa'
                          : 'Pedido #$orderId',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
            onPressed: () {
              _showDetailedModal(orderId, mesa, mensaje);
            },
          ),
        ),
      );

      // Después de 1 segundo, mostrar modal detallado
      await Future.delayed(const Duration(seconds: 1));

      if (_context != null && _context!.mounted) {
        await _showDetailedModal(orderId, mesa, mensaje);
      }
    } catch (e) {
      print('❌ Error al mostrar notificación: $e');
    }
  }

  /// Mostrar modal detallado con información del pedido listo
  Future<void> _showDetailedModal(
    int orderId,
    String? mesa,
    String mensaje,
  ) async {
    if (_context == null || !_context!.mounted) {
      return;
    }

    try {
      final modalMessage =
          mesa != null
              ? 'Tu pedido #$orderId está completado y viene en camino a tu $mesa.\n\n¡Que lo disfrutes!'
              : 'Tu pedido #$orderId está completado y viene en camino.\n\n¡Que lo disfrutes!';

      await CustomModal.showSuccess(
        context: _context!,
        title: '🎉 ¡Tu pedido está listo!',
        message: modalMessage,
        buttonText: '¡Genial!',
      );
    } catch (e) {
      print('❌ Error al mostrar modal detallado: $e');
    }
  }

  /// Actualizar el contexto cuando cambie la pantalla
  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Detener el servicio y limpiar recursos
  void dispose() {
    _orderCompletedSubscription?.cancel();

    // 🆕 NUEVO: Limpiar WebSocket
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isSocketConnected = false;
      print('🔌 WebSocket desconectado y limpiado');
    }

    _context = null;
  }

  /// Recargar usuario actual (útil después de login/logout)
  Future<void> refreshCurrentUser() async {
    await _loadCurrentUser();
  }

  /// 🆕 NUEVO: Método de diagnóstico para verificar el estado del servicio
  void diagnosticInfo() {
    print('🔔 ====== DIAGNÓSTICO ClientNotificationService ======');
    print('🔔 Context disponible: ${_context != null}');
    print('🔔 Context mounted: ${_context?.mounted ?? false}');
    print('🔔 Usuario actual: $_currentUserId');
    print(
      '🔔 Subscription activa: ${_orderCompletedSubscription != null && !_orderCompletedSubscription!.isPaused}',
    );
    print(
      '🔔 OrderStatusService stream: ${_orderStatusService.onOrderCompleted}',
    );
    print('🔔 ===============================================');
  }

  /// 🆕 NUEVO: Verificar si el servicio está correctamente configurado
  bool isProperlyConfigured() {
    final hasContext = _context != null && _context!.mounted;
    final hasSubscription =
        _orderCompletedSubscription != null &&
        !_orderCompletedSubscription!.isPaused;
    final hasUser = _currentUserId != null;

    print('🔔 ClientNotificationService configuración:');
    print('   - Context: $hasContext');
    print('   - Subscription: $hasSubscription');
    print('   - Usuario: $hasUser');

    return hasContext && hasSubscription;
  }

  // Inicializar conexión WebSocket con el servidor
  Future<void> _initializeWebSocket() async {
    try {
      // Obtener información de la mesa y dispositivo
      final tableInfo = await _tableService.identifyTable();
      if (tableInfo != null) {
        _currentTableNumber = tableInfo.tableNumber.toString();
        _currentDeviceMac = tableInfo.macAddress;
      } else {
        _currentTableNumber = '13'; // Default
        _currentDeviceMac = 'unknown';
      }

      // Obtener IP del servidor desde AppConfig
      final prefs = await SharedPreferences.getInstance();
      final serverIp =
          prefs.getString('serverIp') ??
          prefs.getString('network_server_ip') ??
          prefs.getString('global_server_ip') ??
          AppConfig.serverIp;
      final serverUrl = 'http://$serverIp:3000';

      // Limpiar socket anterior si existe
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }

      // Configurar socket
      _socket = io.io(
        serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      // Eventos del socket
      _socket!.onConnect((_) {
        _isSocketConnected = true;

        // Registrar cliente en el servidor
        final registrationData = {
          'tableNumber': int.tryParse(_currentTableNumber ?? '13') ?? 13,
          'deviceMac': _currentDeviceMac,
          'userRole': 1, // Cliente
          'userId': _currentUserId,
        };

        _socket!.emit('register', registrationData);
      });

      _socket!.onDisconnect((reason) {
        _isSocketConnected = false;
      });

      _socket!.onConnectError((error) {
        print('❌ Error conectando WebSocket: $error');
        _isSocketConnected = false;
      });

      _socket!.onReconnect((attempt) {
        _isSocketConnected = true;
      });

      // Eventos de notificación
      _socket!.on('notification', (data) {
        _handleWebSocketNotification(data);
      });

      _socket!.on('order-completed', (data) {
        _handleWebSocketNotification(data);
      });

      _socket!.on('orderCompleted', (data) {
        _handleWebSocketNotification(data);
      });

      // Conectar
      _socket!.connect();

      // Esperar un momento para la conexión
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      print('❌ Error inicializando WebSocket: $e');
      _isSocketConnected = false;
    }
  }

  // Manejar notificaciones recibidas via WebSocket
  void _handleWebSocketNotification(dynamic data) async {
    try {
      if (data is! Map) {
        // Intentar convertir si es string JSON
        if (data is String) {
          try {
            final jsonData = jsonDecode(data);
            if (jsonData is Map) {
              data = jsonData;
            } else {
              return;
            }
          } catch (e) {
            return;
          }
        } else {
          return;
        }
      }

      final notification = Map<String, dynamic>.from(data);

      // Extraer datos de la notificación
      final orderId = notification['orderId'] ?? notification['order_id'];
      final tableNumber =
          notification['tableNumber'] ??
          notification['table_number'] ??
          notification['mesa'];
      final message =
          notification['message'] ??
          notification['msg'] ??
          'Tu pedido está listo';
      final notificationType = notification['type'] ?? 'order_completed';

      // Verificar si es una notificación de pedido completado
      if (notificationType == 'order_completed' ||
          notificationType == 'orderCompleted' ||
          orderId != null) {
        // Verificar si la notificación es para esta mesa
        final notificationTableStr = tableNumber?.toString();
        final currentTableStr = _currentTableNumber;

        if (currentTableStr != null &&
            notificationTableStr == currentTableStr) {
          await _showOrderCompletedNotification(
            orderId ?? 0,
            'Mesa $tableNumber',
            message,
          );
        } else {
          // En desarrollo: Mostrar todas las notificaciones para testing
          await _showOrderCompletedNotification(
            orderId ?? 0,
            'Mesa $tableNumber',
            message,
          );
        }
      }
    } catch (e) {
      print('❌ Error procesando notificación WebSocket: $e');
    }
  }
}
