import 'package:flutter/material.dart';

import '../../../core/models/plea_message_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';

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
          decoration: _bubbleDecoration(context, isArchitect),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isArchitect)
                Text(
                  'THE ARCHITECT',
                  style: AppTheme.labelSmall.copyWith(
                    color: context.colors.warning,
                    letterSpacing: 1.1,
                  ),
                )
              else if (!isMine)
                Text(
                  message.senderName,
                  style: AppTheme.labelSmall.copyWith(
                    color: context.scheme.primary,
                  ),
                ),
              Text(
                message.text,
                style: AppTheme.bodyMedium.copyWith(
                  color: isArchitect
                      ? context.scheme.onSurface.withValues(alpha: 0.92)
                      : (isMine
                            ? context.scheme.onPrimary
                            : context.scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _bubbleDecoration(BuildContext context, bool isArchitect) {
    if (isArchitect) {
      return BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.warning, width: 1.2),
      );
    }
    if (isMine) {
      return BoxDecoration(
        color: context.scheme.primary,
        borderRadius: BorderRadius.circular(16),
      );
    }
    return BoxDecoration(
      color: context.scheme.surface,
      border: Border.all(color: context.scheme.outlineVariant, width: 1),
      borderRadius: BorderRadius.circular(16),
    );
  }
}
