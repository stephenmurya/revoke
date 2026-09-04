import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/native_bridge.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/persistence_service.dart';
import '../../core/services/settings_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/theme_extensions.dart';
import '../monitor/widgets/single_app_icon.dart';

class WhitelistAppsScreen extends StatefulWidget {
  const WhitelistAppsScreen({super.key});

  @override
  State<WhitelistAppsScreen> createState() => _WhitelistAppsScreenState();
}

class _WhitelistAppsScreenState extends State<WhitelistAppsScreen> {
  late Future<List<AppInfo>> _appsFuture;
  Set<String> _selectedPackages = const <String>{};
  String _query = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _appsFuture = AppDiscoveryService.getApps();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final selected = await PersistenceService.getWhitelistedApps();
    if (!mounted) return;
    setState(() {
      _selectedPackages = selected;
      _loading = false;
    });
    unawaited(NativeBridge.syncWhitelistApps(selected).catchError((_) {}));
    unawaited(_refreshSelectionFromCloud());
  }

  Future<void> _refreshSelectionFromCloud() async {
    try {
      await SettingsSyncService.hydrateLocalPreferencesFromCloud();
      final selected = await PersistenceService.getWhitelistedApps();
      if (!mounted) return;
      setState(() => _selectedPackages = selected);
    } catch (_) {}
  }

  Future<void> _togglePackage(String packageName, bool enabled) async {
    final normalized = packageName.trim();
    if (normalized.isEmpty || _saving) return;

    final next = Set<String>.from(_selectedPackages);
    if (enabled) {
      next.add(normalized);
    } else {
      next.remove(normalized);
    }

    setState(() {
      _selectedPackages = next;
      _saving = true;
    });

    try {
      await PersistenceService.saveWhitelistedApps(next);
      await NativeBridge.syncWhitelistApps(next);
      unawaited(
        SettingsSyncService.syncWhitelistedAppsToCloud(next).catchError((_) {}),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update ignored apps.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<AppInfo> _filterApps(List<AppInfo> apps) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? apps
        : apps
              .where((app) {
                return app.name.toLowerCase().contains(query) ||
                    app.packageName.toLowerCase().contains(query);
              })
              .toList(growable: false);
    final sorted = filtered.toList(growable: false)
      ..sort((a, b) {
        final selectedA = _selectedPackages.contains(a.packageName);
        final selectedB = _selectedPackages.contains(b.packageName);
        if (selectedA != selectedB) return selectedA ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whitelist Apps'),
        actions: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.scheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<AppInfo>>(
          future: _appsFuture,
          builder: (context, snapshot) {
            final apps = snapshot.data;
            if (_loading || apps == null) {
              return Center(
                child: CircularProgressIndicator(color: context.scheme.primary),
              );
            }

            final filtered = _filterApps(apps);
            return ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              children: [
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: AppTheme.defaultInputDecoration(
                    hintText: 'Search apps',
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colors.warning.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Text(
                    'Selected apps are ignored for screen time, reminders, and blocking.',
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final app in filtered)
                  _WhitelistAppRow(
                    app: app,
                    selected: _selectedPackages.contains(app.packageName),
                    onChanged: (value) =>
                        _togglePackage(app.packageName, value),
                  ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Text(
                      'No apps found.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WhitelistAppRow extends StatelessWidget {
  final AppInfo app;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _WhitelistAppRow({
    required this.app,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      value: selected,
      onChanged: onChanged,
      secondary: SingleAppIcon(packageName: app.packageName, size: 34),
      title: Text(
        app.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.baseMedium,
      ),
      subtitle: Text(
        app.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.xsMedium.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}
