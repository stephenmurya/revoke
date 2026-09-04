import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/schedule_model.dart';
import '../../core/models/taper_plan_model.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/taper_plan_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import 'commitment_presentation.dart';

class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen> {
  late final Stream<List<ScheduleModel>> _schedulesStream;
  StreamSubscription<List<ScheduleModel>>? _subscription;
  List<ScheduleModel> _schedules = const <ScheduleModel>[];
  TaperPlanModel? _taperPlan;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _schedulesStream = ScheduleService.watchSchedules();
    _subscription = _schedulesStream.listen(
      (schedules) {
        if (!mounted) return;
        setState(() {
          _schedules = schedules;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = error;
        });
      },
    );
    _loadTaperPlan();
  }

  Future<void> _loadTaperPlan() async {
    final plan = await TaperPlanService.getActivePlan();
    if (!mounted) return;
    setState(() => _taperPlan = plan);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _schedules.isEmpty) {
      return const RevokeLoadingState(label: 'Loading Commitments');
    }
    if (_error != null && _schedules.isEmpty) {
      return RevokeErrorState(
        message: 'Commitments could not be loaded.',
        onRetry: _reload,
      );
    }

    final commitments = CommitmentPresentationAdapter.fromSchedules(
      _schedules,
      taperPlan: _taperPlan,
    );
    final active = commitments
        .where(
          (item) =>
              item.status == CommitmentStatus.active ||
              item.status == CommitmentStatus.needsAttention,
        )
        .toList();
    final upcoming = commitments
        .where((item) => item.status == CommitmentStatus.upcoming)
        .toList();
    final paused = commitments
        .where((item) => item.status == CommitmentStatus.paused)
        .toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        color: context.colors.accent,
        child: ListView(
          key: const PageStorageKey<String>('commitments-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            RevokeSpacing.lg,
            RevokeSpacing.sm,
            RevokeSpacing.lg,
            RevokeSpacing.xxl,
          ),
          children: [
            Text(
              'Plans you have chosen to keep.',
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: RevokeSpacing.xl),
            if (commitments.isEmpty)
              _buildEmptyState(context)
            else ...[
              if (active.isNotEmpty) ...[
                const RevokeSectionHeader(title: 'Active'),
                const SizedBox(height: RevokeSpacing.sm),
                _CommitmentGroup(items: active, onTap: _openDetail),
              ],
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: RevokeSpacing.xxl),
                const RevokeSectionHeader(title: 'Upcoming'),
                const SizedBox(height: RevokeSpacing.sm),
                _CommitmentGroup(items: upcoming, onTap: _openDetail),
              ],
              if (paused.isNotEmpty) ...[
                const SizedBox(height: RevokeSpacing.xxl),
                const RevokeSectionHeader(title: 'Paused'),
                const SizedBox(height: RevokeSpacing.sm),
                _CommitmentGroup(items: paused, onTap: _openDetail),
              ],
            ],
            const SizedBox(height: RevokeSpacing.xxl),
            RevokeButton(
              label: 'Create Commitment',
              icon: PhosphorIcons.plus,
              onPressed: () => context.push('/commitment/new'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return RevokeSurface(
      padding: const EdgeInsets.all(RevokeSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.compass,
            size: RevokeIconSizes.feature,
            color: context.colors.accent,
          ),
          const SizedBox(height: RevokeSpacing.lg),
          Text('No Commitments yet', style: context.text.titleLarge),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            'Choose something you want to change and let Revoke help you keep it.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reload() async {
    await _loadTaperPlan();
    final schedules = await ScheduleService.getSchedules();
    if (!mounted) return;
    setState(() => _schedules = schedules);
  }

  void _openDetail(CommitmentViewModel commitment) {
    context.push('/commitment/detail', extra: commitment);
  }
}

class _CommitmentGroup extends StatelessWidget {
  const _CommitmentGroup({required this.items, required this.onTap});

  final List<CommitmentViewModel> items;
  final ValueChanged<CommitmentViewModel> onTap;

  @override
  Widget build(BuildContext context) {
    return RevokeSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _CommitmentRow(item: items[index], onTap: onTap),
            if (index < items.length - 1) const RevokeDivider(),
          ],
        ],
      ),
    );
  }
}

class _CommitmentRow extends StatelessWidget {
  const _CommitmentRow({required this.item, required this.onTap});

  final CommitmentViewModel item;
  final ValueChanged<CommitmentViewModel> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = switch (item.status) {
      CommitmentStatus.active => colors.success,
      CommitmentStatus.needsAttention => colors.warning,
      CommitmentStatus.paused => colors.textMuted,
      CommitmentStatus.upcoming => colors.accent,
      CommitmentStatus.completed => colors.success,
    };
    return Semantics(
      button: true,
      label: '${item.name}, ${item.typeLabel}, ${item.statusLabel}',
      child: InkWell(
        onTap: () => onTap(item),
        borderRadius: RevokeRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(RevokeSpacing.lg),
          child: Row(
            children: [
              Icon(
                item.isReduce
                    ? PhosphorIcons.trendDown
                    : PhosphorIcons.shieldCheck,
                size: RevokeIconSizes.emphasis,
                color: colors.accent,
              ),
              const SizedBox(width: RevokeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: context.text.titleMedium),
                    const SizedBox(height: RevokeSpacing.xs),
                    Text(
                      '${item.typeLabel} · ${item.summary}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: RevokeSpacing.sm),
                    RevokePill(
                      label: item.statusLabel,
                      color: statusColor,
                      icon: item.status == CommitmentStatus.needsAttention
                          ? PhosphorIcons.warningCircle
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RevokeSpacing.sm),
              Icon(
                PhosphorIcons.caretRight,
                size: RevokeIconSizes.standard,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
