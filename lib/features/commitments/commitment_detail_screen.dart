import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/schedule_model.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/taper_plan_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import 'commitment_presentation.dart';

class CommitmentDetailScreen extends StatefulWidget {
  const CommitmentDetailScreen({super.key, required this.commitment});
  final CommitmentViewModel commitment;

  @override
  State<CommitmentDetailScreen> createState() => _CommitmentDetailScreenState();
}

class _CommitmentDetailScreenState extends State<CommitmentDetailScreen> {
  bool _working = false;
  late final Future<List<String>> _appNamesFuture;

  CommitmentViewModel get commitment => widget.commitment;

  @override
  void initState() {
    super.initState();
    _appNamesFuture = _loadAppNames();
  }

  Future<List<String>> _loadAppNames() async {
    final apps = await AppDiscoveryService.getApps();
    final names = {for (final app in apps) app.packageName: app.name};
    return commitment.targetApps
        .map((packageName) => names[packageName] ?? packageName)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final schedule = commitment.sourceSchedule;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commitment'),
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(PhosphorIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            RevokeSpacing.lg,
            RevokeSpacing.sm,
            RevokeSpacing.lg,
            RevokeSpacing.xxl,
          ),
          children: [
            Text(commitment.name, style: context.text.headlineSmall),
            const SizedBox(height: RevokeSpacing.sm),
            Row(
              children: [
                RevokePill(
                  label: commitment.typeLabel,
                  color: context.colors.accent,
                  icon: commitment.isReduce
                      ? PhosphorIcons.trendDown
                      : PhosphorIcons.shieldCheck,
                ),
                const SizedBox(width: RevokeSpacing.sm),
                RevokePill(
                  label: commitment.statusLabel,
                  color: _statusColor(context),
                ),
              ],
            ),
            const SizedBox(height: RevokeSpacing.xl),
            const RevokeSectionHeader(title: 'Current state'),
            const SizedBox(height: RevokeSpacing.sm),
            RevokeSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(commitment.summary, style: context.text.titleMedium),
                  if (commitment.nextTransition != null) ...[
                    const SizedBox(height: RevokeSpacing.sm),
                    Text(
                      'Next transition · ${commitment.nextTransition}',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: RevokeSpacing.xl),
            const RevokeSectionHeader(title: 'Plan'),
            const SizedBox(height: RevokeSpacing.sm),
            RevokeSurface(child: _buildPlan(context, schedule)),
            const SizedBox(height: RevokeSpacing.xl),
            RevokeButton(
              label: 'Back with Credits',
              icon: PhosphorIcons.lock,
              variant: RevokeButtonVariant.secondary,
              onPressed: commitment.isActive
                  ? () => context.push('/commitment/back', extra: commitment)
                  : null,
            ),
            const SizedBox(height: RevokeSpacing.xl),
            const RevokeSectionHeader(title: 'Override authority'),
            const SizedBox(height: RevokeSpacing.sm),
            RevokeSurface(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose how a short access request is decided for this Commitment.',
                      style: context.text.bodySecondary,
                    ),
                  ),
                  const SizedBox(width: RevokeSpacing.md),
                  IconButton(
                    tooltip: 'Configure Override Authority',
                    icon: Icon(PhosphorIcons.caretRight),
                    onPressed: () => context.push(
                      '/commitment/override-policy',
                      extra: commitment,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RevokeSpacing.xl),
            const RevokeSectionHeader(title: 'Apps'),
            const SizedBox(height: RevokeSpacing.sm),
            RevokeSurface(
              child: FutureBuilder<List<String>>(
                future: _appNamesFuture,
                builder: (context, snapshot) {
                  final names = snapshot.data ?? commitment.targetApps;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: names
                        .map(
                          (name) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: RevokeSpacing.sm,
                            ),
                            child: Text(name, style: context.text.bodyLarge),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
            if (commitment.isLegacyAmbiguous) ...[
              const SizedBox(height: RevokeSpacing.lg),
              RevokeSurface(
                color: context.colors.warning.withValues(alpha: 0.10),
                child: Text(
                  'This existing Commitment needs review before it can be represented fully in v2.',
                  style: context.text.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: RevokeSpacing.xxl),
            RevokeButton(
              label: 'Edit Commitment',
              icon: PhosphorIcons.pencilSimple,
              onPressed: () =>
                  context.push('/commitment/edit', extra: commitment),
            ),
            if (!commitment.isReduce &&
                (commitment.status == CommitmentStatus.active ||
                    commitment.status == CommitmentStatus.paused)) ...[
              const SizedBox(height: RevokeSpacing.sm),
              RevokeButton(
                label: commitment.status == CommitmentStatus.active
                    ? 'Pause Commitment'
                    : 'Resume Commitment',
                variant: RevokeButtonVariant.secondary,
                loading: _working,
                onPressed: _toggle,
              ),
            ],
            const SizedBox(height: RevokeSpacing.sm),
            RevokeButton(
              label: 'End Commitment',
              variant: RevokeButtonVariant.tertiary,
              onPressed: _working ? null : _end,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlan(BuildContext context, ScheduleModel schedule) {
    final plan = commitment.taperPlan;
    if (plan != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reduce from ${_minutes(plan.baselineDailyMinutes)} to ${_minutes(plan.targetDailyMinutes)} per day.',
            style: context.text.bodyLarge,
          ),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            '${plan.durationDays} days · Day ${plan.dayIndexFor(DateTime.now()) + 1}',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      );
    }
    if (schedule.type == ScheduleType.timeBlock && schedule.blocks.isNotEmpty) {
      final block = schedule.blocks.first;
      return Text(
        'Stay off from ${block.startTime.format(context)} to ${block.endTime.format(context)} on ${_days(schedule.days)}.',
        style: context.text.bodyLarge,
      );
    }
    return Text(
      'Use selected apps for no more than ${_minutes(schedule.durationLimit?.inMinutes ?? 0)} on ${_days(schedule.days)}.',
      style: context.text.bodyLarge,
    );
  }

  Future<void> _toggle() async {
    setState(() => _working = true);
    await ScheduleService.toggleSchedule(commitment.sourceSchedule.id);
    if (mounted) {
      setState(() => _working = false);
      context.pop(true);
    }
  }

  Future<void> _end() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Commitment?'),
        content: const Text('Revoke will stop enforcing this Commitment.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Commitment'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    if (commitment.taperPlan != null) {
      await TaperPlanService.endPlanLocalFirst(commitment.taperPlan!);
    } else {
      for (final id in commitment.sourceScheduleIds) {
        await ScheduleService.deleteSchedule(id);
      }
    }
    if (mounted) context.pop(true);
  }

  Color _statusColor(BuildContext context) {
    switch (commitment.status) {
      case CommitmentStatus.needsAttention:
        return context.colors.warning;
      case CommitmentStatus.paused:
        return context.colors.textMuted;
      case CommitmentStatus.completed:
        return context.colors.success;
      case CommitmentStatus.active:
      case CommitmentStatus.upcoming:
        return context.colors.accent;
    }
  }

  static String _minutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '$remainder minutes';
    if (remainder == 0) return '$hours hours';
    return '$hours hours $remainder minutes';
  }

  static String _days(List<int> days) {
    if (days.length == 7) return 'every day';
    const labels = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days.map((day) => labels[day - 1]).join(', ');
  }
}
