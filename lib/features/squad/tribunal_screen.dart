import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/plea_message_model.dart';
import '../../core/models/plea_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/chat_bubble.dart';

class TribunalScreen extends StatefulWidget {
  final String pleaId;

  const TribunalScreen({super.key, required this.pleaId});

  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen> {
  static const String _architectEmail = 'stephenmurya@gmail.com';
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _messageScrollController = ScrollController();
  bool _sending = false;
  bool _voting = false;
  String _senderName = 'Member';
  String? _resolvedStatusHandled;
  bool _showVerdictOverlay = false;
  String _verdictText = '';
  bool _autoScrollQueued = false;
  String? _lastLifecycleStatus;
  PleaMessageModel? _replyingTo;
  bool _isAdminObserver = false;
  bool _adminClaimChecked = false;
  bool _sessionReady = false;
  bool _ghostMode = false;
  bool _applyingOverride = false;
  bool _typingIntent = false;
  Timer? _hideOverlayTimer;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(() {
      // Some async rebuilds (streams, overlays, route transitions) can momentarily
      // unmount/remount the TextField, dropping focus. If the user explicitly tapped
      // into the composer, keep focus unless they dismiss it.
      if (!_typingIntent) return;
      if (_messageFocusNode.hasFocus) return;
      scheduleMicrotask(() {
        if (!mounted) return;
        if (_typingIntent && !_messageFocusNode.hasFocus) {
          _messageFocusNode.requestFocus();
        }
      });
    });
    _bootstrapSession();
  }

  @override
  void dispose() {
    _hideOverlayTimer?.cancel();
    _exitTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapSession() async {
    final user = AuthService.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _adminClaimChecked = true;
        _sessionReady = true;
      });
      return;
    }

    final email = user?.email?.trim().toLowerCase();
    bool isAdmin = email == _architectEmail;
    String resolvedSenderName = 'Member';

    try {
      // Force refresh to avoid stale claim state when entering tribunal.
      final tokenResult = await user?.getIdTokenResult(true);
      isAdmin = isAdmin || tokenResult?.claims?['admin'] == true;
    } catch (_) {
      try {
        // Fallback to cached claims when force refresh fails.
        final tokenResult = await user?.getIdTokenResult();
        isAdmin = isAdmin || tokenResult?.claims?['admin'] == true;
      } catch (_) {}
    }

    if (!isAdmin) {
      try {
        await SquadService.joinPleaSession(widget.pleaId, uid);
      } catch (_) {}
    }

    try {
      final userData = await AuthService.getUserData();
      final nickname = (userData?['nickname'] as String?)?.trim();
      final fullName = (userData?['fullName'] as String?)?.trim();
      final resolved = (nickname?.isNotEmpty == true)
          ? nickname!
          : ((fullName?.isNotEmpty == true) ? fullName! : 'Member');
      resolvedSenderName = resolved;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isAdminObserver = isAdmin;
      _adminClaimChecked = true;
      _sessionReady = true;
      _senderName = resolvedSenderName;
      // Default admin chat to Ghost Mode to avoid callable-layer rejection for admin users
      // and make mock tribunal simulations immediately usable.
      _ghostMode = isAdmin;
    });
  }

  Future<void> _sendMessage() async {
    final uid = AuthService.currentUser?.uid;
    final text = _messageController.text.trim();
    if (uid == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      if (_isAdminObserver && _ghostMode) {
        await FirebaseFirestore.instance
            .collection('pleas')
            .doc(widget.pleaId)
            .collection('messages')
            .add({
              'senderId': 'THE_ARCHITECT',
              'senderName': 'The Architect',
              'text': text,
              'isSystem': true,
              'timestamp': FieldValue.serverTimestamp(),
            });
      } else {
        await SquadService.sendPleaMessage(
          pleaId: widget.pleaId,
          senderId: uid,
          senderName: _senderName,
          text: text,
        );
      }
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

  void _scrollMessagesToBottom() {
    if (_autoScrollQueued) return;
    _autoScrollQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _autoScrollQueued = false;
      if (!mounted || !_messageScrollController.hasClients) return;
      final target = _messageScrollController.position.maxScrollExtent;
      _messageScrollController.jumpTo(target);
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

  Future<void> _confirmAndOverride({
    required String verdict,
    required PleaModel plea,
  }) async {
    if (_applyingOverride) return;

    final reasonController = TextEditingController();
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppSemanticColors.surface,
          title: Text('Force Resolve this plea?', style: AppTheme.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plea.userName} on ${plea.appName} (${plea.durationMinutes}m)',
                style: AppTheme.bodySmall.copyWith(
                  color: AppSemanticColors.secondaryText,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: AppTheme.defaultInputDecoration(
                  hintText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(verdict == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );

    if (shouldProceed != true) return;

    setState(() => _applyingOverride = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminOverridePlea',
      );
      await callable.call({
        'pleaId': widget.pleaId,
        'verdict': verdict,
        'reason': reasonController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Override applied: ${verdict.toUpperCase()}')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.message ?? e.code;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Override failed: $message')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Override failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _applyingOverride = false);
      }
    }
  }

  Widget _buildAdminTribunalControls(PleaModel plea) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppSemanticColors.primaryText.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Tribunal Controls', style: AppTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyingOverride
                      ? null
                      : () => _confirmAndOverride(
                          verdict: 'approved',
                          plea: plea,
                        ),
                  style: AppTheme.primaryButtonStyle.copyWith(
                    backgroundColor: const WidgetStatePropertyAll(
                      AppSemanticColors.approve,
                    ),
                    foregroundColor: const WidgetStatePropertyAll(
                      AppSemanticColors.inverseText,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _applyingOverride
                      ? null
                      : () => _confirmAndOverride(
                          verdict: 'rejected',
                          plea: plea,
                        ),
                  style: AppTheme.dangerButtonStyle,
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ghost Mode', style: AppTheme.bodyMedium),
                    Text(
                      'Send as The Architect',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppSemanticColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _ghostMode,
                onChanged: (value) => setState(() => _ghostMode = value),
              ),
            ],
          ),
        ],
      ),
    );
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

    // Admin observers should not auto-exit or trigger overlay transitions.
    // They can keep watching the room state without lifecycle side-effects.
    if (_isAdminObserver) {
      return;
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

    _hideOverlayTimer?.cancel();
    _hideOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showVerdictOverlay = false);
    });

    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
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
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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

    if (!_adminClaimChecked || !_sessionReady) {
      return Scaffold(
        backgroundColor: AppSemanticColors.background,
        appBar: AppBar(
          backgroundColor: AppSemanticColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text('The Tribunal', style: AppTheme.h2),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppSemanticColors.accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: AppSemanticColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('The Tribunal', style: AppTheme.h2),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Some entry paths (dialogs/sheets) can yield an unbounded height.
          // Clamp Tribunal to the viewport height to avoid layout/semantics crashes.
          final boundedHeight = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;

          return SizedBox(
            height: boundedHeight,
            width: double.infinity,
            child: StreamBuilder<PleaModel?>(
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

          final lifecycleStatus = plea.status.trim().toLowerCase();
          if (_lastLifecycleStatus != lifecycleStatus) {
            _lastLifecycleStatus = lifecycleStatus;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _handleResolutionLifecycle(plea);
            });
          }

          final isParticipant =
              currentUid != null && plea.participants.contains(currentUid);
          final canAccessSession = isParticipant || _isAdminObserver;
          if (!canAccessSession) {
            return Center(
              child: Text(
                'ACCESS DENIED',
                style: AppTheme.h3.copyWith(color: AppSemanticColors.errorText),
              ),
            );
          }

          final userVote = currentUid == null ? null : plea.votes[currentUid];
          final isRequester = currentUid != null && currentUid == plea.userId;
          final canVote =
              currentUid != null &&
              plea.status == 'active' &&
              !isRequester &&
              !_isAdminObserver;
          final isAdmin = _isAdminObserver;
          final showObserverBanner = isAdmin && !isParticipant;
          final voteLocked = !canVote || _voting;

          return Stack(
            children: [
              Column(
                children: [
                  _buildTribunalHud(plea),
                  if (showObserverBanner)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: AppTheme.warningBannerDecoration,
                      child: Text(
                        'SYSTEM OBSERVER ACTIVE',
                        textAlign: TextAlign.center,
                        style: AppTheme.warningBannerTextStyle,
                      ),
                    ),
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
                            return ChatBubble(
                              message: message,
                              isMine: isMine,
                              onSwipeReply: _isAdminObserver
                                  ? null
                                  : () => _setReplyTarget(message),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAdmin) ...[
                            _buildAdminTribunalControls(plea),
                            const SizedBox(height: 10),
                          ],
                          if (!isRequester && !isAdmin) ...[
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
                          if (_replyingTo != null && !isAdmin) ...[
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: TextField(
                                    key: const ValueKey(
                                      'tribunal_message_input',
                                    ),
                                    controller: _messageController,
                                    focusNode: _messageFocusNode,
                                    onTap: () => _typingIntent = true,
                                    onTapOutside: (_) {
                                      _typingIntent = false;
                                      _messageFocusNode.unfocus();
                                    },
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: AppTheme.defaultInputDecoration(
                                      hintText: isAdmin
                                          ? (_ghostMode
                                                ? 'Ghost message as The Architect...'
                                                : 'Send admin note...')
                                          : 'Type your argument...',
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
        },
      ),
    );
  }
}
