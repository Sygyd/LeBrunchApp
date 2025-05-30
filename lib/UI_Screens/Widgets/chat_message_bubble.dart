import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/chat_message.dart';
import 'audio_message_widget.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int? userRole; // Nuevo parámetro para el rol del usuario

  const ChatMessageBubble({super.key, required this.message, this.userRole});

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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                message.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    // Determinar si es mensaje del usuario o de Brunchy
    final isUserMessage = message.sender == MessageSender.user;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        mainAxisAlignment:
            isUserMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar de Brunchy (solo para mensajes de soporte)
          if (!isUserMessage) ...[
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.restaurant_menu,
                size: 20,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],

          // Contenedor del mensaje
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: Column(
                crossAxisAlignment:
                    isUserMessage
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  // Nombre del remitente (solo para Brunchy)
                  if (!isUserMessage)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        'Brunchy Asistente',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),

                  // Bubble del mensaje
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: message.isAudioMessage ? 6 : 14,
                      vertical: message.isAudioMessage ? 6 : 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isUserMessage
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft:
                            isUserMessage
                                ? const Radius.circular(18)
                                : const Radius.circular(4),
                        bottomRight:
                            isUserMessage
                                ? const Radius.circular(4)
                                : const Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border:
                          isUserMessage
                              ? null
                              : Border.all(
                                color: theme.colorScheme.outline.withOpacity(
                                  0.15,
                                ),
                                width: 1,
                              ),
                    ),
                    child: _buildMessageContent(context, isUserMessage),
                  ),

                  // Timestamp
                  Padding(
                    padding: EdgeInsets.only(
                      top: 3,
                      left: isUserMessage ? 0 : 4,
                      right: isUserMessage ? 4 : 0,
                    ),
                    child: Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.outline.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar del usuario (solo para mensajes del usuario)
          if (isUserMessage) ...[
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getUserRoleColor(theme),
                    _getUserRoleColor(theme).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getUserRoleColor(theme).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getUserRoleIcon(),
                size: 20,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Obtener ícono según el rol del usuario
  IconData _getUserRoleIcon() {
    switch (userRole) {
      case 0: // Administrador
        return Icons.admin_panel_settings;
      case 1: // Cliente
        return Icons.person;
      case 2: // Cocinero
        return Icons.restaurant;
      case 3: // Barista
        return Icons.coffee;
      default:
        return Icons.person;
    }
  }

  // Obtener color según el rol del usuario
  Color _getUserRoleColor(ThemeData theme) {
    switch (userRole) {
      case 0:
      case 1:
      case 2:
      case 3: // Administrador
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.primary;
    }
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
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
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
            style: TextStyle(fontStyle: FontStyle.italic, color: textColor),
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
              backgroundColor: textColor.withOpacity(0.1),
              color: textColor,
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
        height: 1.5,
        fontSize: 14.5,
        letterSpacing: 0.2,
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
    final theme = Theme.of(context);

    // Verificar si realmente es una tabla
    final lines = text.split('\n');
    bool isTable = false;

    // Una tabla debe tener al menos 2 líneas con |
    if (lines.length >= 2) {
      int linesWithPipes = 0;
      for (String line in lines) {
        if (line.trim().contains('|')) {
          linesWithPipes++;
        }
      }
      isTable = linesWithPipes >= 2;
    }

    if (isTable) {
      // Procesar como tabla
      List<Widget> tableRows = [];

      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        // Saltar líneas de separación (solo guiones y |)
        if (line.replaceAll(RegExp(r'[-|\s]'), '').isEmpty) continue;

        if (line.contains('|')) {
          List<String> cells =
              line
                  .split('|')
                  .map((cell) => cell.trim())
                  .where((cell) => cell.isNotEmpty)
                  .toList();

          if (cells.isNotEmpty) {
            tableRows.add(
              Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: textColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children:
                      cells
                          .map(
                            (cell) => Expanded(
                              child: Text(
                                cell,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight:
                                      i == 0
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            );
          }
        }
      }

      if (tableRows.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tableRows,
        );
      }
    }

    // Si no es una tabla válida, mostrar como texto normal
    return RichText(text: _buildTextSpan(context, text, textColor));
  }

  Widget _buildMessageContent(BuildContext context, bool isUserMessage) {
    final theme = Theme.of(context);

    if (message.isAudioMessage && message.audioPath != null) {
      return AudioMessageWidget(
        audioPath: message.audioPath!,
        isUserMessage: isUserMessage,
        duration: message.audioDuration,
      );
    } else {
      return _buildFormattedText(
        context,
        message.message,
        isUserMessage
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
      );
    }
  }
}
