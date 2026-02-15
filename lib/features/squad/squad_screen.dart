import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/plea_model.dart';
import '../../core/models/squad_log_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/pillory_hero.dart';
import 'widgets/plea_judgment_card.dart';
import 'widgets/squad_log_feed.dart';
import 'widgets/squad_roster_strip.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBegForTimePicker(context),
        backgroundColor: AppSemanticColors.accent,
        foregroundColor: AppSemanticColors.onAccentText,
        icon: const Icon(Icons.gavel_rounded),
        label: const Text('BEG FOR TIME'),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: AuthService.getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppSemanticColors.accent),
              );
            }

            final userData = snapshot.data ?? const <String, dynamic>{};
            final squadId = (userData['squadId'] as String?)?.trim() ?? '';
            final squadCode = (userData['squadCode'] as String?)?.trim() ?? '';

            if (squadId.isEmpty) {
              return _EmptyBarracks(
                title: 'NO SQUAD ASSIGNED',
                subtitle: 'Report to onboarding and swear allegiance.',
              );
            }

            return Stack(
              children: [
                StreamBuilder<List<UserModel>>(
                  stream: SquadService.getSquadMembersStream(squadId),
                  builder: (context, membersSnap) {
                    if (membersSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppSemanticColors.accent),
                      );
                    }
                    if (membersSnap.hasError) {
                      return _EmptyBarracks(
                        title: 'COMMS FAILURE',
                        subtitle: membersSnap.error.toString(),
                      );
                    }

                    final members = (membersSnap.data ?? const <UserModel>[])
                        .toList()
                      ..sort((a, b) => a.focusScore.compareTo(b.focusScore));

                    if (members.isEmpty) {
                      return const _EmptyBarracks(
                        title: 'NO ROSTER FOUND',
                        subtitle: 'Your squad roster is empty.',
                      );
                    }

                    final victim = members.first;

                    return StreamBuilder<List<SquadLogModel>>(
                      stream: SquadService.getSquadLogs(squadId),
                      builder: (context, logsSnap) {
                        final logs = logsSnap.data ?? const <SquadLogModel>[];

                        return CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: _BarracksHeader(
                                squadCode: squadCode,
                                memberCount: members.length,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _LiveTribunalBanner(squadId: squadId),
                            ),
                            SliverToBoxAdapter(
                              child: PilloryHero(
                                victim: victim,
                                onBailOut: () {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text('BAIL OUT: Coming soon.'),
                                      ),
                                    );
                                },
                                onPileOn: () {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text('PILE ON: Coming soon.'),
                                      ),
                                    );
                                },
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _SectionLabel(
                                title: 'THE ROSTER',
                                subtitle: 'Status rings report operational posture.',
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SquadRosterStrip(
                                members: members,
                                highlightUserId: currentUid,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _SectionLabel(
                                title: 'THE SQUAD LOG',
                                subtitle: 'Audit trail. Double-tap to salute.',
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SquadLogFeed(
                                logs: logs,
                                onSalute: (log) async {
                                  // Stubbed: rules disallow client writes to squad logs.
                                  // This will become a callable-backed reaction endpoint.
                                  HapticFeedback.lightImpact();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text('Salute recorded (stub).'),
                                          duration: Duration(milliseconds: 900),
                                        ),
                                      );
                                  }
                                },
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 110)),
                          ],
                        );
                      },
                    );
                  },
                ),
                // Judgment overlay (kept server-authoritative and always available).
                StreamBuilder<List<PleaModel>>(
                  stream: SquadService.getActivePleasStream(squadId),
                  builder: (context, pleaSnapshot) {
                    if (!pleaSnapshot.hasData || pleaSnapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final activePleas = pleaSnapshot.data!.where((p) {
                      final hasNotVoted = !p.votes.containsKey(currentUid);
                      final isNotRequester = p.userId != currentUid;
                      return p.status == 'active' && hasNotVoted && isNotRequester;
                    }).toList();

                    if (activePleas.isEmpty) return const SizedBox.shrink();

                    return Container(
                      color: AppSemanticColors.background.withValues(alpha: 0.82),
                      child: Center(child: PleaJudgmentCard(plea: activePleas.first)),
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

  Future<void> _openBegForTimePicker(BuildContext context) async {
    final appsFuture = AppDiscoveryService.getApps();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        String query = '';
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
            final safeBottom = MediaQuery.paddingOf(sheetContext).bottom;
            final sheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.88;

            // Bounded height + `Expanded` list area to prevent bottom overflow.
            // We manually account for safe-area + keyboard to avoid double-padding.
            return SafeArea(
              top: false,
              bottom: false,
              child: SizedBox(
                height: sheetHeight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    14 + safeBottom + bottomInset,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppSemanticColors.primaryText.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'SELECT TARGET APP',
                              style: AppTheme.smBold.copyWith(
                                color: AppSemanticColors.mutedText,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('CLOSE'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (value) =>
                            setModalState(() => query = value.trim()),
                        style: AppTheme.baseMedium.copyWith(
                          color: AppSemanticColors.primaryText,
                        ),
                        decoration: AppTheme.defaultInputDecoration(
                          hintText: 'Search apps...',
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<List<AppInfo>>(
                          future: appsFuture,
                          builder: (context, appsSnap) {
                            if (appsSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppSemanticColors.accent,
                                ),
                              );
                            }

                            final apps = (appsSnap.data ?? const <AppInfo>[]);
                            final filtered = query.isEmpty
                                ? apps
                                : apps.where((a) {
                                    final name = a.name.toLowerCase();
                                    final pkg = a.packageName.toLowerCase();
                                    final q = query.toLowerCase();
                                    return name.contains(q) || pkg.contains(q);
                                  }).toList();

                            filtered.sort((a, b) => a.name.compareTo(b.name));

                            if (filtered.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No matches.',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppSemanticColors.secondaryText,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: AppSemanticColors.primaryText.withValues(
                                  alpha: 0.06,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final app = filtered[index];
                                return ListTile(
                                  leading: _AppIcon(bytes: app.icon),
                                  title: Text(
                                    app.name,
                                    style: AppTheme.baseMedium,
                                  ),
                                  subtitle: Text(
                                    app.packageName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppSemanticColors.mutedText,
                                    ),
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    context.push(
                                      '/plea-compose',
                                      extra: {
                                        'appName': app.name,
                                        'packageName': app.packageName,
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BarracksHeader extends StatelessWidget {
  final String squadCode;
  final int memberCount;

  const _BarracksHeader({required this.squadCode, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: AppSemanticColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppSemanticColors.primaryText.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE SQUAD',
                    style: AppTheme.smBold.copyWith(
                      color: AppSemanticColors.mutedText,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$memberCount ACTIVE',
                    style: AppTheme.lgBold.copyWith(
                      color: AppSemanticColors.primaryText,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            if (squadCode.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: squadCode));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('SQUAD CODE COPIED'),
                        duration: Duration(milliseconds: 900),
                      ),
                    );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppSemanticColors.background.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppSemanticColors.accent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        squadCode,
                        style: AppTheme.smBold.copyWith(
                          color: AppSemanticColors.accent,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppSemanticColors.accent.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          SharePlus.instance.share(
                            ShareParams(text: 'Join my Revoke Squad: $squadCode'),
                          );
                        },
                        child: Icon(
                          Icons.ios_share_rounded,
                          size: 16,
                          color: AppSemanticColors.accent.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.smBold.copyWith(
              color: AppSemanticColors.mutedText,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(color: AppSemanticColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _LiveTribunalBanner extends StatelessWidget {
  final String squadId;

  const _LiveTribunalBanner({required this.squadId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PleaModel>>(
      stream: SquadService.getActivePleasStream(squadId),
      builder: (context, snap) {
        final pleas = snap.data ?? const <PleaModel>[];
        final active = pleas.where((p) => p.status == 'active').toList();
        if (active.isEmpty) return const SizedBox.shrink();

        final livePlea = active.first;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push('/tribunal/${livePlea.id}'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppSemanticColors.reject.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppSemanticColors.reject.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.gavel_rounded,
                    color: AppSemanticColors.reject.withValues(alpha: 0.90),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'LIVE TRIBUNAL: Tap to enter',
                      style: AppTheme.smBold.copyWith(
                        color: AppSemanticColors.reject.withValues(alpha: 0.95),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AppIcon extends StatelessWidget {
  final List<int>? bytes;

  const _AppIcon({required this.bytes});

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null || data.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppSemanticColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
          ),
        ),
        child: const Icon(Icons.apps_rounded, color: AppSemanticColors.accent),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        Uint8List.fromList(data),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _EmptyBarracks extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyBarracks({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppSemanticColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
                ),
              ),
              child: const Icon(
                Icons.groups_rounded,
                size: 42,
                color: AppSemanticColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.h2.copyWith(color: AppSemanticColors.primaryText),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall.copyWith(
                color: AppSemanticColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
