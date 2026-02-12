import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/plea_model.dart';
import 'widgets/plea_judgment_card.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: AuthService.getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.orange),
              );
            }

            final userData = snapshot.data;
            final squadId = userData?['squadId'] as String?;
            final squadCode = userData?['squadCode'] as String?;
            final normalizedSquadId = squadId?.trim();

            print(
              'PLEA_DEBUG: SquadScreen user=$currentUid squadId=$normalizedSquadId squadCode=$squadCode',
            );

            if (normalizedSquadId == null || normalizedSquadId.isEmpty) {
              return _buildEmptyState(context, "NO SQUAD JOINED");
            }

            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("SQUAD HUD", style: AppTheme.h1),
                              Text(
                                "SQUAD CODE: ${squadCode ?? '--- ---'}",
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed:
                                (squadCode == null || squadCode.trim().isEmpty)
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: squadCode),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text("SQUAD CODE COPIED"),
                                          duration: Duration(
                                            milliseconds: 1200,
                                          ),
                                        ),
                                      );
                                  },
                            icon: const Icon(
                              Icons.copy_rounded,
                              color: AppTheme.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<List<PleaModel>>(
                      stream: SquadService.getActivePleasStream(
                        normalizedSquadId,
                      ),
                      builder: (context, liveSnapshot) {
                        if (!liveSnapshot.hasData ||
                            liveSnapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final livePlea = liveSnapshot.data!.firstWhere(
                          (p) => p.status == 'active',
                          orElse: () => liveSnapshot.data!.first,
                        );

                        if (livePlea.status != 'active') {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: GestureDetector(
                            onTap: () =>
                                context.push('/tribunal/${livePlea.id}'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: RevokeTheme.warningBanner,
                              child: Text(
                                'LIVE TRIBUNAL IN PROGRESS',
                                textAlign: TextAlign.center,
                                style: RevokeTheme.warningBannerText,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: StreamBuilder<List<UserModel>>(
                        stream: SquadService.getSquadMembersStream(
                          normalizedSquadId,
                        ),
                        builder: (context, streamSnapshot) {
                          if (streamSnapshot.hasError) {
                            return Center(
                              child: Text(
                                "ERROR: ${streamSnapshot.error}",
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          if (streamSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppTheme.orange,
                              ),
                            );
                          }

                          final members = streamSnapshot.data ?? [];

                          if (members.length <= 1) {
                            return _buildEmptyState(
                              context,
                              "YOU ARE ALONE. APPOINT A WARDEN.",
                              code: squadCode,
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              return _buildMemberCard(members[index]);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // --- JUDGMENT DAY OVERLAY ---
                StreamBuilder<List<PleaModel>>(
                  stream: SquadService.getActivePleasStream(normalizedSquadId),
                  builder: (context, pleaSnapshot) {
                    if (pleaSnapshot.hasError) {
                      print(
                        'PLEA_DEBUG: Plea stream error for squadId=$normalizedSquadId -> ${pleaSnapshot.error}',
                      );
                    }

                    if (pleaSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      print(
                        'PLEA_DEBUG: Plea stream waiting for squadId=$normalizedSquadId',
                      );
                    }

                    if (!pleaSnapshot.hasData || pleaSnapshot.data!.isEmpty) {
                      print(
                        'PLEA_DEBUG: No active pleas visible for squadId=$normalizedSquadId',
                      );
                      return const SizedBox.shrink();
                    }

                    // Filter for pleas that aren't from the current user
                    // and that the current user hasn't voted on yet.
                    final activePleas = pleaSnapshot.data!.where((p) {
                      final hasNotVoted = !p.votes.containsKey(currentUid);
                      final isNotRequester = p.userId != currentUid;
                      return hasNotVoted && isNotRequester;
                    }).toList();

                    print(
                      'PLEA_DEBUG: Pleas fetched=${pleaSnapshot.data!.length} filteredForHud=${activePleas.length} currentUid=$currentUid squadId=$normalizedSquadId',
                    );

                    if (activePleas.isEmpty) return const SizedBox.shrink();

                    // Show the first available plea for judgment
                    return Container(
                      color: AppTheme.black.withOpacity(0.8),
                      child: Center(
                        child: PleaJudgmentCard(plea: activePleas.first),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    final bool isCooked = member.focusScore < 200;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCooked
              ? AppTheme.orange.withOpacity(0.5)
              : AppTheme.white.withOpacity(0.05),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(member.photoUrl, isCooked),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.nickname?.toUpperCase() ?? "UNKNOWN",
                  style: AppTheme.h3.copyWith(fontSize: 18),
                ),
                Text(
                  member.fullName ?? member.email ?? "",
                  style: AppTheme.bodySmall,
                ),
                if (isCooked) ...[
                  const SizedBox(height: 4),
                  Text("⚠️ COOKED", style: AppTheme.labelSmall),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                member.focusScore.toString(),
                style: AppTheme.h2.copyWith(
                  color: isCooked ? AppTheme.orange : AppTheme.white,
                ),
              ),
              Text(
                "FOCUS",
                style: AppTheme.labelSmall.copyWith(color: AppTheme.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, bool isPulse) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isPulse ? AppTheme.orange : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.black,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? const Icon(Icons.person, color: AppTheme.lightGrey)
            : null,
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String message, {
    String? code,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.group_off_rounded,
              color: AppTheme.darkGrey,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(message, textAlign: TextAlign.center, style: AppTheme.h2),
            const SizedBox(height: 32),
            if (code != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      "Join my Revoke Squad and watch my screen time: $code",
                    );
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text("SHARE SQUAD CODE"),
                  style: AppTheme.primaryButtonStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
