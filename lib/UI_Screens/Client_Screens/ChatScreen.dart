import 'package:flutter/material.dart';
import 'dart:async';
import '../Shared/shared_chat_screen.dart';

class ChatScreen extends StatelessWidget {
  final StreamController<int>? pageStreamController;

  const ChatScreen({Key? key, this.pageStreamController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SharedChatScreen(
      isAdmin: false,
      pageStreamController: pageStreamController,
      currentIndex: 2,
    );
  }
}
