import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/native_bridge.dart';
import '../../core/widgets/revoke_logo.dart';
import '../../core/widgets/revoke_progress_bar.dart';
import 'package:share_plus/share_plus.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  static const String _squadCodePrefix = 'REV-';
  static const int _squadCodeTotalLength = 7;
  static const int _squadCodeSuffixLength = 3;

  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalSteps =
      7; // Auth, Alias, Perms, Delusion, Reality, Vow, Recruit

  // Form Data
  String? _nickname;
  double _estimatedHours = 2.0;
  double _goalHours = 1.0;
  Map<String, dynamic>? _realityData;
  String? _squadId;
  String? _squadCode;
  bool _isLoading = false;
  bool _isJoiningMode = false;
  final TextEditingController _joinCodeController = TextEditingController();
  bool _isFormattingJoinCode = false;
  bool _didHandleRouteResume = false;
  bool _isSquadCodePressed = false;

  // Permissions Data
  bool _hasUsageStats = false;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _joinCodeController.value = const TextEditingValue(
      text: _squadCodePrefix,
      selection: TextSelection.collapsed(offset: _squadCodePrefix.length),
    );
    _joinCodeController.addListener(_handleJoinCodeChanged);
    _checkPermissions(); // Initial check
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _joinCodeController.removeListener(_handleJoinCodeChanged);
    _joinCodeController.dispose();
    super.dispose();
  }

  void _handleJoinCodeChanged() {
    if (_isFormattingJoinCode) return;
    final formatted = _formatSquadCodeInput(_joinCodeController.text);
    if (formatted == _joinCodeController.text) return;

    _isFormattingJoinCode = true;
    _joinCodeController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormattingJoinCode = false;
  }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final perms = await NativeBridge.checkPermissions();
    if (mounted) {
      setState(() {
        _hasUsageStats = perms['usage_stats'] ?? false;
        _hasOverlay = perms['overlay'] ?? false;
      });
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submitNickname() async {
    final nickname = _nickname?.trim();
    if (nickname == null || nickname.isEmpty) return;

    FocusScope.of(context).unfocus();
    await AuthService.updateNickname(nickname);
    if (!mounted) return;
    _nextPage();
  }

  Future<void> _routePostSignIn() async {
    final userData = await AuthService.getUserData();
    final squadId = (userData?['squadId'] as String?)?.trim();
    final nickname = (userData?['nickname'] as String?)?.trim();
    final hasSquad = squadId != null && squadId.isNotEmpty;
    final hasNickname = nickname != null && nickname.isNotEmpty;

    if (!mounted) return;
    if (hasSquad) {
      context.go('/home');
      return;
    }
    if (hasNickname) {
      await _jumpToShareSquadStep();
      return;
    }
    _nextPage();
  }

  Future<void> _fetchReality() async {
    setState(() => _isLoading = true);
    // Ensure permissions are actually granted before calling this
    if (!_hasUsageStats) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("WE NEED PERMISSIONS TO SEE THE TRUTH.")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await NativeBridge.getRealityCheck();
      setState(() {
        _realityData = data;
        _isLoading = false;
      });
      _nextPage();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to get reality check: $e")),
        );
      }
    }
  }

  Future<void> _handleStepSixEntering() async {
    setState(() => _isLoading = true);
    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) return;

      final userData = await AuthService.getUserData();
      if (userData?['squadId'] == null) {
        // Automatically create a squad if none exists
        await SquadService.createSquad(uid);
        // Re-fetch to get the new code/id
        final updatedData = await AuthService.getUserData();
        setState(() {
          _squadId = updatedData?['squadId'];
          _squadCode = updatedData?['squadCode'];
        });
      } else {
        setState(() {
          _squadId = userData?['squadId'];
          _squadCode = userData?['squadCode'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Squad Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didHandleRouteResume) return;
    _didHandleRouteResume = true;

    final routeState = GoRouterState.of(context);
    final resumeStep = routeState.uri.queryParameters['step'];
    if (resumeStep == 'share_squad') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToShareSquadStep();
      });
    }
  }

  Future<void> _jumpToShareSquadStep() async {
    if (_currentPage == 6) {
      await _handleStepSixEntering();
      return;
    }

    _pageController.jumpToPage(6);
    if (mounted) {
      setState(() => _currentPage = 6);
    }
    await _handleStepSixEntering();
  }

  Future<void> _copySquadCodeToClipboard() async {
    final code = _squadCode;
    if (code == null || code.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Code copied to clipboard.",
            style: AppTheme.baseBold.copyWith(
              color: AppSemanticColors.onAccentText,
              letterSpacing: 0.8,
            ),
          ),
          backgroundColor: AppSemanticColors.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          duration: const Duration(milliseconds: 1200),
        ),
      );
  }

  bool _isSystemUsageEntry(String packageName) {
    final normalized = packageName.toLowerCase();
    return normalized.contains('systemui') ||
        normalized.contains('system ui') ||
        normalized == 'android' ||
        normalized == 'com.android.systemui';
  }

  List<Map<String, dynamic>> _filteredTopApps() {
    final rawTopApps = (_realityData?['topApps'] as List?) ?? const [];
    return rawTopApps
        .whereType<Map>()
        .map((app) => Map<String, dynamic>.from(app))
        .where((app) {
          final packageName = (app['packageName'] ?? '').toString();
          return !_isSystemUsageEntry(packageName);
        })
        .toList();
  }

  double _calculateFilteredActualHours({
    required List<Map<String, dynamic>> topApps,
    required double fallbackHours,
  }) {
    if (topApps.isEmpty) return fallbackHours;
    final hasUsageMs = topApps.any((app) => app['usageMs'] is num);
    if (!hasUsageMs) return fallbackHours;

    final totalUsageMs = topApps.fold<double>(0, (sum, app) {
      final usageMs = (app['usageMs'] as num?)?.toDouble() ?? 0;
      return sum + usageMs;
    });
    final dailyUsageMs = totalUsageMs / 7.0;
    return dailyUsageMs / (1000 * 60 * 60);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: RevokeProgressBar(
                    totalSteps: _totalSteps,
                    currentStep: _currentPage,
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                      if (page == 6) {
                        _handleStepSixEntering();
                      }
                    },
                    children: [
                      _buildStepAuth(),
                      _buildStepAlias(),
                      _buildStepPermissions(),
                      _buildStepDelusion(),
                      _buildStepReality(),
                      _buildStepVow(),
                      _buildStepRecruitment(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: AppSemanticColors.background.withOpacity(0.8),
              child: const Center(
                child: CircularProgressIndicator(color: AppSemanticColors.accent),
              ),
            ),
        ],
      ),
    );
  }

  // --- STEPS ---

  Widget _buildStepAuth() {
    return _buildBaseStep(
      header: "SURRENDER\nYOUR DATA.",
      child: Column(
        children: [
          const Spacer(),
          const RevokeLogo(size: 100),
          const SizedBox(height: 24),
          Text(
            "WE NEED ACCESS TO YOUR SOUL\n(AND YOUR SCREEN TIME DATA 🙃)",
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: AppSemanticColors.mutedText,
            ),
          ),
          const Spacer(),
          _buildPrimaryButton(
            label: "Sign in with Google",
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                final user = await AuthService.signInWithGoogle();
                if (user != null) {
                  await _routePostSignIn();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Sign-in failed. Please check your internet and Google account.",
                        ),
                        backgroundColor: AppSemanticColors.danger,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: AppSemanticColors.danger,
                      duration: const Duration(seconds: 10),
                    ),
                  );
                }
              } finally {
                setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepAlias() {
    return _buildBaseStep(
      header: "PICK A SQUAD\nNICKNAME.",
      subtext:
          "This is the name your Wardens will see when they decide your fate.",
      child: Column(
        children: [
          const Spacer(),
          TextField(
            onChanged: (v) => _nickname = v,
            onSubmitted: (_) => _submitNickname(),
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: AppTheme.h2,
            decoration: AppTheme.nicknameInputDecoration,
          ),
          const Spacer(),
          _buildPrimaryButton(label: "Continue", onPressed: _submitNickname),
        ],
      ),
    );
  }

  Widget _buildStepPermissions() {
    final allGranted = _hasUsageStats && _hasOverlay;

    return _buildBaseStep(
      header: "GRANT\nGOD MODE.",
      subtext:
          "Revoke needs to see what you're doing to roast you properly. Grant these to continue.",
      child: Column(
        children: [
          const Spacer(),
          _buildPermissionTile(
            "Usage Access",
            "Required to see app usage.",
            _hasUsageStats,
            () => NativeBridge.requestUsageStats(),
          ),
          const SizedBox(height: 16),
          _buildPermissionTile(
            "Draw Over Apps",
            "Required to block you.",
            _hasOverlay,
            () => NativeBridge.requestOverlay(),
          ),
          const Spacer(),
          _buildPrimaryButton(
            label: "Continue",
            onPressed: allGranted ? _nextPage : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStepDelusion() {
    return _buildBaseStep(
      header: "THE\nDELUSION.",
      subtext: "How many hours do you THINK you spend on your phone daily?",
      child: Column(
        children: [
          const Spacer(),
          Text(
            "${_estimatedHours.toStringAsFixed(1)} HOURS",
            textAlign: TextAlign.center, // Centered
            style: AppTheme.size5xlBold.copyWith(
              color: AppSemanticColors.accentText,
            ),
          ),
          const SizedBox(height: 32),
          SliderTheme(
            data: AppTheme.vowSliderTheme,
            child: Slider(
              value: _estimatedHours,
              min: 0,
              max: 24,
              divisions: 48,
              onChanged: (v) => setState(() => _estimatedHours = v),
            ),
          ),
          const Spacer(),
          _buildPrimaryButton(
            label: "VERIFY THE TRUTH",
            onPressed: _fetchReality,
          ),
        ],
      ),
    );
  }

  Widget _buildStepReality() {
    if (_realityData == null) return const SizedBox();

    final fallbackHours = (_realityData!['totalAvgDailyHours'] as num)
        .toDouble();
    final filteredTopApps = _filteredTopApps();
    final actualHours = _calculateFilteredActualHours(
      topApps: filteredTopApps,
      fallbackHours: fallbackHours,
    );
    final delta = actualHours - _estimatedHours;
    final isCooked = delta > 0;

    return _buildBaseStep(
      header: "REALITY\nCHECK.",
      child: Column(
        children: [
          const Spacer(),
          Text(
            "${actualHours.toStringAsFixed(1)} HOURS DAILY",
            textAlign: TextAlign.center,
            style: AppTheme.size5xlMedium.copyWith(
              color: AppSemanticColors.accentText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isCooked
                ? "YOU'RE COOKED.\nThat's ${delta.toStringAsFixed(1)} hours more than you thought."
                : "Surprisingly disciplined.\nFor now.",
            textAlign: TextAlign.center,
            style: AppTheme.bodyLarge.copyWith(
              color: isCooked
                  ? AppSemanticColors.errorText
                  : AppSemanticColors.success,
            ),
          ),
          const Spacer(),
          _buildSectionHeader("TOP TIME-WASTERS"),
          const SizedBox(height: 16),
          ...filteredTopApps.take(3).map((app) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppSemanticColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.apps_rounded,
                    color: AppSemanticColors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      (app['packageName'] as String)
                          .split('.')
                          .last
                          .toUpperCase(),
                      style: AppTheme.baseBold.copyWith(
                        color: AppSemanticColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Spacer(),
          _buildPrimaryButton(
            label: "I ACCEPT THE TRUTH",
            onPressed: _nextPage,
          ),
        ],
      ),
    );
  }

  Widget _buildStepVow() {
    return _buildBaseStep(
      header: "THE VOW.",
      subtext: "How much of your life do you want to reclaim?",
      child: Column(
        children: [
          const Spacer(),
          Text(
            "${_goalHours.toStringAsFixed(1)} HOURS",
            textAlign: TextAlign.center,
            style: AppTheme.size5xlBold.copyWith(
              color: AppSemanticColors.accentText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "DAILY LIMIT",
            style: AppTheme.labelSmall.copyWith(
              color: AppSemanticColors.mutedText,
            ),
          ),
          const SizedBox(height: 32),
          SliderTheme(
            data: AppTheme.vowSliderTheme,
            child: Slider(
              value: _goalHours,
              min: 0.5,
              max: 12,
              divisions: 23,
              onChanged: (v) => setState(() => _goalHours = v),
            ),
          ),
          const Spacer(),
          _buildPrimaryButton(
            label: "LOCK IT IN",
            onPressed: () {
              // Save goal logic here if needed
              _nextPage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepRecruitment() {
    return _buildBaseStep(
      header: _isJoiningMode ? "JOIN A\nSQUAD." : "APPOINT A\nWARDEN.",
      subtext: _isJoiningMode
          ? "Enter the code provided by your Squad Leader."
          : "Revoke is a social contract. You must invite someone to watch you or join a squad.",
      child: Column(
        children: [
          const Spacer(),
          if (!_isJoiningMode) ...[
            AnimatedScale(
              scale: _isSquadCodePressed ? 0.98 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _squadCode == null ? null : _copySquadCodeToClipboard,
                  onHighlightChanged: (isPressed) {
                    if (!mounted) return;
                    setState(() => _isSquadCodePressed = isPressed);
                  },
                  child: Ink(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppSemanticColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppSemanticColors.accent.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "YOUR SQUAD CODE",
                          style: AppTheme.smMedium.copyWith(
                            color: AppSemanticColors.mutedText,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              _squadCode ?? "--- ---",
                              textWidthBasis: TextWidthBasis.parent,
                              style: AppTheme.squadCodeInput,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "TAP ANYWHERE TO COPY",
                          style: AppTheme.xsMedium.copyWith(
                            color: AppSemanticColors.secondaryText.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSecondaryIconButton(
              onPressed: _squadCode == null
                  ? null
                  : () {
                      Share.share(
                        "Join my Revoke Squad and watch my screen time: $_squadCode",
                      );
                    },
              icon: Icons.share_rounded,
              label: "Share Invite Code",
            ),
            const SizedBox(height: 16),
            _buildSecondaryButton(
              onPressed: () => setState(() => _isJoiningMode = true),
              label: "I Have a Code",
            ),
          ] else ...[
            TextField(
              controller: _joinCodeController,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                LengthLimitingTextInputFormatter(_squadCodeTotalLength),
              ],
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: AppTheme.squadCodeInput,
              decoration: AppTheme.defaultInputDecoration(hintText: "REV-XXX"),
            ),
            const SizedBox(height: 32),
            _buildPrimaryButton(
              label: "JOIN SQUAD",
              onPressed: () async {
                final code = _joinCodeController.text;
                if (code.length != _squadCodeTotalLength) return;

                setState(() => _isLoading = true);
                try {
                  final uid = AuthService.currentUser?.uid;
                  if (uid != null) {
                    await SquadService.joinSquad(uid, code);
                    final userData = await AuthService.getUserData();
                    setState(() {
                      _squadId = userData?['squadId'];
                      _squadCode = userData?['squadCode'];
                    });
                    if (mounted) context.go('/home');
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
            ),
            const SizedBox(height: 16),
            _buildSecondaryButton(
              onPressed: () => setState(() => _isJoiningMode = false),
              label: "BACK TO INVITE",
            ),
          ],
          const Spacer(),
          if (!_isJoiningMode)
            _buildPrimaryButton(
              label: "ENTER THE GAUNTLET",
              onPressed: _squadId != null ? () => context.go('/home') : null,
            ),
        ],
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildBaseStep({
    required String header,
    String? subtext,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            header,
            textAlign: TextAlign.center,
            style: AppTheme.size4xlBold.copyWith(
              color: AppSemanticColors.primaryText,
              height: 1.1,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 16),
            Text(
              subtext,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppSemanticColors.mutedText,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    String desc,
    bool isGranted,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppSemanticColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? AppSemanticColors.success
              : AppSemanticColors.primaryText.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        onTap: isGranted ? null : onTap,
        title: Text(title, style: AppTheme.h3),
        subtitle: Text(desc, style: AppTheme.bodySmall),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: AppSemanticColors.success)
            : ElevatedButton(
                onPressed: onTap,
                style: AppTheme.secondaryButtonStyle.copyWith(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  backgroundColor: const WidgetStatePropertyAll(AppSemanticColors.background),
                ),
                child: const Text("GRANT"),
              ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: AppTheme.primaryButtonStyle,
        child: Text(label),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback? onPressed,
    required String label,
    bool fullWidth = false,
  }) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: AppTheme.secondaryButtonStyle,
      child: Text(label),
    );
    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildSecondaryIconButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    bool fullWidth = false,
  }) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      style: AppTheme.secondaryButtonStyle,
      icon: Icon(icon),
      label: Text(label),
    );
    if (!fullWidth) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.baseBold.copyWith(
        color: AppSemanticColors.accentText.withValues(alpha: 0.7),
      ),
    );
  }
}
