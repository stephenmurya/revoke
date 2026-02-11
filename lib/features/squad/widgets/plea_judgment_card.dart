import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/plea_model.dart';
import '../../../core/services/squad_service.dart';
import '../../../core/services/auth_service.dart';

class PleaJudgmentCard extends StatelessWidget {
  final PleaModel plea;

  const PleaJudgmentCard({super.key, required this.plea});

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.orange, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.orange.withOpacity(0.2),
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
              const Icon(Icons.gavel_rounded, color: AppTheme.orange, size: 28),
              const SizedBox(width: 12),
              Text(
                "JUDGMENT DAY",
                style: GoogleFonts.jetBrainsMono(
                  color: AppTheme.orange,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.white,
                fontSize: 18,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: plea.userName.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.orange,
                  ),
                ),
                const TextSpan(text: " is begging for 5 minutes of "),
                TextSpan(
                  text: plea.appName.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ".\n\nWhat is the verdict?"),
              ],
            ),
          ),
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
                  child: const Text("SAVE"),
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
                      AppTheme.darkGrey,
                    ),
                  ),
                  child: const Text("REVOKE"),
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
      await SquadService.voteOnPlea(plea.id, uid, vote);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("VOTE FAILED: $e")));
      }
    }
  }
}
