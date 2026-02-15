import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';

class SquadMemberCard extends StatelessWidget {
  const SquadMemberCard({
    super.key,
    required this.member,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final UserModel member;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final bool isCooked = member.focusScore < 200;
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCooked
              ? AppSemanticColors.accent.withValues(alpha: 0.5)
              : AppSemanticColors.primaryText.withValues(alpha: 0.05),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(member.photoUrl, isCooked),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayNickname(member.nickname),
                  style: AppTheme.lgMedium.copyWith(
                    color: AppSemanticColors.primaryText,
                  ),
                ),
                Text(
                  member.fullName ?? member.email ?? '',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppSemanticColors.mutedText,
                  ),
                ),
                if (isCooked)
                  Text(
                    'Cooked',
                    style: AppTheme.smBold.copyWith(
                      color: AppSemanticColors.accentText,
                    ),
                  ),
              ],
            ),
          ),
          trailing ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    member.focusScore.toString(),
                    style: AppTheme.xlMedium.copyWith(
                      color: isCooked
                          ? AppSemanticColors.accentText
                          : AppSemanticColors.primaryText,
                    ),
                  ),
                  Text(
                    'Focus Score',
                    style: AppTheme.xsRegular.copyWith(
                      color: AppSemanticColors.mutedText,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, bool isPulse) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isPulse ? AppSemanticColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: AppSemanticColors.background,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? const Icon(Icons.person, color: AppSemanticColors.secondaryText)
            : null,
      ),
    );
  }

  String _displayNickname(String? nickname) {
    final normalized = (nickname ?? '').trim();
    if (normalized.isEmpty) return 'Unknown';
    if (normalized.length == 1) return normalized.toUpperCase();
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}
