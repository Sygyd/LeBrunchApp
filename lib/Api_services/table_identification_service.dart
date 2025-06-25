import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';

/// Clase para representar información de una mesa
class TableInfo {
  final int tableNumber;
  final String macAddress;
  final String deviceName;
  final bool isActive;

  TableInfo({
    required this.tableNumber,
    required this.macAddress,
    required this.deviceName,
    required this.isActive,
  });

  factory TableInfo.fromJson(Map<String, dynamic> json) {
    return TableInfo(
      tableNumber: json['tableNumber'] as int,
      macAddress: json['macAddress'] as String,
      deviceName: json['deviceName'] as String? ?? 'Dispositivo desconocido',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tableNumber': tableNumber,
      'macAddress': macAddress,
      'deviceName': deviceName,
      'isActive': isActive,
    };
  }
}

/// Servicio para identificar mesas mediante direcciones MAC
class TableIdentificationService {
  static const String _endpoint = '/api/table/identify';

  /// Obtener información del dispositivo actual
  Future<Map<String, String>> getDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      Map<String, String> deviceData = {};

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceData = {
          'deviceId': androidInfo.id,
          'deviceName': '${androidInfo.brand} ${androidInfo.model}',
          'androidId': androidInfo.id,
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'version': androidInfo.version.release,
          'platform': 'Android',
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceData = {
          'deviceId': iosInfo.identifierForVendor ?? 'unknown',
          'deviceName': iosInfo.name,
          'model': iosInfo.model,
          'version': iosInfo.systemVersion,
          'platform': 'iOS',
        };
      } else {
        // Para web o desktop, usar valores por defecto
        deviceData = {
          'deviceId': 'web_device_${DateTime.now().millisecondsSinceEpoch}',
          'deviceName': 'Dispositivo Web',
          'platform': 'Web',
        };
      }

      // Intentar obtener MAC address (limitado en dispositivos móviles modernos)
      try {
        // En dispositivos móviles modernos, la MAC real no está disponible
        // Usaremos el deviceId como identificador único
        deviceData['macAddress'] = _generateMacFromDeviceId(
          deviceData['deviceId'] ?? '',
        );
      } catch (e) {
        print('⚠️ No se pudo obtener MAC address real: $e');
        deviceData['macAddress'] = _generateMacFromDeviceId(
          deviceData['deviceId'] ?? '',
        );
      }

      print('📱 Información del dispositivo obtenida:');
      print('   - Nombre: ${deviceData['deviceName']}');
      print('   - ID: ${deviceData['deviceId']}');
      print('   - MAC (generada): ${deviceData['macAddress']}');
      print('   - Plataforma: ${deviceData['platform']}');

      return deviceData;
    } catch (e) {
      print('❌ Error obteniendo información del dispositivo: $e');
      rethrow;
    }
  }

  /// Generar una MAC address basada en el device ID
  /// (Necesario porque los dispositivos modernos no permiten acceso a la MAC real)
  String _generateMacFromDeviceId(String deviceId) {
    if (deviceId.isEmpty) {
      deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Generar un hash simple y convertirlo a formato MAC
    final hash = deviceId.hashCode.toRadixString(16).padLeft(8, '0');
    final macParts = <String>[];

    for (int i = 0; i < hash.length && macParts.length < 6; i += 2) {
      final part = hash.substring(i, i + 2);
      macParts.add(part.padLeft(2, '0'));
    }

    // Completar con ceros si es necesario
    while (macParts.length < 6) {
      macParts.add('00');
    }

    return macParts.join(':').toUpperCase();
  }

  /// Identificar la mesa basada en la MAC del dispositivo
  Future<TableInfo?> identifyTable() async {
    try {
      print('🔍 Iniciando identificación de mesa...');

      // Obtener información del dispositivo
      final deviceInfo = await getDeviceInfo();
      final macAddress = deviceInfo['macAddress'] ?? '';
      final deviceName = deviceInfo['deviceName'] ?? 'Dispositivo desconocido';

      if (macAddress.isEmpty) {
        print('❌ No se pudo obtener MAC address del dispositivo');
        return null;
      }

      // Enviar solicitud al servidor
      final url = Uri.parse('${AppConfig.serverUrl}$_endpoint');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'macAddress': macAddress,
          'deviceName': deviceName,
          'deviceInfo': deviceInfo,
        }),
      );

      print('📡 Respuesta del servidor para identificación de mesa:');
      print('   - Status: ${response.statusCode}');
      print('   - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['table'] != null) {
          final tableInfo = TableInfo.fromJson(data['table']);
          print('✅ Mesa identificada: Mesa ${tableInfo.tableNumber}');
          return tableInfo;
        } else {
          print('⚠️ Dispositivo no registrado en ninguna mesa');
          print('   - MAC enviada: $macAddress');
          print('   - Mensaje: ${data['message'] ?? 'Sin mensaje'}');
          return null;
        }
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('   - Mensaje: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error en identificación de mesa: $e');
      return null;
    }
  }

  /// Registrar un dispositivo en una mesa específica (para administradores)
  Future<bool> registerDeviceToTable(
    int tableNumber,
    String macAddress,
    String deviceName,
  ) async {
    try {
      final url = Uri.parse('${AppConfig.serverUrl}/api/table/register');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'tableNumber': tableNumber,
          'macAddress': macAddress,
          'deviceName': deviceName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('❌ Error registrando dispositivo: $e');
      return false;
    }
  }

  /// Obtener todas las mesas registradas (para administradores)
  Future<List<TableInfo>> getAllTables() async {
    try {
      final url = Uri.parse('${AppConfig.serverUrl}/api/table/all');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['tables'] != null) {
          return (data['tables'] as List)
              .map((table) => TableInfo.fromJson(table))
              .toList();
        }
      }

      return [];
    } catch (e) {
      print('❌ Error obteniendo mesas: $e');
      return [];
    }
  }

  /// 🆕 NUEVO: Obtener estado de conexión actualizado con verificación de actividad real
  Future<List<TableInfo>> getTablesWithConnectionStatus() async {
    try {
      print('📊 Verificando estado real de conexión de dispositivos...');

      // Obtener todas las mesas configuradas
      final configuredTables = await getAllTables();

      if (configuredTables.isEmpty) {
        print('⚠️ No hay mesas configuradas');
        return [];
      }

      // Lista para almacenar mesas con estado actualizado
      List<TableInfo> tablesWithStatus = [];

      for (final table in configuredTables) {
        // Verificar si realmente hay un dispositivo conectado
        bool isReallyConnected = await _checkRealConnection(table.macAddress);

        // Crear nueva instancia con estado actualizado
        final updatedTable = TableInfo(
          tableNumber: table.tableNumber,
          macAddress: table.macAddress,
          deviceName: table.deviceName,
          isActive: isReallyConnected,
        );

        tablesWithStatus.add(updatedTable);

        print(
          '📱 Mesa ${table.tableNumber}: ${isReallyConnected ? "Conectada" : "Desconectada"}',
        );
      }

      return tablesWithStatus;
    } catch (e) {
      print('❌ Error verificando estado de conexión: $e');
      // Fallback: devolver mesas básicas
      return await getAllTables();
    }
  }

  /// Verificar si un dispositivo está realmente conectado
  Future<bool> _checkRealConnection(String macAddress) async {
    try {
      print('🔍 Verificando conexión REAL para MAC: $macAddress');

      // 🔄 MEJORADO: Usar el nuevo endpoint POST para verificación real
      final url = Uri.parse('${AppConfig.serverUrl}/api/table/debug/mac');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'macAddress': macAddress}),
          )
          .timeout(
            Duration(seconds: 8), // Un poco más de tiempo para conexión real
            onTimeout: () {
              print('⏰ Timeout verificando conexión para $macAddress');
              throw Exception('Timeout');
            },
          );

      print('📡 Response status para $macAddress: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isConnected =
            data['success'] == true &&
            data['found'] == true &&
            data['table']?['isActive'] == true;

        if (data['realTimeStatus'] != null) {
          final lastSeen = data['realTimeStatus']['lastSeenHuman'];
          print('📊 Estado detallado para $macAddress:');
          print('   - Conectado: $isConnected');
          print('   - Última actividad: $lastSeen');
          print(
            '   - Timeout: ${data['realTimeStatus']['timeoutMinutes']} minutos',
          );
        }

        print('✅ Verificación REAL para $macAddress: $isConnected');
        return isConnected;
      }

      // Si hay error del servidor, considerar desconectado
      print(
        '⚠️ Servidor respondió ${response.statusCode}, considerando desconectado',
      );
      return false;
    } catch (e) {
      print('❌ Error verificando conexión REAL para MAC $macAddress: $e');
      print('🔄 Sin conexión al servidor, considerando desconectado');

      // 🔄 CAMBIO IMPORTANTE: Sin fallback hardcodeado
      // Si no podemos verificar con el servidor, consideramos desconectado
      return false;
    }
  }

  /// Método para testing - obtener solo la MAC del dispositivo actual
  Future<String> getCurrentDeviceMac() async {
    try {
      final deviceInfo = await getDeviceInfo();
      return deviceInfo['macAddress'] ?? '';
    } catch (e) {
      print('❌ Error obteniendo MAC: $e');
      return '';
    }
  }
}
