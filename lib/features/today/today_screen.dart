import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/schedule_model.dart';
import '../../core/models/taper_plan_model.dart';
import '../../core/models/usage_insights_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/taper_plan_service.dart';
import '../../core/services/usage_insights_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/schedule_block_validator.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class TodayViewData {
  const TodayViewData({
    this.schedules = const <ScheduleModel>[],
    this.usage = const <String, TodayUsageStatus>{},
    this.taperPlan,
    this.weekSnapshot,
    this.temporaryApprovedPackages = const <String>{},
    this.accessibilityMissing = false,
    this.usageStatsMissing = false,
    this.overlayMissing = false,
    this.exactAlarmMissing = false,
  });

  final List<ScheduleModel> schedules;
  final Map<String, TodayUsageStatus> usage;
  final TaperPlanModel? taperPlan;
  final UsageInsightsSnapshot? weekSnapshot;
  final Set<String> temporaryApprovedPackages;
  final bool accessibilityMissing;
  final bool usageStatsMissing;
  final bool overlayMissing;
  final bool exactAlarmMissing;

  bool get hasPermissionIssue =>
      accessibilityMissing ||
      usageStatsMissing ||
      overlayMissing ||
      exactAlarmMissing;

  List<ScheduleModel> get activeSchedules =>
      schedules.where((schedule) => schedule.isActive).toList(growable: false);

  List<ScheduleModel> get scheduledToday => activeSchedules
      .where((schedule) => schedule.days.contains(DateTime.now().weekday))
      .toList(growable: false);

  ScheduleModel? primarySchedule({DateTime? now}) {
    final current = now ?? DateTime.now();
    final candidates = activeSchedules;
    if (candidates.isEmpty) return null;

    final ranked = candidates.toList()
      ..sort((a, b) {
        final priorityA = _priorityFor(a, current);
        final priorityB = _priorityFor(b, current);
        if (priorityA != priorityB) return priorityA.compareTo(priorityB);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return ranked.first;
  }

  int _priorityFor(ScheduleModel schedule, DateTime now) {
    if (!_isScheduledToday(schedule, now)) return 4;
    if (_isBlocked(schedule, now)) return 0;
    if (schedule.type == ScheduleType.usageLimit &&
        usage[schedule.id]?.isNearLimit == true) {
      return 1;
    }
    if (schedule.type == ScheduleType.timeBlock &&
        _isTimeBlockActive(schedule, now)) {
      return 2;
    }
    if (taperPlan?.scheduleId == schedule.id) return 3;
    return 3;
  }

  bool isScheduledToday(ScheduleModel schedule, [DateTime? now]) {
    return _isScheduledToday(schedule, now ?? DateTime.now());
  }

  bool isBlocked(ScheduleModel schedule, [DateTime? now]) {
    return _isBlocked(schedule, now ?? DateTime.now());
  }

  bool isTimeBlockActive(ScheduleModel schedule, [DateTime? now]) {
    return _isTimeBlockActive(schedule, now ?? DateTime.now());
  }

  bool _isScheduledToday(ScheduleModel schedule, DateTime now) {
    return schedule.isActive && schedule.days.contains(now.weekday);
  }

  bool _isBlocked(ScheduleModel schedule, DateTime now) {
    if (!_isScheduledToday(schedule, now)) return false;
    if (schedule.type == ScheduleType.usageLimit) {
      return usage[schedule.id]?.limitReached == true;
    }
    return schedule.type == ScheduleType.timeBlock &&
        _isTimeBlockActive(schedule, now);
  }

  bool _isTimeBlockActive(ScheduleModel schedule, DateTime now) {
    if (!_isScheduledToday(schedule, now) || schedule.blocks.isEmpty) {
      return false;
    }
    final minute = now.hour * 60 + now.minute;
    return ScheduleBlockValidator.isMinuteWithinBlocks(schedule.blocks, minute);
  }
}

class TodayUsageStatus {
  const TodayUsageStatus({
    required this.usedMillis,
    required this.limitMillis,
    this.missingUsageAccess = false,
    this.pendingActivation = false,
  });

  final int usedMillis;
  final int limitMillis;
  final bool missingUsageAccess;
  final bool pendingActivation;

  int get remainingMillis => (limitMillis - usedMillis).clamp(0, 604800000);
  bool get limitReached =>
      !missingUsageAccess && !pendingActivation && remainingMillis <= 0;
  bool get isNearLimit =>
      !missingUsageAccess &&
      !pendingActivation &&
      (remainingMillis <= 15 * 60 * 1000 ||
          (limitMillis > 0 && usedMillis / limitMillis >= 0.75));

  const TodayUsageStatus.missingPermission({required int limitMillis})
    : this(usedMillis: 0, limitMillis: limitMillis, missingUsageAccess: true);

  const TodayUsageStatus.pending({required int limitMillis})
    : this(usedMillis: 0, limitMillis: limitMillis, pendingActivation: true);
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  late final StreamSubscription<List<ScheduleModel>> _scheduleSubscription;
  StreamSubscription? _permissionSubscription;
  StreamSubscription? _temporaryApprovalSubscription;
  Timer? _usageTimer;

  List<ScheduleModel> _schedules = const <ScheduleModel>[];
  Map<String, TodayUsageStatus> _usage = const <String, TodayUsageStatus>{};
  Set<String> _temporaryApprovedPackages = const <String>{};
  TaperPlanModel? _taperPlan;
  UsageInsightsSnapshot? _weekSnapshot;
  bool _isLoading = true;
  Object? _error;
  bool _accessibilityMissing = false;
  bool _usageStatsMissing = false;
  bool _overlayMissing = false;
  bool _exactAlarmMissing = false;
  int _usageRefreshGeneration = 0;

  TodayViewData get _viewData => TodayViewData(
    schedules: _schedules,
    usage: _usage,
    taperPlan: _taperPlan,
    weekSnapshot: _weekSnapshot,
    temporaryApprovedPackages: _temporaryApprovedPackages,
    accessibilityMissing: _accessibilityMissing,
    usageStatsMissing: _usageStatsMissing,
    overlayMissing: _overlayMissing,
    exactAlarmMissing: _exactAlarmMissing,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleSubscription = ScheduleService.watchSchedules().listen(
      _onSchedules,
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _isLoading = false;
        });
      },
    );
    _refreshPermissions();
    _refreshTemporaryApprovals();
    _refreshTaperPlan();
    _refreshWeekSnapshot();
    _permissionSubscription = Stream.periodic(
      const Duration(seconds: 5),
    ).listen((_) => _refreshPermissions());
    _temporaryApprovalSubscription = Stream.periodic(
      const Duration(seconds: 5),
    ).listen((_) => _refreshTemporaryApprovals());
    _usageTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshUsageStatuses());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduleSubscription.cancel();
    _permissionSubscription?.cancel();
    _temporaryApprovalSubscription?.cancel();
    _usageTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAll());
    }
  }

  void _onSchedules(List<ScheduleModel> schedules) {
    if (!mounted) return;
    final changed =
        _scheduleFingerprint(_schedules) != _scheduleFingerprint(schedules);
    if (changed || _isLoading) {
      setState(() {
        _schedules = List<ScheduleModel>.unmodifiable(schedules);
        _isLoading = false;
        _error = null;
      });
      unawaited(_refreshUsageStatuses());
    }
  }

  String _scheduleFingerprint(List<ScheduleModel> schedules) {
    return schedules
        .map(
          (schedule) =>
              '${schedule.id}:${schedule.isActive}:${schedule.type.index}:${schedule.name}:${schedule.days}:${schedule.blocks.length}:${schedule.durationLimit?.inMilliseconds ?? 0}:${schedule.activatedAt?.millisecondsSinceEpoch ?? 0}',
        )
        .join('|');
  }

  Future<void> _refreshAll() async {
    try {
      final schedules = await ScheduleService.getSchedules();
      if (!mounted) return;
      _onSchedules(schedules);
    } catch (_) {
      // The stream remains the local-first source when a refresh fails.
    }
    await Future.wait<void>([
      _refreshPermissions(),
      _refreshTemporaryApprovals(),
      _refreshTaperPlan(),
      _refreshWeekSnapshot(),
      _refreshUsageStatuses(),
    ]);
  }

  Future<void> _refreshPermissions() async {
    try {
      final permissions = await NativeBridge.checkPermissions();
      if (!mounted) return;
      final accessibilityMissing = permissions['accessibility'] != true;
      final usageStatsMissing = permissions['usage_stats'] != true;
      final overlayMissing = permissions['overlay'] != true;
      final exactAlarmMissing = permissions['exact_alarm'] != true;
      if (accessibilityMissing == _accessibilityMissing &&
          usageStatsMissing == _usageStatsMissing &&
          overlayMissing == _overlayMissing &&
          exactAlarmMissing == _exactAlarmMissing) {
        return;
      }
      setState(() {
        _accessibilityMissing = accessibilityMissing;
        _usageStatsMissing = usageStatsMissing;
        _overlayMissing = overlayMissing;
        _exactAlarmMissing = exactAlarmMissing;
      });
    } catch (_) {
      // Permission status is advisory; retain the last known state.
    }
  }

  Future<void> _refreshTemporaryApprovals() async {
    try {
      final packages = await NativeBridge.getTemporaryApprovedPackages();
      final next = packages
          .map((packageName) => packageName.trim())
          .where((packageName) => packageName.isNotEmpty)
          .toSet();
      if (!mounted ||
          (next.length == _temporaryApprovedPackages.length &&
              next.containsAll(_temporaryApprovedPackages))) {
        return;
      }
      setState(() {
        _temporaryApprovedPackages = next;
      });
    } catch (_) {
      // The indicator is cosmetic and must not affect enforcement.
    }
  }

  Future<void> _refreshTaperPlan() async {
    try {
      final plan = await TaperPlanService.getActivePlan();
      if (!mounted) return;
      if (plan?.id == _taperPlan?.id &&
          plan?.updatedAt == _taperPlan?.updatedAt) {
        return;
      }
      setState(() {
        _taperPlan = plan;
      });
    } catch (_) {
      if (!mounted) return;
      if (_taperPlan != null) setState(() => _taperPlan = null);
    }
  }

  Future<void> _refreshWeekSnapshot() async {
    try {
      final snapshot = await UsageInsightsService.refresh(
        mode: 'week',
        anchorDate: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _weekSnapshot = snapshot.hasUsageAccess ? snapshot : null;
      });
    } catch (_) {
      // Weekly usage is optional; do not render a synthetic metric.
    }
  }

  Future<void> _refreshUsageStatuses() async {
    final generation = ++_usageRefreshGeneration;
    final usageSchedules = _schedules
        .where(
          (schedule) =>
              schedule.isActive &&
              schedule.type == ScheduleType.usageLimit &&
              schedule.days.contains(DateTime.now().weekday),
        )
        .toList(growable: false);

    if (usageSchedules.isEmpty) {
      if (mounted &&
          _usage.isNotEmpty &&
          generation == _usageRefreshGeneration) {
        setState(() => _usage = const <String, TodayUsageStatus>{});
      }
      return;
    }

    final permissions = await _safePermissions();
    final usageAccess = permissions['usage_stats'] == true;
    if (!usageAccess) {
      final missing = {
        for (final schedule in usageSchedules)
          schedule.id: TodayUsageStatus.missingPermission(
            limitMillis: schedule.durationLimit?.inMilliseconds ?? 0,
          ),
      };
      _setUsageIfCurrent(generation, missing);
      return;
    }

    final entries = await Future.wait(
      usageSchedules.map((schedule) async {
        final limitMillis = schedule.durationLimit?.inMilliseconds ?? 0;
        final activation = schedule.activatedAt?.millisecondsSinceEpoch;
        if (activation == null || activation <= 0) {
          return MapEntry(
            schedule.id,
            TodayUsageStatus.pending(limitMillis: limitMillis),
          );
        }
        try {
          final byPackage = await NativeBridge.getSessionUsage(
            schedule.targetApps,
            activation,
          );
          final used = schedule.targetApps.fold<int>(
            0,
            (sum, packageName) => sum + (byPackage[packageName] ?? 0),
          );
          return MapEntry(
            schedule.id,
            TodayUsageStatus(usedMillis: used, limitMillis: limitMillis),
          );
        } catch (_) {
          return MapEntry(
            schedule.id,
            TodayUsageStatus.missingPermission(limitMillis: limitMillis),
          );
        }
      }),
    );
    _setUsageIfCurrent(
      generation,
      Map<String, TodayUsageStatus>.fromEntries(entries),
    );
  }

  Future<Map<String, bool>> _safePermissions() async {
    try {
      final permissions = await NativeBridge.checkPermissions();
      _applyPermissionFlags(permissions);
      return permissions;
    } catch (_) {
      return <String, bool>{'usage_stats': !_usageStatsMissing};
    }
  }

  void _applyPermissionFlags(Map<String, bool> permissions) {
    if (!mounted) return;
    final nextAccessibility = permissions['accessibility'] != true;
    final nextUsageStats = permissions['usage_stats'] != true;
    final nextOverlay = permissions['overlay'] != true;
    final nextAlarm = permissions['exact_alarm'] != true;
    if (nextAccessibility == _accessibilityMissing &&
        nextUsageStats == _usageStatsMissing &&
        nextOverlay == _overlayMissing &&
        nextAlarm == _exactAlarmMissing) {
      return;
    }
    setState(() {
      _accessibilityMissing = nextAccessibility;
      _usageStatsMissing = nextUsageStats;
      _overlayMissing = nextOverlay;
      _exactAlarmMissing = nextAlarm;
    });
  }

  void _setUsageIfCurrent(int generation, Map<String, TodayUsageStatus> next) {
    if (!mounted || generation != _usageRefreshGeneration) return;
    if (_sameUsage(_usage, next)) return;
    setState(() {
      _usage = next;
    });
  }

  bool _sameUsage(
    Map<String, TodayUsageStatus> first,
    Map<String, TodayUsageStatus> second,
  ) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      final other = second[entry.key];
      if (other == null ||
          entry.value.usedMillis != other.usedMillis ||
          entry.value.limitMillis != other.limitMillis ||
          entry.value.missingUsageAccess != other.missingUsageAccess ||
          entry.value.pendingActivation != other.pendingActivation) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const RevokeLoadingState(label: 'Loading Today');
    if (_error != null && _schedules.isEmpty) {
      return RevokeErrorState(
        message: 'Today could not be loaded.',
        onRetry: () => unawaited(_refreshAll()),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: context.colors.accent,
      child: TodayContent(data: _viewData),
    );
  }
}

class TodayContent extends StatelessWidget {
  const TodayContent({super.key, required this.data});

  final TodayViewData data;

  @override
  Widget build(BuildContext context) {
    final primary = data.primarySchedule();
    final otherSchedules = data.activeSchedules
        .where((schedule) => schedule.id != primary?.id)
        .toList(growable: false);
    final protections = data.activeSchedules
        .where(
          (schedule) =>
              schedule.type == ScheduleType.timeBlock &&
              data.isScheduledToday(schedule),
        )
        .toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        RevokeSpacing.lg,
        RevokeSpacing.md,
        RevokeSpacing.lg,
        RevokeSpacing.xxl,
      ),
      children: [
        _DailyStateHeader(data: data),
        const SizedBox(height: RevokeSpacing.xl),
        if (data.hasPermissionIssue) ...[
          _MonitoringHealthBanner(data: data),
          const SizedBox(height: RevokeSpacing.lg),
        ],
        if (primary == null && data.activeSchedules.isEmpty)
          _NoCommitmentsState()
        else ...[
          if (primary != null) ...[
            const RevokeSectionHeader(title: 'Primary Commitment'),
            const SizedBox(height: RevokeSpacing.sm),
            _PrimaryCommitmentPanel(schedule: primary, data: data),
          ],
          if (protections.isNotEmpty) ...[
            const SizedBox(height: RevokeSpacing.xl),
            const RevokeSectionHeader(title: 'Active protections'),
            const SizedBox(height: RevokeSpacing.sm),
            _ProtectionList(protections: protections, data: data),
          ],
          if (data.weekSnapshot != null) ...[
            const SizedBox(height: RevokeSpacing.xl),
            _WeekSummary(snapshot: data.weekSnapshot!),
          ],
          if (otherSchedules.isNotEmpty) ...[
            const SizedBox(height: RevokeSpacing.xl),
            const RevokeSectionHeader(title: 'Other active Commitments'),
            const SizedBox(height: RevokeSpacing.sm),
            _CommitmentList(schedules: otherSchedules, data: data),
          ],
        ],
      ],
    );
  }
}

class _DailyStateHeader extends StatelessWidget {
  const _DailyStateHeader({required this.data});

  final TodayViewData data;

  @override
  Widget build(BuildContext context) {
    final primary = data.primarySchedule();
    final state = _dailyState(data, primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: AppTheme.caption.copyWith(color: context.colors.textMuted),
        ),
        const SizedBox(height: RevokeSpacing.xs),
        Text(state.title, style: AppTheme.pageTitle),
        const SizedBox(height: RevokeSpacing.xs),
        Text(
          state.description,
          style: AppTheme.bodySecondary.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  _DailyState _dailyState(TodayViewData data, ScheduleModel? primary) {
    if (data.hasPermissionIssue) {
      return const _DailyState(
        title: 'Monitoring needs attention',
        description:
            'Complete setup so Revoke can enforce and measure accurately.',
      );
    }
    if (data.activeSchedules.isEmpty) {
      return const _DailyState(
        title: 'No active Commitments',
        description: 'Set one clear boundary for the day.',
      );
    }
    if (primary != null &&
        primary.type == ScheduleType.usageLimit &&
        data.isBlocked(primary)) {
      return const _DailyState(
        title: 'One Commitment needs attention',
        description: 'A protection or usage limit is active now.',
      );
    }
    if (primary != null &&
        primary.type == ScheduleType.usageLimit &&
        data.usage[primary.id]?.isNearLimit == true) {
      return const _DailyState(
        title: 'You are close to a daily limit',
        description: 'There is still room, but the boundary is approaching.',
      );
    }
    if (primary != null && data.isTimeBlockActive(primary)) {
      return const _DailyState(
        title: 'A protected period is active',
        description: 'Your selected apps are protected right now.',
      );
    }
    return const _DailyState(
      title: "You're on track today",
      description: 'Your active Commitments are ready and being monitored.',
    );
  }
}

class _DailyState {
  const _DailyState({required this.title, required this.description});
  final String title;
  final String description;
}

class _MonitoringHealthBanner extends StatelessWidget {
  const _MonitoringHealthBanner({required this.data});

  final TodayViewData data;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final details = <String>[
      if (data.accessibilityMissing) 'Accessibility',
      if (data.usageStatsMissing) 'Usage Access',
      if (data.overlayMissing) 'Overlay',
      if (data.exactAlarmMissing) 'Alarms',
    ];
    return RevokeSurface(
      color: colors.warning.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(RevokeSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.warningCircle,
            color: colors.warning,
            size: RevokeIconSizes.emphasis,
          ),
          const SizedBox(width: RevokeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enforcement setup needs attention',
                  style: AppTheme.cardTitle,
                ),
                const SizedBox(height: RevokeSpacing.xs),
                Text(
                  'Missing: ${details.join(', ')}.',
                  style: AppTheme.bodySecondary.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: RevokeSpacing.sm),
                RevokeButton(
                  label: 'Fix setup',
                  onPressed: () => context.push('/permissions'),
                  variant: RevokeButtonVariant.tertiary,
                  expand: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCommitmentPanel extends StatelessWidget {
  const _PrimaryCommitmentPanel({required this.schedule, required this.data});

  final ScheduleModel schedule;
  final TodayViewData data;

  @override
  Widget build(BuildContext context) {
    final status = _scheduleStatus(context, schedule, data);
    final taper = data.taperPlan?.scheduleId == schedule.id
        ? data.taperPlan
        : null;
    final usage = data.usage[schedule.id];
    final isTemporary = schedule.targetApps.any(
      data.temporaryApprovedPackages.contains,
    );
    final usageLimitReached =
        schedule.type == ScheduleType.usageLimit && data.isBlocked(schedule);
    final statusColor = usageLimitReached
        ? context.colors.destructive
        : isTemporary
        ? context.colors.warning
        : context.colors.accent;

    return RevokeSurface(
      padding: const EdgeInsets.all(RevokeSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(schedule.name, style: AppTheme.sectionTitle),
              ),
              RevokePill(label: status.label, color: statusColor),
            ],
          ),
          const SizedBox(height: RevokeSpacing.xs),
          Text(
            _targetSummary(schedule),
            style: AppTheme.bodySecondary.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: RevokeSpacing.xl),
          if (taper != null) ...[
            Text(
              'Day ${taper.dayIndexFor(DateTime.now()) + 1} of ${taper.durationDays}',
              style: AppTheme.body,
            ),
            const SizedBox(height: RevokeSpacing.xs),
            Text(
              "Today's allowance: ${_formatMinutes(taper.limitFor(DateTime.now()))} - Target: ${_formatMinutes(taper.targetDailyMinutes)}",
              style: AppTheme.bodySecondary.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: RevokeSpacing.md),
            if (usage != null && !usage.missingUsageAccess) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '${_formatDuration(usage.usedMillis)} used of ${_formatDuration(usage.limitMillis)}',
                      style: AppTheme.body,
                    ),
                  ),
                  Text(
                    '${_formatDuration(usage.remainingMillis)} left',
                    style: AppTheme.numericStat.copyWith(
                      fontSize: AppTheme.sizeXl,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RevokeSpacing.md),
              _UsageProgress(status: usage, color: statusColor),
            ] else ...[
              _TaperProgress(plan: taper),
            ],
          ] else if (usage != null && !usage.missingUsageAccess) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${_formatDuration(usage.usedMillis)} used of ${_formatDuration(usage.limitMillis)}',
                    style: AppTheme.body,
                  ),
                ),
                Text(
                  '${_formatDuration(usage.remainingMillis)} left',
                  style: AppTheme.numericStat.copyWith(
                    fontSize: AppTheme.sizeXl,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: RevokeSpacing.md),
            _UsageProgress(status: usage, color: statusColor),
          ] else
            Text(status.detail, style: AppTheme.body),
          if (isTemporary) ...[
            const SizedBox(height: RevokeSpacing.lg),
            RevokePill(
              icon: PhosphorIcons.timer,
              label: 'Temporary access active',
              color: context.colors.warning,
            ),
          ],
          const SizedBox(height: RevokeSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: RevokeButton(
              label: 'View Commitment',
              onPressed: () => context.go('/commitments'),
              variant: RevokeButtonVariant.tertiary,
              expand: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageProgress extends StatelessWidget {
  const _UsageProgress({required this.status, required this.color});

  final TodayUsageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final value = status.limitMillis <= 0
        ? 0.0
        : (status.usedMillis / status.limitMillis).clamp(0.0, 1.0);
    return Semantics(
      label:
          '${_formatDuration(status.usedMillis)} used of ${_formatDuration(status.limitMillis)}',
      value: '${(value * 100).round()} percent',
      child: ClipRRect(
        borderRadius: RevokeRadii.pillRadius,
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          color: color,
          backgroundColor: context.colors.surfaceSubtle,
        ),
      ),
    );
  }
}

class _TaperProgress extends StatelessWidget {
  const _TaperProgress({required this.plan});

  final TaperPlanModel plan;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Taper progress',
      value: '${(plan.progressFor(DateTime.now()) * 100).round()} percent',
      child: ClipRRect(
        borderRadius: RevokeRadii.pillRadius,
        child: LinearProgressIndicator(
          value: plan.progressFor(DateTime.now()),
          minHeight: 8,
          color: context.colors.accent,
          backgroundColor: context.colors.surfaceSubtle,
        ),
      ),
    );
  }
}

class _ProtectionList extends StatelessWidget {
  const _ProtectionList({required this.protections, required this.data});

  final List<ScheduleModel> protections;
  final TodayViewData data;

  @override
  Widget build(BuildContext context) {
    return RevokeSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < protections.length; index++) ...[
            _ProtectionRow(schedule: protections[index], data: data),
            if (index < protections.length - 1) const RevokeDivider(),
          ],
        ],
      ),
    );
  }
}

class _ProtectionRow extends StatelessWidget {
  const _ProtectionRow({required this.schedule, required this.data});

  final ScheduleModel schedule;
  final TodayViewData data;

  @override
  Widget build(BuildContext context) {
    final isActive = data.isTimeBlockActive(schedule);
    final time = isActive
        ? _currentBlockEnd(schedule)
        : _nextBlockStart(schedule);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RevokeSpacing.lg,
        vertical: RevokeSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            isActive ? PhosphorIcons.shieldCheck : PhosphorIcons.clock,
            color: isActive
                ? context.colors.enforcement
                : context.colors.textSecondary,
            size: RevokeIconSizes.standard,
          ),
          const SizedBox(width: RevokeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(schedule.name, style: AppTheme.cardTitle),
                const SizedBox(height: RevokeSpacing.xs),
                Text(
                  isActive
                      ? 'Protected now${time == null ? '' : ' · until ${time.format(context)}'}'
                      : time == null
                      ? 'Protection scheduled today'
                      : 'Next protection · ${time.format(context)}',
                  style: AppTheme.bodySecondary.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${schedule.targetApps.length} ${schedule.targetApps.length == 1 ? 'app' : 'apps'}',
            style: AppTheme.caption.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.snapshot});

  final UsageInsightsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final recordedDays = snapshot.buckets
        .where((bucket) => !bucket.isFuture && bucket.usageMs > 0)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RevokeSectionHeader(title: 'This week'),
        const SizedBox(height: RevokeSpacing.sm),
        RevokeSurface(
          child: Row(
            children: [
              Expanded(
                child: _WeekMetric(
                  label: 'Average daily use',
                  value: '${snapshot.averageDailyMinutes}m',
                ),
              ),
              Expanded(
                child: _WeekMetric(
                  label: 'Days recorded',
                  value: '$recordedDays',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekMetric extends StatelessWidget {
  const _WeekMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTheme.numericStat),
        const SizedBox(height: RevokeSpacing.xs),
        Text(
          label,
          style: AppTheme.caption.copyWith(color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

class _CommitmentList extends StatelessWidget {
  const _CommitmentList({required this.schedules, required this.data});

  final List<ScheduleModel> schedules;
  final TodayViewData data;

  @override
  Widget build(BuildContext context) {
    return RevokeSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < schedules.length; index++) ...[
            InkWell(
              onTap: () => context.go('/commitments'),
              child: Padding(
                padding: const EdgeInsets.all(RevokeSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedules[index].name,
                            style: AppTheme.cardTitle,
                          ),
                          const SizedBox(height: RevokeSpacing.xs),
                          Text(
                            _scheduleStatus(
                              context,
                              schedules[index],
                              data,
                            ).detail,
                            style: AppTheme.bodySecondary.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretRight,
                      size: RevokeIconSizes.standard,
                      color: context.colors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (index < schedules.length - 1) const RevokeDivider(),
          ],
        ],
      ),
    );
  }
}

class _NoCommitmentsState extends StatelessWidget {
  const _NoCommitmentsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: RevokeSpacing.xxl),
      child: RevokeEmptyState(
        title: 'No active Commitments today',
        message:
            'Create one clear boundary and Revoke will keep its state here.',
        action: RevokeButton(
          label: 'Create a Commitment',
          onPressed: () => context.push('/commitment/new'),
          expand: false,
        ),
      ),
    );
  }
}

class _ScheduleStatus {
  const _ScheduleStatus({required this.label, required this.detail});
  final String label;
  final String detail;
}

_ScheduleStatus _scheduleStatus(
  BuildContext context,
  ScheduleModel schedule,
  TodayViewData data,
) {
  if (!data.isScheduledToday(schedule)) {
    return const _ScheduleStatus(
      label: 'Upcoming',
      detail: 'Scheduled on another day',
    );
  }
  if (schedule.type == ScheduleType.usageLimit) {
    final status = data.usage[schedule.id];
    if (status == null || status.pendingActivation) {
      return const _ScheduleStatus(
        label: 'Starting soon',
        detail: 'Usage limit is preparing',
      );
    }
    if (status.missingUsageAccess) {
      return const _ScheduleStatus(
        label: 'Needs setup',
        detail: 'Restore Usage Access to measure this limit',
      );
    }
    if (status.limitReached) {
      return const _ScheduleStatus(
        label: 'Limit reached',
        detail: 'Usage allowance has been reached',
      );
    }
    return _ScheduleStatus(
      label: 'On track',
      detail: '${_formatDuration(status.remainingMillis)} remaining today',
    );
  }
  if (data.isTimeBlockActive(schedule)) {
    final end = _currentBlockEnd(schedule);
    return _ScheduleStatus(
      label: 'Protected',
      detail: end == null
          ? 'Protected now'
          : 'Protected until ${end.format(context)}',
    );
  }
  final next = _nextBlockStart(schedule);
  return _ScheduleStatus(
    label: 'Ready',
    detail: next == null
        ? 'Protection scheduled today'
        : 'Next protection at ${next.format(context)}',
  );
}

String _targetSummary(ScheduleModel schedule) {
  final count = schedule.targetApps.length;
  if (count == 0) return 'No target apps configured';
  return '$count ${count == 1 ? 'app' : 'apps'} · ${_typeLabel(schedule.type)}';
}

String _typeLabel(ScheduleType type) {
  return switch (type) {
    ScheduleType.timeBlock => 'time protection',
    ScheduleType.usageLimit => 'daily usage limit',
    ScheduleType.launchCount => 'launch limit',
  };
}

TimeOfDay? _currentBlockEnd(ScheduleModel schedule) {
  final now = DateTime.now();
  final minute = now.hour * 60 + now.minute;
  for (final block in schedule.blocks) {
    if (ScheduleBlockValidator.isMinuteWithinBlocks(<ScheduleBlock>[
      block,
    ], minute)) {
      return block.endTime;
    }
  }
  return null;
}

TimeOfDay? _nextBlockStart(ScheduleModel schedule) {
  if (schedule.blocks.isEmpty) return null;
  final now = DateTime.now();
  final currentMinute = now.hour * 60 + now.minute;
  ScheduleBlock? best;
  var bestDelta = 1441;
  for (final block in schedule.blocks) {
    final delta = block.startMinutes >= currentMinute
        ? block.startMinutes - currentMinute
        : 1440 - currentMinute + block.startMinutes;
    if (delta < bestDelta) {
      best = block;
      bestDelta = delta;
    }
  }
  return best?.startTime;
}

String _formatDuration(int milliseconds) {
  final minutes = ((milliseconds.clamp(0, 604800000) + 59999) ~/ 60000);
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours > 0 && remaining > 0) return '${hours}h ${remaining}m';
  if (hours > 0) return '${hours}h';
  return '${minutes}m';
}

String _formatMinutes(int minutes) {
  final safe = minutes.clamp(0, 1440).toInt();
  final hours = safe ~/ 60;
  final remaining = safe % 60;
  if (hours > 0 && remaining > 0) return '${hours}h ${remaining}m';
  if (hours > 0) return '${hours}h';
  return '${remaining}m';
}
