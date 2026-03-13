import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/models/squad_log_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';

class SquadLogFeed extends StatelessWidget {
  final List<SquadLogModel> logs;
  final Future<void> Function(SquadLogModel log)? onSalute;
  final String? viewerUid;

  const SquadLogFeed({
    super.key,
    required this.logs,
    this.onSalute,
    this.viewerUid,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: Text(
            'No incidents logged. This silence is suspicious.',
            style: AppTheme.bodySmall.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      );
    }

    // NOTE: The parent should own the primary scroll. This list is dense and
    // uses shrinkWrap so it can live inside a sliver.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = logs[index];
        final isLast = index == logs.length - 1;

        return GestureDetector(
          onDoubleTap: onSalute != null ? () => onSalute!(log) : null,
          child: _TimelineRow(
            log: log,
            drawTail: !isLast,
            viewerUid: viewerUid,
          ),
        );
      },
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final SquadLogModel log;
  final bool drawTail;
  final String? viewerUid;

  const _TimelineRow({
    required this.log,
    required this.drawTail,
    required this.viewerUid,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accentForType(context, log.type);
    final icon = _iconForType(log.type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                  border: Border.all(color: accent.withValues(alpha: 0.40)),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: accent.withValues(alpha: 0.95),
                ),
              ),
              if (drawTail)
                Container(
                  width: 2,
                  height: 44,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: context.scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: context.scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.title.trim().isNotEmpty
                            ? log.title.trim()
                            : 'Event',
                        style: AppTheme.baseMedium.copyWith(
                          color: context.scheme.onSurface,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatTimestamp(log.timestamp),
                      style: AppTheme.labelSmall.copyWith(
                        color: context.colors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                if ((log.userName).trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Filed by ${log.userName.trim()}',
                    style: AppTheme.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
                ..._buildReactionRow(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static IconData _iconForType(String typeRaw) {
    final type = (typeRaw).trim().toLowerCase();
    switch (type) {
      case 'plea_request':
        return PhosphorIcons.megaphone();
      case 'verdict':
        return PhosphorIcons.gavel();
      case 'violation':
        return PhosphorIcons.warning();
      case 'regime_adopt':
        return PhosphorIcons.flag();
      default:
        return PhosphorIcons.receipt();
    }
  }

  static Color _accentForType(BuildContext context, String typeRaw) {
    final type = (typeRaw).trim().toLowerCase();
    switch (type) {
      case 'plea_request':
        return context.scheme.primary;
      case 'verdict':
        return context.scheme.onSurface;
      case 'violation':
        return context.colors.danger;
      case 'regime_adopt':
        return context.colors.success;
      default:
        return context.colors.textSecondary;
    }
  }

  static String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (sameDay) return '$h:$m';
    final mon = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$mon/$day $h:$m';
  }

  List<Widget> _buildReactionRow(BuildContext context) {
    int saluteCount = 0;
    for (final reaction in log.reactions.values) {
      if (reaction.trim().toLowerCase() == 'salute') {
        saluteCount += 1;
      }
    }
    if (saluteCount <= 0) return const <Widget>[];

    final hasViewerSaluted =
        viewerUid != null &&
        viewerUid!.trim().isNotEmpty &&
        (log.reactions[viewerUid!]?.trim().toLowerCase() == 'salute');
    final accent = hasViewerSaluted
        ? context.scheme.primary
        : context.colors.textSecondary;

    return <Widget>[
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SALUTE',
              style: AppTheme.labelSmall.copyWith(
                color: accent,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$saluteCount',
              style: AppTheme.smBold.copyWith(color: accent),
            ),
          ],
        ),
      ),
    ];
  }
}
