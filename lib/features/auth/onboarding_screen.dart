import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/app_router.dart';
import '../../core/models/onboarding_state.dart';
import '../../core/native_bridge.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/onboarding_state_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/taper_plan_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import '../commitments/commitment_presentation.dart';
import '../commitments/create_commitment_screen.dart';

/// A production-safe seam for smoke tests and lightweight onboarding previews.
class OnboardingWelcome extends StatelessWidget {
  const OnboardingWelcome({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(RevokeSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            PhosphorIcons.compass,
            size: RevokeIconSizes.feature,
            color: context.colors.accent,
          ),
          const SizedBox(height: RevokeSpacing.hero),
          Text(
            'A clearer way to change your habits',
            style: context.text.displaySmall,
          ),
          const SizedBox(height: RevokeSpacing.md),
          Text(
            'Revoke helps you see your real usage, make a Commitment, and keep the boundary you chose.',
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const Spacer(),
          RevokeButton(label: 'Get started', onPressed: onContinue),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  OnboardingState _state = const OnboardingState();
  final TextEditingController _nicknameController = TextEditingController();
  bool _loading = true;
  bool _working = false;
  String? _error;
  Map<String, bool> _permissions = const <String, bool>{};
  Map<String, dynamic>? _reality;
  CommitmentViewModel? _firstCommitment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_state.step == OnboardingStep.usagePermission ||
        _state.step == OnboardingStep.enforcementPermissions) {
      unawaited(_checkPermissions());
    }
  }

  Future<void> _loadState() async {
    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final state = await OnboardingStateService.loadOrCreate();
      if (!mounted) return;
      _nicknameController.text = state.nickname ?? '';
      setState(() {
        _state = state;
        _loading = false;
      });
      if (state.step == OnboardingStep.realityCheck) {
        unawaited(_loadReality());
      }
      if (state.step == OnboardingStep.review) {
        unawaited(_loadFirstCommitment());
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'We could not restore your onboarding progress. Try again.';
        });
      }
    }
  }

  Future<void> _persist(OnboardingState next) async {
    setState(() {
      _state = next;
      _error = null;
    });
    await OnboardingStateService.save(next);
  }

  Future<void> _goTo(OnboardingStep step, {OnboardingState? base}) async {
    await _persist((base ?? _state).copyWith(step: step));
    if (!mounted) return;
    if (step == OnboardingStep.realityCheck) unawaited(_loadReality());
    if (step == OnboardingStep.review) unawaited(_loadFirstCommitment());
  }

  Future<void> _checkPermissions() async {
    try {
      final permissions = await NativeBridge.checkPermissions();
      if (!mounted) return;
      setState(() => _permissions = permissions);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Android permission status is unavailable.');
      }
    }
  }

  Future<void> _loadReality() async {
    if ((_permissions['usage_stats'] ?? false) != true) {
      await _checkPermissions();
      if ((_permissions['usage_stats'] ?? false) != true) return;
    }
    setState(() => _working = true);
    try {
      final data = await NativeBridge.getRealityCheck();
      if (!mounted) return;
      setState(() {
        _reality = data;
        _working = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _error =
              'Current usage could not be measured. Check Usage Access and try again.';
        });
      }
    }
  }

  Future<void> _signIn() async {
    await _run(() async {
      await AuthService.signInWithGoogle();
      final restored = await OnboardingStateService.loadOrCreate();
      if (!mounted) return;
      if (restored.isComplete) {
        AppRouter.invalidateOnboardingCache();
        context.go('/home');
        return;
      }
      _nicknameController.text = restored.nickname ?? '';
      await _persist(restored.copyWith(step: OnboardingStep.identity));
    });
  }

  Future<void> _saveIdentity() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = 'Enter a name to continue.');
      return;
    }
    await _run(() async {
      await AuthService.updateNickname(nickname);
      await _persist(
        _state.copyWith(
          nickname: nickname,
          step: OnboardingStep.usagePermission,
        ),
      );
      await _checkPermissions();
    });
  }

  Future<void> _openUsageAccess() async {
    try {
      await NativeBridge.requestUsageStats();
      await _checkPermissions();
      if ((_permissions['usage_stats'] ?? false) == true && mounted) {
        await _goTo(OnboardingStep.realityCheck);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Usage Access could not be opened.');
    }
  }

  Future<void> _chooseIntent(CommitmentType type) async {
    await _persist(
      _state.copyWith(intent: type.name, step: OnboardingStep.firstCommitment),
    );
  }

  Future<void> _createFirstCommitment() async {
    final type = _state.intent == CommitmentType.reduce.name
        ? CommitmentType.reduce
        : CommitmentType.protect;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) =>
            CreateCommitmentScreen(onboardingMode: true, initialType: type),
      ),
    );
    if (!mounted || result == null || result.trim().isEmpty) return;
    await _persist(
      _state.copyWith(
        firstCommitmentId: result,
        step: OnboardingStep.enforcementPermissions,
      ),
    );
    await _checkPermissions();
  }

  String? get _nextMissingPermission {
    if ((_permissions['accessibility'] ?? false) != true) {
      return 'accessibility';
    }
    if ((_permissions['overlay'] ?? false) != true) return 'overlay';
    if ((_permissions['exact_alarm'] ?? false) != true) return 'exact_alarm';
    return null;
  }

  Future<void> _handleEnforcementPermission() async {
    await _checkPermissions();
    final missing = _nextMissingPermission;
    if (missing == null) {
      await _goTo(OnboardingStep.intervention);
      return;
    }
    try {
      switch (missing) {
        case 'accessibility':
          await NativeBridge.requestAccessibilityPermission();
        case 'overlay':
          await NativeBridge.requestOverlay();
        case 'exact_alarm':
          await NativeBridge.requestExactAlarms();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This permission screen could not be opened.');
      }
    }
  }

  Future<void> _loadFirstCommitment() async {
    final id = _state.firstCommitmentId;
    if (id == null || id.isEmpty) return;
    try {
      final schedules = await ScheduleService.getSchedules();
      final plan = await TaperPlanService.getActivePlan();
      final matching = schedules
          .where((schedule) => schedule.id == id)
          .toList();
      if (!mounted || matching.isEmpty) return;
      setState(
        () => _firstCommitment = CommitmentPresentationAdapter.fromSchedule(
          matching.first,
          taperPlan: plan?.scheduleId == id ? plan : null,
        ),
      );
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = 'That did not complete. Try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _complete() async {
    await _persist(_state.copyWith(step: OnboardingStep.complete));
    AppRouter.invalidateOnboardingCache();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: RevokeLoadingState(label: 'Restoring your progress'),
      );
    }
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              RevokeSpacing.lg,
              RevokeSpacing.xl,
              RevokeSpacing.lg,
              RevokeSpacing.lg,
            ),
            child: Column(
              children: [
                _buildProgress(),
                const SizedBox(height: RevokeSpacing.lg),
                Expanded(child: _buildStep()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final step = _state.step.index;
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: (step / (OnboardingStep.values.length - 1)).clamp(0, 1),
            minHeight: RevokeSpacing.xs,
            borderRadius: RevokeRadii.pillRadius,
            backgroundColor: context.colors.surfaceSubtle,
            color: context.colors.accent,
          ),
        ),
        const SizedBox(width: RevokeSpacing.md),
        Text(
          '${step + 1}/${OnboardingStep.values.length - 1}',
          style: context.text.labelMedium,
        ),
      ],
    );
  }

  Widget _buildStep() {
    switch (_state.step) {
      case OnboardingStep.welcome:
        return OnboardingWelcome(
          onContinue: () => _goTo(
            AuthService.currentUser == null
                ? OnboardingStep.authentication
                : OnboardingStep.identity,
          ),
        );
      case OnboardingStep.authentication:
        return _page(
          icon: PhosphorIcons.lockOpen,
          title: 'Keep your progress with you',
          body:
              'Sign in to save your Commitments and resume after Android settings detours.',
          action: RevokeButton(
            label: 'Continue with Google',
            icon: PhosphorIcons.googleLogo,
            onPressed: _working ? null : _signIn,
            loading: _working,
          ),
        );
      case OnboardingStep.identity:
        return _identityStep();
      case OnboardingStep.usagePermission:
        return _permissionStep(
          icon: PhosphorIcons.chartBar,
          title: 'Start with what is real',
          body:
              'Usage Access lets Revoke measure your current behavior before you choose a Commitment. Revoke does not read your screen content.',
          granted: _permissions['usage_stats'] == true,
          buttonLabel: _permissions['usage_stats'] == true
              ? 'Continue'
              : 'Allow Usage Access',
          onPressed: _permissions['usage_stats'] == true
              ? () => _goTo(OnboardingStep.realityCheck)
              : _openUsageAccess,
        );
      case OnboardingStep.realityCheck:
        return _realityStep();
      case OnboardingStep.intent:
        return _intentStep();
      case OnboardingStep.firstCommitment:
        return _page(
          icon: PhosphorIcons.target,
          title: 'Make your first Commitment',
          body:
              'Choose one behavior to change. Revoke will use the existing enforcement system to carry out the boundary you select.',
          action: RevokeButton(
            label: 'Create Commitment',
            onPressed: _working ? null : _createFirstCommitment,
          ),
        );
      case OnboardingStep.enforcementPermissions:
        return _enforcementStep();
      case OnboardingStep.intervention:
        return _page(
          icon: PhosphorIcons.shieldCheck,
          title: 'Know what happens at the boundary',
          body:
              'Notice gives you a clear reminder. Resist makes the boundary harder to ignore. Revoke can place an enforcement surface over a restricted app. You stay in control of the Commitment you chose.',
          action: RevokeButton(
            label: 'Review my Commitment',
            onPressed: () => _goTo(OnboardingStep.review),
          ),
        );
      case OnboardingStep.review:
        return _reviewStep();
      case OnboardingStep.complete:
        return _page(
          icon: PhosphorIcons.check,
          title: 'You are ready',
          body: 'Your Revoke space is set up.',
          action: RevokeButton(
            label: 'Open Today',
            onPressed: () => context.go('/home'),
          ),
        );
    }
  }

  Widget _page({
    required IconData icon,
    required String title,
    required String body,
    required Widget action,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: RevokeIconSizes.feature, color: context.colors.accent),
        const SizedBox(height: RevokeSpacing.xl),
        Text(title, style: context.text.headlineLarge),
        const SizedBox(height: RevokeSpacing.md),
        Text(
          body,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: RevokeSpacing.lg),
          RevokeSurface(
            color: context.colors.warning.withValues(alpha: 0.10),
            child: Text(_error!, style: context.text.bodyMedium),
          ),
        ],
        const Spacer(),
        action,
      ],
    );
  }

  Widget _identityStep() => _page(
    icon: PhosphorIcons.user,
    title: 'How should Revoke address you?',
    body:
        'This is only for your account experience. It does not determine whether onboarding is complete.',
    action: Column(
      children: [
        TextField(
          controller: _nicknameController,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        const SizedBox(height: RevokeSpacing.md),
        RevokeButton(
          label: 'Continue',
          onPressed: _working ? null : _saveIdentity,
          loading: _working,
        ),
      ],
    ),
  );

  Widget _permissionStep({
    required IconData icon,
    required String title,
    required String body,
    required bool granted,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) => _page(
    icon: icon,
    title: title,
    body: body,
    action: Column(
      children: [
        if (granted)
          RevokeSurface(
            padding: const EdgeInsets.all(RevokeSpacing.md),
            color: context.colors.success.withValues(alpha: 0.10),
            child: Row(
              children: [
                Icon(PhosphorIcons.checkCircle, color: context.colors.success),
                const SizedBox(width: RevokeSpacing.sm),
                Expanded(
                  child: Text(
                    'Usage Access is enabled.',
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (granted) const SizedBox(height: RevokeSpacing.md),
        RevokeButton(
          label: buttonLabel,
          onPressed: _working ? null : onPressed,
          loading: _working,
        ),
      ],
    ),
  );

  Widget _realityStep() {
    final average = _reality?['totalAvgDailyHours'];
    final topApps =
        (_reality?['topApps'] as List?)?.whereType<Map>().toList() ??
        const <Map>[];
    return _page(
      icon: PhosphorIcons.eye,
      title: 'Here is your starting point',
      body: average is num
          ? 'Your measured average is ${average.toStringAsFixed(1)} hours per day. Use this as context, not a judgment.'
          : 'Revoke has access to Usage Access, but there is not enough history for a reliable baseline yet.',
      action: Column(
        children: [
          if (topApps.isNotEmpty)
            RevokeSurface(
              padding: const EdgeInsets.all(RevokeSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Highest-use apps', style: context.text.titleMedium),
                  const SizedBox(height: RevokeSpacing.sm),
                  ...topApps
                      .take(3)
                      .map(
                        (app) => Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: RevokeSpacing.xs,
                          ),
                          child: Text(
                            '${app['name'] ?? app['packageName'] ?? 'App'}',
                            style: context.text.bodyMedium,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          if (topApps.isNotEmpty) const SizedBox(height: RevokeSpacing.md),
          RevokeButton(
            label: 'Choose what to change',
            onPressed: _working ? null : () => _goTo(OnboardingStep.intent),
          ),
        ],
      ),
    );
  }

  Widget _intentStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        PhosphorIcons.target,
        size: RevokeIconSizes.feature,
        color: context.colors.accent,
      ),
      const SizedBox(height: RevokeSpacing.xl),
      Text('What do you want to do?', style: context.text.headlineLarge),
      const SizedBox(height: RevokeSpacing.md),
      Text(
        'Choose the behavioral intent first. Revoke will guide the configuration that follows.',
        style: context.text.bodyLarge?.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
      const SizedBox(height: RevokeSpacing.xl),
      _intentChoice(
        CommitmentType.reduce,
        PhosphorIcons.trendDown,
        'Reduce',
        'Gradually use selected apps less over a defined plan.',
      ),
      const SizedBox(height: RevokeSpacing.md),
      _intentChoice(
        CommitmentType.protect,
        PhosphorIcons.shieldCheck,
        'Protect',
        'Create a clear boundary Revoke can enforce.',
      ),
    ],
  );

  Widget _intentChoice(
    CommitmentType type,
    IconData icon,
    String title,
    String body,
  ) => Semantics(
    button: true,
    label: '$title. $body',
    child: InkWell(
      onTap: _working ? null : () => _chooseIntent(type),
      borderRadius: RevokeRadii.cardRadius,
      child: RevokeSurface(
        color: _state.intent == type.name ? context.colors.accentSoft : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: RevokeIconSizes.emphasis,
              color: context.colors.accent,
            ),
            const SizedBox(width: RevokeSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  const SizedBox(height: RevokeSpacing.xs),
                  Text(
                    body,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(PhosphorIcons.arrowRight, color: context.colors.textMuted),
          ],
        ),
      ),
    ),
  );

  Widget _enforcementStep() {
    final missing = _nextMissingPermission;
    return _page(
      icon: PhosphorIcons.lightning,
      title: missing == null
          ? 'Enforcement is ready'
          : 'Let Revoke enforce your Commitment',
      body: missing == null
          ? 'The Android permissions needed for your Commitment are enabled.'
          : 'Revoke needs a few Android permissions after you choose a Commitment. Each one has a specific role and can be changed later in Android settings.',
      action: Column(
        children: [
          _permissionRow(
            'Accessibility',
            'Detect restricted apps as they open',
            _permissions['accessibility'] == true,
          ),
          _permissionRow(
            'Display over other apps',
            'Show the native enforcement surface',
            _permissions['overlay'] == true,
          ),
          _permissionRow(
            'Exact alarms',
            'Start time-based enforcement on time',
            _permissions['exact_alarm'] == true,
          ),
          const SizedBox(height: RevokeSpacing.md),
          RevokeButton(
            label: missing == null ? 'Continue' : 'Open next permission',
            onPressed: _working ? null : _handleEnforcementPermission,
            loading: _working,
          ),
        ],
      ),
    );
  }

  Widget _permissionRow(String title, String body, bool granted) => Padding(
    padding: const EdgeInsets.only(bottom: RevokeSpacing.sm),
    child: Row(
      children: [
        Icon(
          granted ? PhosphorIcons.checkCircle : PhosphorIcons.circle,
          color: granted ? context.colors.success : context.colors.textMuted,
        ),
        const SizedBox(width: RevokeSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.titleSmall),
              Text(
                body,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _reviewStep() => _page(
    icon: PhosphorIcons.checkCircle,
    title: 'Your first Commitment is ready',
    body: _firstCommitment == null
        ? 'Your Commitment was saved locally. Revoke will keep it synchronized with the existing enforcement system.'
        : '${_firstCommitment!.typeLabel} · ${_firstCommitment!.name}\n${_firstCommitment!.summary}',
    action: RevokeButton(
      label: 'Start using Revoke',
      onPressed: _working ? null : _complete,
    ),
  );
}
