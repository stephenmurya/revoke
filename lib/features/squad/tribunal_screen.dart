import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/plea_message_model.dart';
import '../../core/models/plea_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';
import 'widgets/chat_bubble.dart';

class TribunalScreen extends StatefulWidget {
  final String pleaId;

  const TribunalScreen({super.key, required this.pleaId});

  @override
  State<TribunalScreen> createState() => _TribunalScreenState();
}

class _TribunalScreenState extends State<TribunalScreen> {
  static const String _architectEmail = 'stephenmurya@gmail.com';
  static const String _resolvedOutcomeKey = 'tribunal_resolved_outcomes';
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _messageScrollController = ScrollController();
  late final Stream<PleaModel?> _pleaStream;
  late final Stream<List<PleaMessageModel>> _messagesStream;
  bool _sending = false;
  bool _voting = false;
  String _senderName = 'Member';
  String? _resolvedStatusHandled;
  bool _showVerdictOverlay = false;
  bool _autoScrollQueued = false;
  String? _lastLifecycleStatus;
  PleaMessageModel? _replyingTo;
  bool _isAdminObserver = false;
  bool _adminClaimChecked = false;
  bool _sessionReady = false;
  bool _ghostMode = false;
  bool _applyingOverride = false;
  bool _typingIntent = false;
  PleaModel? _resolvedPlea;
  Future<Map<String, _VoterProfile>>? _voterProfilesFuture;

  @override
  void initState() {
    super.initState();
    _pleaStream = SquadService.getPleaStream(widget.pleaId);
    _messagesStream = SquadService.getPleaMessagesStream(widget.pleaId);
    _messageFocusNode.addListener(() {
      // Some async rebuilds (streams, overlays, route transitions) can momentarily
      // unmount/remount the TextField, dropping focus. If the user explicitly tapped
      // into the composer, keep focus unless they dismiss it.
      if (!_typingIntent || _showVerdictOverlay) return;
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
          backgroundColor: dialogContext.scheme.surface,
          title: Text('Force Resolve this plea?', style: AppTheme.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${plea.userName} on ${plea.appName} (${plea.durationMinutes}m)',
                style: AppTheme.bodySmall.copyWith(
                  color: dialogContext.colors.textSecondary,
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

  Future<bool> _hasAppliedOutcome(String pleaId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_resolvedOutcomeKey) ?? const <String>[];
    return ids.contains(pleaId);
  }

  Future<void> _markOutcomeApplied(String pleaId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = List<String>.from(
      prefs.getStringList(_resolvedOutcomeKey) ?? const <String>[],
    );
    if (!ids.contains(pleaId)) {
      ids.add(pleaId);
      // Keep this bounded to avoid unbounded growth.
      if (ids.length > 200) {
        ids.removeRange(0, ids.length - 200);
      }
      await prefs.setStringList(_resolvedOutcomeKey, ids);
    }
  }

  Future<void> _applyApprovedOutcomeOnce(PleaModel plea) async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || uid != plea.userId) return;
    final packageName = plea.packageName.trim();
    if (packageName.isEmpty) return;

    final alreadyApplied = await _hasAppliedOutcome(plea.id);
    if (alreadyApplied) return;

    final grantedMinutes = plea.durationMinutes > 0 ? plea.durationMinutes : 5;
    if (packageName.startsWith('regime-delete:')) {
      final regimeId = packageName.replaceFirst('regime-delete:', '').trim();
      if (regimeId.isEmpty) return;
      await ScheduleService.deleteSchedule(regimeId);
      await _markOutcomeApplied(plea.id);
      return;
    }

    if (packageName.startsWith('regime:')) {
      await NativeBridge.pauseMonitoring(grantedMinutes);
      await _markOutcomeApplied(plea.id);
      return;
    }

    await NativeBridge.temporaryUnlock(packageName, grantedMinutes);
    await _markOutcomeApplied(plea.id);
  }

  List<String> _voterIdsForChoice(PleaModel plea, String choice) {
    return plea.votes.entries
        .where((entry) => entry.value.trim().toLowerCase() == choice)
        .map((entry) => entry.key.trim())
        .where((uid) => uid.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, _VoterProfile>> _loadVoterProfiles(PleaModel plea) async {
    final allUids = <String>{
      ..._voterIdsForChoice(plea, 'accept'),
      ..._voterIdsForChoice(plea, 'reject'),
    };
    if (allUids.isEmpty) return <String, _VoterProfile>{};

    final futures = allUids.map((uid) async {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data() ?? const <String, dynamic>{};
      final nickname = (data['nickname'] as String?)?.trim();
      final fullName = (data['fullName'] as String?)?.trim();
      final resolvedName = (nickname?.isNotEmpty == true)
          ? nickname!
          : ((fullName?.isNotEmpty == true) ? fullName! : 'Member');
      final photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
      return MapEntry(
        uid,
        _VoterProfile(uid: uid, name: resolvedName, photoUrl: photoUrl),
      );
    });

    final entries = await Future.wait(futures);
    return Map<String, _VoterProfile>.fromEntries(entries);
  }

  Future<void> _closeVerdictAndExit() async {
    try {
      await SquadService.markPleaForDeletion(widget.pleaId);
    } catch (_) {
      // Best-effort cleanup; do not block leaving the verdict page.
    }
    if (!mounted) return;
    context.go('/squad');
  }

  Widget _buildVoterTile({
    required _VoterProfile? profile,
    required String uid,
    required bool approved,
  }) {
    final fallbackName = uid == AuthService.currentUser?.uid ? 'You' : 'Member';
    final displayName = profile?.name.trim().isNotEmpty == true
        ? profile!.name
        : fallbackName;
    final photoUrl = profile?.photoUrl.trim() ?? '';
    final hasPhoto = photoUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: context.scheme.onSurface.withValues(alpha: 0.08),
            backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
            child: hasPhoto
                ? null
                : Text(
                    (displayName.isNotEmpty ? displayName[0] : '?')
                        .toUpperCase(),
                    style: AppTheme.xsBold,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.smMedium,
            ),
          ),
          Icon(
            approved ? PhosphorIcons.check() : PhosphorIcons.x(),
            size: 14,
            color: approved ? context.colors.success : context.colors.danger,
          ),
        ],
      ),
    );
  }

  Widget _buildVoterColumn({
    required String title,
    required int count,
    required List<String> voterIds,
    required Map<String, _VoterProfile> profiles,
    required bool approved,
  }) {
    final accent = approved ? context.colors.success : context.colors.danger;
    final knownCount = voterIds.length;
    final unknownCount = count - knownCount;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title [$count]',
              style: AppTheme.smBold.copyWith(color: accent),
            ),
            const SizedBox(height: 8),
            if (voterIds.isEmpty)
              Text(
                'No votes recorded',
                style: AppTheme.xsMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              )
            else
              ...voterIds.map(
                (uid) => _buildVoterTile(
                  profile: profiles[uid],
                  uid: uid,
                  approved: approved,
                ),
              ),
            if (unknownCount > 0)
              Text(
                '+$unknownCount pending profile${unknownCount == 1 ? '' : 's'}',
                style: AppTheme.xsMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerdictPage(PleaModel plea) {
    final status = plea.status.trim().toLowerCase();
    final approved = status == 'approved';
    final approveCount = plea.voteCounts['accept'] ?? 0;
    final rejectCount = plea.voteCounts['reject'] ?? 0;
    final approvedIds = _voterIdsForChoice(plea, 'accept');
    final rejectedIds = _voterIdsForChoice(plea, 'reject');
    final verdictColor = approved
        ? context.colors.success
        : context.colors.danger;
    final verdictText = approved ? 'VERDICT GRANTED' : 'VERDICT REJECTED';

    final profilesFuture = _voterProfilesFuture ?? _loadVoterProfiles(plea);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                verdictText,
                textAlign: TextAlign.center,
                style: AppTheme.h3.copyWith(color: verdictColor),
              ),
              const SizedBox(height: 6),
              Text(
                '${plea.userName} • ${plea.appName}',
                textAlign: TextAlign.center,
                style: AppTheme.smRegular.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<Map<String, _VoterProfile>>(
                future: profilesFuture,
                builder: (context, snapshot) {
                  final profiles =
                      snapshot.data ?? const <String, _VoterProfile>{};
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVoterColumn(
                        title: 'Accepted',
                        count: approveCount,
                        voterIds: approvedIds,
                        profiles: profiles,
                        approved: true,
                      ),
                      const SizedBox(width: 10),
                      _buildVoterColumn(
                        title: 'Rejected',
                        count: rejectCount,
                        voterIds: rejectedIds,
                        profiles: profiles,
                        approved: false,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _closeVerdictAndExit,
                style: AppTheme.primaryButtonStyle,
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTribunalControls(PleaModel plea) {
    final isActive = plea.status.trim().toLowerCase() == 'active';
    final successScheme = ColorScheme.fromSeed(
      seedColor: context.colors.success,
      brightness: Theme.of(context).brightness,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.scheme.outlineVariant),
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
                  onPressed: (_applyingOverride || !isActive)
                      ? null
                      : () => _confirmAndOverride(
                          verdict: 'approved',
                          plea: plea,
                        ),
                  style: AppTheme.primaryButtonStyle.copyWith(
                    backgroundColor: WidgetStatePropertyAll(
                      context.colors.success,
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      successScheme.onPrimary,
                    ),
                  ),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_applyingOverride || !isActive)
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
                        color: context.colors.textSecondary,
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
    _resolvedPlea = plea;
    _voterProfilesFuture = _loadVoterProfiles(plea);
    _typingIntent = false;
    _messageFocusNode.unfocus();

    if (status == 'approved') {
      unawaited(_applyApprovedOutcomeOnce(plea));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_showVerdictOverlay) return;
      setState(() {
        _showVerdictOverlay = true;
      });
    });
  }

  Widget _buildTribunalHud(PleaModel plea) {
    final rejectCount = plea.voteCounts['reject'] ?? 0;
    final approveCount = plea.voteCounts['accept'] ?? 0;
    final rejectLeading = rejectCount > approveCount;
    final approveLeading = approveCount > rejectCount;

    final rejectBg = rejectLeading
        ? context.colors.danger
        : context.colors.danger.withValues(alpha: 0.14);
    final approveBg = approveLeading
        ? context.colors.success
        : context.colors.success.withValues(alpha: 0.14);

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
            style: AppTheme.smBold.copyWith(color: context.scheme.onSurface),
          ),
          if (plea.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '"${plea.reason.trim()}"',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.smRegular.copyWith(
                color: context.colors.textSecondary,
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
                    border: Border.all(color: context.colors.danger),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.x(),
                        size: 14,
                        color: context.colors.danger,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'REJECT [$rejectCount]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.xsBold.copyWith(
                            color: context.colors.danger,
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
                    border: Border.all(color: context.colors.success),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.check(),
                        size: 14,
                        color: context.colors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'APPROVE [$approveCount]',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.xsBold.copyWith(
                            color: context.colors.success,
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text('The Tribunal', style: AppTheme.h2),
        ),
        body: Center(
          child: CircularProgressIndicator(color: context.scheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              stream: _pleaStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'ACCESS DENIED',
                      style: AppTheme.h3.copyWith(color: context.colors.danger),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: context.scheme.primary,
                    ),
                  );
                }

                final plea = snapshot.data;
                if (plea == null) {
                  return Center(
                    child: Text(
                      'SESSION NOT FOUND',
                      style: AppTheme.h3.copyWith(
                        color: context.scheme.primary,
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
                    currentUid != null &&
                    plea.participants.contains(currentUid);
                final canAccessSession = isParticipant || _isAdminObserver;
                if (!canAccessSession) {
                  return Center(
                    child: Text(
                      'ACCESS DENIED',
                      style: AppTheme.h3.copyWith(color: context.colors.danger),
                    ),
                  );
                }

                final userVote = currentUid == null
                    ? null
                    : plea.votes[currentUid];
                final isRequester =
                    currentUid != null && currentUid == plea.userId;
                final canVote =
                    currentUid != null &&
                    plea.status == 'active' &&
                    !isRequester &&
                    !_isAdminObserver;
                final isAdmin = _isAdminObserver;
                final showObserverBanner = isAdmin && !isParticipant;
                final voteLocked = !canVote || _voting;

                if (_showVerdictOverlay && _resolvedPlea != null) {
                  return _buildVerdictPage(_resolvedPlea!);
                }

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
                            stream: _messagesStream,
                            builder: (context, msgSnapshot) {
                              if (msgSnapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'ACCESS DENIED OR CHAT ERROR.',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: context.colors.danger,
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
                                      color: context.colors.textSecondary,
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
                                          style:
                                              AppTheme.tribunalVoteButtonStyle(
                                                isSelected:
                                                    userVote == 'accept',
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
                                          style:
                                              AppTheme.tribunalVoteButtonStyle(
                                                isSelected:
                                                    userVote == 'reject',
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
                                      color: context.scheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: context.colors.success,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          PhosphorIcons.arrowBendUpLeft(),
                                          size: 16,
                                          color: context.colors.success,
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
                                                style: AppTheme.labelSmall
                                                    .copyWith(
                                                      color: context
                                                          .colors
                                                          .success,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _replyingTo!.text,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTheme.bodySmall
                                                    .copyWith(
                                                      color: context
                                                          .colors
                                                          .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _clearReplyTarget,
                                          icon: Icon(
                                            PhosphorIcons.x(),
                                            color: context.colors.textSecondary,
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
                                          controller: _messageController,
                                          focusNode: _messageFocusNode,
                                          onTap: () => _typingIntent = true,
                                          onTapOutside: (_) {
                                            _typingIntent = false;
                                            _messageFocusNode.unfocus();
                                          },
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          decoration:
                                              AppTheme.defaultInputDecoration(
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
                                        onPressed: _sending
                                            ? null
                                            : _sendMessage,
                                        style: AppTheme.primaryButtonStyle
                                            .copyWith(
                                              padding:
                                                  const WidgetStatePropertyAll(
                                                    EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                    ),
                                                  ),
                                              minimumSize:
                                                  const WidgetStatePropertyAll(
                                                    Size(56, 56),
                                                  ),
                                            ),
                                        child: Icon(
                                          PhosphorIcons.paperPlaneRight(),
                                        ),
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

class _VoterProfile {
  final String uid;
  final String name;
  final String photoUrl;

  const _VoterProfile({
    required this.uid,
    required this.name,
    required this.photoUrl,
  });
}
