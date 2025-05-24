import 'package:flutter/material.dart';
import '../Shared/shared_chat_screen.dart';

class AdminChatScreen extends StatelessWidget {
  const AdminChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const SharedChatScreen(isAdmin: true, currentIndex: 2);
  }
}
