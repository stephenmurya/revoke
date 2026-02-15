import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/native_bridge.dart';
import '../../core/models/schedule_model.dart';
import '../../core/services/schedule_service.dart';
import 'widgets/focus_score_card.dart';
import 'widgets/single_app_icon.dart';
import '../../core/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final List<ScheduleModel> schedules;
  const HomeScreen({super.key, required this.schedules});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<ScheduleModel> _schedules = [];
  bool _isLoading = true;
  bool _isMissingPermissions = false;
  StreamSubscription? _permissionSubscription;
  StreamSubscription? _temporaryApprovalSubscription;
  Set<String> _temporaryApprovedPackages = const <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NativeBridge.setupOverlayListener();
    NativeBridge.startService();
    _checkPermissions();
    _refreshTemporaryApprovals();
    _schedules = widget.schedules;
    _isLoading = false;
    AuthService.validateSession();

    // Periodic check every 5 seconds while UI is open
    _permissionSubscription = Stream.periodic(const Duration(seconds: 5))
        .listen((_) {
          _checkPermissions();
        });

    _temporaryApprovalSubscription = Stream.periodic(const Duration(seconds: 5))
        .listen((_) {
          _refreshTemporaryApprovals();
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _permissionSubscription?.cancel();
    _temporaryApprovalSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _refreshTemporaryApprovals();
      _loadSchedules();
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep UI in sync with cloud-backed stream from RegimesScreen.
    final oldKey = oldWidget.schedules
        .map((s) => '${s.id}:${s.isActive ? 1 : 0}:${s.name}:${s.targetApps.length}')
        .join('|');
    final newKey = widget.schedules
        .map((s) => '${s.id}:${s.isActive ? 1 : 0}:${s.name}:${s.targetApps.length}')
        .join('|');
    if (oldKey != newKey) {
      setState(() {
        _schedules = widget.schedules;
      });
    }
  }

  Future<void> _checkPermissions() async {
    final perms = await NativeBridge.checkPermissions();
    final nextMissing =
        !(perms['usage_stats'] ?? false) || !(perms['overlay'] ?? false);
    if (!mounted) return;
    if (nextMissing != _isMissingPermissions) {
      setState(() {
        _isMissingPermissions = nextMissing;
      });
    }
  }

  Future<void> _refreshTemporaryApprovals() async {
    try {
      final active = await NativeBridge.getTemporaryApprovedPackages();
      final next = active
          .map((pkg) => pkg.trim())
          .where((pkg) => pkg.isNotEmpty)
          .toSet();
      if (!mounted) return;
      if (next.length == _temporaryApprovedPackages.length &&
          next.containsAll(_temporaryApprovedPackages)) {
        return;
      }
      setState(() {
        _temporaryApprovedPackages = next;
      });
    } catch (_) {
      // No-op: indicator is cosmetic and should not break home rendering.
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await ScheduleService.getSchedules();
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _schedules = const [];
          _isLoading = false;
        });
      }
    }
  }

  Set<String> get _activeHitlist {
    final active = _schedules.where((s) => s.isActive);
    final Set<String> packages = {};
    for (var s in active) {
      packages.addAll(s.targetApps);
    }
    return packages;
  }

  void _onToggleSchedule(ScheduleModel schedule) async {
    // OPTIMISTIC UI UPDATE
    setState(() {
      final index = _schedules.indexWhere((s) => s.id == schedule.id);
      if (index != -1) {
        _schedules[index] = _schedules[index].copyWith(
          isActive: !schedule.isActive,
        );
      }
    });

    // BACKGROUND SAVE
    await ScheduleService.toggleSchedule(schedule.id);

    // CRITICAL: Sync immediately after toggle
    await ScheduleService.syncWithNative();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppSemanticColors.accent),
              )
            : RefreshIndicator(
                onRefresh: _loadSchedules,
                color: AppSemanticColors.accent,
                child: CustomScrollView(
                  slivers: [
                    if (_isMissingPermissions)
                      SliverToBoxAdapter(
                        child: GestureDetector(
                          onTap: () async {
                            await context.push('/permissions');
                            _checkPermissions();
                          },
                          child: Container(
                            color: AppSemanticColors.danger,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Revoke is blind. Tap to fix.',
                                style: AppTheme.baseBold.copyWith(
                                  color: AppSemanticColors.primaryText,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const FocusScoreCard(),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('CURRENTLY RESTRICTED'),
                                const SizedBox(height: 16),
                                _buildHitlistSection(),
                                const SizedBox(height: 32),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildSectionHeader('ACTIVE REGIMES'),
                                    Text(
                                      '${_schedules.where((s) => s.isActive).length}/${_schedules.length}',
                                      style: AppTheme.smMedium.copyWith(
                                        color: AppSemanticColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _schedules.isEmpty
                        ? SliverToBoxAdapter(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildScheduleCard(_schedules[index]),
                              childCount: _schedules.length,
                            ),
                          ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () async {
          await context.push('/regime/new');
          _loadSchedules();
        },
        backgroundColor: AppSemanticColors.accent,
        child: const Icon(Icons.add, color: AppSemanticColors.background, size: 40),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: AppTheme.smBold.copyWith(color: AppSemanticColors.accent));
  }

  bool _isCurrentlyBlocking(ScheduleModel s) {
    if (!s.isActive) return false;

    final dayOfWeek = DateTime.now().weekday; // 1 (Mon) to 7 (Sun)
    if (!s.days.contains(dayOfWeek)) return false;

    if (s.type == ScheduleType.timeBlock) {
      if (s.startTime == null || s.endTime == null) return false;

      final now = TimeOfDay.fromDateTime(DateTime.now());
      final nowMin = now.hour * 60 + now.minute;
      final startMin = s.startTime!.hour * 60 + s.startTime!.minute;
      final endMin = s.endTime!.hour * 60 + s.endTime!.minute;

      if (startMin <= endMin) {
        return nowMin >= startMin && nowMin <= endMin;
      } else {
        // Overnight
        return nowMin >= startMin || nowMin <= endMin;
      }
    } else {
      // UsageLimit mock: blocked if > 50% used (mocking)
      return false; // For now default to idle unless blocked on native
    }
  }

  String _getTimeRemaining(ScheduleModel s) {
    if (!s.isActive) return "PAUSED";

    final isBlocking = _isCurrentlyBlocking(s);

    if (s.type == ScheduleType.timeBlock) {
      if (s.startTime == null || s.endTime == null) return "INVALID TIME";

      if (isBlocking) {
        final now = DateTime.now();
        final end = DateTime(
          now.year,
          now.month,
          now.day,
          s.endTime!.hour,
          s.endTime!.minute,
        );
        var diff = end.difference(now);
        if (diff.isNegative) {
          // It's technically tomorrow
          diff = diff + const Duration(days: 1);
        }

        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

        return "🔒 Locked until ${s.endTime!.format(context)} ($timeStr left)";
      } else {
        return "✅ Standing by until ${s.startTime!.format(context)}";
      }
    } else {
      // UsageLimit mock
      return "⏳ 15m / ${s.durationLimit?.inMinutes}m used";
    }
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    final isBlocking = _isCurrentlyBlocking(schedule);
    final hasTemporaryApproval = schedule.targetApps.any(
      _temporaryApprovedPackages.contains,
    );
    final cardBorderColor = hasTemporaryApproval
        ? AppSemanticColors.approve
        : (schedule.isActive
              ? (isBlocking
                    ? AppSemanticColors.accent
                    : AppSemanticColors.success.withOpacity(0.5))
              : Colors.transparent);
    final cardBorderWidth = hasTemporaryApproval ? 1.0 : 2.0;

    return GestureDetector(
      onTap: () async {
        await context.push('/regime/edit', extra: schedule);
        _loadSchedules();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppSemanticColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cardBorderColor, width: cardBorderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(schedule.name, style: AppTheme.h3)),
                Switch(
                  value: schedule.isActive,
                  activeColor: AppSemanticColors.background,
                  activeTrackColor: AppSemanticColors.accent,
                  onChanged: (v) => _onToggleSchedule(schedule),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: schedule.isActive
                        ? (isBlocking
                              ? AppSemanticColors.accent.withOpacity(0.1)
                              : AppSemanticColors.success.withOpacity(0.1))
                        : AppSemanticColors.background.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    schedule.isActive
                        ? (isBlocking ? "⛔ ACTIVE" : "✅ STANDING BY")
                        : "💤 INACTIVE",
                    style: AppTheme.labelSmall.copyWith(
                      color: schedule.isActive
                          ? (isBlocking ? AppSemanticColors.accent : AppSemanticColors.success)
                          : AppSemanticColors.mutedText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getTimeRemaining(schedule),
                    style: AppTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStackedIcons(schedule.targetApps),
                Text(
                  schedule.type == ScheduleType.timeBlock
                      ? "TIME BLOCK"
                      : "USAGE LIMIT",
                  style: AppTheme.labelSmall.copyWith(
                    color: AppSemanticColors.mutedText.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedIcons(List<String> packages) {
    final icons = packages.take(3).toList();
    return SizedBox(
      height: 32,
      width: 80,
      child: Stack(
        children: List.generate(icons.length, (i) {
          return Positioned(
            left: i * 20.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _temporaryApprovedPackages.contains(icons[i])
                      ? AppSemanticColors.approve
                      : AppSemanticColors.surface,
                  width: _temporaryApprovedPackages.contains(icons[i]) ? 1 : 2,
                ),
              ),
              child: ClipOval(
                child: SingleAppIcon(packageName: icons[i], size: 28),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHitlistSection() {
    final packages = _activeHitlist.toList();
    if (packages.isEmpty) return _buildEmptyLabel('HITLIST CLEAR');
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: packages.length,
        itemBuilder: (context, index) {
          final packageName = packages[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppSemanticColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: _temporaryApprovedPackages.contains(packageName)
                  ? Border.all(color: AppSemanticColors.approve, width: 1)
                  : null,
            ),
            child: SingleAppIcon(packageName: packageName, size: 32),
          );
        },
      ),
    );
  }

  Widget _buildEmptyLabel(String text) {
    return Text(
      text,
      style: AppTheme.bodySmall.copyWith(
        color: AppSemanticColors.mutedText.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Text(
          'TAP + TO START THE GRIND',
          style: AppTheme.bodyMedium.copyWith(
            color: AppSemanticColors.mutedText,
          ),
        ),
      ),
    );
  }
}
