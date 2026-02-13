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
  final ScrollController _messageScrollController = ScrollController();
  bool _sending = false;
  bool _voting = false;
  String _senderName = 'Member';
  String? _resolvedStatusHandled;
  bool _showVerdictOverlay = false;
  String _verdictText = '';
  int _lastMessageCount = 0;
  PleaMessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageScrollController.dispose();
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
      _replyingTo = null;
      _scrollMessagesToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('MESSAGE FAILED: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollMessagesToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      final target = _messageScrollController.position.maxScrollExtent;
      if (animated) {
        _messageScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _messageScrollController.jumpTo(target);
      }
    });
  }

  void _setReplyTarget(PleaMessageModel message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _clearReplyTarget() {
    if (_replyingTo == null) return;
    setState(() {
      _replyingTo = null;
    });
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
        ? AppSemanticColors.reject
        : AppSemanticColors.reject.withValues(alpha: 0.14);
    final approveBg = approveLeading
        ? AppSemanticColors.approve
        : AppSemanticColors.approve.withValues(alpha: 0.14);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AppTheme.tribunalScoreboardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${plea.userName} asks ${plea.durationMinutes}m on ${plea.appName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.smBold.copyWith(
              color: AppSemanticColors.primaryText,
            ),
          ),
          if (plea.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '"${plea.reason.trim()}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.smRegular.copyWith(
                color: AppSemanticColors.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: rejectBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppSemanticColors.reject),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppSemanticColors.reject,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'REJECT [$rejectCount]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.xsBold.copyWith(
                            color: AppSemanticColors.rejectText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: approveBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppSemanticColors.approve),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppSemanticColors.approve,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'APPROVE [$approveCount]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.xsBold.copyWith(
                            color: AppSemanticColors.approveText,
                          ),
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
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('The Tribunal', style: AppTheme.h2),
      ),
      body: StreamBuilder<PleaModel?>(
        stream: SquadService.getPleaStream(widget.pleaId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'ACCESS DENIED',
                style: AppTheme.h3.copyWith(color: AppSemanticColors.errorText),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppSemanticColors.accent),
            );
          }

          final plea = snapshot.data;
          if (plea == null) {
            return Center(
              child: Text(
                'SESSION NOT FOUND',
                style: AppTheme.h3.copyWith(
                  color: AppSemanticColors.accentText,
                ),
              ),
            );
          }

          _handleResolutionLifecycle(plea);

          final userVote = currentUid == null ? null : plea.votes[currentUid];
          final isRequester = currentUid != null && currentUid == plea.userId;
          final canVote =
              currentUid != null && plea.status == 'active' && !isRequester;
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
                                color: AppSemanticColors.errorText,
                              ),
                            ),
                          );
                        }

                        final messages = msgSnapshot.data ?? const [];
                        if (messages.length != _lastMessageCount) {
                          _lastMessageCount = messages.length;
                          _scrollMessagesToBottom();
                        }
                        if (messages.isEmpty) {
                          return Center(
                            child: Text(
                              'NO MESSAGES YET',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppSemanticColors.mutedText,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _messageScrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMine = message.senderId == currentUid;
                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  if (details.primaryVelocity != null &&
                                      details.primaryVelocity! > 220) {
                                    _setReplyTarget(message);
                                  }
                                },
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
                                      ? AppTheme.chatBubbleUserDecoration
                                      : AppTheme.chatBubbleOtherDecoration,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isMine)
                                        Text(
                                          message.senderName,
                                          style: AppTheme.labelSmall.copyWith(
                                            color: AppSemanticColors.accentText,
                                          ),
                                        ),
                                      Text(
                                        message.text,
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: isMine
                                              ? AppSemanticColors.inverseText
                                              : AppSemanticColors.primaryText,
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
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        children: [
                          if (!isRequester) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: voteLocked
                                        ? null
                                        : () => _setVote('accept'),
                                    style: AppTheme.tribunalVoteButtonStyle(
                                      isSelected: userVote == 'accept',
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: voteLocked
                                        ? null
                                        : () => _setVote('reject'),
                                    style: AppTheme.tribunalVoteButtonStyle(
                                      isSelected: userVote == 'reject',
                                      isDanger: true,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_replyingTo != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppSemanticColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppSemanticColors.approve,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.reply_rounded,
                                    size: 16,
                                    color: AppSemanticColors.approve,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Replying to ${_replyingTo!.senderName}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTheme.labelSmall.copyWith(
                                            color: AppSemanticColors.approve,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _replyingTo!.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTheme.bodySmall.copyWith(
                                            color:
                                                AppSemanticColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _clearReplyTarget,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: AppSemanticColors.mutedText,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: TextField(
                                    controller: _messageController,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: AppTheme.defaultInputDecoration(
                                      hintText: 'Type your argument...',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _sending ? null : _sendMessage,
                                  style: AppTheme.primaryButtonStyle.copyWith(
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 18),
                                    ),
                                    minimumSize: const WidgetStatePropertyAll(
                                      Size(56, 56),
                                    ),
                                  ),
                                  child: const Icon(Icons.send_rounded),
                                ),
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
                    color: AppSemanticColors.background.withValues(alpha: 0.92),
                    alignment: Alignment.center,
                    child: Text(
                      _verdictText,
                      style: AppTheme.h1.copyWith(
                        color: _verdictText.contains('REJECTED')
                            ? AppSemanticColors.errorText
                            : AppSemanticColors.accentText,
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
