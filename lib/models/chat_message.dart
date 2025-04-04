import 'package:flutter/material.dart';

enum MessageType {
  text,
  image,
  // Puedes expandir con más tipos si es necesario
}

enum MessageSender { user, support }

class ChatMessage {
  final String id;
  final String message;
  final String? imageUrl;
  final MessageType type;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.message,
    this.imageUrl,
    required this.type,
    required this.sender,
    required this.timestamp,
    this.isRead = false,
  });

  // Método para crear un mensaje de texto del usuario
  factory ChatMessage.fromUser({required String message, String? id}) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: MessageType.text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
  }

  // Método para crear un mensaje de texto del soporte
  factory ChatMessage.fromSupport({required String message, String? id}) {
    return ChatMessage(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: MessageType.text,
      sender: MessageSender.support,
      timestamp: DateTime.now(),
    );
  }

  // Color de burbuja según el remitente
  Color getBubbleColor(ThemeData theme) {
    return sender == MessageSender.user
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceVariant;
  }

  // Color de texto según el remitente
  Color getTextColor(ThemeData theme) {
    return sender == MessageSender.user
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;
  }

  // Alineación según el remitente
  Alignment getAlignment() {
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
      'type': type.toString(),
      'sender': sender.toString(),
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  // Crear desde JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      message: json['message'],
      imageUrl: json['imageUrl'],
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
    );
  }
}
