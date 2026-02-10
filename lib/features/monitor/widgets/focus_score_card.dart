import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

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
    if (_score >= 900) return 'MONK MODE 🧘';
    if (_score >= 700) return 'LOCKED IN 🔒';
    if (_score >= 400) return 'MID 😐';
    return 'COOKED 💀';
  }

  Color get _rankColor {
    if (_score >= 900) return AppTheme.orange;
    if (_score >= 700) return AppTheme.white;
    if (_score >= 400) return AppTheme.lightGrey;
    return const Color(0xFFFF0000);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.darkGrey, AppTheme.black],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _rankColor.withOpacity(0.3), width: 2),
        boxShadow: _score >= 900
            ? [
                BoxShadow(
                  color: AppTheme.orange.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FOCUS SCORE',
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.orange,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Text(
                    '${_animation.value}',
                    style: GoogleFonts.spaceGrotesk(
                      color: _rankColor,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
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
                    style: GoogleFonts.spaceGrotesk(
                      color: _rankColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '▲ 12% this week',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF00FF00),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
