import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/plea_message_model.dart';
import '../../core/models/plea_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';

class TribunalScreen extends StatefulWidget {
  final String pleaId;

  const TribunalScreen({super.key, required this.pleaId});

  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  bool _voting = false;
  String _senderName = 'Member';
  String? _resolvedStatusHandled;
  bool _showVerdictOverlay = false;
  String _verdictText = '';

  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSession() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;
    try {
      await SquadService.joinPleaSession(widget.pleaId, uid);
    } catch (_) {}

    final userData = await AuthService.getUserData();
    final nickname = (userData?['nickname'] as String?)?.trim();
    final fullName = (userData?['fullName'] as String?)?.trim();
    final resolved = (nickname?.isNotEmpty == true)
        ? nickname!
        : ((fullName?.isNotEmpty == true) ? fullName! : 'Member');
    if (!mounted) return;
    setState(() => _senderName = resolved);
  }

  Future<void> _sendMessage() async {
    final uid = AuthService.currentUser?.uid;
    final text = _messageController.text.trim();
    if (uid == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await SquadService.sendPleaMessage(
        pleaId: widget.pleaId,
        senderId: uid,
        senderName: _senderName,
        text: text,
      );
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('MESSAGE FAILED: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setVote(String voteChoice) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || _voting) return;

    setState(() => _voting = true);
    try {
      await SquadService.voteOnPleaChoice(widget.pleaId, uid, voteChoice);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('VOTE FAILED: $e')));
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  void _handleResolutionLifecycle(PleaModel plea) {
    final status = plea.status.trim().toLowerCase();
    if (status != 'approved' && status != 'rejected') return;
    if (_resolvedStatusHandled != null) return;

    _resolvedStatusHandled = status;

    final uid = AuthService.currentUser?.uid;
    if (status == 'approved' &&
        uid != null &&
        uid == plea.userId &&
        plea.packageName.trim().isNotEmpty) {
      final grantedMinutes = plea.durationMinutes > 0
          ? plea.durationMinutes
          : 5;
      NativeBridge.temporaryUnlock(plea.packageName.trim(), grantedMinutes);
    }

    final verdictText = status == 'approved'
        ? 'VERDICT: GRANTED'
        : 'VERDICT: REJECTED';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _verdictText = verdictText;
        _showVerdictOverlay = true;
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showVerdictOverlay = false);
    });

    Future.delayed(const Duration(seconds: 5), () async {
      await SquadService.markPleaForDeletion(widget.pleaId);
      if (!mounted) return;
      context.go('/squad');
    });
  }

  Widget _buildTribunalHud(PleaModel plea) {
    final rejectCount = plea.voteCounts['reject'] ?? 0;
    final approveCount = plea.voteCounts['accept'] ?? 0;
    final rejectLeading = rejectCount > approveCount;
    final approveLeading = approveCount > rejectCount;

    final rejectBg = rejectLeading
        ? TribunalTheme.rejectColor
        : TribunalTheme.rejectColor.withOpacity(0.14);
    final approveBg = approveLeading
        ? TribunalTheme.approveColor
        : TribunalTheme.approveColor.withOpacity(0.14);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: RevokeTheme.tribunalScoreboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE TRIBUNAL',
            style: AppTheme.labelSmall.copyWith(color: AppTheme.orange),
          ),
          const SizedBox(height: 8),
          Text(
            '${plea.userName} requests ${plea.durationMinutes} mins on ${plea.appName}',
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          if (plea.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${plea.reason.trim()}"',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.lightGrey),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: rejectBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: TribunalTheme.rejectColor,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'REJECT',
                        style: AppTheme.labelSmall.copyWith(
                          color: TribunalTheme.rejectColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '[$rejectCount]',
                        style: AppTheme.h2.copyWith(
                          color: TribunalTheme.rejectColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: approveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: TribunalTheme.approveColor,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'APPROVE',
                        style: AppTheme.labelSmall.copyWith(
                          color: TribunalTheme.approveColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '[$approveCount]',
                        style: AppTheme.h2.copyWith(
                          color: TribunalTheme.approveColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('THE TRIBUNAL'),
      ),
      body: StreamBuilder<PleaModel?>(
        stream: SquadService.getPleaStream(widget.pleaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'ACCESS DENIED',
                style: AppTheme.h3.copyWith(color: AppTheme.deepRed),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.orange),
            );
          }

          final plea = snapshot.data;
          if (plea == null) {
            return Center(
              child: Text(
                'SESSION NOT FOUND',
                style: AppTheme.h3.copyWith(color: AppTheme.orange),
              ),
            );
          }

          _handleResolutionLifecycle(plea);

          final userVote = currentUid == null ? null : plea.votes[currentUid];
          final canVote = currentUid != null && plea.status == 'active';
          final voteLocked = !canVote || _voting;

          return Stack(
            children: [
              Column(
                children: [
                  _buildTribunalHud(plea),
                  Expanded(
                    child: StreamBuilder<List<PleaMessageModel>>(
                      stream: SquadService.getPleaMessagesStream(widget.pleaId),
                      builder: (context, msgSnapshot) {
                        if (msgSnapshot.hasError) {
                          return Center(
                            child: Text(
                              'ACCESS DENIED OR CHAT ERROR.',
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.deepRed,
                              ),
                            ),
                          );
                        }

                        final messages = msgSnapshot.data ?? const [];
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'NO MESSAGES YET',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.grey,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMine = message.senderId == currentUid;
                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: isMine
                                    ? RevokeTheme.chatBubbleUser
                                    : RevokeTheme.chatBubbleOther,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMine)
                                      Text(
                                        message.senderName.toUpperCase(),
                                        style: AppTheme.labelSmall.copyWith(
                                          color: AppTheme.orange,
                                        ),
                                      ),
                                    Text(
                                      message.text,
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: isMine
                                            ? AppTheme.black
                                            : AppTheme.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: voteLocked
                                      ? null
                                      : () => _setVote('accept'),
                                  style: RevokeTheme.brutalistButton(
                                    isSelected: userVote == 'accept',
                                  ),
                                  child: const Text('APPROVE'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: voteLocked
                                      ? null
                                      : () => _setVote('reject'),
                                  style: RevokeTheme.brutalistButton(
                                    isSelected: userVote == 'reject',
                                    isDanger: true,
                                  ),
                                  child: const Text('REJECT'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: AppTheme.defaultInputDecoration(
                                    hintText: 'Type your argument...',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _sending ? null : _sendMessage,
                                style: AppTheme.primaryButtonStyle.copyWith(
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                                child: const Icon(Icons.send_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_showVerdictOverlay)
                Positioned.fill(
                  child: Container(
                    color: AppTheme.black.withOpacity(0.92),
                    alignment: Alignment.center,
                    child: Text(
                      _verdictText,
                      style: AppTheme.h1.copyWith(
                        color: _verdictText.contains('REJECTED')
                            ? AppTheme.deepRed
                            : AppTheme.orange,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
