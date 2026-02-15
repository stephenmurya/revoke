import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';
import 'member_detail_sheet.dart';

class SquadRosterStrip extends StatelessWidget {
  final List<UserModel> members;
  final String? highlightUserId;
  final void Function(UserModel user)? onMemberTap;

  const SquadRosterStrip({
    super.key,
    required this.members,
    this.highlightUserId,
    this.onMemberTap,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 124,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: members.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final user = members[index];
          final ringColor = _ringColor(context, user);
          final isHighlighted =
              highlightUserId != null && user.uid == highlightUserId;

          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              if (onMemberTap != null) {
                onMemberTap!(user);
                return;
              }
              _showMemberDetail(context, user);
            },
            child: Container(
              width: 86,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isHighlighted
                      ? context.colors.accent.withValues(alpha: 0.40)
                      : context.colors.textPrimary.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusRingAvatar(
                    photoUrl: user.photoUrl,
                    fallbackText: _handle(user),
                    ringColor: ringColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '@${_handle(user)}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (context.text.labelMedium ?? AppTheme.smMedium).copyWith(
                      color: context.colors.textSecondary,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ScorePill(score: user.focusScore),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _showMemberDetail(
    BuildContext context,
    UserModel user,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.92,
          child: MemberDetailSheet(member: user),
        );
      },
    );
  }

  static Color _ringColor(BuildContext context, UserModel user) {
    final status = (user.currentStatus ?? 'idle').trim().toLowerCase();
    switch (status) {
      case 'locked_in':
        return context.colors.success;
      case 'vulnerable':
        return context.colors.danger;
      case 'idle':
      default:
        return context.colors.textSecondary.withValues(alpha: 0.70);
    }
  }

  static String _handle(UserModel user) {
    final nick = (user.nickname ?? '').trim();
    if (nick.isNotEmpty) return nick;
    final full = (user.fullName ?? '').trim();
    if (full.isNotEmpty) return full.split(' ').first;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'member';
  }

}

class _StatusRingAvatar extends StatelessWidget {
  final String? photoUrl;
  final String fallbackText;
  final Color ringColor;

  const _StatusRingAvatar({
    required this.photoUrl,
    required this.fallbackText,
    required this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (photoUrl ?? '').trim().isNotEmpty;

    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor.withValues(alpha: 0.95), width: 2),
        boxShadow: [
          BoxShadow(
            color: ringColor.withValues(alpha: 0.12),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.colors.background,
          border: Border.all(
            color: context.colors.textPrimary.withValues(alpha: 0.10),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasPhoto
            ? Image(
                image: CachedNetworkImageProvider(photoUrl!.trim()),
                fit: BoxFit.cover,
              )
            : Center(
                child: Text(
                  fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : 'U',
                  style: (context.text.labelMedium ?? AppTheme.smBold).copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int score; // 0-1000

  const _ScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 1000);
    final Color base = clamped >= 800
        ? context.colors.success
        : (clamped >= 500 ? context.colors.warning : context.colors.danger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: base.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$clamped',
        style: (context.text.labelMedium ?? AppTheme.smBold).copyWith(
          color: base.withValues(alpha: 0.95),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
