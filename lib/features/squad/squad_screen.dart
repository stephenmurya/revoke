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
  static const String _squadCodePrefix = 'REV-';
  static const int _squadCodeTotalLength = 7;
  static const int _squadCodeSuffixLength = 3;

  String _formatSquadCodeInput(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    String suffix = cleaned.startsWith('REV') ? cleaned.substring(3) : cleaned;
    if (suffix.length > _squadCodeSuffixLength) {
      suffix = suffix.substring(0, _squadCodeSuffixLength);
    }
    final formatted = '$_squadCodePrefix$suffix';
    if (formatted.length > _squadCodeTotalLength) {
      return formatted.substring(0, _squadCodeTotalLength);
    }
    return formatted;
  }

  Future<void> _showSquadHudSheet(
    BuildContext context,
    String squadCode,
  ) async {
    final shouldTransfer = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('SQUAD DIRECTIVES', style: AppTheme.h3),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: squadCode));
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('SQUAD CODE COPIED'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.background,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppSemanticColors.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'YOUR SQUAD CODE',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelSmall.copyWith(
                              color: AppSemanticColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              squadCode,
                              textAlign: TextAlign.center,
                              style: AppTheme.squadCodeInput.copyWith(
                                color: AppSemanticColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'TAP TO COPY',
                            textAlign: TextAlign.center,
                            style: AppTheme.labelSmall.copyWith(
                              color: AppSemanticColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(true);
                      },
                      style: AppTheme.secondaryButtonStyle,
                      child: const Text('TRANSFER TO NEW SQUAD'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldTransfer == true && context.mounted) {
      await _showTransferSheet(context, squadCode);
    }
  }

  Future<void> _showTransferSheet(
    BuildContext context,
    String currentSquadCode,
  ) async {
    String transferCode = _squadCodePrefix;
    final squadCodeFormatter = TextInputFormatter.withFunction((
      oldValue,
      newValue,
    ) {
      final formatted = _formatSquadCodeInput(newValue.text);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
    bool isTransferring = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppSemanticColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            final normalizedCurrent = currentSquadCode.trim().toUpperCase();
            final normalizedTarget = transferCode.trim().toUpperCase();
            final canSubmit =
                normalizedTarget.length == _squadCodeTotalLength &&
                normalizedTarget != normalizedCurrent &&
                !isTransferring;

            final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('INITIATE TRANSFER', style: AppTheme.h3),
                    const SizedBox(height: 12),
                    Text(
                      'Transferring will remove you from your current squad. If you are the last member, this squad will be deleted.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppSemanticColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: _squadCodePrefix,
                      autofocus: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9-]'),
                        ),
                        LengthLimitingTextInputFormatter(_squadCodeTotalLength),
                        squadCodeFormatter,
                      ],
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: AppTheme.squadCodeInput,
                      onChanged: (value) {
                        setModalState(() {
                          transferCode = value;
                        });
                      },
                      decoration: AppTheme.defaultInputDecoration(
                        hintText: 'REV-XXX',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () async {
                                final uid = AuthService.currentUser?.uid;
                                if (uid == null) return;

                                setModalState(() => isTransferring = true);
                                try {
                                  await SquadService.joinSquad(
                                    uid,
                                    transferCode,
                                  );
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'TRANSFER COMPLETE: ALLEGIANCE UPDATED',
                                        ),
                                      ),
                                    );
                                  context.go('/squad');
                                } catch (e) {
                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(sheetContext)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                } finally {
                                  if (sheetContext.mounted) {
                                    setModalState(() => isTransferring = false);
                                  }
                                }
                              }
                            : null,
                        style: AppTheme.primaryButtonStyle,
                        child: Text(
                          isTransferring
                              ? 'PROCESSING TRANSFER...'
                              : 'INITIATE TRANSFER',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: AuthService.getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppSemanticColors.accent),
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
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            final normalizedCode = squadCode?.trim();
                            if (normalizedCode == null ||
                                normalizedCode.isEmpty) {
                              return;
                            }
                            _showSquadHudSheet(context, normalizedCode);
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("SQUAD HUD", style: AppTheme.xxlMedium),
                                    Text(
                                      "SQUAD CODE: ${squadCode ?? '--- ---'}",
                                      style: AppTheme.smMedium.copyWith(
                                        color: AppSemanticColors.accentText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppSemanticColors.accent,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
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
                              decoration: AppTheme.warningBannerDecoration,
                              child: Text(
                                'LIVE TRIBUNAL IN PROGRESS',
                                textAlign: TextAlign.center,
                                style: AppTheme.warningBannerTextStyle,
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
                                style: AppTheme.baseMedium.copyWith(
                                  color: AppSemanticColors.errorText,
                                ),
                              ),
                            );
                          }

                          if (streamSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppSemanticColors.accent,
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
                      color: AppSemanticColors.background.withValues(alpha: 0.8),
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
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCooked
              ? AppSemanticColors.accent.withOpacity(0.5)
              : AppSemanticColors.primaryText.withOpacity(0.05),
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
                  member.nickname != null ? member.nickname![0].toUpperCase() + member.nickname!.substring(1) : "UNKNOWN",
                  style: AppTheme.lgMedium.copyWith(
                    color: AppSemanticColors.primaryText,
                  ),
                ),
                Text(
                  member.fullName ?? member.email ?? "",
                  style: AppTheme.bodySmall.copyWith(
                    color: AppSemanticColors.mutedText,
                  ),
                ),
                if (isCooked) ...[
                  const SizedBox(height: 0),
                  Text(
                    "Cooked",
                    style: AppTheme.smBold.copyWith(
                      color: AppSemanticColors.accentText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                member.focusScore.toString(),
                style: AppTheme.xlMedium.copyWith(
                  color: isCooked
                      ? AppSemanticColors.accentText
                      : AppSemanticColors.primaryText,
                ),
              ),
              Text(
                "FOCUS SCORE",
                style: AppTheme.xsRegular.copyWith(
                  color: AppSemanticColors.mutedText,
                ),
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
          color: isPulse ? AppSemanticColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: AppSemanticColors.background,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? const Icon(Icons.person, color: AppSemanticColors.secondaryText)
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
              color: AppSemanticColors.surface,
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
