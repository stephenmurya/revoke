import '../native_bridge.dart';
import '../utils/app_categorizer.dart';
import 'persistence_service.dart';

class AppInfo {
  final String name;
  final String packageName;
  final List<int>? icon;
  final AppCategory category;
  bool isRestricted;

  AppInfo({
    required this.name,
    required this.packageName,
    required this.category,
    this.icon,
    this.isRestricted = false,
  });
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

      final list = nativeApps.map((app) {
        final packageName = app['packageName'] as String;
        final nativeCategory = app['category'] as int? ?? -1;

        final info = AppInfo(
          name: app['name'] as String,
          packageName: packageName,
          category: AppCategorizer.categorize(packageName, nativeCategory),
          icon: app['icon'] != null ? List<int>.from(app['icon']) : null,
          isRestricted: restrictedApps[packageName] ?? false,
        );
        _appCache[info.packageName] = info;
        return info;
      }).toList();

      return list;
    } catch (e) {
      print('Error getting apps: $e');
      return _cachedApps ?? [];
    }
  }

  static Future<AppInfo> getAppDetails(String packageName) async {
    // Check cache first
    if (_appCache.containsKey(packageName)) {
      return _appCache[packageName]!;
    }

    try {
      final result = await NativeBridge.getAppDetails(packageName);
      final restrictedApps =
          await PersistenceService.getRestrictedApps(); // Fetch restricted apps here

      final info = AppInfo(
        name: result['name'] as String,
        packageName: packageName,
        category: AppCategory
            .others, // Single app fetch doesn't need category from native, default to others
        icon: result['icon'] != null ? List<int>.from(result['icon']) : null,
        isRestricted:
            restrictedApps[packageName] ?? false, // Apply restriction status
      );

      // Cache the result
      _appCache[packageName] = info;
      return info;
    } catch (e) {
      print('Error getting app details for $packageName: $e');
      // Return a fallback AppInfo
      final fallback = AppInfo(
        name: packageName,
        packageName: packageName,
        category: AppCategory.others,
        icon: null,
        isRestricted: false, // Default to not restricted for fallback
      );
      _appCache[packageName] = fallback;
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
