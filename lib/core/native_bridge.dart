import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.revoke.app/overlay');
  static Function()? onOpenSquadSetup;
  static Function(String appName, String packageName)? onRequestPlea;
  static Function(String appName, String packageName, int blockedAtMs)?
  onBlockedAttempt;

  static void setupOverlayListener() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openSquadSetup') {
        onOpenSquadSetup?.call();
      } else if (call.method == 'requestPlea') {
        final appName = call.arguments?['appName'] as String? ?? "Unknown App";
        final packageName = call.arguments?['packageName'] as String? ?? "";
        onRequestPlea?.call(appName, packageName);
      } else if (call.method == 'blockedAttempt') {
        final appName = call.arguments?['appName'] as String? ?? "Unknown App";
        final packageName = call.arguments?['packageName'] as String? ?? "";
        final rawBlockedAt = call.arguments?['blockedAtMs'];
        final blockedAtMs = rawBlockedAt is int
            ? rawBlockedAt
            : int.tryParse(rawBlockedAt?.toString() ?? "") ??
                  DateTime.now().millisecondsSinceEpoch;
        onBlockedAttempt?.call(appName, packageName, blockedAtMs);
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

  /// Requests an exemption from battery optimizations (best effort).
  static Future<void> requestBatteryOptimizations() async {
    await _channel.invokeMethod('requestBatteryOptimizations');
  }

  /// Opens the system settings for exact alarm access on Android 12+.
  static Future<void> requestExactAlarms() async {
    await _channel.invokeMethod('requestExactAlarms');
  }

  /// Opens Android accessibility settings for the fast-path enforcement service.
  static Future<void> requestAccessibilityPermission() async {
    await openAccessibilitySettings();
  }

  /// Opens Android accessibility settings.
  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
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

  /// Asks Android to verify the monitor service state and revive it if needed.
  static Future<Map<String, dynamic>> checkAndReviveService() async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'checkAndReviveService',
    );
    return Map<String, dynamic>.from(result);
  }

  static Future<void> syncUserOverlayContext({required bool hasSquad}) async {
    await _channel.invokeMethod('syncUserOverlayContext', {
      'hasSquad': hasSquad,
    });
  }

  /// Returns whether the Accessibility fast path is currently enabled.
  static Future<bool> checkAccessibilityPermission() async {
    final result = await _channel.invokeMethod('checkAccessibilityPermission');
    return result == true;
  }

  /// Syncs schedule state with Android so native can decide whether to run.
  static Future<void> syncSchedules(
    String jsonSchedules, {
    int nextWakeupMs = 0,
  }) async {
    await _channel.invokeMethod('syncSchedules', {
      'schedules': jsonSchedules,
      'nextWakeupMs': nextWakeupMs,
    });
  }

  /// Returns exact usage per package since the provided activation timestamp.
  static Future<Map<String, int>> getSessionUsage(
    List<String> packageNames,
    int activationTimestamp,
  ) async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'getSessionUsage',
      {
        'packageNames': packageNames,
        'activationTimestamp': activationTimestamp,
      },
    );
    return result.map(
      (key, value) => MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
    );
  }

  /// Schedules the next exact Android wakeup for regime enforcement.
  static Future<void> scheduleNextWakeup(int timestampMs) async {
    await _channel.invokeMethod('scheduleNextWakeup', {
      'timestampMs': timestampMs,
    });
  }

  /// Fetches usage stats for the last 7 days.
  static Future<Map<String, dynamic>> getRealityCheck() async {
    final Map<dynamic, dynamic> result = await _channel.invokeMethod(
      'getRealityCheck',
    );
    return Map<String, dynamic>.from(result);
  }

  /// Returns 24 hourly usage intensity values (avg minutes/hour over 7 days).
  static Future<List<int>> getHourlyUsagePattern() async {
    final List<dynamic> result = await _channel.invokeMethod(
      'getHourlyUsagePattern',
    );
    return result
        .map((value) => (value as num?)?.toInt() ?? 0)
        .toList(growable: false);
  }

  /// Temporarily unlocks an app for a specific duration.
  static Future<void> temporaryUnlock(String packageName, int minutes) async {
    await _channel.invokeMethod('temporaryUnlock', {
      'packageName': packageName,
      'minutes': minutes,
    });
  }

  /// Returns package names currently under temporary tribunal approval.
  static Future<List<String>> getTemporaryApprovedPackages() async {
    final List<dynamic> result = await _channel.invokeMethod(
      'getTemporaryApprovals',
    );
    return result.map((e) => e.toString()).toList();
  }

  /// Pauses native monitoring/enforcement for a duration in minutes.
  static Future<void> pauseMonitoring(int minutes) async {
    await _channel.invokeMethod('pauseMonitoring', {'minutes': minutes});
  }
}
