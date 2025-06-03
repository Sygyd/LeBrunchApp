import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Configuración para Android
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuración para iOS (si se usa en el futuro)
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestCriticalPermission: true,
            requestProvisionalPermission: true,
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Solicitar permisos para Android 13+
      if (Platform.isAndroid) {
        await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }

      print('✅ NotificationService inicializado correctamente');
    } catch (e) {
      print('❌ Error al inicializar NotificationService: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    final String? payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      _openFile(payload);
    }
  }

  static Future<void> _openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final result = await OpenFile.open(filePath);
        print('📂 Resultado al abrir archivo: ${result.message}');

        if (result.type != ResultType.done) {
          print('⚠️ No se pudo abrir el archivo: ${result.message}');
        }
      } else {
        print('❌ Archivo no encontrado: $filePath');
      }
    } catch (e) {
      print('❌ Error al abrir archivo: $e');
    }
  }

  static Future<void> showPdfDownloadedNotification({
    required String fileName,
    required String filePath,
  }) async {
    try {
      final AndroidNotificationDetails
      androidDetails = AndroidNotificationDetails(
        'pdf_downloads',
        'Descargas de PDF',
        channelDescription: 'Notificaciones para descargas de reportes PDF',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: const Color.fromARGB(255, 62, 166, 155), // Color verde del tema
        playSound: true,
        enableVibration: true,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '📄 Reporte descargado',
        'Toca para abrir: $fileName',
        platformChannelSpecifics,
        payload: filePath,
      );

      print('✅ Notificación mostrada para: $fileName');
    } catch (e) {
      print('❌ Error al mostrar notificación: $e');
    }
  }

  static Future<void> showDownloadProgressNotification({
    required int id,
    required String title,
    required String message,
    required int progress,
    required int maxProgress,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'pdf_progress',
            'Progreso de descarga',
            channelDescription: 'Progreso de generación de reportes PDF',
            importance: Importance.low,
            priority: Priority.low,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: maxProgress,
            progress: progress,
            playSound: false,
            enableVibration: false,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(id, title, message, platformChannelSpecifics);
    } catch (e) {
      print('❌ Error al mostrar notificación de progreso: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
    } catch (e) {
      print('❌ Error al cancelar notificación: $e');
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      print('❌ Error al cancelar todas las notificaciones: $e');
    }
  }

  // Función de prueba para verificar notificaciones
  static Future<void> showTestNotification() async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'test_channel',
            'Prueba de notificaciones',
            channelDescription: 'Canal de prueba para verificar notificaciones',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidDetails,
      );

      await _notifications.show(
        999999,
        '🔔 Notificación de prueba',
        'Si puedes ver esto, las notificaciones están funcionando',
        platformChannelSpecifics,
      );

      print('✅ Notificación de prueba enviada');
    } catch (e) {
      print('❌ Error al mostrar notificación de prueba: $e');
    }
  }
}
