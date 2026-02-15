import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';

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
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text("Account & Profile", style: context.text.titleLarge),
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
              child: Text("USER NOT FOUND", style: context.text.titleMedium),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
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
                            style: (context.text.displayLarge ?? AppTheme.size5xlBold).copyWith(
                              color: context.colors.accent,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isGodMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.danger,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'GOD MODE',
                          style: (context.text.labelMedium ?? AppTheme.smBold).copyWith(
                            color: context.scheme.onError,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                // Info Cards
                _buildInfoCard("FULL NAME", userData['fullName'] ?? "Not Set"),
                const SizedBox(height: 16),
                _buildInfoCard("EMAIL", userData['email'] ?? "Not Set"),
                const SizedBox(height: 16),
                _buildNicknameCard(
                  "SQUAD NICKNAME",
                  userData['nickname'] ?? "No Nickname",
                ),

                if (_isGodMode) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/god-mode'),
                      style: AppTheme.primaryButtonStyle,
                      icon: const Icon(Icons.visibility_rounded),
                      label: const Text('Admin Dashboard'),
                    ),
                  ),
                ],

                const SizedBox(height: 60),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleLogout(context),
                    style: AppTheme.secondaryButtonStyle,
                    child: const Text("LOGOUT"),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showDeleteConfirmation(context),
                    style: AppTheme.dangerButtonStyle,
                    child: const Text("DELETE ACCOUNT"),
                  ),
                ),
                const SizedBox(height: 40),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.textPrimary.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: (context.text.labelSmall ?? AppTheme.labelSmall).copyWith(
              letterSpacing: 1.5,
            ),
          ),
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
        borderRadius: BorderRadius.circular(16),
        onTap: _isSavingNickname ? null : () => _showNicknameEditor(value),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colors.textPrimary.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: (context.text.labelSmall ?? AppTheme.labelSmall).copyWith(
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: context.text.titleMedium?.copyWith(
                            color: context.colors.textPrimary,
                          ) ??
                          AppTheme.lgMedium.copyWith(
                            color: context.colors.textPrimary,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_rounded,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EDIT NICKNAME', style: sheetContext.text.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: 24,
                style: sheetContext.text.bodyLarge,
                decoration: AppTheme.defaultInputDecoration(
                  hintText: 'ENTER NEW NICKNAME',
                ),
                onSubmitted: (value) {
                  Navigator.of(sheetContext).pop(value.trim());
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppTheme.primaryButtonStyle,
                  onPressed: () {
                    Navigator.of(sheetContext).pop(controller.text.trim());
                  },
                  child: const Text('SAVE'),
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
      ).showSnackBar(const SnackBar(content: Text('Nickname updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update nickname: $e')));
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
        backgroundColor: context.colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.colors.danger, width: 2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.colors.danger,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  "EXTERMINATE ACCOUNT?",
                  textAlign: TextAlign.center,
                  style: context.text.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  "This action is irreversible. Your focus scores, squad history, and presence will be purged from the archives.",
                  textAlign: TextAlign.center,
                  style: (context.text.bodyMedium ?? AppTheme.bodyMedium).copyWith(
                    color: context.colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: AppTheme.secondaryButtonStyle,
                        child: const Text("CANCEL"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          unawaited(
                            AuthService.deleteAccount().catchError((_) {}),
                          );
                        },
                        style: AppTheme.dangerButtonStyle,
                        child: const Text("PURGE"),
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
