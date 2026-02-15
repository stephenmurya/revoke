import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _rankColorFor(context).withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: _score >= 900
              ? [
                  BoxShadow(
                    color: context.scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'FOCUS SCORE',
                    style: AppTheme.smBold.copyWith(
                      color: context.scheme.primary,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: context.colors.textSecondary.withValues(alpha: 0.9),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final rankColor = _rankColorFor(context);
                    return Text(
                      '${_animation.value}',
                      style: AppTheme.size5xlBold.copyWith(
                        color: rankColor,
                        height: 1,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rankTitle,
                      style: AppTheme.lgBold.copyWith(
                        color: _rankColorFor(context),
                      ),
                    ),
                    Text(
                      'Up 12% this week',
                      style: AppTheme.smRegular.copyWith(
                        color: context.colors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
