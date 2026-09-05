import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/insights_models.dart';
import '../../core/models/usage_insights_model.dart';
import '../../core/services/insights_repository.dart';
import '../../core/services/premium_entitlement_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import '../monitor/widgets/single_app_icon.dart';
import 'widgets/usage_trend_chart.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _InsightsBody();
}

class AppInsightsScreen extends StatelessWidget {
  const AppInsightsScreen({super.key, required this.packageName});

  final String packageName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayPackageName(packageName)),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        top: false,
        child: _InsightsBody(packageName: packageName),
      ),
    );
  }
}

class _InsightsBody extends StatefulWidget {
  const _InsightsBody({this.packageName});

  final String? packageName;

  @override
  State<_InsightsBody> createState() => _InsightsBodyState();
}

class _InsightsBodyState extends State<_InsightsBody> {
  InsightsOverview? _overview;
  InsightsAdvancedData? _advanced;
  bool _loading = true;
  bool _loadingAdvanced = false;
  bool _refreshing = false;
  String? _error;
  int _periodDays = 7;
  late bool _hasPremium;

  bool get _isAppDetail => widget.packageName?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _hasPremium = PremiumEntitlementService.instance.hasPremium;
    PremiumEntitlementService.instance.state.addListener(_onEntitlementChanged);
    _load();
  }

  @override
  void dispose() {
    PremiumEntitlementService.instance.state.removeListener(
      _onEntitlementChanged,
    );
    super.dispose();
  }

  void _onEntitlementChanged() {
    final next = PremiumEntitlementService.instance.hasPremium;
    if (!mounted || next == _hasPremium) return;
    setState(() {
      _hasPremium = next;
      if (!next) _periodDays = 7;
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final periodDays = _hasPremium ? _periodDays : 7;
    if (mounted) {
      setState(() {
        _refreshing = _overview != null;
        _loading = _overview == null;
        _error = null;
        _advanced = null;
      });
    }
    try {
      final overview = _isAppDetail
          ? InsightsOverview(
              snapshot: await InsightsRepository.loadPackageOverview(
                packageName: widget.packageName!,
                periodDays: periodDays,
              ),
              appNames: const <String, String>{},
            )
          : await InsightsRepository.loadOverview(periodDays: periodDays);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
        _refreshing = false;
      });
      if (_hasPremium && !_isAppDetail) {
        unawaited(_loadAdvanced(periodDays));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error =
            'Insights could not be refreshed. Your last view is still available.';
      });
    }
  }

  Future<void> _loadAdvanced(int periodDays) async {
    if (!mounted) return;
    setState(() => _loadingAdvanced = true);
    try {
      final advanced = await InsightsRepository.loadAdvanced(
        periodDays: periodDays,
      );
      if (!mounted) return;
      setState(() => _advanced = advanced);
    } finally {
      if (mounted) setState(() => _loadingAdvanced = false);
    }
  }

  Future<void> _selectPeriod(int periodDays) async {
    if (periodDays == _periodDays) return;
    if (periodDays > 7 && !_hasPremium) {
      await context.push(
        '/premium',
        extra: 'Understand how your Commitments change your habits over time.',
      );
      if (!mounted) return;
      final nowPremium = PremiumEntitlementService.instance.hasPremium;
      if (!nowPremium) return;
      setState(() => _hasPremium = true);
    }
    if (!mounted) return;
    setState(() => _periodDays = periodDays);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;
    return RefreshIndicator(
      color: context.colors.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          RevokeSpacing.lg,
          RevokeSpacing.sm,
          RevokeSpacing.lg,
          RevokeSpacing.xxl,
        ),
        children: [
          if (_isAppDetail)
            Text(
              'Usage evidence for this app.',
              style: context.text.bodySecondary.copyWith(
                color: context.colors.textSecondary,
              ),
            )
          else ...[
            Text(
              'Understand how your usage is changing.',
              style: context.text.bodySecondary.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: RevokeSpacing.lg),
            _buildPeriodSelector(),
          ],
          const SizedBox(height: RevokeSpacing.xl),
          if (_refreshing) ...[
            LinearProgressIndicator(
              minHeight: RevokeBorders.subtle,
              color: context.colors.accent,
              backgroundColor: context.colors.borderSubtle,
            ),
            const SizedBox(height: RevokeSpacing.md),
          ],
          if (overview == null && _loading)
            const SizedBox(
              height: 260,
              child: RevokeLoadingState(label: 'Loading Insights'),
            )
          else if (overview == null)
            RevokeErrorState(
              message: _error ?? 'Insights are unavailable.',
              onRetry: _load,
            )
          else ...[
            if (_error != null) _buildInlineError(_error!),
            _buildOverview(overview),
            if (overview.snapshot.hasUsageAccess) ...[
              const SizedBox(height: RevokeSpacing.xl),
              _buildTopApps(overview),
              if (!_isAppDetail && _hasPremium) ...[
                const SizedBox(height: RevokeSpacing.xl),
                if (_loadingAdvanced && _advanced == null)
                  const RevokeLoadingState(label: 'Loading Commitment insights')
                else ...[
                  if (_advanced?.reduceInsights.isNotEmpty == true)
                    _buildReduceSection(_advanced!.reduceInsights, overview),
                  if (_advanced?.overrideSummary != null) ...[
                    const SizedBox(height: RevokeSpacing.xl),
                    _buildOverrideSection(_advanced!.overrideSummary!),
                  ],
                ],
              ] else if (!_isAppDetail) ...[
                const SizedBox(height: RevokeSpacing.xl),
                _buildPremiumPreview(),
              ],
            ] else ...[
              const SizedBox(height: RevokeSpacing.xl),
              _buildPermissionState(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Semantics(
      label: 'Insights period',
      child: Row(
        children: [
          Expanded(child: _periodOption(7, '7 days')),
          const SizedBox(width: RevokeSpacing.sm),
          Expanded(child: _periodOption(30, '30 days')),
        ],
      ),
    );
  }

  Widget _periodOption(int days, String label) {
    final selected = days == _periodDays;
    final premiumOnly = days > 7 && !_hasPremium;
    return Semantics(
      button: true,
      selected: selected,
      label: premiumOnly ? '$label, Premium' : label,
      child: InkWell(
        onTap: () => _selectPeriod(days),
        borderRadius: RevokeRadii.controlRadius,
        child: AnimatedContainer(
          duration: RevokeMotion.state,
          constraints: const BoxConstraints(
            minHeight: RevokeTouchTargets.minimum,
          ),
          padding: const EdgeInsets.symmetric(vertical: RevokeSpacing.md),
          decoration: BoxDecoration(
            color: selected ? context.colors.accentSoft : Colors.transparent,
            borderRadius: RevokeRadii.controlRadius,
            border: Border.all(
              color: selected
                  ? context.colors.accent
                  : context.colors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: context.text.label.copyWith(
                  color: selected
                      ? context.colors.accent
                      : context.colors.textSecondary,
                ),
              ),
              if (premiumOnly) ...[
                const SizedBox(width: RevokeSpacing.xs),
                Icon(
                  PhosphorIcons.lock,
                  size: RevokeIconSizes.compact,
                  color: context.colors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverview(InsightsOverview overview) {
    final snapshot = overview.snapshot;
    final comparison = snapshot.comparisonAvailable
        ? _comparisonText(snapshot)
        : 'Comparison will appear when both periods contain reliable data.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RevokeSectionHeader(
          title: 'Usage overview',
          action: Text(
            'Last ${snapshot.periodDays} complete days',
            style: context.text.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: RevokeSpacing.md),
        RevokeSurface(
          padding: const EdgeInsets.all(RevokeSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatMinutes(snapshot.averageDailyMinutes),
                style: context.text.numericDisplay,
              ),
              const SizedBox(height: RevokeSpacing.xs),
              Text('Average daily usage', style: context.text.bodySecondary),
              const SizedBox(height: RevokeSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _overviewStat(
                      'Total',
                      _formatMinutes(snapshot.totalMinutes),
                    ),
                  ),
                  Expanded(
                    child: _overviewStat(
                      'Recorded',
                      '${snapshot.observedDays} days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RevokeSpacing.md),
              Text(
                comparison,
                style: context.text.bodySecondary.copyWith(
                  color: snapshot.comparisonAvailable
                      ? context.colors.textPrimary
                      : context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RevokeSpacing.md),
        RevokeSurface(
          padding: const EdgeInsets.fromLTRB(
            RevokeSpacing.md,
            RevokeSpacing.md,
            RevokeSpacing.md,
            RevokeSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daily usage', style: context.text.sectionTitle),
              const SizedBox(height: RevokeSpacing.sm),
              UsageTrendChart(buckets: snapshot.buckets),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overviewStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: context.text.numericStat),
        const SizedBox(height: RevokeSpacing.xs),
        Text(
          label,
          style: context.text.caption.copyWith(color: context.colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildTopApps(InsightsOverview overview) {
    final apps = overview.snapshot.topApps.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RevokeSectionHeader(title: 'Where your time went'),
        const SizedBox(height: RevokeSpacing.md),
        if (apps.isEmpty)
          const RevokeEmptyState(
            title: 'No app usage recorded',
            message:
                'Revoke needs a little more usage history before this insight is available.',
          )
        else
          RevokeSurface(
            padding: const EdgeInsets.symmetric(horizontal: RevokeSpacing.lg),
            child: Column(
              children: [
                for (var i = 0; i < apps.length; i++) ...[
                  _AppUsageRow(
                    app: apps[i],
                    name:
                        overview.appNames[apps[i].packageName] ??
                        _displayPackageName(apps[i].packageName),
                    onTap: () => context.push(
                      '/insights/app?packageName=${Uri.encodeComponent(apps[i].packageName)}',
                    ),
                  ),
                  if (i < apps.length - 1) const RevokeDivider(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildReduceSection(
    List<ReduceInsight> insights,
    InsightsOverview overview,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RevokeSectionHeader(title: 'Reduce Commitments'),
        const SizedBox(height: RevokeSpacing.md),
        for (var i = 0; i < insights.length; i++) ...[
          _ReduceInsightSurface(
            insight: insights[i],
            appNames: overview.appNames,
          ),
          if (i < insights.length - 1) const SizedBox(height: RevokeSpacing.md),
        ],
      ],
    );
  }

  Widget _buildOverrideSection(OverrideInsightSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RevokeSectionHeader(title: 'Override behavior'),
        const SizedBox(height: RevokeSpacing.md),
        RevokeSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.total} recorded requests',
                style: context.text.numericStat,
              ),
              const SizedBox(height: RevokeSpacing.md),
              Text(
                '${summary.approved} approved · ${summary.rejected} not approved',
                style: context.text.bodySecondary,
              ),
              if (summary.approvedMinutes > 0) ...[
                const SizedBox(height: RevokeSpacing.xs),
                Text(
                  '${summary.approvedMinutes}m temporary access',
                  style: context.text.bodySecondary,
                ),
              ],
              const SizedBox(height: RevokeSpacing.lg),
              for (final entry in summary.byAuthority.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: RevokeSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: context.text.bodySecondary,
                        ),
                      ),
                      Text('${entry.value}', style: context.text.label),
                    ],
                  ),
                ),
              const SizedBox(height: RevokeSpacing.sm),
              RevokeButton(
                label: 'View Override History',
                variant: RevokeButtonVariant.tertiary,
                expand: false,
                onPressed: () => context.push('/override-history'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumPreview() {
    return RevokeSurface(
      color: context.colors.surfaceSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Go deeper with Premium', style: context.text.cardTitle),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            'See how your Commitments change your usage, where overrides happen, and how your habits move over time.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: RevokeSpacing.lg),
          RevokeButton(
            label: 'Explore Premium',
            onPressed: () => context.push(
              '/premium',
              extra:
                  'Understand how your Commitments change your habits over time.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionState() {
    return RevokeSurface(
      color: context.colors.warning.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Usage Access is needed', style: context.text.cardTitle),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            'Revoke needs Usage Access to measure app time and show reliable Insights.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: RevokeSpacing.lg),
          RevokeButton(
            label: 'Open permissions',
            variant: RevokeButtonVariant.secondary,
            onPressed: () => context.push('/permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineError(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RevokeSpacing.md),
      child: Text(
        message,
        style: context.text.caption.copyWith(color: context.colors.warning),
      ),
    );
  }

  String _comparisonText(UsageInsightsSnapshot snapshot) {
    final delta = snapshot.trendDeltaMinutes;
    if (delta == 0) {
      return 'No change from the previous ${snapshot.periodDays} days';
    }
    final direction = delta < 0 ? 'less' : 'more';
    return '${_formatMinutes(delta.abs())} $direction than the previous ${snapshot.periodDays} days';
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({
    required this.app,
    required this.name,
    required this.onTap,
  });

  final UsageInsightApp app;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$name, ${_formatMinutes(app.minutes)}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: RevokeSpacing.md),
          child: Row(
            children: [
              SingleAppIcon(
                packageName: app.packageName,
                size: RevokeIconSizes.emphasis,
              ),
              const SizedBox(width: RevokeSpacing.md),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.body,
                ),
              ),
              Text(_formatMinutes(app.minutes), style: context.text.label),
              const SizedBox(width: RevokeSpacing.sm),
              Icon(
                PhosphorIcons.caretRight,
                size: RevokeIconSizes.compact,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReduceInsightSurface extends StatelessWidget {
  const _ReduceInsightSurface({required this.insight, required this.appNames});

  final ReduceInsight insight;
  final Map<String, String> appNames;

  @override
  Widget build(BuildContext context) {
    final plan = insight.plan;
    final usage = insight.usage;
    final currentAllowance = plan.limitFor(DateTime.now());
    final currentActual = usage.averageDailyMinutes;
    final week = (plan.dayIndexFor(DateTime.now()) ~/ 7) + 1;
    final planned = usage.buckets
        .map(
          (bucket) => plan.limitFor(
            DateTime.fromMillisecondsSinceEpoch(bucket.startMs),
          ),
        )
        .toList(growable: false);
    return RevokeSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: context.text.cardTitle),
          const SizedBox(height: RevokeSpacing.xs),
          Text(
            plan.targetApps
                .map((app) => appNames[app] ?? _displayPackageName(app))
                .join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.caption.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: RevokeSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context,
                  'Baseline',
                  _formatMinutes(plan.baselineDailyMinutes),
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  'Current use',
                  _formatMinutes(currentActual),
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  'Goal',
                  _formatMinutes(plan.targetDailyMinutes),
                ),
              ),
            ],
          ),
          const SizedBox(height: RevokeSpacing.md),
          Text(
            'Week $week of ${(plan.durationDays / 7).ceil()} · Today allowance ${_formatMinutes(currentAllowance)}',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: RevokeSpacing.md),
          UsageTrendChart(
            buckets: usage.buckets,
            plannedMinutes: planned,
            height: 160,
          ),
          Row(
            children: [
              _legend(context, context.colors.accent, 'Actual use'),
              const SizedBox(width: RevokeSpacing.lg),
              _legend(
                context,
                context.colors.textSecondary,
                'Planned allowance',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: context.text.numericStat),
        const SizedBox(height: RevokeSpacing.xs),
        Text(
          label,
          style: context.text.caption.copyWith(color: context.colors.textMuted),
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 2, color: color),
        const SizedBox(width: RevokeSpacing.xs),
        Text(label, style: context.text.caption),
      ],
    );
  }
}

String _formatMinutes(int minutes) {
  final safe = minutes.clamp(0, 100000).toInt();
  final hours = safe ~/ 60;
  final remainder = safe % 60;
  if (hours == 0) return '${remainder}m';
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String _displayPackageName(String packageName) {
  final normalized = packageName.trim();
  if (normalized.isEmpty) return 'Unknown app';
  final last = normalized.split('.').last;
  if (last.isEmpty) return normalized;
  return last[0].toUpperCase() + last.substring(1);
}
