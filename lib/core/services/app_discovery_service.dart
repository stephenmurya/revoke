import '../native_bridge.dart';
import '../utils/app_categorizer.dart';
import 'persistence_service.dart';

class AppInfo {
  static const String ghostAppName = 'Uninstalled App';

  final String name;
  final String packageName;
  final List<int>? icon;
  final AppCategory category;
  final bool isSystemApp;
  final bool isGhost;
  bool isRestricted;

  AppInfo({
    required this.name,
    required this.packageName,
    required this.category,
    this.isSystemApp = false,
    this.isGhost = false,
    this.icon,
    this.isRestricted = false,
  });

  factory AppInfo.ghost({
    required String packageName,
    required bool isRestricted,
  }) {
    return AppInfo(
      name: ghostAppName,
      packageName: packageName,
      category: AppCategory.others,
      icon: null,
      isSystemApp: false,
      isGhost: true,
      isRestricted: isRestricted,
    );
  }
}

class AppDiscoveryService {
  // Cache for individual app details
  static final Map<String, AppInfo> _appCache = {};

  // Cache for the full app list
  static List<AppInfo>? _cachedApps;
  static Future<List<AppInfo>>? _fetchFuture;

  /// Starts fetching apps in the background if not already cached.
  static void prefetch() {
    if (_cachedApps == null && _fetchFuture == null) {
      getApps();
    }
  }

  static Future<List<AppInfo>> getApps({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedApps != null) {
      return _cachedApps!;
    }

    if (_fetchFuture != null && !forceRefresh) {
      return _fetchFuture!;
    }

    _fetchFuture = _performFetch();

    try {
      final apps = await _fetchFuture!;
      _cachedApps = apps;
      return apps;
    } finally {
      _fetchFuture = null;
    }
  }

  static Future<List<AppInfo>> _performFetch() async {
    try {
      final nativeApps = await NativeBridge.getInstalledApps();
      final restrictedApps = await PersistenceService.getRestrictedApps();

      final list = <AppInfo>[];
      for (final app in nativeApps) {
        final packageName = (app['packageName'] as String?)?.trim() ?? '';
        if (packageName.isEmpty) continue;

        final nativeCategory = app['category'] as int? ?? -1;
        final info = AppInfo(
          name: (app['name'] as String?)?.trim().isNotEmpty == true
              ? (app['name'] as String).trim()
              : packageName,
          packageName: packageName,
          category: AppCategorizer.categorize(packageName, nativeCategory),
          icon: app['icon'] != null ? List<int>.from(app['icon']) : null,
          isSystemApp: app['isSystemApp'] == true,
          isGhost: false,
          isRestricted: restrictedApps[packageName] ?? false,
        );
        _appCache[info.packageName] = info;
        list.add(info);
      }

      return list;
    } catch (_) {
      return _cachedApps ?? [];
    }
  }

  static Future<AppInfo> getAppDetails(String packageName) async {
    final normalizedPackage = packageName.trim();
    if (normalizedPackage.isEmpty) {
      return AppInfo.ghost(packageName: packageName, isRestricted: false);
    }

    // Check cache first
    if (_appCache.containsKey(normalizedPackage)) {
      return _appCache[normalizedPackage]!;
    }

    final restrictedApps = await PersistenceService.getRestrictedApps();
    final isRestricted = restrictedApps[normalizedPackage] ?? false;

    try {
      final result = await NativeBridge.getAppDetails(normalizedPackage);
      final rawName = (result['name'] as String?)?.trim();
      final looksGhost = rawName == null ||
          rawName.isEmpty ||
          rawName == AppInfo.ghostAppName;

      if (looksGhost) {
        final ghost = AppInfo.ghost(
          packageName: normalizedPackage,
          isRestricted: isRestricted,
        );
        _appCache[normalizedPackage] = ghost;
        return ghost;
      }

      final info = AppInfo(
        name: rawName,
        packageName: normalizedPackage,
        category: AppCategory
            .others, // Single app fetch doesn't need category from native, default to others
        icon: result['icon'] != null ? List<int>.from(result['icon']) : null,
        isSystemApp: result['isSystemApp'] == true,
        isGhost: false,
        isRestricted: isRestricted, // Apply restriction status
      );

      // Cache the result
      _appCache[normalizedPackage] = info;
      return info;
    } catch (_) {
      // Preserve restrictions and package identity even if app is uninstalled.
      final fallback = AppInfo.ghost(
        packageName: normalizedPackage,
        isRestricted: isRestricted,
      );
      _appCache[normalizedPackage] = fallback;
      return fallback;
    }
  }

  static Future<void> toggleRestriction(AppInfo app) async {
    app.isRestricted = !app.isRestricted;
    final restrictedApps = await PersistenceService.getRestrictedApps();
    restrictedApps[app.packageName] = app.isRestricted;
    await PersistenceService.saveRestrictedApps(restrictedApps);
  }
}
