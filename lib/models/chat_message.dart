// chat_message.dart
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? metadata; // Para datos adicionales como IDs de platos

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'],
    isUser: json['isUser'],
    timestamp: DateTime.parse(json['timestamp']),
    metadata: json['metadata'],
  );
}
