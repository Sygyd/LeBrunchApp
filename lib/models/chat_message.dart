import 'package:flutter/material.dart';

enum MessageType {
  text,
  image,
  audio, // Nuevo tipo para mensajes de audio
  // Puedes expandir con más tipos si es necesario
}

enum MessageSender { user, support, system }

class ChatMessage {
  final String id;
  final String message;
  final String? imageUrl;
  final String? audioPath; // Nuevo campo para la ruta del archivo de audio
  final Duration? audioDuration; // Nuevo campo para la duración del audio
  final MessageType type;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isRead;
  String? messageId; // ID único para prevenir duplicación de mensajes

  ChatMessage({
    required this.id,
    required this.message,
    this.imageUrl,
    this.audioPath,
    this.audioDuration,
    required this.type,
    required this.sender,
    required this.timestamp,
    this.isRead = false,
    this.messageId,
  });

  // Método para crear un mensaje de texto del usuario
  factory ChatMessage.fromUser({
    required String message,
    String? id,
    String? messageId,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: MessageType.text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      messageId: messageId,
    );
  }

  // Método para crear un mensaje de audio del usuario
  factory ChatMessage.audioFromUser({
    required String audioPath,
    Duration? audioDuration,
    String? transcribedText,
    String? id,
    String? messageId,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: transcribedText ?? 'Mensaje de audio',
      audioPath: audioPath,
      audioDuration: audioDuration,
      type: MessageType.audio,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      messageId: messageId,
    );
  }

  // Método para crear un mensaje de texto del soporte
  factory ChatMessage.fromSupport({
    required String message,
    String? id,
    String? messageId,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: MessageType.text,
      sender: MessageSender.support,
      timestamp: DateTime.now(),
      messageId: messageId,
    );
  }

  // Método para crear un mensaje de texto del sistema
  factory ChatMessage.fromSystem({
    required String message,
    String? id,
    String? messageId,
  }) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: MessageType.text,
      sender: MessageSender.system,
      timestamp: DateTime.now(),
      messageId: messageId,
    );
  }

  // Verificar si el mensaje es del sistema
  bool get isFromSystem => sender == MessageSender.system;

  // Verificar si el mensaje es de soporte
  bool get isFromSupport => sender == MessageSender.support;

  // Verificar si el mensaje es de audio
  bool get isAudioMessage => type == MessageType.audio;

  // Color de burbuja según el remitente
  Color getBubbleColor(ThemeData theme) {
    if (sender == MessageSender.system) {
      return theme.colorScheme.tertiary.withOpacity(0.2);
    }
    return sender == MessageSender.user
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant;
  }

  // Color de texto según el remitente
  Color getTextColor(ThemeData theme) {
    if (sender == MessageSender.system) {
      return theme.colorScheme.tertiary;
    }
    return sender == MessageSender.user
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;
  }

  // Alineación según el remitente
  Alignment getAlignment() {
    if (sender == MessageSender.system) {
      return Alignment.center;
    }
    return sender == MessageSender.user
        ? Alignment.centerRight
        : Alignment.centerLeft;
  }

  // Convertir a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'imageUrl': imageUrl,
      'audioPath': audioPath,
      'audioDuration': audioDuration?.inMilliseconds,
      'type': type.toString(),
      'sender': sender.toString(),
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'messageId': messageId,
    };
  }

  // Crear desde JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      message: json['message'],
      imageUrl: json['imageUrl'],
      audioPath: json['audioPath'],
      audioDuration:
          json['audioDuration'] != null
              ? Duration(milliseconds: json['audioDuration'])
              : null,
      type: MessageType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => MessageType.text,
      ),
      sender: MessageSender.values.firstWhere(
        (e) => e.toString() == json['sender'],
        orElse: () => MessageSender.user,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      messageId: json['messageId'],
    );
  }
}
