import 'package:flutter/material.dart';
import '../../core/native_bridge.dart';
import '../../core/theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _usageStatsGranted = false;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final permissions = await NativeBridge.checkPermissions();
      if (mounted) {
        setState(() {
          _usageStatsGranted = permissions['usage_stats'] ?? false;
          _overlayGranted = permissions['overlay'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Required Permissions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildPermissionTile(
              'Usage Stats',
              'Required to monitor app usage time.',
              _usageStatsGranted,
              NativeBridge.requestUsageStats,
            ),
            const SizedBox(height: 16),
            _buildPermissionTile(
              'Overlay',
              'Required to show alerts over other apps.',
              _overlayGranted,
              NativeBridge.requestOverlay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    String description,
    bool isGranted,
    VoidCallback onPressed,
  ) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(description),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: AppSemanticColors.success)
            : ElevatedButton(onPressed: onPressed, child: const Text('Grant')),
      ),
    );
  }
}
