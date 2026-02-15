import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';

class PilloryHero extends StatelessWidget {
  final UserModel victim;
  final VoidCallback? onBailOut;
  final VoidCallback? onPileOn;

  const PilloryHero({
    super.key,
    required this.victim,
    this.onBailOut,
    this.onPileOn,
  });

  @override
  Widget build(BuildContext context) {
    final displayHandle = _displayHandle(victim);
    final score = victim.focusScore;
    final isCritical = score < 50;

    final avatar = _AvatarWithTreatment(
      photoUrl: victim.photoUrl,
      fallbackText: displayHandle,
      isCritical: isCritical,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppSemanticColors.accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppSemanticColors.background.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  'THE PILLORY',
                  style: AppTheme.labelSmall.copyWith(
                    color: AppSemanticColors.mutedText,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              _ScorePill(score: score),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENTLY SHAMED',
                      style: AppTheme.smBold.copyWith(
                        color: AppSemanticColors.reject.withValues(alpha: 0.9),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@$displayHandle',
                      style: AppTheme.h2.copyWith(
                        color: AppSemanticColors.primaryText,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCritical
                          ? 'This soldier has fallen below operational readiness.'
                          : 'Morale is low. Supervision recommended.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppSemanticColors.secondaryText,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onBailOut,
                  style: AppTheme.primaryButtonStyle.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  child: const Text('BAIL OUT'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onPileOn,
                  style: AppTheme.secondaryButtonStyle.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 14),
                    ),
                    backgroundColor: WidgetStatePropertyAll(
                      AppSemanticColors.background.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text('PILE ON'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _displayHandle(UserModel user) {
    final nick = (user.nickname ?? '').trim();
    if (nick.isNotEmpty) return nick;
    final full = (user.fullName ?? '').trim();
    if (full.isNotEmpty) return full.split(' ').first;
    final email = (user.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'member';
  }
}

class _ScorePill extends StatelessWidget {
  final int score;

  const _ScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 1000);
    final severity = (1.0 - (clamped / 1000.0)).clamp(0.0, 1.0);
    final heat = Color.lerp(
      AppSemanticColors.success,
      AppSemanticColors.reject,
      math.min(1.0, severity * 1.1),
    )!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: heat.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: heat.withValues(alpha: 0.35)),
      ),
      child: Text(
        'SCORE: $clamped',
        style: AppTheme.smBold.copyWith(
          color: heat.withValues(alpha: 0.95),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _AvatarWithTreatment extends StatelessWidget {
  final String? photoUrl;
  final String fallbackText;
  final bool isCritical;

  const _AvatarWithTreatment({
    required this.photoUrl,
    required this.fallbackText,
    required this.isCritical,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (photoUrl ?? '').trim().isNotEmpty;

    final avatarCore = Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppSemanticColors.background,
        border: Border.all(
          color: AppSemanticColors.primaryText.withValues(alpha: 0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image(
              image: CachedNetworkImageProvider(photoUrl!.trim()),
              fit: BoxFit.cover,
            )
          : Center(
              child: Text(
                fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : 'U',
                style: AppTheme.xlMedium.copyWith(
                  color: AppSemanticColors.secondaryText,
                ),
              ),
            ),
    );

    final treated = isCritical
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0.2126, 0.7152, 0.0722, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: avatarCore,
          )
        : avatarCore;

    return Stack(
      children: [
        treated,
        if (isCritical)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _JailBarsPainter(),
              ),
            ),
          ),
      ],
    );
  }
}

class _JailBarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    final edgePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    final barWidth = math.max(5.5, size.width / 14.0);
    final gap = barWidth * 0.75;

    for (double x = -barWidth; x < size.width + barWidth; x += barWidth + gap) {
      canvas.drawRect(Rect.fromLTWH(x, 0, barWidth, size.height), barPaint);
    }

    // A bit of vignette to make the "bars" feel harsher.
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.45),
      size.shortestSide * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
        ).createShader(Offset.zero & size),
    );

    // Edge darkening to imply confinement.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 10), edgePaint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 10, size.width, 10),
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

