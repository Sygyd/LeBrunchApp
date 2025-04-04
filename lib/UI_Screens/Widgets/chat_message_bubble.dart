import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleColor = message.getBubbleColor(theme);
    final textColor = message.getTextColor(theme);
    final alignment = message.getAlignment();
    final isUser = message.sender == MessageSender.user;

    // Formatear la hora del mensaje
    final formattedTime = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 20 : 4),
            topRight: Radius.circular(isUser ? 4 : 20),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              offset: const Offset(0, 2),
              blurRadius: 4.0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Si es un mensaje de texto
            if (message.type == MessageType.text)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  message.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontFamily: 'MADE TOMMY',
                    height: 1.4,
                  ),
                ),
              ),

            // Si es una imagen (puedes expandir esto si necesitas más tipos)
            if (message.type == MessageType.image && message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: 200,
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                  ),
                  child: Image.network(
                    message.imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: SizedBox(
                          height: 100,
                          width: 100,
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        color: theme.colorScheme.surfaceVariant,
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Marca de tiempo
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4, left: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formattedTime,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: textColor.withOpacity(0.7),
                      fontFamily: 'MADE TOMMY',
                    ),
                  ),
                  if (isUser) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 12,
                      color:
                          message.isRead
                              ? theme.colorScheme.onPrimary.withOpacity(0.7)
                              : theme.colorScheme.onPrimary.withOpacity(0.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
