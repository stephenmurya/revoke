import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/utils/app_categorizer.dart';
import '../../core/utils/theme_extensions.dart';
import 'dart:typed_data';

class AppListScreen extends StatefulWidget {
  final Set<String> initialSelection;
  const AppListScreen({super.key, required this.initialSelection});

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen> {
  late Set<String> _selectedPackages;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<AppInfo> _allApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set.from(widget.initialSelection);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _loadApps();
  }

  Future<void> _loadApps({bool forceRefresh = false}) async {
    if (forceRefresh) {
      setState(() => _isLoading = true);
    }

    final apps = await AppDiscoveryService.getApps(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _allApps = apps;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select apps', style: AppTheme.h3),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedPackages),
            child: Text(
              'DONE',
              style: AppTheme.baseMedium.copyWith(
                color: context.scheme.primary,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: context.scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Scanning apps...',
                    style: AppTheme.baseMedium.copyWith(
                      color: context.scheme.primary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: AppTheme.defaultInputDecoration(
                      hintText: 'Search for apps...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: context.scheme.primary,
                      ),
                    ),
                  ),
                ),
                // Selected apps chips (under search bar)
                if (_selectedPackages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedPackages.length,
                      itemBuilder: (context, index) {
                        final pkg = _selectedPackages.elementAt(index);
                        final app = _allApps.firstWhere(
                          (a) => a.packageName == pkg,
                          orElse: () => AppInfo(
                            name: pkg,
                            packageName: pkg,
                            category: AppCategory.others,
                          ),
                        );
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: AppTheme.chipDecoration(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (app.icon != null)
                                Image.memory(
                                  Uint8List.fromList(app.icon!),
                                  width: 24,
                                  height: 24,
                                )
                              else
                                Icon(
                                  Icons.android,
                                  size: 24,
                                  color: context.colors.textSecondary,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                app.name,
                                style: AppTheme.smBold.copyWith(
                                  color: context.scheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPackages.remove(pkg);
                                  });
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                // App list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadApps(forceRefresh: true),
                    color: context.scheme.primary,
                    backgroundColor: context.scheme.surface,
                    child: _buildAppList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAppList() {
    final categorized = _categorizeApps(_allApps);
    final sortedCategories = categorized.keys.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sortedCategories.length,
      itemBuilder: (context, index) {
        final category = sortedCategories[index];
        final apps = categorized[category]!;
        return ExpansionTile(
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleCategorySelection(apps),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    category.label,
                    style: AppTheme.baseMedium.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  _allAppsSelectedInCategory(apps)
                      ? 'Deselect all'
                      : 'Select all',
                  style: AppTheme.smMedium.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          children: apps
              .map(
                (app) => CheckboxListTile(
                  value: _selectedPackages.contains(app.packageName),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      if (v) {
                        _selectedPackages.add(app.packageName);
                      } else {
                        _selectedPackages.remove(app.packageName);
                      }
                    });
                  },
                  title: Text(app.name, style: AppTheme.bodyMedium),
                  secondary: app.icon != null
                      ? Image.memory(
                          Uint8List.fromList(app.icon!),
                          width: 32,
                          height: 32,
                        )
                      : Icon(Icons.android, color: context.colors.textSecondary),
                  activeColor: context.scheme.primary,
                  checkColor: context.scheme.onPrimary,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Map<AppCategory, List<AppInfo>> _categorizeApps(List<AppInfo> apps) {
    final Map<AppCategory, List<AppInfo>> categorized = {};
    for (var app in apps) {
      if (_searchQuery.isNotEmpty &&
          !app.name.toLowerCase().contains(_searchQuery)) {
        continue;
      }
      categorized.putIfAbsent(app.category, () => []).add(app);
    }
    return categorized;
  }

  bool _allAppsSelectedInCategory(List<AppInfo> apps) {
    if (apps.isEmpty) return false;
    return apps.every((app) => _selectedPackages.contains(app.packageName));
  }

  void _toggleCategorySelection(List<AppInfo> apps) {
    if (apps.isEmpty) return;
    final shouldSelectAll = !_allAppsSelectedInCategory(apps);
    setState(() {
      for (final app in apps) {
        if (shouldSelectAll) {
          _selectedPackages.add(app.packageName);
        } else {
          _selectedPackages.remove(app.packageName);
        }
      }
    });
  }
}
