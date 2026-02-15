import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';

class FocusScoreDetailScreen extends StatefulWidget {
  const FocusScoreDetailScreen({super.key});

  @override
  State<FocusScoreDetailScreen> createState() => _FocusScoreDetailScreenState();
}

class _FocusScoreDetailScreenState extends State<FocusScoreDetailScreen> {
  int _score = 500;
  Map<String, dynamic>? _scoringMeta;
  List<int> _history = const [];
  DateTime? _metaUpdatedAt;
  bool _loadingRemote = false;

  @override
  void initState() {
    super.initState();
    _loadScore();
    _loadRemoteMeta();
  }

  Future<void> _loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    final score = prefs.getInt('focus_score') ?? 500;
    if (mounted) {
      setState(() => _score = score.clamp(0, 1000));
    }
  }

  Future<void> _loadRemoteMeta() async {
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() => _loadingRemote = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!snap.exists) return;

      final data = snap.data() ?? <String, dynamic>{};
      final meta = (data['scoringMeta'] as Map?)?.cast<String, dynamic>();
      final historyRaw = (data['scoreHistory'] as List?) ?? const [];
      final history =
          historyRaw.map((e) => (e as num).toInt()).toList(growable: false);

      DateTime? updatedAt;
      final ts = meta?['updatedAt'];
      if (ts is Timestamp) updatedAt = ts.toDate();

      final remoteScore = (data['focusScore'] as num?)?.toInt();
      if (!mounted) return;
      setState(() {
        if (remoteScore != null) {
          _score = remoteScore.clamp(0, 1000);
        }
        _scoringMeta = meta;
        _history = history;
        _metaUpdatedAt = updatedAt;
      });
    } catch (_) {
      // Non-fatal: screen should still be readable without cloud metadata.
    } finally {
      if (mounted) setState(() => _loadingRemote = false);
    }
  }

  double get _scoreProgress => (_score / 1000).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final meta = _scoringMeta ?? const <String, dynamic>{};
    final num? vowHoursRaw = meta['vowHours'] as num?;
    final num? restrictedHoursRaw = meta['restrictedHoursToday'] as num?;
    final num? decayAppliedRaw = meta['dailyDecayApplied'] as num?;
    final num? rewardAppliedRaw = meta['dailyRewardApplied'] as num?;

    final double? vowHours = vowHoursRaw?.toDouble();
    final double? restrictedHours = restrictedHoursRaw?.toDouble();
    final int? decayApplied = decayAppliedRaw?.toInt();
    final int? rewardApplied = rewardAppliedRaw?.toInt();

    final int predictedPenalty = _predictOveragePenalty(
      vowHours: vowHours,
      restrictedHours: restrictedHours,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Focus Score', style: AppTheme.xxlMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildScoreHero(),
          const SizedBox(height: 16),
          _buildHowItWorksCard(predictedPenalty: predictedPenalty),
          const SizedBox(height: 12),
          _buildTodayStatsCard(
            vowHours: vowHours,
            restrictedHours: restrictedHours,
            decayApplied: decayApplied,
            rewardApplied: rewardApplied,
          ),
          const SizedBox(height: 12),
          _buildStatsDisclaimerCard(),
          const SizedBox(height: 12),
          if (_history.isNotEmpty) ...[
            _buildHistoryCard(_history),
            const SizedBox(height: 12),
          ],
          _buildBands(),
        ],
      ),
    );
  }

  Widget _buildScoreHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus Score',
            style: AppTheme.xsBold.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_score',
            style: AppTheme.size5xlBold.copyWith(
              color: context.scheme.onSurface,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _scoreProgress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(context.scheme.primary),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: AppTheme.smRegular.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              Row(
                children: [
                  if (_loadingRemote)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.scheme.primary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  Text(
                    '1000',
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_metaUpdatedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last updated: ${_formatTimestamp(_metaUpdatedAt!)}',
              style: AppTheme.smRegular.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHowItWorksCard({required int predictedPenalty}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'How It\'s Calculated',
                  style: AppTheme.xlBold.copyWith(
                    color: context.scheme.onSurface,
                  ),
                ),
              ),
              Tooltip(
                message: 'These are the exact point drivers currently implemented.',
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'No essays. These are the levers that move your score.',
            style: AppTheme.baseRegular.copyWith(
              color: context.colors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _deltaChip(
                label: 'Baseline',
                delta: '+500',
                color: context.colors.success,
              ),
              _deltaChip(
                label: 'Over vow',
                delta: '-50/hr',
                color: context.colors.danger,
              ),
              _deltaChip(
                label: 'Daily reward',
                delta: '+15',
                color: context.colors.success,
              ),
              _deltaChip(
                label: 'Beg tax',
                delta: '-25',
                color: context.colors.danger,
              ),
              _deltaChip(
                label: 'Rejected plea',
                delta: '-100',
                color: context.colors.danger,
              ),
              _deltaChip(
                label: 'Post bail',
                delta: '-50/+50',
                color: context.scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Predicted overage penalty (today)',
                    style: AppTheme.baseMedium.copyWith(
                      color: context.scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '-$predictedPenalty',
                  style: AppTheme.baseBold.copyWith(
                    color: context.colors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            collapsedIconColor: context.colors.textSecondary,
            iconColor: context.colors.textSecondary,
            title: Text(
              'Show the math',
              style: AppTheme.baseMedium.copyWith(
                color: context.scheme.onSurface,
              ),
            ),
            children: [
              const SizedBox(height: 10),
              _ruleRow(
                context,
                label: 'Overage penalty',
                delta: '-50 / hour',
                detail: 'For each full hour you exceed your vow on restricted apps.',
                deltaColor: context.colors.danger,
              ),
              const SizedBox(height: 10),
              _ruleRow(
                context,
                label: 'Daily regime reward',
                delta: '+15',
                detail: 'If you have an active regime and you stayed within your vow.',
                deltaColor: context.colors.success,
              ),
              const SizedBox(height: 12),
              Text(
                'Formula',
                style: AppTheme.lgBold.copyWith(
                  color: context.scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Penalty = floor(max(0, RestrictedHours - VowHours)) x 50',
                style: AppTheme.smRegular.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Notes',
                style: AppTheme.lgBold.copyWith(
                  color: context.scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'RestrictedHours is currently estimated using your last 7 days of usage, averaged into a typical day.',
                style: AppTheme.smRegular.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Event-based changes (beg tax, rejected pleas, bail transfers) apply when those events happen.',
                style: AppTheme.smRegular.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deltaChip({
    required String label,
    required String delta,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.smMedium.copyWith(
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            delta,
            style: AppTheme.smBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStatsCard({
    required double? vowHours,
    required double? restrictedHours,
    required int? decayApplied,
    required int? rewardApplied,
  }) {
    String fmtHours(double? v) => v == null ? '—' : v.toStringAsFixed(1);
    String fmtInt(int? v) => v == null ? '—' : v.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Stats',
            style: AppTheme.xlBold.copyWith(
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          _statRow(context, label: 'Vow (hours)', value: fmtHours(vowHours)),
          const SizedBox(height: 8),
          _statRow(
            context,
            label: 'Restricted hours (est.)',
            value: fmtHours(restrictedHours),
          ),
          const SizedBox(height: 8),
          _statRow(
            context,
            label: 'Penalty applied today',
            value: fmtInt(decayApplied),
          ),
          const SizedBox(height: 8),
          _statRow(
            context,
            label: 'Reward earned today',
            value: fmtInt(rewardApplied),
          ),
          const SizedBox(height: 10),
          Text(
            'These values come from your latest sync. If you just installed Revoke or you\'re offline, this section may show dashes.',
            style: AppTheme.smRegular.copyWith(
              color: context.colors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Stats',
            style: AppTheme.xlBold.copyWith(
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Stats are measurements (what happened). The calculation rules above are the levers (what changes your score). We keep them separate so it\'s easier to understand what you can control.',
            style: AppTheme.baseRegular.copyWith(
              color: context.colors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(List<int> history) {
    final items = history.length > 7 ? history.sublist(history.length - 7) : history;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent History',
            style: AppTheme.xlBold.copyWith(
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            items.join('  ·  '),
            style: AppTheme.baseMedium.copyWith(
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last ${items.length} recorded scores.',
            style: AppTheme.smRegular.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBands() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rank Bands',
            style: AppTheme.xsBold.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _band('900-1000', 'MONK MODE', context.scheme.primary),
          _band('700-899', 'LOCKED IN', context.scheme.onSurface),
          _band(
            '400-699',
            'MID',
            context.scheme.onSurface.withValues(alpha: 0.72),
          ),
          _band('0-399', 'COOKED', context.colors.danger),
        ],
      ),
    );
  }

  Widget _band(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              range,
              style: AppTheme.smRegular.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: AppTheme.baseBold.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(
    BuildContext context, {
    required String label,
    required String delta,
    required String detail,
    required Color deltaColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.baseMedium.copyWith(
                  color: context.scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: AppTheme.smRegular.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          delta,
          style: AppTheme.baseBold.copyWith(
            color: deltaColor,
          ),
        ),
      ],
    );
  }

  Widget _statRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTheme.baseMedium.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTheme.baseBold.copyWith(
            color: context.scheme.onSurface,
          ),
        ),
      ],
    );
  }

  static int _predictOveragePenalty({
    required double? vowHours,
    required double? restrictedHours,
  }) {
    if (vowHours == null || restrictedHours == null) return 0;
    final excess = restrictedHours - vowHours;
    if (excess <= 0) return 0;
    return excess.floor() * 50;
  }

  static String _formatTimestamp(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = two(dt.hour);
    final m = two(dt.minute);
    final month = two(dt.month);
    final day = two(dt.day);
    return '$month/$day $h:$m';
  }
}
