import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';

class FocusScoreCard extends StatefulWidget {
  const FocusScoreCard({super.key});

  @override
  State<FocusScoreCard> createState() => _FocusScoreCardState();
}

class _FocusScoreCardState extends State<FocusScoreCard>
    with SingleTickerProviderStateMixin {
  int _score = 500;
  String _trendLabel = 'No trend yet';
  bool _trendPositive = false;
  bool _trendNegative = false;
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadScore();
  }

  Future<void> _loadScore() async {
    final prefs = await SharedPreferences.getInstance();
    final score = prefs.getInt('focus_score') ?? 500;

    _animation = IntTween(
      begin: 0,
      end: score,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    setState(() => _score = score);
    _controller.forward();
    _loadTrend();
  }

  Future<void> _loadTrend() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      final historyRaw = (data['scoreHistory'] as List?) ?? const [];
      final history = historyRaw
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false);

      if (!mounted) return;
      if (history.length < 2) {
        setState(() {
          _trendLabel = 'No trend yet';
          _trendPositive = false;
          _trendNegative = false;
        });
        return;
      }

      final first = history.first;
      final last = history.last;
      final delta = last - first;
      if (delta == 0) {
        setState(() {
          _trendLabel = 'Flat this week';
          _trendPositive = false;
          _trendNegative = false;
        });
        return;
      }

      final base = first <= 0 ? 1 : first;
      final pct = ((delta.abs() / base) * 100).round();
      setState(() {
        _trendLabel = delta > 0 ? 'Up $pct% this week' : 'Down $pct% this week';
        _trendPositive = delta > 0;
        _trendNegative = delta < 0;
      });
    } catch (_) {
      // Non-fatal: preserve card rendering without trend metadata.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _rankTitle {
    if (_score >= 900) return 'Monk mode';
    if (_score >= 700) return 'Locked in';
    if (_score >= 400) return 'MID';
    return 'Cooked';
  }

  Color _rankColorFor(BuildContext context) {
    if (_score >= 900) return context.scheme.primary;
    if (_score >= 700) return context.scheme.onSurface;
    if (_score >= 400) return context.colors.textSecondary;
    return context.colors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/focus-score');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.scheme.outlineVariant.withValues(alpha: 0.7),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              'Score',
              style: AppTheme.smBold.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Text(
                  '${_animation.value}',
                  style: AppTheme.xlBold.copyWith(
                    color: _rankColorFor(context),
                    height: 1,
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_rankTitle - $_trendLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.smRegular.copyWith(
                  color: _trendPositive
                      ? context.colors.success
                      : _trendNegative
                      ? context.colors.danger
                      : context.colors.textSecondary,
                ),
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(),
              size: 16,
              color: context.colors.textSecondary.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}
