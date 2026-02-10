import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/native_bridge.dart';
import '../../core/models/schedule_model.dart';
import '../../core/services/schedule_service.dart';
import 'create_schedule_screen.dart';
import 'widgets/focus_score_card.dart';
import 'widgets/single_app_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<ScheduleModel> _schedules = [];
  bool _isLoading = true;
  bool _isMissingPermissions = false;
  StreamSubscription? _permissionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NativeBridge.setupOverlayListener();
    NativeBridge.startService();
    _checkPermissions();
    _loadSchedules();

    // Periodic check every 5 seconds while UI is open
    _permissionSubscription = Stream.periodic(const Duration(seconds: 5))
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
      _loadSchedules();
    }
  }

  Future<void> _checkPermissions() async {
    final perms = await NativeBridge.checkPermissions();
    if (mounted) {
      setState(() {
        _isMissingPermissions =
            !(perms['usage_stats'] ?? false) || !(perms['overlay'] ?? false);
      });
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);

    final schedules = await ScheduleService.getSchedules();

    if (mounted) {
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
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
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.orange),
              )
            : RefreshIndicator(
                onRefresh: _loadSchedules,
                color: AppTheme.orange,
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
                            color: AppTheme.deepRed,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                '⚠️ REVOKE IS BLIND. TAP TO FIX.',
                                style: GoogleFonts.spaceGrotesk(
                                  color: AppTheme.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                          _buildHeader(),
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
                                      style: GoogleFonts.jetBrainsMono(
                                        color: AppTheme.lightGrey,
                                        fontSize: 12,
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
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateScheduleScreen(),
            ),
          );
          _loadSchedules();
        },
        backgroundColor: AppTheme.orange,
        child: const Icon(Icons.add, color: AppTheme.black, size: 40),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppTheme.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'REVOKE',
                style: GoogleFonts.spaceGrotesk(
                  color: AppTheme.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppTheme.white,
                      size: 28,
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.orange.withOpacity(0.5),
                    width: 1.5,
                  ),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://api.dicebear.com/7.x/pixel-art/svg?seed=Revoke',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        color: AppTheme.orange,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
        fontSize: 12,
      ),
    );
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

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CreateScheduleScreen(existingSchedule: schedule),
          ),
        );
        _loadSchedules();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: schedule.isActive
                ? (isBlocking ? AppTheme.orange : Colors.green.withOpacity(0.5))
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    schedule.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                Switch(
                  value: schedule.isActive,
                  activeColor: AppTheme.black,
                  activeTrackColor: AppTheme.orange,
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
                              ? AppTheme.orange.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1))
                        : AppTheme.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    schedule.isActive
                        ? (isBlocking ? "⛔ ACTIVE" : "✅ STANDING BY")
                        : "💤 INACTIVE",
                    style: GoogleFonts.jetBrainsMono(
                      color: schedule.isActive
                          ? (isBlocking ? AppTheme.orange : Colors.green)
                          : AppTheme.lightGrey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getTimeRemaining(schedule),
                    style: GoogleFonts.jetBrainsMono(
                      color: AppTheme.lightGrey,
                      fontSize: 11,
                    ),
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
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.lightGrey.withOpacity(0.5),
                    fontSize: 10,
                    letterSpacing: 1,
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
                border: Border.all(color: AppTheme.darkGrey, width: 2),
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
              color: AppTheme.darkGrey,
              borderRadius: BorderRadius.circular(12),
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
      style: GoogleFonts.jetBrainsMono(
        color: AppTheme.lightGrey.withOpacity(0.5),
        fontSize: 12,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Text(
          'TAP + TO START THE GRIND',
          style: GoogleFonts.jetBrainsMono(color: AppTheme.lightGrey),
        ),
      ),
    );
  }
}
