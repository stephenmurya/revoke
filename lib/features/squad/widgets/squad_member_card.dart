import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';

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
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCooked
              ? context.scheme.primary.withValues(alpha: 0.55)
              : context.scheme.outlineVariant,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(context, member.photoUrl, isCooked),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayNickname(member.nickname),
                  style: AppTheme.lgMedium.copyWith(
                    color: context.scheme.onSurface,
                  ),
                ),
                Text(
                  member.fullName ?? member.email ?? '',
                  style: AppTheme.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                if (isCooked)
                  Text(
                    'Cooked',
                    style: AppTheme.smBold.copyWith(
                      color: context.scheme.primary,
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
                          ? context.scheme.primary
                          : context.scheme.onSurface,
                    ),
                  ),
                  Text(
                    'Focus Score',
                    style: AppTheme.xsRegular.copyWith(
                      color: context.colors.textSecondary,
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

  Widget _buildAvatar(BuildContext context, String? photoUrl, bool isPulse) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isPulse ? context.scheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: context.scheme.surface,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? Icon(Icons.person, color: context.colors.textSecondary)
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
