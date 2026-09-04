import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/schedule_model.dart';
import '../../core/models/taper_plan_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/services/taper_plan_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_block_validator.dart';
import '../../core/utils/theme_extensions.dart';
import 'widgets/focus_score_card.dart';
import 'widgets/single_app_icon.dart';

class HomeScreen extends StatefulWidget {
  final List<ScheduleModel> schedules;
  const HomeScreen({super.key, required this.schedules});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<ScheduleModel> _schedules = [];
  bool _isLoading = true;
  bool _isMissingPermissions = false;
  bool _isAccessibilityMissing = false;
  bool _isUsageStatsMissing = false;
  bool _isOverlayMissing = false;
  bool _isExactAlarmMissing = false;
  StreamSubscription? _permissionSubscription;
  StreamSubscription? _temporaryApprovalSubscription;
  Set<String> _temporaryApprovedPackages = const <String>{};
  Timer? _usageLimitRefreshTimer;
  Map<String, _UsageLimitStatus> _usageLimitStatuses =
      const <String, _UsageLimitStatus>{};
  TaperPlanModel? _activeTaperPlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _refreshTemporaryApprovals();
    _schedules = widget.schedules;
    _isLoading = false;
    unawaited(_loadTaperPlan());
    unawaited(_refreshUsageLimitStatuses());
    AuthService.validateSession();

    _permissionSubscription = Stream.periodic(const Duration(seconds: 5))
        .listen((_) {
          _checkPermissions();
        });

    _temporaryApprovalSubscription = Stream.periodic(const Duration(seconds: 5))
        .listen((_) {
          _refreshTemporaryApprovals();
        });

    _usageLimitRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_refreshUsageLimitStatuses());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionSubscription?.cancel();
    _temporaryApprovalSubscription?.cancel();
    _usageLimitRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _refreshTemporaryApprovals();
      _loadSchedules();
      unawaited(_loadTaperPlan());
      unawaited(_refreshUsageLimitStatuses());
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = oldWidget.schedules
        .map(
          (s) =>
              '${s.id}:${s.isActive ? 1 : 0}:${s.type.index}:${s.name}:${s.targetApps.length}:${s.blocks.length}:${s.durationLimit?.inSeconds ?? 0}:${s.activatedAt?.millisecondsSinceEpoch ?? 0}',
        )
        .join('|');
    final newKey = widget.schedules
        .map(
          (s) =>
              '${s.id}:${s.isActive ? 1 : 0}:${s.type.index}:${s.name}:${s.targetApps.length}:${s.blocks.length}:${s.durationLimit?.inSeconds ?? 0}:${s.activatedAt?.millisecondsSinceEpoch ?? 0}',
        )
        .join('|');
    if (oldKey != newKey) {
      setState(() {
        _schedules = widget.schedules;
      });
      unawaited(_refreshUsageLimitStatuses());
    }
  }

  Future<void> _checkPermissions() async {
    final perms = await NativeBridge.checkPermissions();
    _applyPermissionState(perms);
  }

  void _applyPermissionState(Map<String, bool> perms) {
    final usageStatsMissing = !(perms['usage_stats'] ?? false);
    final accessibilityMissing = !(perms['accessibility'] ?? false);
    final overlayMissing = !(perms['overlay'] ?? false);
    final exactAlarmMissing = !(perms['exact_alarm'] ?? false);
    final nextMissing =
        accessibilityMissing ||
        usageStatsMissing ||
        overlayMissing ||
        exactAlarmMissing;
    if (!mounted) return;
    if (nextMissing != _isMissingPermissions ||
        accessibilityMissing != _isAccessibilityMissing ||
        usageStatsMissing != _isUsageStatsMissing ||
        overlayMissing != _isOverlayMissing ||
        exactAlarmMissing != _isExactAlarmMissing) {
      setState(() {
        _isMissingPermissions = nextMissing;
        _isAccessibilityMissing = accessibilityMissing;
        _isUsageStatsMissing = usageStatsMissing;
        _isOverlayMissing = overlayMissing;
        _isExactAlarmMissing = exactAlarmMissing;
      });
    }
  }

  Future<void> _refreshTemporaryApprovals() async {
    try {
      final active = await NativeBridge.getTemporaryApprovedPackages();
      final next = active
          .map((pkg) => pkg.trim())
          .where((pkg) => pkg.isNotEmpty)
          .toSet();
      if (!mounted) return;
      if (next.length == _temporaryApprovedPackages.length &&
          next.containsAll(_temporaryApprovedPackages)) {
        return;
      }
      setState(() {
        _temporaryApprovedPackages = next;
      });
    } catch (_) {
      // Cosmetic indicator only.
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await ScheduleService.getSchedules();
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
      unawaited(_refreshUsageLimitStatuses());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _schedules = const [];
        _isLoading = false;
        _usageLimitStatuses = const <String, _UsageLimitStatus>{};
      });
    }
  }

  Future<void> _loadTaperPlan() async {
    try {
      final plan = await TaperPlanService.getActivePlan();
      if (!mounted) return;
      setState(() {
        _activeTaperPlan = plan;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeTaperPlan = null;
      });
    }
  }

  bool _isUsageLimitSessionActive(ScheduleModel schedule) {
    if (!schedule.isActive || schedule.type != ScheduleType.usageLimit) {
      return false;
    }
    if (!schedule.days.contains(DateTime.now().weekday)) {
      return false;
    }
    if (schedule.blocks.isEmpty) {
      return true;
    }
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final nowMin = now.hour * 60 + now.minute;
    return ScheduleBlockValidator.isMinuteWithinBlocks(schedule.blocks, nowMin);
  }

  Future<void> _refreshUsageLimitStatuses() async {
    final usageLimitSchedules = _schedules
        .where(_isUsageLimitSessionActive)
        .toList(growable: false);

    if (usageLimitSchedules.isEmpty) {
      if (!mounted) return;
      if (_usageLimitStatuses.isNotEmpty) {
        setState(() {
          _usageLimitStatuses = const <String, _UsageLimitStatus>{};
        });
      }
      return;
    }

    try {
      final perms = await NativeBridge.checkPermissions();
      _applyPermissionState(perms);
      if (!(perms['usage_stats'] ?? false)) {
        if (!mounted) return;
        setState(() {
          _usageLimitStatuses = {
            for (final schedule in usageLimitSchedules)
              schedule.id: _UsageLimitStatus.missingPermission(
                limitMillis: schedule.durationLimit?.inMilliseconds ?? 0,
              ),
          };
        });
        return;
      }

      final entries = await Future.wait(
        usageLimitSchedules.map((schedule) async {
          final activationTimestamp =
              schedule.activatedAt?.millisecondsSinceEpoch;
          if (activationTimestamp == null || activationTimestamp <= 0) {
            return MapEntry(
              schedule.id,
              _UsageLimitStatus.pending(
                limitMillis: schedule.durationLimit?.inMilliseconds ?? 0,
              ),
            );
          }
          final usageByPackage = await NativeBridge.getSessionUsage(
            schedule.targetApps,
            activationTimestamp,
          );
          final usedMillis = schedule.targetApps.fold<int>(
            0,
            (sum, packageName) => sum + (usageByPackage[packageName] ?? 0),
          );
          final limitMillis = schedule.durationLimit?.inMilliseconds ?? 0;
          return MapEntry(
            schedule.id,
            _UsageLimitStatus(
              usedMillis: usedMillis,
              remainingMillis: limitMillis - usedMillis,
              missingUsageAccess: false,
              pendingActivation: false,
            ),
          );
        }),
      );

      if (!mounted) return;
      setState(() {
        _usageLimitStatuses = Map<String, _UsageLimitStatus>.fromEntries(
          entries,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usageLimitStatuses = {
          for (final schedule in usageLimitSchedules)
            schedule.id: _UsageLimitStatus.missingPermission(
              limitMillis: schedule.durationLimit?.inMilliseconds ?? 0,
            ),
        };
      });
    }
  }

  Set<String> get _activeHitlist {
    final active = _schedules.where((s) => s.isActive);
    final Set<String> packages = {};
    for (final schedule in active) {
      packages.addAll(schedule.targetApps);
    }
    return packages;
  }

  String _permissionAlertTitle() {
    if (_isAccessibilityMissing) {
      return 'Enable Accessibility for instant blocking';
    }
    if (_isUsageStatsMissing) {
      return 'Enable Usage Access for accurate limits';
    }
    if (_isOverlayMissing) {
      return 'Enable overlay for blocking screens';
    }
    if (_isExactAlarmMissing) {
      return 'Enable alarms for scheduled blocks';
    }
    return 'Finish setup for reliable blocking';
  }

  String _permissionAlertBody() {
    return _permissionAlertTitle();
  }

  Widget _buildPermissionAlertCard() {
    final alertColor = context.colors.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await context.push('/permissions');
          if (!mounted) return;
          _checkPermissions();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: alertColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: alertColor.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(PhosphorIcons.warningCircle, size: 18, color: alertColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _permissionAlertBody(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.smMedium.copyWith(
                    color: context.scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Enable',
                style: AppTheme.xsBold.copyWith(color: context.scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaperCtaCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _showTaperSetupSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.scheme.primary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                PhosphorIcons.trendDown,
                color: context.scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Build Daily Goal Plan', style: AppTheme.baseMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Create a daily limit schedule from your 7-day average.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.caretRight, color: context.scheme.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.scheme.primary),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadSchedules();
                  await _loadTaperPlan();
                },
                color: context.scheme.primary,
                child: CustomScrollView(
                  slivers: [
                    if (_isMissingPermissions)
                      SliverToBoxAdapter(child: _buildPermissionAlertCard()),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const FocusScoreCard(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_activeTaperPlan == null) ...[
                                  _buildTaperCtaCard(),
                                  const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 18),
                                _buildSectionHeader('SCHEDULES & APPS'),
                                const SizedBox(height: 10),
                                _buildHitlistSection(),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionHeader('ACTIVE SCHEDULES'),
                                    Text(
                                      '${_schedules.where((s) => s.isActive).length}/${_schedules.length}',
                                      style: AppTheme.smMedium.copyWith(
                                        color: context.colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _schedules.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildScheduleCard(_schedules[index]),
                              childCount: _schedules.length,
                            ),
                          ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () async {
          await context.push('/regime/new');
          if (!mounted) return;
          _loadSchedules();
        },
        backgroundColor: context.scheme.primary,
        child: Icon(
          PhosphorIcons.plus,
          color: context.scheme.onPrimary,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.smBold.copyWith(color: context.scheme.primary),
    );
  }

  String _formatMinutes(int minutes) {
    final safe = minutes.clamp(0, 1440 * 7).toInt();
    final hours = safe ~/ 60;
    final mins = safe % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  int _deriveTaperBaselineMinutes({
    required Map<String, dynamic> reality,
    required Set<String> targetPackages,
  }) {
    final rawTopApps = (reality['topApps'] as List?) ?? const [];
    var targetUsageMs = 0.0;
    for (final raw in rawTopApps) {
      if (raw is! Map) continue;
      final packageName = (raw['packageName'] as String?)?.trim() ?? '';
      if (!targetPackages.contains(packageName)) continue;
      targetUsageMs += ((raw['usageMs'] as num?) ?? 0).toDouble();
    }
    if (targetUsageMs > 0) {
      return (targetUsageMs / 7 / 60000).round().clamp(1, 1440).toInt();
    }
    final totalAvgDailyHours = ((reality['totalAvgDailyHours'] as num?) ?? 0)
        .toDouble();
    return (totalAvgDailyHours * 60).round().clamp(0, 1440).toInt();
  }

  Future<void> _showTaperSetupSheet() async {
    final targetPackages = _activeHitlist;
    if (targetPackages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a schedule before starting a plan.'),
        ),
      );
      return;
    }

    Map<String, dynamic> reality;
    List<int> hourly;
    try {
      reality = await NativeBridge.getRealityCheck();
      hourly = await NativeBridge.getHourlyUsagePattern();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not read usage data: $e')));
      return;
    }

    final rawTopApps = (reality['topApps'] as List?) ?? const [];
    final baselineMinutes = _deriveTaperBaselineMinutes(
      reality: reality,
      targetPackages: targetPackages,
    );
    final hasSevenDaySignal =
        baselineMinutes >= 5 &&
        rawTopApps.isNotEmpty &&
        hourly.fold<int>(0, (sum, value) => sum + value) > 0;
    if (!hasSevenDaySignal) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need 7 days of usage data before creating a plan.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    var targetMinutes = (baselineMinutes * 0.55)
        .round()
        .clamp(5, baselineMinutes)
        .toInt();
    var durationDays = 14;

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final sliderMax = baselineMinutes.clamp(5, 1440).toDouble();
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Goal Plan', style: AppTheme.h3),
                    const SizedBox(height: 8),
                    Text(
                      'Baseline ${_formatMinutes(baselineMinutes)} per day across ${targetPackages.length} restricted apps.',
                      style: AppTheme.smRegular.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Daily goal: ${_formatMinutes(targetMinutes)}',
                      style: AppTheme.baseMedium,
                    ),
                    Slider(
                      value: targetMinutes.toDouble(),
                      min: 5,
                      max: sliderMax,
                      divisions: (baselineMinutes - 5).clamp(1, 80).toInt(),
                      label: _formatMinutes(targetMinutes),
                      onChanged: (value) {
                        setSheetState(() {
                          targetMinutes = value
                              .round()
                              .clamp(5, baselineMinutes)
                              .toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Duration', style: AppTheme.baseMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <int>[7, 14, 21, 30]
                          .map(
                            (days) => ChoiceChip(
                              label: Text('$days days'),
                              selected: durationDays == days,
                              onSelected: (_) {
                                setSheetState(() => durationDays = days);
                              },
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            style: AppTheme.secondaryButtonStyle,
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(sheetContext, true),
                            style: AppTheme.primaryButtonStyle,
                            child: const Text('Accept plan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (accepted != true) return;

    final plan = TaperPlanService.buildLinearPlan(
      targetApps: targetPackages.toList(),
      baselineDailyMinutes: baselineMinutes,
      targetDailyMinutes: targetMinutes,
      durationDays: durationDays,
    );
    try {
      await TaperPlanService.savePlanLocalFirst(plan);
      if (!mounted) return;
      setState(() {
        _activeTaperPlan = plan;
      });
      await _loadSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan saved on this device.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save plan: $e')));
    }
  }

  bool _isMinuteInsideBlock(ScheduleBlock block, int minuteOfDay) {
    final start = block.startMinutes;
    final end = block.endMinutes;
    if (start < end) return minuteOfDay >= start && minuteOfDay < end;
    if (start > end) return minuteOfDay >= start || minuteOfDay < end;
    return false;
  }

  bool _isCurrentlyBlocking(ScheduleModel schedule) {
    if (!schedule.isActive) return false;
    if (!schedule.days.contains(DateTime.now().weekday)) return false;

    if (schedule.type == ScheduleType.timeBlock) {
      if (schedule.blocks.isEmpty) return false;
      final now = TimeOfDay.fromDateTime(DateTime.now());
      final nowMin = now.hour * 60 + now.minute;
      return ScheduleBlockValidator.isMinuteWithinBlocks(
        schedule.blocks,
        nowMin,
      );
    }
    if (schedule.type == ScheduleType.usageLimit) {
      return _usageLimitStatuses[schedule.id]?.limitReached ?? false;
    }
    return false;
  }

  TimeOfDay? _currentBlockEndTime(ScheduleModel schedule) {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final nowMin = now.hour * 60 + now.minute;
    for (final block in schedule.blocks) {
      if (_isMinuteInsideBlock(block, nowMin)) {
        return block.endTime;
      }
    }
    return null;
  }

  TimeOfDay? _nextBlockStartTime(ScheduleModel schedule) {
    if (schedule.blocks.isEmpty) return null;
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final nowMin = now.hour * 60 + now.minute;

    ScheduleBlock? bestBlock;
    int? bestDelta;
    for (final block in schedule.blocks) {
      final delta = block.startMinutes >= nowMin
          ? block.startMinutes - nowMin
          : (1440 - nowMin) + block.startMinutes;
      if (bestDelta == null || delta < bestDelta) {
        bestDelta = delta;
        bestBlock = block;
      }
    }
    return bestBlock?.startTime;
  }

  String _buildScheduleStatus(ScheduleModel schedule) {
    if (!schedule.isActive) {
      return 'Block now to reactivate';
    }

    if (schedule.type == ScheduleType.usageLimit) {
      final status = _usageLimitStatuses[schedule.id];
      if (status?.missingUsageAccess == true || _isUsageStatsMissing) {
        return 'Restore usage access';
      }
      if (_isUsageLimitSessionActive(schedule) && status != null) {
        if (status.pendingActivation) {
          return 'Waiting to start';
        }
        if (status.limitReached) {
          return 'Limit reached';
        }
        return _formatRemainingMillis(status.remainingMillis);
      }
      if (schedule.blocks.isNotEmpty &&
          schedule.days.contains(DateTime.now().weekday)) {
        final nextStart = _nextBlockStartTime(schedule);
        if (nextStart != null) {
          return 'Usage window ${nextStart.format(context)}';
        }
      }
      return _formatUsageLimitCap(schedule.durationLimit);
    }

    if (schedule.blocks.isEmpty) {
      return 'No focus windows';
    }

    if (!schedule.days.contains(DateTime.now().weekday)) {
      return 'Active on selected days';
    }

    final activeEnd = _currentBlockEndTime(schedule);
    if (activeEnd != null) {
      return 'Active till ${activeEnd.format(context)}';
    }

    final nextStart = _nextBlockStartTime(schedule);
    if (nextStart != null) {
      return 'Next block ${nextStart.format(context)}';
    }
    return 'Active on selected days';
  }

  String _formatUsageLimitCap(Duration? duration) {
    final totalMinutes = duration?.inMinutes ?? 0;
    if (totalMinutes <= 0) return 'Usage limit pending';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return 'Session cap ${hours}h ${minutes}m';
    }
    if (hours > 0) return 'Session cap ${hours}h';
    return 'Session cap ${minutes}m';
  }

  String _formatRemainingMillis(int remainingMillis) {
    if (remainingMillis <= 0) return 'Limit reached';
    final totalMinutes = ((remainingMillis + 59999) ~/ 60000).clamp(
      0,
      1440 * 7,
    );
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m remaining';
    }
    if (hours > 0) return '${hours}h remaining';
    return '${totalMinutes}m remaining';
  }

  IconData _blockTypeIcon(ScheduleType type) {
    return type == ScheduleType.timeBlock
        ? PhosphorIcons.clock
        : PhosphorIcons.hourglassLow;
  }

  String _blockTypeLabel(ScheduleType type) {
    return switch (type) {
      ScheduleType.timeBlock => 'Time block',
      ScheduleType.usageLimit => 'Usage limit',
      ScheduleType.launchCount => 'Launch count',
    };
  }

  String _daySummary(List<int> days) {
    if (days.isEmpty) return 'No days';
    final normalized = days.toSet().toList()..sort();
    const weekdays = <int>[1, 2, 3, 4, 5];
    if (normalized.length == 7) return 'Daily';
    if (normalized.length == 5 &&
        normalized.every((day) => weekdays.contains(day))) {
      return 'Weekdays';
    }
    if (normalized.length == 2 &&
        normalized.contains(6) &&
        normalized.contains(7)) {
      return 'Weekends';
    }
    if (normalized.length == 1) {
      const labels = <int, String>{
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      };
      return labels[normalized.first] ?? 'Custom';
    }
    return '${normalized.length} days';
  }

  Future<void> _activateScheduleNow(ScheduleModel schedule) async {
    try {
      if (schedule.isActive) {
        await ScheduleService.syncWithNative();
      } else {
        await ScheduleService.saveSchedule(schedule.copyWith(isActive: true));
      }
      if (!mounted) return;
      await _loadSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule synced now.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to activate: $e')));
    }
  }

  Future<void> _duplicateSchedule(ScheduleModel schedule) async {
    final copy = ScheduleModel(
      id: const Uuid().v4(),
      name: '${schedule.name} Copy',
      type: schedule.type,
      targetApps: List<String>.from(schedule.targetApps),
      days: List<int>.from(schedule.days),
      blocks: List<ScheduleBlock>.from(schedule.blocks),
      durationLimit: schedule.durationLimit,
      isActive: true,
      emoji: schedule.emoji,
    );
    try {
      await ScheduleService.saveSchedule(copy);
      if (!mounted) return;
      await _loadSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schedule duplicated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Duplicate failed: $e')));
    }
  }

  Future<void> _openRegimePleaComposer({
    required ScheduleModel schedule,
    required bool deleteMode,
  }) async {
    final reasonController = TextEditingController();
    var selectedMinutes = 15;
    final durationOptions = <int>[5, 10, 20, 30];

    final request = await showModalBottomSheet<_RegimePleaRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deleteMode
                        ? 'Delete schedule via tribunal'
                        : 'Beg for a break',
                    style: AppTheme.h3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    deleteMode
                        ? 'Explain why this schedule should be removed.'
                        : 'Request temporary relief from this schedule.',
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  if (!deleteMode) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: durationOptions
                          .map((minutes) {
                            final selected = selectedMinutes == minutes;
                            return ChoiceChip(
                              label: Text('$minutes min'),
                              selected: selected,
                              onSelected: (_) {
                                setSheetState(() => selectedMinutes = minutes);
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    maxLength: 180,
                    decoration: AppTheme.defaultInputDecoration(
                      labelText: 'Reason',
                      hintText: deleteMode
                          ? 'Why should this schedule be deleted?'
                          : 'Why do you need a break?',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: AppTheme.secondaryButtonStyle,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Add a reason for the tribunal.',
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(
                              sheetContext,
                              _RegimePleaRequest(
                                reason: reason,
                                durationMinutes: deleteMode
                                    ? 5
                                    : selectedMinutes,
                              ),
                            );
                          },
                          style: deleteMode
                              ? AppTheme.dangerButtonStyle
                              : AppTheme.primaryButtonStyle,
                          child: Text(
                            deleteMode ? 'Request delete' : 'Send plea',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();

    if (request == null) return;

    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    try {
      final userData = await AuthService.getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();
      final nickname = (userData?['nickname'] as String?)?.trim();
      if (squadId == null || squadId.isEmpty) {
        throw const PleaNoSquadException();
      }

      final pleaId = await SquadService.createPlea(
        uid: uid,
        userName: nickname?.isNotEmpty == true ? nickname! : 'A Member',
        squadId: squadId,
        appName: deleteMode
            ? 'Delete ${schedule.name}'
            : '${schedule.name} break',
        packageName: deleteMode
            ? 'regime-delete:${schedule.id}'
            : 'regime:${schedule.id}',
        durationMinutes: request.durationMinutes,
        reason: request.reason,
      );
      if (!mounted) return;
      context.go('/tribunal/$pleaId');
    } on PleaNoSquadException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(
            label: 'Open Squad',
            onPressed: () => context.go('/squad'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tribunal request failed: $e')));
    }
  }

  Future<void> _showScheduleActionSheet(ScheduleModel schedule) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    PhosphorIcons.lockSimple,
                    color: context.scheme.primary,
                  ),
                  title: Text('Block now', style: AppTheme.baseMedium),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _activateScheduleNow(schedule);
                  },
                ),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.hourglassHigh,
                    color: context.scheme.primary,
                  ),
                  title: Text('Beg for a break', style: AppTheme.baseMedium),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openRegimePleaComposer(
                      schedule: schedule,
                      deleteMode: false,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.copy,
                    color: context.scheme.primary,
                  ),
                  title: Text('Duplicate', style: AppTheme.baseMedium),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _duplicateSchedule(schedule);
                  },
                ),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.trash,
                    color: context.colors.danger,
                  ),
                  title: Text(
                    'Delete',
                    style: AppTheme.baseMedium.copyWith(
                      color: context.colors.danger,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openRegimePleaComposer(
                      schedule: schedule,
                      deleteMode: true,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    final isBlocking = _isCurrentlyBlocking(schedule);
    final usageLimitStatus = _usageLimitStatuses[schedule.id];
    final isLimitReached = usageLimitStatus?.limitReached ?? false;
    final isUsageBannerState =
        schedule.type == ScheduleType.usageLimit &&
        (usageLimitStatus?.missingUsageAccess == true || _isUsageStatsMissing);
    final hasTemporaryApproval = schedule.targetApps.any(
      _temporaryApprovedPackages.contains,
    );
    final borderColor = hasTemporaryApproval
        ? context.colors.success
        : (isLimitReached
              ? context.colors.danger
              : isBlocking
              ? context.scheme.primary
              : context.scheme.outlineVariant.withValues(alpha: 0.6));
    final statusColor = hasTemporaryApproval
        ? context.colors.success
        : (isLimitReached || isUsageBannerState
              ? context.colors.danger
              : (isBlocking
                    ? context.scheme.primary
                    : context.colors.textSecondary));
    final statusLabel = hasTemporaryApproval
        ? 'Temporarily unlocked'
        : _buildScheduleStatus(schedule);
    final typeLabel = _blockTypeLabel(schedule.type);
    final dayLabel = _daySummary(schedule.days);
    final blockCount = schedule.type == ScheduleType.timeBlock
        ? '${schedule.blocks.length} blocks'
        : 'Session cap';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        await context.push('/regime/edit', extra: schedule);
        if (!mounted) return;
        _loadSchedules();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: isBlocking || isLimitReached ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: context.scheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _blockTypeIcon(schedule.type),
                        size: 14,
                        color: context.scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        typeLabel,
                        style: AppTheme.xsBold.copyWith(
                          color: context.scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    PhosphorIcons.dotsThree,
                    color: context.colors.textSecondary,
                  ),
                  onPressed: () => _showScheduleActionSheet(schedule),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.center,
              child: Text(
                schedule.emoji,
                style: AppTheme.xxlMedium.copyWith(fontSize: 64, height: 1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              schedule.name,
              textAlign: TextAlign.center,
              style: AppTheme.lgBold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: AppTheme.smMedium.copyWith(color: statusColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: context.scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStackedIcons(schedule.targetApps)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.scheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$dayLabel - $blockCount',
                    style: AppTheme.xsMedium.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            _buildGhostRestrictionNotice(schedule.targetApps),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostRestrictionNotice(List<String> packages) {
    if (packages.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<AppInfo>>(
      future: Future.wait(
        packages.map((package) => AppDiscoveryService.getAppDetails(package)),
      ),
      builder: (context, snapshot) {
        final apps = snapshot.data;
        if (apps == null || apps.isEmpty) return const SizedBox.shrink();

        final ghosts = apps
            .where((app) => app.isGhost || app.name == AppInfo.ghostAppName)
            .toList(growable: false);
        if (ghosts.isEmpty) return const SizedBox.shrink();

        final packageSummary = ghosts
            .map((app) => app.packageName)
            .where((pkg) => pkg.trim().isNotEmpty)
            .join(', ');

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.ghost,
                      size: 14,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        packageSummary.isEmpty
                            ? AppInfo.ghostAppName
                            : '${AppInfo.ghostAppName} - $packageSummary',
                        style: AppTheme.xsMedium.copyWith(
                          color: context.colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Restriction remains active',
                  style: AppTheme.xsBold.copyWith(color: context.colors.danger),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackedIcons(List<String> packages) {
    final icons = packages.take(5).toList();
    if (icons.isEmpty) {
      return Text(
        'No apps selected',
        style: AppTheme.smRegular.copyWith(color: context.colors.textSecondary),
      );
    }
    final width = 28 + ((icons.length - 1) * 20);
    return SizedBox(
      height: 32,
      width: width.toDouble(),
      child: Stack(
        children: List.generate(icons.length, (i) {
          return Positioned(
            left: i * 20.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _temporaryApprovedPackages.contains(icons[i])
                      ? context.colors.success
                      : context.scheme.surface,
                  width: _temporaryApprovedPackages.contains(icons[i]) ? 1 : 2,
                ),
              ),
              child: ClipOval(
                child: SingleAppIcon(packageName: icons[i], size: 28),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHitlistSection() {
    final packages = _activeHitlist.toList();
    if (packages.isEmpty) return _buildEmptyLabel('HITLIST CLEAR');
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: packages.length,
        itemBuilder: (context, index) {
          final packageName = packages[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: _temporaryApprovedPackages.contains(packageName)
                  ? Border.all(color: context.colors.success, width: 1)
                  : null,
            ),
            child: SingleAppIcon(packageName: packageName, size: 32),
          );
        },
      ),
    );
  }

  Widget _buildEmptyLabel(String text) {
    return Text(
      text,
      style: AppTheme.bodySmall.copyWith(
        color: context.colors.textSecondary.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Center(
        child: Text(
          'TAP + TO START THE GRIND',
          style: AppTheme.bodyMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RegimePleaRequest {
  final String reason;
  final int durationMinutes;

  const _RegimePleaRequest({
    required this.reason,
    required this.durationMinutes,
  });
}

class _UsageLimitStatus {
  final int usedMillis;
  final int remainingMillis;
  final bool missingUsageAccess;
  final bool pendingActivation;

  const _UsageLimitStatus({
    required this.usedMillis,
    required this.remainingMillis,
    required this.missingUsageAccess,
    required this.pendingActivation,
  });

  const _UsageLimitStatus.missingPermission({required int limitMillis})
    : this(
        usedMillis: 0,
        remainingMillis: limitMillis,
        missingUsageAccess: true,
        pendingActivation: false,
      );

  const _UsageLimitStatus.pending({required int limitMillis})
    : this(
        usedMillis: 0,
        remainingMillis: limitMillis,
        missingUsageAccess: false,
        pendingActivation: true,
      );

  bool get limitReached =>
      !missingUsageAccess && !pendingActivation && remainingMillis <= 0;
}
