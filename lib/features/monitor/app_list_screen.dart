import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/utils/app_categorizer.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';

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
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: Text(
          'SELECT APPS',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedPackages),
            child: Text(
              'DONE',
              style: GoogleFonts.spaceGrotesk(
                color: AppTheme.orange,
                fontWeight: FontWeight.bold,
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
                  const CircularProgressIndicator(color: AppTheme.orange),
                  const SizedBox(height: 16),
                  Text(
                    'SCANNING APPS...',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
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
                    decoration: const InputDecoration(
                      hintText: 'SEARCH APPS...',
                      prefixIcon: Icon(Icons.search, color: AppTheme.orange),
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
                                  width: 20,
                                  height: 20,
                                )
                              else
                                const Icon(
                                  Icons.android,
                                  size: 20,
                                  color: AppTheme.white,
                                ),
                              const SizedBox(width: 8),
                              Text(
                                app.name,
                                style: GoogleFonts.jetBrainsMono(
                                  color: AppTheme.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPackages.remove(pkg);
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppTheme.white,
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
                    color: AppTheme.orange,
                    backgroundColor: AppTheme.darkGrey,
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
          title: Text(
            category.label,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              color: AppTheme.orange,
            ),
          ),
          children: apps
              .map(
                (app) => CheckboxListTile(
                  value: _selectedPackages.contains(app.packageName),
                  onChanged: (v) {
                    setState(() {
                      if (v!) {
                        _selectedPackages.add(app.packageName);
                      } else {
                        _selectedPackages.remove(app.packageName);
                      }
                    });
                  },
                  title: Text(
                    app.name,
                    style: GoogleFonts.jetBrainsMono(fontSize: 14),
                  ),
                  secondary: app.icon != null
                      ? Image.memory(
                          Uint8List.fromList(app.icon!),
                          width: 32,
                          height: 32,
                        )
                      : const Icon(Icons.android, color: AppTheme.lightGrey),
                  activeColor: AppTheme.orange,
                  checkColor: AppTheme.black,
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
}
