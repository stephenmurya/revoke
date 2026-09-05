import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/premium_entitlement_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>?> _userDataFuture;
  bool _isSavingNickname = false;
  bool _isGodMode = false;

  @override
  void initState() {
    super.initState();
    _userDataFuture = AuthService.getUserData();
    _initializeStealthGodMode();
  }

  void _refreshUserData() {
    setState(() {
      _userDataFuture = AuthService.getUserData();
    });
  }

  Future<void> _loadAdminClaim({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final tokenResult = await user.getIdTokenResult(forceRefresh);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      final isAdmin = claims['admin'] == true;
      if (!mounted) return;
      setState(() => _isGodMode = isAdmin);
    } catch (_) {
      // Non-fatal: profile UI should remain usable without claim visibility.
    }
  }

  Future<void> _initializeStealthGodMode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final email = user.email?.trim().toLowerCase() ?? '';
    if (email != 'stephenmurya@gmail.com') {
      if (!mounted) return;
      setState(() => _isGodMode = false);
      return;
    }

    try {
      await user.getIdToken(true);
    } catch (_) {}

    await _loadAdminClaim(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: RevokeElevation.none,
        leading: IconButton(
          icon: Icon(
            PhosphorIcons.arrowLeft,
            color: context.colors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text('Profile', style: context.text.pageTitle),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: context.colors.accent),
            );
          }

          final userData = snapshot.data;
          if (userData == null) {
            return Center(
              child: Text(
                'Profile unavailable',
                style: context.text.sectionTitle,
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: RevokeSpacing.lg),
                // Avatar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: AppTheme.avatarBorderStyle,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: context.colors.surface,
                    backgroundImage: userData['photoUrl'] != null
                        ? CachedNetworkImageProvider(userData['photoUrl'])
                        : null,
                    child: userData['photoUrl'] == null
                        ? Text(
                            (userData['fullName'] ?? "?")[0].toUpperCase(),
                            style:
                                (context.text.displayLarge ??
                                        AppTheme.size5xlBold)
                                    .copyWith(color: context.colors.accent),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: RevokeSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isGodMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RevokeSpacing.md,
                          vertical: RevokeSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.danger,
                          borderRadius: RevokeRadii.pillRadius,
                        ),
                        child: Text(
                          'GOD MODE',
                          style: (context.text.labelMedium ?? AppTheme.smBold)
                              .copyWith(
                                color: context.scheme.onError,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: RevokeSpacing.xxl),

                // Info Cards
                _buildInfoCard('Full name', userData['fullName'] ?? 'Not set'),
                const SizedBox(height: RevokeSpacing.lg),
                _buildInfoCard('Email', userData['email'] ?? 'Not set'),
                const SizedBox(height: RevokeSpacing.lg),
                _buildNicknameCard(
                  'Circle name',
                  userData['nickname'] ?? 'No name set',
                ),
                const SizedBox(height: RevokeSpacing.lg),
                ValueListenableBuilder(
                  valueListenable: PremiumEntitlementService.instance.state,
                  builder: (context, entitlementState, _) {
                    final active = entitlementState.isPremium;
                    final until = entitlementState.entitlement.premiumUntil;
                    final detail = active && until != null
                        ? 'Active until ${until.day}/${until.month}/${until.year}'
                        : 'Explore prepaid Premium access';
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: RevokeRadii.cardRadius,
                        onTap: () => context.push('/premium'),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(RevokeSpacing.lg),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: RevokeRadii.cardRadius,
                            border: Border.all(
                              color: context.colors.borderSubtle,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.sparkle,
                                color: context.colors.accent,
                                size: RevokeIconSizes.emphasis,
                              ),
                              const SizedBox(width: RevokeSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Premium', style: context.text.label),
                                    const SizedBox(height: RevokeSpacing.xs),
                                    Text(
                                      detail,
                                      style: context.text.bodySecondary,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                PhosphorIcons.caretRight,
                                color: context.colors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                if (_isGodMode) ...[
                  const SizedBox(height: RevokeSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/god-mode'),
                      style: AppTheme.primaryButtonStyle,
                      icon: Icon(PhosphorIcons.eye),
                      label: const Text('Admin Dashboard'),
                    ),
                  ),
                ],

                const SizedBox(height: RevokeSpacing.xxl),

                // Actions
                RevokeButton(
                  label: 'Log out',
                  onPressed: () => _handleLogout(context),
                  variant: RevokeButtonVariant.secondary,
                ),
                const SizedBox(height: RevokeSpacing.sm),
                RevokeButton(
                  label: 'Delete account',
                  onPressed: () => _showDeleteConfirmation(context),
                  variant: RevokeButtonVariant.destructive,
                ),
                const SizedBox(height: RevokeSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RevokeSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: RevokeRadii.cardRadius,
        border: Border.all(color: context.colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.label),
          const SizedBox(height: 8),
          Text(value, style: context.text.titleMedium),
        ],
      ),
    );
  }

  Widget _buildNicknameCard(String label, String value) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: RevokeRadii.cardRadius,
        onTap: _isSavingNickname ? null : () => _showNicknameEditor(value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(RevokeSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: RevokeRadii.cardRadius,
            border: Border.all(color: context.colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.text.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style:
                          context.text.titleMedium?.copyWith(
                            color: context.colors.textPrimary,
                          ) ??
                          AppTheme.lgMedium.copyWith(
                            color: context.colors.textPrimary,
                          ),
                    ),
                  ),
                  const SizedBox(width: RevokeSpacing.sm),
                  Icon(
                    PhosphorIcons.pencilSimple,
                    color: context.colors.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNicknameEditor(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);
    final newNickname = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RevokeRadii.large),
        ),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            RevokeSpacing.lg,
            RevokeSpacing.lg,
            RevokeSpacing.lg,
            bottomInset + RevokeSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Edit Circle name', style: sheetContext.text.sectionTitle),
              const SizedBox(height: RevokeSpacing.lg),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: 24,
                style: sheetContext.text.bodyLarge,
                decoration: AppTheme.defaultInputDecoration(
                  hintText: 'Enter a name',
                ),
                onSubmitted: (value) {
                  Navigator.of(sheetContext).pop(value.trim());
                },
              ),
              const SizedBox(height: RevokeSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop(controller.text.trim());
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (newNickname == null || newNickname.isEmpty) return;
    if (!mounted) return;

    setState(() => _isSavingNickname = true);
    try {
      await AuthService.updateNickname(newNickname);
      _refreshUserData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Circle name updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update Circle name')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingNickname = false);
      }
    }
  }

  void _handleLogout(BuildContext context) {
    unawaited(AuthService.signOut().catchError((_) {}));
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: RevokeRadii.largeRadius,
          side: BorderSide(color: context.colors.destructive),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(RevokeSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIcons.warning,
                  color: context.colors.destructive,
                  size: RevokeIconSizes.feature,
                ),
                const SizedBox(height: 20),
                Text(
                  'Delete account?',
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'This permanently removes your Revoke account and its stored data.',
                  textAlign: TextAlign.center,
                  style: (context.text.bodyMedium ?? AppTheme.bodyMedium)
                      .copyWith(
                        color: context.colors.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: RevokeSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: AppTheme.secondaryButtonStyle,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: RevokeSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          unawaited(
                            AuthService.deleteAccount().catchError((_) {}),
                          );
                        },
                        style: AppTheme.dangerButtonStyle,
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
