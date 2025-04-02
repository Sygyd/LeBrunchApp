// chat_provider.dart
import 'package:flutter/foundation.dart';
import '/models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;

  List<ChatMessage> get messages => _messages;
  bool get isProcessing => _isProcessing;

  void addUserMessage(String text) {
    _messages.insert(0, ChatMessage(text: text, isUser: true));
    notifyListeners();
  }

  void addBotMessage(String text, {String? metadata}) {
    _messages.insert(
      0,
      ChatMessage(text: text, isUser: false, metadata: metadata),
    );
    notifyListeners();
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  // Limpiar conversación pero mantener el saludo inicial
  void resetConversation() {
    _messages.removeWhere((msg) => msg.isUser);
    notifyListeners();
  }

  List<Map<String, dynamic>> toJson() =>
      _messages.map((msg) => msg.toJson()).toList();
}
