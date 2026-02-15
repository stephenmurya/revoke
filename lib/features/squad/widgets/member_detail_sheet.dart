import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/schedule_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/regime_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';

class MemberDetailSheet extends StatelessWidget {
  final UserModel member;

  const MemberDetailSheet({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final handle = _handle(member);
    final ringColor = _ringColor(context, member);
    final scoreDisplay = member.focusScore.clamp(0, 1000);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: context.scheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'RAP SHEET',
                      style: AppTheme.smBold.copyWith(
                        color: context.colors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  _header(
                    context,
                    handle: handle,
                    ringColor: ringColor,
                    scoreDisplay: scoreDisplay,
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: 'ACTIVE PROTOCOLS',
                    subtitle: 'Enabled regimes for this member.',
                    child: FutureBuilder<List<ScheduleModel>>(
                      future: RegimeService.getRegimesForUser(member.uid),
                      builder: (context, snap) {
                        final regimes = snap.data ?? const <ScheduleModel>[];
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        if (regimes.isEmpty) {
                          return _emptyLine(context, 'No active protocols.');
                        }
                        final active =
                            regimes.where((r) => r.isActive).toList();
                        final list = active.isEmpty ? regimes : active;
                        return Column(
                          children: [
                            for (final r in list.take(6))
                              _bulletLine(
                                context,
                                r.name.trim().isEmpty ? 'REGIME' : r.name,
                              ),
                            if (list.length > 6)
                              _mutedLine(context, '+ ${list.length - 6} more'),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'BLACKLIST',
                    subtitle: 'Consolidated blocked apps from protocols.',
                    child: FutureBuilder<List<ScheduleModel>>(
                      future: RegimeService.getRegimesForUser(member.uid),
                      builder: (context, snap) {
                        final regimes = snap.data ?? const <ScheduleModel>[];
                        final apps = <String>{};
                        for (final r in regimes) {
                          apps.addAll(r.targetApps.map((e) => e.trim()).where((e) => e.isNotEmpty));
                        }
                        if (snap.connectionState == ConnectionState.waiting) {
                          return _mutedLine(context, 'Assembling blacklist...');
                        }
                        if (apps.isEmpty) {
                          return _emptyLine(context, 'Blacklist empty.');
                        }
                        final count = apps.length;
                        final preview = apps.take(2).join(', ');
                        return _mutedLine(
                          context,
                          count <= 2 ? preview : '$preview + ${count - 2} others',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Section(
                    title: 'CRIMINAL RECORD',
                    subtitle: 'Plea stats within your current squad.',
                    child: FutureBuilder<_PleaStats?>(
                      future: _loadPleaStatsForCurrentSquad(),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return _mutedLine(context, 'Querying record...');
                        }
                        final stats = snap.data;
                        if (stats == null) {
                          return _emptyLine(context, 'No record available.');
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _statCard(context, 'TOTAL', '${stats.total}'),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statCard(
                                context,
                                'APPROVED',
                                '${stats.approved}',
                                accent: context.colors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statCard(
                                context,
                                'REJECTED',
                                '${stats.rejected}',
                                accent: context.colors.danger,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required String handle,
    required Color ringColor,
    required int scoreDisplay,
  }) {
    final hasPhoto = (member.photoUrl ?? '').trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.scheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ringColor.withValues(alpha: 0.95),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.14),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: hasPhoto
                  ? Image(
                      image: CachedNetworkImageProvider(member.photoUrl!.trim()),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Center(
                        child: Text(
                          handle.isNotEmpty ? handle[0].toUpperCase() : 'U',
                          style: AppTheme.xlMedium.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '@$handle',
            style: AppTheme.h2.copyWith(color: context.scheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            (member.fullName ?? member.email ?? '').toString().trim(),
            style: AppTheme.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          Text(
            '$scoreDisplay',
            style: AppTheme.size5xlBold.copyWith(
              color: context.scheme.primary,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'FOCUS SCORE',
            style: AppTheme.labelSmall.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Future<_PleaStats?> _loadPleaStatsForCurrentSquad() async {
    final current = AuthService.currentUser;
    if (current == null) return null;
    final currentUserData = await AuthService.getUserData();
    final squadId = (currentUserData?['squadId'] as String?)?.trim() ?? '';
    if (squadId.isEmpty) return null;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('pleas')
          .where('squadId', isEqualTo: squadId)
          .where('userId', isEqualTo: member.uid)
          .get();

      int total = 0;
      int approved = 0;
      int rejected = 0;
      for (final doc in snap.docs) {
        total += 1;
        final status = (doc.data()['status'] ?? '').toString().toLowerCase();
        if (status == 'approved') approved += 1;
        if (status == 'rejected') rejected += 1;
      }
      return _PleaStats(total: total, approved: approved, rejected: rejected);
    } catch (_) {
      return null;
    }
  }

  static Widget _statCard(
    BuildContext context,
    String label,
    String value, {
    Color? accent,
  }) {
    final c = accent ?? context.scheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelSmall.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.lgBold.copyWith(color: c.withValues(alpha: 0.95)),
          ),
        ],
      ),
    );
  }

  static Widget _bulletLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.scheme.primary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(
                color: context.scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _mutedLine(BuildContext context, String text) {
    return Text(
      text,
      style: AppTheme.bodySmall.copyWith(color: context.colors.textSecondary),
    );
  }

  static Widget _emptyLine(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.scheme.outlineVariant,
        ),
      ),
      child: Text(
        text,
        style: AppTheme.bodySmall.copyWith(color: context.colors.textSecondary),
      ),
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
        return context.colors.textSecondary.withValues(alpha: 0.55);
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

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.smBold.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PleaStats {
  final int total;
  final int approved;
  final int rejected;

  const _PleaStats({
    required this.total,
    required this.approved,
    required this.rejected,
  });
}
