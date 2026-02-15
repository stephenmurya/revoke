import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/squad_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';

class PilloryHero extends StatelessWidget {
  final UserModel victim;
  final String squadId;

  const PilloryHero({
    super.key,
    required this.victim,
    required this.squadId,
  });

  @override
  Widget build(BuildContext context) {
    final warningScheme = ColorScheme.fromSeed(
      seedColor: context.colors.warning,
      brightness: Theme.of(context).brightness,
    );
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.accent.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.background.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: context.colors.textPrimary.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  'THE PILLORY',
                  style: (context.text.labelSmall ?? AppTheme.labelSmall).copyWith(
                    color: context.colors.textSecondary,
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
                      style: (context.text.labelMedium ?? AppTheme.smBold).copyWith(
                        color: context.colors.danger.withValues(alpha: 0.9),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@$displayHandle',
                      style: (context.text.headlineMedium ?? AppTheme.h2).copyWith(
                        color: context.colors.textPrimary,
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
                      style: (context.text.bodySmall ?? AppTheme.bodySmall).copyWith(
                        color: context.colors.textSecondary,
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
          
          // --- FIXED SECTION START ---
          const SizedBox(height: 16), // Add vertical spacing before buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _castStone(context),
                  icon: const Icon(Icons.gavel_rounded, size: 16),
                  label: const Text(
                    'Stone',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.danger,
                    side: BorderSide(
                      color: context.colors.danger.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _prayFor(context),
                  icon: const Icon(Icons.spa_rounded, size: 16),
                  label: const Text(
                    'Pray',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.success,
                    side: BorderSide(
                      color: context.colors.success.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _postBail(context, displayHandle),
                  icon: const Icon(Icons.lock_open_rounded, size: 16),
                  label: const Text(
                    'Bail',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.warning,
                    foregroundColor: warningScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          // --- FIXED SECTION END ---
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

  Future<void> _castStone(BuildContext context) async {
    HapticFeedback.heavyImpact();
    try {
      await SquadService.castStone(victim.uid, squadId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Judgment delivered.'),
            duration: Duration(milliseconds: 900),
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _prayFor(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      await SquadService.prayForUser(victim.uid, squadId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Prayers sent.'),
            duration: Duration(milliseconds: 900),
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _postBail(BuildContext context, String displayHandle) async {
    final callerUid = AuthService.currentUser?.uid;
    if (callerUid == null) return;
    if (callerUid == victim.uid) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('You cannot post bail for yourself.')),
        );
      return;
    }

    final should = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogContext.colors.surface,
          title: const Text('Post Bail?'),
          content: Text(
            'Sacrifice 50 Points to save @$displayHandle?',
            style: (dialogContext.text.bodyMedium ?? AppTheme.bodyMedium).copyWith(
              color: dialogContext.colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogContext.colors.warning,
                foregroundColor: ColorScheme.fromSeed(
                  seedColor: dialogContext.colors.warning,
                  brightness: Theme.of(dialogContext).brightness,
                ).onPrimary,
              ),
              child: const Text('Post Bail'),
            ),
          ],
        );
      },
    );

    if (should != true) return;

    try {
      await SquadService.postBail(victim.uid, squadId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Bail posted. You are a martyr.'),
            duration: Duration(milliseconds: 1200),
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
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
      context.colors.success,
      context.colors.danger,
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
        style: (context.text.labelMedium ?? AppTheme.smBold).copyWith(
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
        color: context.colors.background,
        border: Border.all(
          color: context.colors.textPrimary.withValues(alpha: 0.10),
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
                style: (context.text.titleLarge ?? AppTheme.xlMedium).copyWith(
                  color: context.colors.textSecondary,
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
                painter: _JailBarsPainter(
                  barColor: context.scheme.onSurface.withValues(alpha: 0.09),
                  edgeColor: Theme.of(context).shadowColor.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _JailBarsPainter extends CustomPainter {
  final Color barColor;
  final Color edgeColor;

  _JailBarsPainter({required this.barColor, required this.edgeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final edgePaint = Paint()
      ..color = edgeColor
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
            edgeColor,
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
