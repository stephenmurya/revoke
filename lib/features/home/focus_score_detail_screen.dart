import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';

class FocusScoreDetailScreen extends StatefulWidget {
  const FocusScoreDetailScreen({super.key});

  @override
  State<FocusScoreDetailScreen> createState() => _FocusScoreDetailScreenState();
}

class _FocusScoreDetailScreenState extends State<FocusScoreDetailScreen> {
  int _score = 500;

  @override
  void initState() {
    super.initState();
    _loadScore();
  }

  Future<void> _loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    final score = prefs.getInt('focus_score') ?? 500;
    if (mounted) {
      setState(() => _score = score.clamp(0, 1000));
    }
  }

  double get _scoreProgress => (_score / 1000).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        elevation: 0,
        title: Text('FOCUS SCORE', style: AppTheme.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildScoreHero(),
          const SizedBox(height: 16),
          _buildMetricCard(
            icon: Icons.block_rounded,
            title: 'BLOCKED APP ATTEMPTS',
            value: '${(_score * 0.32).round()}',
            subtitle: 'Each failed launch strengthens your score.',
            color: AppSemanticColors.accent,
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            icon: Icons.bolt_rounded,
            title: 'CONSISTENCY',
            value: '${(_scoreProgress * 100).round()}%',
            subtitle: 'Daily discipline keeps your trend alive.',
            color: AppSemanticColors.success,
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            icon: Icons.gavel_rounded,
            title: 'SQUAD JUDGMENTS',
            value: '${((_score / 100).round()).clamp(0, 10)}',
            subtitle: 'Plea outcomes and squad decisions impact rank.',
            color: AppSemanticColors.reject,
          ),
          const SizedBox(height: 18),
          _buildBands(),
        ],
      ),
    );
  }

  Widget _buildScoreHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppSemanticColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LIVE SCORE', style: AppTheme.labelSmall),
          const SizedBox(height: 8),
          Text(
            '$_score',
            style: AppTheme.size5xlBold.copyWith(
              color: AppSemanticColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _scoreProgress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: AppSemanticColors.background,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppSemanticColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: AppTheme.bodySmall),
              Text('1000', style: AppTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.labelSmall),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: AppTheme.h2.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildBands() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RANK BANDS', style: AppTheme.labelSmall),
          const SizedBox(height: 12),
          _band('900-1000', 'MONK MODE', AppSemanticColors.accent),
          _band('700-899', 'LOCKED IN', AppSemanticColors.primaryText),
          _band('400-699', 'MID', AppSemanticColors.secondaryText),
          _band('0-399', 'COOKED', AppSemanticColors.reject),
        ],
      ),
    );
  }

  Widget _band(String range, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(range, style: AppTheme.bodySmall)),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
