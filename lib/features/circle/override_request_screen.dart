import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/circle_models.dart';
import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/circle_service.dart';
import '../../core/services/local_override_history_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

/// Short, deliberate access request. The authority is explicit and resolved
/// from the Commitment policy; it is never selected randomly by the client.
class OverrideRequestScreen extends StatefulWidget {
  const OverrideRequestScreen({
    super.key,
    required this.appName,
    required this.packageName,
    this.commitmentId = '',
    this.authority,
  });

  final String appName;
  final String packageName;
  final String commitmentId;
  final OverrideAuthority? authority;

  @override
  State<OverrideRequestScreen> createState() => _OverrideRequestScreenState();
}

class _OverrideRequestScreenState extends State<OverrideRequestScreen> {
  static const List<int> _durations = [5, 10, 15];
  final TextEditingController _reasonController = TextEditingController();
  Timer? _reflectionTimer;
  int _selectedMinutes = 5;
  int _reflectionSeconds = 0;
  bool _submitting = false;
  bool _loadingPolicy = true;
  bool _policyUnavailable = false;
  OverrideAuthority _authority = OverrideAuthority.self;
  Future<Map<String, dynamic>>? _appDetailsFuture;

  @override
  void initState() {
    super.initState();
    _appDetailsFuture = _loadAppDetails();
    _loadPolicy();
  }

  Future<Map<String, dynamic>> _loadAppDetails() async {
    try {
      return await NativeBridge.getAppDetails(widget.packageName);
    } catch (_) {
      return {'name': widget.appName};
    }
  }

  Future<void> _loadPolicy() async {
    final supplied = widget.authority;
    if (supplied != null) {
      if (mounted) {
        setState(() {
          _authority = supplied;
          _loadingPolicy = false;
        });
      }
      return;
    }
    final uid = AuthService.currentUser?.uid;
    if (uid == null || widget.commitmentId.trim().isEmpty) {
      if (mounted) setState(() => _loadingPolicy = false);
      return;
    }
    try {
      final policy = await CircleService.getPolicy(
        uid: uid,
        commitmentId: widget.commitmentId,
      );
      if (mounted) {
        setState(() {
          _authority = policy.authority;
          _loadingPolicy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingPolicy = false;
          _policyUnavailable = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _reflectionTimer?.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Access'),
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(PhosphorIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _appDetailsFuture,
          builder: (context, snapshot) {
            final iconBytes = snapshot.data?['icon'] as Uint8List?;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                RevokeSpacing.lg,
                RevokeSpacing.sm,
                RevokeSpacing.lg,
                RevokeSpacing.xxl,
              ),
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: RevokeRadii.cardRadius,
                      border: Border.all(color: context.colors.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: iconBytes == null
                        ? Icon(
                            PhosphorIcons.squaresFour,
                            size: RevokeIconSizes.feature,
                            color: context.colors.accent,
                          )
                        : Image.memory(iconBytes, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: RevokeSpacing.lg),
                Text(
                  widget.appName,
                  textAlign: TextAlign.center,
                  style: context.text.sectionTitle,
                ),
                const SizedBox(height: RevokeSpacing.xl),
                RevokeSurface(
                  child: Row(
                    children: [
                      Icon(
                        _authorityIcon,
                        size: RevokeIconSizes.emphasis,
                        color: context.colors.accent,
                      ),
                      const SizedBox(width: RevokeSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loadingPolicy
                                  ? 'Checking authority…'
                                  : _policyUnavailable
                                  ? 'Authority unavailable'
                                  : _authority.label,
                              style: context.text.cardTitle,
                            ),
                            const SizedBox(height: RevokeSpacing.xs),
                            Text(
                              _policyUnavailable
                                  ? 'Reconnect before requesting access so the Commitment policy cannot be bypassed.'
                                  : _authority.description,
                              style: context.text.bodySecondary.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RevokeSpacing.xl),
                Text('Access duration', style: context.text.label),
                const SizedBox(height: RevokeSpacing.sm),
                Wrap(
                  spacing: RevokeSpacing.sm,
                  children: _durations
                      .map(
                        (minutes) => ChoiceChip(
                          label: Text('$minutes min'),
                          selected: _selectedMinutes == minutes,
                          onSelected: _loadingPolicy || _policyUnavailable
                              ? null
                              : (_) =>
                                    setState(() => _selectedMinutes = minutes),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: RevokeSpacing.xl),
                TextField(
                  controller: _reasonController,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Why do you need access?',
                    hintText: 'Give a concise reason.',
                  ),
                ),
                const SizedBox(height: RevokeSpacing.md),
                Text(
                  _reflectionSeconds > 0
                      ? 'Take a moment. You can continue in $_reflectionSeconds seconds.'
                      : 'A 30-second pause is required before this request can continue.',
                  style: context.text.bodySecondary.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: RevokeSpacing.md),
                RevokeButton(
                  label: _reflectionSeconds > 0
                      ? 'Reflecting…'
                      : 'Begin 30-second pause',
                  variant: RevokeButtonVariant.secondary,
                  onPressed:
                      _reflectionSeconds > 0 ||
                          _submitting ||
                          _loadingPolicy ||
                          _policyUnavailable
                      ? null
                      : _beginReflection,
                ),
                const SizedBox(height: RevokeSpacing.sm),
                RevokeButton(
                  label: _submitting ? 'Sending…' : 'Request access',
                  loading: _submitting,
                  onPressed:
                      _submitting ||
                          _reflectionSeconds > 0 ||
                          _reflectionTimer == null ||
                          _loadingPolicy ||
                          _policyUnavailable
                      ? null
                      : _submit,
                ),
                const SizedBox(height: RevokeSpacing.sm),
                RevokeButton(
                  label: 'Cancel',
                  variant: RevokeButtonVariant.tertiary,
                  onPressed: _submitting ? null : () => context.go('/home'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData get _authorityIcon => switch (_authority) {
    OverrideAuthority.self => PhosphorIcons.user,
    OverrideAuthority.ai => PhosphorIcons.sparkle,
    OverrideAuthority.circle => PhosphorIcons.usersThree,
  };

  void _beginReflection() {
    if (_reflectionTimer != null) return;
    setState(() => _reflectionSeconds = 30);
    _reflectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_reflectionSeconds <= 1) {
        timer.cancel();
        setState(() {
          _reflectionSeconds = 0;
          _reflectionTimer = null;
        });
        return;
      }
      setState(() => _reflectionSeconds -= 1);
    });
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a reason before requesting access.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final uid = AuthService.currentUser?.uid;
    try {
      if (uid == null || uid.isEmpty) {
        throw Exception('Sign in to request access.');
      }
      if (_policyUnavailable) {
        throw Exception('Reconnect before requesting access.');
      }
      if (_authority == OverrideAuthority.self) {
        final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
        await LocalOverrideHistoryService.record(
          uid: uid,
          idempotencyKey: localId,
          commitmentId: widget.commitmentId,
          appName: widget.appName,
          packageName: widget.packageName,
          durationMinutes: _selectedMinutes,
          reason: reason,
        );
        await NativeBridge.temporaryUnlock(
          widget.packageName,
          _selectedMinutes,
        );
        try {
          await CircleService.recordSelfOverride(
            commitmentId: widget.commitmentId,
            appName: widget.appName,
            packageName: widget.packageName,
            durationMinutes: _selectedMinutes,
            reason: reason,
            localRequestId: localId,
          );
        } catch (_) {
          // The local/native result is intentionally usable offline. The
          // local history remains until a later sync path is available.
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Temporary access granted.')),
          );
          context.go('/home');
        }
        return;
      }

      final requestId = await CircleService.createOverrideRequest(
        commitmentId: widget.commitmentId,
        authority: _authority,
        appName: widget.appName,
        packageName: widget.packageName,
        durationMinutes: _selectedMinutes,
        reason: reason,
      );
      if (mounted) context.go('/tribunal/$requestId');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Access request could not be sent: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// Source compatibility for the retained legacy native callback and older
/// deep links. New UI uses the neutral Request Access name.
typedef BegForTimeScreen = OverrideRequestScreen;
