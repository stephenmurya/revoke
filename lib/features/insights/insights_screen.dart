import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/schedule_model.dart';
import '../../core/models/usage_insights_model.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/taper_plan_service.dart';
import '../../core/services/usage_insights_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_block_validator.dart';
import '../../core/utils/theme_extensions.dart';
import '../monitor/widgets/single_app_icon.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SafeArea(top: false, child: _InsightsBody()));
  }
}

class AppInsightsScreen extends StatelessWidget {
  final String packageName;

  const AppInsightsScreen({super.key, required this.packageName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppInfo>(
      future: AppDiscoveryService.getAppDetails(packageName),
      builder: (context, snapshot) {
        final app = snapshot.data;
        final title = app?.name ?? packageName;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                SingleAppIcon(packageName: packageName, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.lgMedium,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: _InsightsBody(packageName: packageName),
          ),
        );
      },
    );
  }
}

enum _InsightsTab { today, week, trend }

extension on _InsightsTab {
  String get label {
    return switch (this) {
      _InsightsTab.today => 'Today',
      _InsightsTab.week => 'This Week',
      _InsightsTab.trend => 'Trend',
    };
  }

  String get mode {
    return switch (this) {
      _InsightsTab.today => 'day',
      _InsightsTab.week => 'week',
      _InsightsTab.trend => 'trend',
    };
  }
}

class _InsightsBody extends StatefulWidget {
  final String? packageName;

  const _InsightsBody({this.packageName});

  @override
  State<_InsightsBody> createState() => _InsightsBodyState();
}

class _InsightsBodyState extends State<_InsightsBody> {
  _InsightsTab _selectedTab = _InsightsTab.today;
  DateTime _selectedDay = _startOfDay(DateTime.now());
  DateTime _selectedWeekAnchor = _startOfDay(DateTime.now());
  int _trendPeriodDays = 30;
  UsageInsightsSnapshot? _snapshot;
  bool _loading = true;
  bool _refreshing = false;
  int _dailyGoalMinutes = 0;

  bool get _isAppDetail => widget.packageName?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _loadDailyGoal();
    _loadInsights();
  }

  Future<void> _loadDailyGoal() async {
    if (_isAppDetail) return;
    try {
      final activePlan = await TaperPlanService.getActivePlan();
      if (!mounted) return;
      if (activePlan != null) {
        setState(() {
          _dailyGoalMinutes = activePlan.limitFor(DateTime.now());
        });
        return;
      }

      final schedules = await ScheduleService.getSchedules();
      final caps =
          schedules
              .where(_isUsageLimitSessionActive)
              .map((schedule) => schedule.durationLimit?.inMinutes ?? 0)
              .where((minutes) => minutes > 0)
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _dailyGoalMinutes = caps.isEmpty ? 0 : caps.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dailyGoalMinutes = 0;
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
    if (schedule.blocks.isEmpty) return true;
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final nowMin = now.hour * 60 + now.minute;
    return ScheduleBlockValidator.isMinuteWithinBlocks(schedule.blocks, nowMin);
  }

  DateTime get _activeAnchorDate {
    return switch (_selectedTab) {
      _InsightsTab.today => _selectedDay,
      _InsightsTab.week => _selectedWeekAnchor,
      _InsightsTab.trend => DateTime.now(),
    };
  }

  int? get _activePeriodDays {
    return _selectedTab == _InsightsTab.trend ? _trendPeriodDays : null;
  }

  Future<void> _loadInsights({bool forceLoading = false}) async {
    final mode = _selectedTab.mode;
    final anchor = _activeAnchorDate;
    final periodDays = _activePeriodDays;
    if (forceLoading && mounted) {
      setState(() {
        _loading = true;
      });
    }

    final cached = await UsageInsightsService.readCache(
      mode: mode,
      anchorDate: anchor,
      packageName: widget.packageName,
      periodDays: periodDays,
    );
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _snapshot = cached;
        _loading = false;
      });
    }

    setState(() {
      _refreshing = true;
      _loading = cached == null;
    });

    try {
      final fresh = await UsageInsightsService.refresh(
        mode: mode,
        anchorDate: anchor,
        packageName: widget.packageName,
        periodDays: periodDays,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = fresh;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _snapshot ??= UsageInsightsSnapshot.empty(
          mode: mode,
          packageName: widget.packageName ?? '',
          periodDays: periodDays ?? 1,
        );
        _loading = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _selectTab(_InsightsTab tab) {
    if (tab == _selectedTab) return;
    setState(() {
      _selectedTab = tab;
      _snapshot = null;
    });
    _loadInsights(forceLoading: true);
  }

  void _shiftDay(int delta) {
    final today = _startOfDay(DateTime.now());
    final next = _startOfDay(_selectedDay.add(Duration(days: delta)));
    if (next.isAfter(today)) return;
    setState(() {
      _selectedDay = next;
      _snapshot = null;
    });
    _loadInsights(forceLoading: true);
  }

  void _shiftWeek(int deltaWeeks) {
    final currentWeek = _startOfWeek(DateTime.now());
    final next = _startOfWeek(
      _selectedWeekAnchor.add(Duration(days: deltaWeeks * 7)),
    );
    if (next.isAfter(currentWeek)) return;
    setState(() {
      _selectedWeekAnchor = next;
      _snapshot = null;
    });
    _loadInsights(forceLoading: true);
  }

  void _toggleTrendPeriod() {
    setState(() {
      _trendPeriodDays = _trendPeriodDays == 30 ? 14 : 30;
      _snapshot = null;
    });
    _loadInsights(forceLoading: true);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.scheme.primary,
      onRefresh: () => _loadInsights(forceLoading: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 110),
        children: [
          _buildTabs(),
          const SizedBox(height: 10),
          _buildSelector(),
          const SizedBox(height: 10),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: CircularProgressIndicator(color: context.scheme.primary),
              ),
            )
          else
            _buildContent(_snapshot ?? UsageInsightsSnapshot.empty()),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          for (final tab in _InsightsTab.values)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _selectTab(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: tab == _selectedTab
                        ? context.scheme.primary.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tab.label,
                    textAlign: TextAlign.center,
                    style: AppTheme.smBold.copyWith(
                      color: tab == _selectedTab
                          ? context.scheme.primary
                          : context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    final canForward = switch (_selectedTab) {
      _InsightsTab.today => _startOfDay(
        _selectedDay,
      ).isBefore(_startOfDay(DateTime.now())),
      _InsightsTab.week => _startOfWeek(
        _selectedWeekAnchor,
      ).isBefore(_startOfWeek(DateTime.now())),
      _InsightsTab.trend => true,
    };

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _selectedTab == _InsightsTab.trend
              ? _toggleTrendPeriod
              : () {
                  if (_selectedTab == _InsightsTab.today) {
                    _shiftDay(-1);
                  } else {
                    _shiftWeek(-1);
                  }
                },
          icon: Icon(PhosphorIcons.caretLeft),
        ),
        Expanded(
          child: Text(
            _selectorLabel(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.baseBold.copyWith(color: context.scheme.onSurface),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: !canForward
              ? null
              : _selectedTab == _InsightsTab.trend
              ? _toggleTrendPeriod
              : () {
                  if (_selectedTab == _InsightsTab.today) {
                    _shiftDay(1);
                  } else {
                    _shiftWeek(1);
                  }
                },
          icon: Icon(PhosphorIcons.caretRight),
        ),
      ],
    );
  }

  String _selectorLabel() {
    return switch (_selectedTab) {
      _InsightsTab.today => _dayLabel(_selectedDay),
      _InsightsTab.week => _weekLabel(_selectedWeekAnchor),
      _InsightsTab.trend =>
        _trendPeriodDays == 30 ? 'Last 1 Month' : 'Last 2 Weeks',
    };
  }

  Widget _buildContent(UsageInsightsSnapshot snapshot) {
    if (!snapshot.hasUsageAccess) {
      return _buildPermissionState();
    }
    return switch (_selectedTab) {
      _InsightsTab.today => _buildToday(snapshot),
      _InsightsTab.week => _buildWeek(snapshot),
      _InsightsTab.trend => _buildTrend(snapshot),
    };
  }

  Widget _buildToday(UsageInsightsSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isAppDetail)
          _buildAppMetricCard(
            title: 'App use today',
            minutes: snapshot.totalMinutes,
          )
        else
          _UsageHeroCard(
            snapshot: snapshot,
            dailyGoalMinutes: _dailyGoalMinutes,
            isRefreshing: _refreshing,
            onOpenApp: _openAppInsights,
          ),
        const SizedBox(height: 10),
        _UsageLineChartCard(
          title: 'Usage by time',
          snapshot: snapshot,
          averageMinutes: null,
          showPeak: true,
        ),
        if (!_isAppDetail) ...[
          const SizedBox(height: 10),
          _MostUsedAppsCard(apps: snapshot.topApps, onTap: _openAppInsights),
          const SizedBox(height: 10),
          _FocusCards(snapshot: snapshot),
        ],
      ],
    );
  }

  Widget _buildWeek(UsageInsightsSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAppMetricCard(
          title: _isAppDetail ? 'Average app use' : 'Average screen time',
          minutes: snapshot.averageDailyMinutes,
        ),
        const SizedBox(height: 10),
        _UsageLineChartCard(
          title: 'Week view',
          snapshot: snapshot,
          averageMinutes: snapshot.averageDailyMinutes,
          showPeak: false,
        ),
        if (!_isAppDetail) ...[
          const SizedBox(height: 10),
          _MostUsedAppsCard(apps: snapshot.topApps, onTap: _openAppInsights),
          const SizedBox(height: 10),
          _FocusCards(snapshot: snapshot),
        ],
      ],
    );
  }

  Widget _buildTrend(UsageInsightsSnapshot snapshot) {
    final isLess = snapshot.trendDeltaMinutes < 0;
    final isMore = snapshot.trendDeltaMinutes > 0;
    final color = isLess
        ? context.colors.success
        : isMore
        ? context.colors.danger
        : context.colors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: _cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _formatSignedMinutes(snapshot.trendDeltaMinutes),
                textAlign: TextAlign.center,
                style: AppTheme.size5xlBold.copyWith(
                  color: context.scheme.onSurface,
                  height: 0.95,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLess
                    ? 'Less Screen Time Per Day'
                    : isMore
                    ? 'More Screen Time Per Day'
                    : 'No Change Per Day',
                style: AppTheme.baseMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLess
                          ? Icons.arrow_downward
                          : isMore
                          ? Icons.arrow_upward
                          : Icons.remove,
                      size: 15,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${isLess
                          ? '-'
                          : isMore
                          ? '+'
                          : ''}${snapshot.trendPercent}% change in this period',
                      style: AppTheme.xsBold.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _UsageLineChartCard(
          title: 'Daily trend',
          snapshot: snapshot,
          averageMinutes: snapshot.averageDailyMinutes,
          showPeak: false,
          dottedAverage: true,
        ),
      ],
    );
  }

  Widget _buildAppMetricCard({required String title, required int minutes}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          Text(
            title,
            style: AppTheme.smBold.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMinutes(minutes),
            textAlign: TextAlign.center,
            style: AppTheme.size5xlBold.copyWith(
              color: context.scheme.onSurface,
              height: 0.95,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Enable Usage Access', style: AppTheme.xlBold),
          const SizedBox(height: 8),
          Text(
            'Insights need Usage Access to calculate screen time, app lists, focus periods, and charts.',
            style: AppTheme.baseRegular.copyWith(
              color: context.colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => context.push('/permissions'),
            child: const Text('Open permissions'),
          ),
        ],
      ),
    );
  }

  void _openAppInsights(UsageInsightApp app) {
    if (app.packageName.trim().isEmpty) return;
    context.push(
      '/insights/app?packageName=${Uri.encodeComponent(app.packageName)}',
    );
  }
}

class _UsageHeroCard extends StatelessWidget {
  final UsageInsightsSnapshot snapshot;
  final int dailyGoalMinutes;
  final bool isRefreshing;
  final ValueChanged<UsageInsightApp> onOpenApp;

  const _UsageHeroCard({
    required this.snapshot,
    required this.dailyGoalMinutes,
    required this.isRefreshing,
    required this.onOpenApp,
  });

  @override
  Widget build(BuildContext context) {
    final progress = dailyGoalMinutes <= 0
        ? 0.0
        : snapshot.totalMinutes / dailyGoalMinutes;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Screen time today',
                      style: AppTheme.smBold.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatMinutes(snapshot.totalMinutes),
                        style: AppTheme.size5xlBold.copyWith(
                          color: context.scheme.onSurface,
                          height: 0.95,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Daily goal ${dailyGoalMinutes <= 0 ? '-' : _formatMinutes(dailyGoalMinutes)}',
                      style: AppTheme.baseMedium.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                  painter: _RadialUsagePainter(
                    progress: progress,
                    baseColor: context.scheme.primary,
                    overflowColor: context.colors.warning,
                    trackColor: context.scheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      dailyGoalMinutes <= 0
                          ? '-'
                          : '${(progress * 100).round()}%',
                      style: AppTheme.smBold.copyWith(
                        color: context.scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              if (isRefreshing)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.scheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Top apps',
            style: AppTheme.smBold.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          if (snapshot.topApps.isEmpty)
            Text(
              'No app usage yet.',
              style: AppTheme.smRegular.copyWith(
                color: context.colors.textSecondary,
              ),
            )
          else
            for (final app in snapshot.topApps.take(3)) ...[
              _CompactAppUsageRow(app: app, onTap: () => onOpenApp(app)),
              if (app != snapshot.topApps.take(3).last)
                Divider(
                  height: 12,
                  color: context.scheme.outlineVariant.withValues(alpha: 0.35),
                ),
            ],
        ],
      ),
    );
  }
}

class _UsageLineChartCard extends StatelessWidget {
  final String title;
  final UsageInsightsSnapshot snapshot;
  final int? averageMinutes;
  final bool showPeak;
  final bool dottedAverage;

  const _UsageLineChartCard({
    required this.title,
    required this.snapshot,
    required this.averageMinutes,
    required this.showPeak,
    this.dottedAverage = false,
  });

  @override
  Widget build(BuildContext context) {
    final peakLabel = (snapshot.peak['label'] as String?)?.trim();
    final peakMinutes = switch (snapshot.peak['minutes']) {
      num() => snapshot.peak['minutes'].toInt(),
      String() => int.tryParse(snapshot.peak['minutes']) ?? 0,
      _ => 0,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTheme.lgBold)),
              if (showPeak && peakLabel != null && peakMinutes > 0)
                Text(
                  'Peak $peakLabel',
                  style: AppTheme.xsBold.copyWith(
                    color: context.scheme.primary,
                  ),
                )
              else if (averageMinutes != null && averageMinutes! > 0)
                Text(
                  'Avg ${_formatMinutes(averageMinutes!)}',
                  style: AppTheme.xsBold.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 172,
            width: double.infinity,
            child: CustomPaint(
              painter: _UsageLineChartPainter(
                buckets: snapshot.buckets,
                peakIndex: switch (snapshot.peak['index']) {
                  num() => snapshot.peak['index'].toInt(),
                  String() => int.tryParse(snapshot.peak['index']),
                  _ => null,
                },
                averageMinutes: averageMinutes,
                dottedAverage: dottedAverage,
                lineColor: context.scheme.primary,
                mutedColor: context.colors.textSecondary,
                borderColor: context.scheme.outlineVariant.withValues(
                  alpha: 0.55,
                ),
                fillColor: context.scheme.primary.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MostUsedAppsCard extends StatelessWidget {
  final List<UsageInsightApp> apps;
  final ValueChanged<UsageInsightApp> onTap;

  const _MostUsedAppsCard({required this.apps, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Most used apps', style: AppTheme.lgBold),
          const SizedBox(height: 6),
          if (apps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No app usage yet.',
                style: AppTheme.smRegular.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            )
          else
            for (final app in apps.take(10)) ...[
              _AppUsageListRow(app: app, onTap: () => onTap(app)),
              if (app != apps.take(10).last)
                Divider(
                  height: 1,
                  color: context.scheme.outlineVariant.withValues(alpha: 0.35),
                ),
            ],
        ],
      ),
    );
  }
}

class _CompactAppUsageRow extends StatelessWidget {
  final UsageInsightApp app;
  final VoidCallback onTap;

  const _CompactAppUsageRow({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SingleAppIcon(packageName: app.packageName, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: FutureBuilder<AppInfo>(
                future: AppDiscoveryService.getAppDetails(app.packageName),
                builder: (context, snapshot) {
                  final name = snapshot.data?.name ?? app.packageName;
                  return Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.smMedium,
                  );
                },
              ),
            ),
            Text(
              _formatMinutes(app.minutes),
              style: AppTheme.smBold.copyWith(color: context.scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppUsageListRow extends StatelessWidget {
  final UsageInsightApp app;
  final VoidCallback onTap;

  const _AppUsageListRow({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SingleAppIcon(packageName: app.packageName, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: FutureBuilder<AppInfo>(
                future: AppDiscoveryService.getAppDetails(app.packageName),
                builder: (context, snapshot) {
                  final name = snapshot.data?.name ?? app.packageName;
                  return Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.baseMedium,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(_formatMinutes(app.minutes), style: AppTheme.baseBold),
            const SizedBox(width: 8),
            Icon(
              PhosphorIcons.caretRight,
              size: 16,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusCards extends StatelessWidget {
  final UsageInsightsSnapshot snapshot;

  const _FocusCards({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryMetricCard(
            label: 'Longest Focus',
            value: _formatMs(snapshot.longestFocusMs),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryMetricCard(
            label: 'Continuous Use',
            value: _formatMs(snapshot.longestContinuousUseMs),
          ),
        ),
      ],
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.smBold.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.xxlBold.copyWith(color: context.scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialUsagePainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color overflowColor;
  final Color trackColor;

  const _RadialUsagePainter({
    required this.progress,
    required this.baseColor,
    required this.overflowColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = math.min(size.width, size.height) / 2 - 8;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8
      ..color = trackColor;

    canvas.drawCircle(center, maxRadius, trackPaint);

    final safeProgress = progress.isFinite
        ? progress.clamp(0, 6).toDouble()
        : 0.0;
    var remaining = safeProgress;
    var radius = maxRadius;
    var ring = 0;
    while (remaining > 0 && radius > 18) {
      final segment = remaining.clamp(0, 1).toDouble();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ring == 0 ? 8 : 6
        ..color = ring == 0
            ? baseColor
            : Color.lerp(
                overflowColor,
                Colors.redAccent,
                (ring - 1) / 4,
              )!.withValues(alpha: 0.92);
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * segment, false, paint);
      remaining -= 1;
      radius -= 10;
      ring += 1;
    }
  }

  @override
  bool shouldRepaint(covariant _RadialUsagePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.overflowColor != overflowColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class _UsageLineChartPainter extends CustomPainter {
  final List<UsageInsightBucket> buckets;
  final int? peakIndex;
  final int? averageMinutes;
  final bool dottedAverage;
  final Color lineColor;
  final Color mutedColor;
  final Color borderColor;
  final Color fillColor;

  const _UsageLineChartPainter({
    required this.buckets,
    required this.peakIndex,
    required this.averageMinutes,
    required this.dottedAverage,
    required this.lineColor,
    required this.mutedColor,
    required this.borderColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(0, 8, size.width, size.height - 26);
    final activeBuckets = buckets.where((bucket) => !bucket.isFuture).toList();
    final maxBaseMinutes = [
      ...activeBuckets.map((bucket) => bucket.minutes),
      averageMinutes ?? 0,
      10,
    ].fold<int>(10, (maxValue, value) => math.max(maxValue, value).toInt());
    final maxMinutes = maxBaseMinutes * 1.18;

    final gridPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + (chartRect.height * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (activeBuckets.isEmpty) return;

    Offset pointFor(UsageInsightBucket bucket) {
      final divisor = math.max(1, buckets.length - 1);
      final x = chartRect.left + (chartRect.width * bucket.index / divisor);
      final y =
          chartRect.bottom -
          ((bucket.minutes / maxMinutes).clamp(0, 1).toDouble() *
              chartRect.height);
      return Offset(x, y);
    }

    if (averageMinutes != null && averageMinutes! > 0) {
      final averageY =
          chartRect.bottom -
          ((averageMinutes! / maxMinutes).clamp(0, 1).toDouble() *
              chartRect.height);
      final avgPaint = Paint()
        ..color = mutedColor.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      if (dottedAverage) {
        var x = 0.0;
        while (x < size.width) {
          canvas.drawLine(
            Offset(x, averageY),
            Offset(x + 6, averageY),
            avgPaint,
          );
          x += 12;
        }
      } else {
        canvas.drawLine(
          Offset(0, averageY),
          Offset(size.width, averageY),
          avgPaint,
        );
      }
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < activeBuckets.length; i++) {
      final point = pointFor(activeBuckets[i]);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        fillPath.moveTo(point.dx, chartRect.bottom);
        fillPath.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        fillPath.lineTo(point.dx, point.dy);
      }
    }
    fillPath.lineTo(pointFor(activeBuckets.last).dx, chartRect.bottom);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final dotPaint = Paint()..color = lineColor;
    for (final bucket in activeBuckets) {
      canvas.drawCircle(pointFor(bucket), 2.5, dotPaint);
    }

    UsageInsightBucket? peakBucket;
    if (peakIndex != null) {
      for (final bucket in activeBuckets) {
        if (bucket.index == peakIndex) {
          peakBucket = bucket;
          break;
        }
      }
    }
    if (peakBucket != null && peakBucket.minutes > 0) {
      final point = pointFor(peakBucket);
      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        9,
        Paint()
          ..color = lineColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _UsageLineChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.peakIndex != peakIndex ||
        oldDelegate.averageMinutes != averageMinutes ||
        oldDelegate.dottedAverage != dottedAverage ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.mutedColor != mutedColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.fillColor != fillColor;
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.scheme.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: context.scheme.outlineVariant.withValues(alpha: 0.7),
    ),
    boxShadow: [
      BoxShadow(
        color: context.scheme.onSurface.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _startOfWeek(DateTime value) {
  final day = _startOfDay(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String _dayLabel(DateTime value) {
  final today = _startOfDay(DateTime.now());
  final day = _startOfDay(value);
  if (day == today) return 'Today';
  return DateFormat('EEEE MMMM d').format(day);
}

String _weekLabel(DateTime value) {
  final currentWeek = _startOfWeek(DateTime.now());
  final week = _startOfWeek(value);
  if (week == currentWeek) return 'This Week';
  final end = week.add(const Duration(days: 6));
  return '${DateFormat('MMM d').format(week)} - ${DateFormat('MMM d').format(end)}';
}

String _formatMinutes(int minutes) {
  final safe = minutes.clamp(0, 100000).toInt();
  final hours = safe ~/ 60;
  final mins = safe % 60;
  if (hours <= 0) return '${mins}m';
  if (mins == 0) return '${hours}h';
  return '${hours}h ${mins}m';
}

String _formatMs(int ms) {
  return _formatMinutes(((ms + 59999) / 60000).floor());
}

String _formatSignedMinutes(int minutes) {
  if (minutes == 0) return '0m';
  final prefix = minutes < 0 ? '-' : '+';
  return '$prefix${_formatMinutes(minutes.abs())}';
}
