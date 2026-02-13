import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/plea_model.dart';
import '../../../core/services/squad_service.dart';
import '../../../core/services/auth_service.dart';

class PleaJudgmentCard extends StatefulWidget {
  final PleaModel plea;

  const PleaJudgmentCard({super.key, required this.plea});

  @override
  State<PleaJudgmentCard> createState() => _PleaJudgmentCardState();
}

class _PleaJudgmentCardState extends State<PleaJudgmentCard> {
  @override
  void initState() {
    super.initState();
    _markAttendance();
  }

  Future<void> _markAttendance() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await SquadService.joinPleaSession(widget.plea.id, uid);
    } catch (_) {
      // Attendance is best-effort and should not block judgment UI.
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppSemanticColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppSemanticColors.accent, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.accent.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel_rounded, color: AppSemanticColors.accent, size: 28),
              const SizedBox(width: 12),
              Text(
                'Judgment day',
                style: AppTheme.h3.copyWith(
                  color: AppSemanticColors.accent,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTheme.bodyLarge.copyWith(
                color: AppSemanticColors.primaryText,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: widget.plea.userName,
                  style: AppTheme.lgBold.copyWith(
                    color: AppSemanticColors.accentText,
                  ),
                ),
                TextSpan(
                  text:
                      " is begging for ${widget.plea.durationMinutes} minutes on ",
                ),
                TextSpan(
                  text: widget.plea.appName,
                  style: AppTheme.lgBold.copyWith(
                    color: AppSemanticColors.primaryText,
                  ),
                ),
                const TextSpan(text: ".\n\nWhat is the verdict?"),
              ],
            ),
          ),
          if (widget.plea.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppSemanticColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                '"${widget.plea.reason.trim()}"',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppSemanticColors.secondaryText,
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _vote(context, currentUid, true),
                  style: AppTheme.primaryButtonStyle.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _vote(context, currentUid, false),
                  style: AppTheme.secondaryButtonStyle.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 16),
                    ),
                    backgroundColor: const WidgetStatePropertyAll(
                      AppSemanticColors.surface,
                    ),
                  ),
                  child: const Text('Revoke'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _vote(BuildContext context, String? uid, bool vote) async {
    if (uid == null) return;
    try {
      await SquadService.voteOnPlea(widget.plea.id, uid, vote);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Vote failed: $e')));
      }
    }
  }
}
