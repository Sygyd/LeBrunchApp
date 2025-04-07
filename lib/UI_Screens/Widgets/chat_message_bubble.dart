import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Si es un mensaje del sistema, lo mostramos centrado
    if (message.isFromSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                message.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Para mensajes normales (usuario o soporte)
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Column(
        crossAxisAlignment:
            message.sender == MessageSender.user
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
        children: [
          // Encabezado del mensaje
          if (message.sender == MessageSender.support)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Brunchy',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

          // Contenido del mensaje
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: _buildFormattedText(
              context,
              message.message,
              message.sender == MessageSender.user
                  ? theme.colorScheme.onBackground
                  : theme.colorScheme.onBackground,
            ),
          ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(fontSize: 10, color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  // Método para formatear texto con Markdown básico, emojis y tablas
  Widget _buildFormattedText(
    BuildContext context,
    String text,
    Color textColor,
  ) {
    final theme = Theme.of(context);

    // Comprueba si contiene una tabla
    if (text.contains('|') && text.contains('\n')) {
      return _buildTableOrFormattedText(context, text, textColor);
    }

    // Procesar formato normal de texto
    return RichText(text: _buildTextSpan(context, text, textColor));
  }

  // Procesa el formato de texto para generar TextSpans
  TextSpan _buildTextSpan(BuildContext context, String text, Color textColor) {
    final theme = Theme.of(context);

    // Lista para almacenar los diferentes segmentos de texto formateados
    List<InlineSpan> spans = [];

    // Expresiones regulares para diferentes formatos
    final boldPattern = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
    final italicPattern = RegExp(r'_(.*?)_');
    final codePattern = RegExp(r'`(.*?)`');

    // Estado actual del texto
    String remainingText = text;

    while (remainingText.isNotEmpty) {
      bool foundMatch = false;

      // Verifica negrita
      Match? boldMatch = boldPattern.firstMatch(remainingText);
      if (boldMatch != null) {
        // Añadir texto anterior al match
        if (boldMatch.start > 0) {
          spans.add(
            TextSpan(text: remainingText.substring(0, boldMatch.start)),
          );
        }

        // Añadir texto en negrita
        final boldText = boldMatch.group(1) ?? boldMatch.group(2) ?? '';
        spans.add(
          TextSpan(
            text: boldText,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );

        remainingText = remainingText.substring(boldMatch.end);
        foundMatch = true;
        continue;
      }

      // Verifica cursiva
      Match? italicMatch = italicPattern.firstMatch(remainingText);
      if (italicMatch != null) {
        // Añadir texto anterior al match
        if (italicMatch.start > 0) {
          spans.add(
            TextSpan(text: remainingText.substring(0, italicMatch.start)),
          );
        }

        // Añadir texto en cursiva
        final italicText = italicMatch.group(1) ?? '';
        spans.add(
          TextSpan(
            text: italicText,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        );

        remainingText = remainingText.substring(italicMatch.end);
        foundMatch = true;
        continue;
      }

      // Verifica código (monoespaciado)
      Match? codeMatch = codePattern.firstMatch(remainingText);
      if (codeMatch != null) {
        // Añadir texto anterior al match
        if (codeMatch.start > 0) {
          spans.add(
            TextSpan(text: remainingText.substring(0, codeMatch.start)),
          );
        }

        // Añadir texto en código
        final codeText = codeMatch.group(1) ?? '';
        spans.add(
          TextSpan(
            text: codeText,
            style: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: Colors.black12,
              letterSpacing: -0.5,
            ),
          ),
        );

        remainingText = remainingText.substring(codeMatch.end);
        foundMatch = true;
        continue;
      }

      // Si no se encontró ningún formato, añadir el texto restante
      if (!foundMatch) {
        spans.add(TextSpan(text: remainingText));
        break;
      }
    }

    return TextSpan(
      style: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        height: 1.4,
      ),
      children: spans,
    );
  }

  // Mantener el método para procesar tablas
  Widget _buildTableOrFormattedText(
    BuildContext context,
    String text,
    Color textColor,
  ) {
    // Implementación existente para tablas
    // ...

    // Si no es una tabla, mostrar como texto normal
    return Text(text, style: TextStyle(color: textColor));
  }
}
