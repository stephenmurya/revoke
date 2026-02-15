import 'package:flutter/material.dart';

import '../../../core/models/plea_message_model.dart';
import '../../../core/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onSwipeReply,
  });

  final PleaMessageModel message;
  final bool isMine;
  final VoidCallback? onSwipeReply;

  bool get _isArchitect =>
      message.senderId == 'THE_ARCHITECT' || message.isSystem;

  @override
  Widget build(BuildContext context) {
    final canReply = onSwipeReply != null;
    final isArchitect = _isArchitect;
    final alignment = isArchitect
        ? Alignment.center
        : (isMine ? Alignment.centerRight : Alignment.centerLeft);

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (!canReply) return;
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 220) {
            onSwipeReply?.call();
          }
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: _bubbleDecoration(isArchitect),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isArchitect)
                Text(
                  'THE ARCHITECT',
                  style: AppTheme.labelSmall.copyWith(
                    color: const Color(0xFFFFD54F),
                    letterSpacing: 1.1,
                  ),
                )
              else if (!isMine)
                Text(
                  message.senderName,
                  style: AppTheme.labelSmall.copyWith(
                    color: AppSemanticColors.accentText,
                  ),
                ),
              Text(
                message.text,
                style: AppTheme.bodyMedium.copyWith(
                  color: isArchitect
                      ? const Color(0xFFFFF3C4)
                      : (isMine
                            ? AppSemanticColors.inverseText
                            : AppSemanticColors.primaryText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _bubbleDecoration(bool isArchitect) {
    if (isArchitect) {
      return BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.2),
      );
    }
    if (isMine) {
      return AppTheme.chatBubbleUserDecoration;
    }
    return AppTheme.chatBubbleOtherDecoration;
  }
}
