import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _hasUsageStats = false;
  bool _hasOverlay = false;
  StreamSubscription? _permissionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();

    // Check every 2 seconds while on this screen
    _permissionSubscription = Stream.periodic(const Duration(seconds: 2))
        .listen((_) {
          _checkPermissions();
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionSubscription?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text(
                'GRANT GOD MODE',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'REVOKE NEEDS DEEP ACCESS TO GUARD YOUR FOCUS.',
                style: GoogleFonts.jetBrainsMono(
                  color: AppTheme.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              _buildPermissionCard(
                title: 'USAGE ACCESS',
                description: 'REQUIRED TO SEE WHEN YOU OPEN RESTRICTED APPS.',
                isGranted: _hasUsageStats,
                onGrant: () => NativeBridge.requestUsageStats(),
                color: AppTheme.orange,
              ),
              const SizedBox(height: 20),
              _buildPermissionCard(
                title: 'DRAW OVER APPS',
                description: 'REQUIRED TO BLOCK THE SCREEN.',
                isGranted: _hasOverlay,
                onGrant: () => NativeBridge.requestOverlay(),
                color: AppTheme.orange,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: (_hasUsageStats && _hasOverlay)
                      ? () => context.go('/home')
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.white,
                    foregroundColor: AppTheme.black,
                    disabledBackgroundColor: AppTheme.darkGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'CONTINUE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onGrant,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? Colors.greenAccent
              : AppTheme.white.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: AppTheme.lightGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isGranted)
            const CircleAvatar(
              backgroundColor: Colors.greenAccent,
              child: Icon(Icons.check, color: AppTheme.black),
            )
          else
            ElevatedButton(
              onPressed: onGrant,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'GRANT',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
