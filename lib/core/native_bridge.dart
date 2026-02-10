import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.revoke.app/overlay');
  static Function()? onShowOverlay;

  static void setupOverlayListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'showOverlay') {
        onShowOverlay?.call();
      }
    });
  }

  /// Checks the status of required permissions.
  static Future<Map<String, bool>> checkPermissions() async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'checkPermissions',
    );
    return Map<String, bool>.from(result);
  }

  /// Opens the system settings for usage stats access.
  static Future<void> requestUsageStats() async {
    await _channel.invokeMethod('requestUsageStats');
  }

  /// Opens the system settings for overlay permission.
  static Future<void> requestOverlay() async {
    await _channel.invokeMethod('requestOverlay');
  }

  /// Fetches a list of installed apps.
  static Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final List<dynamic> result = await _channel.invokeMethod(
      'getInstalledApps',
    );
    return result.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Fetches details for a single app by package name.
  static Future<Map<String, dynamic>> getAppDetails(String packageName) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'getAppDetails',
      {'packageName': packageName},
    );
    return Map<String, dynamic>.from(result);
  }

  /// Starts the app monitor foreground service.
  static Future<void> startService() async {
    await _channel.invokeMethod('startService');
  }

  /// Syncs schedules with the native Android service.
  static Future<void> syncSchedules(String jsonSchedules) async {
    await _channel.invokeMethod('syncSchedules', {'schedules': jsonSchedules});
  }
}
