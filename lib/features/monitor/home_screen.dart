import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/schedule_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_block_validator.dart';
import '../../core/utils/theme_extensions.dart';
import 'widgets/focus_score_card.dart';
import 'widgets/single_app_icon.dart';

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
    _checkPermissions();
    _refreshTemporaryApprovals();
    _schedules = widget.schedules;
    _isLoading = false;
    AuthService.validateSession();

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
    final oldKey = oldWidget.schedules
        .map(
          (s) =>
              '${s.id}:${s.isActive ? 1 : 0}:${s.name}:${s.targetApps.length}',
        )
        .join('|');
    final newKey = widget.schedules
        .map(
          (s) =>
              '${s.id}:${s.isActive ? 1 : 0}:${s.name}:${s.targetApps.length}',
        )
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
        !(perms['usage_stats'] ?? false) ||
        !(perms['overlay'] ?? false) ||
        !(perms['exact_alarm'] ?? false);
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
      // Cosmetic indicator only.
    }
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await ScheduleService.getSchedules();
      if (!mounted) return;
      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _schedules = const [];
        _isLoading = false;
      });
    }
  }

  Set<String> get _activeHitlist {
    final active = _schedules.where((s) => s.isActive);
    final Set<String> packages = {};
    for (final schedule in active) {
      packages.addAll(schedule.targetApps);
    }
    return packages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.scheme.primary),
              )
            : RefreshIndicator(
                onRefresh: _loadSchedules,
                color: context.scheme.primary,
                child: CustomScrollView(
                  slivers: [
                    if (_isMissingPermissions)
                      SliverToBoxAdapter(
                        child: GestureDetector(
                          onTap: () async {
                            await context.push('/permissions');
                            if (!mounted) return;
                            _checkPermissions();
                          },
                          child: Container(
                            color: context.colors.danger,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Revoke is missing a core Android permission. Tap to fix.',
                                style: AppTheme.baseBold.copyWith(
                                  color: context.scheme.onError,
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
                                        color: context.colors.textSecondary,
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
          if (!mounted) return;
          _loadSchedules();
        },
        backgroundColor: context.scheme.primary,
        child: Icon(
          PhosphorIcons.plus(),
          color: context.scheme.onPrimary,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.smBold.copyWith(color: context.scheme.primary),
    );
  }

  bool _isMinuteInsideBlock(ScheduleBlock block, int minuteOfDay) {
    final start = block.startMinutes;
    final end = block.endMinutes;
    if (start < end) return minuteOfDay >= start && minuteOfDay < end;
    if (start > end) return minuteOfDay >= start || minuteOfDay < end;
    return false;
  }

  bool _isCurrentlyBlocking(ScheduleModel schedule) {
    if (!schedule.isActive) return false;
    if (!schedule.days.contains(DateTime.now().weekday)) return false;

    if (schedule.type == ScheduleType.timeBlock) {
      if (schedule.blocks.isEmpty) return false;
      final now = TimeOfDay.fromDateTime(DateTime.now());
      final nowMin = now.hour * 60 + now.minute;
      return ScheduleBlockValidator.isMinuteWithinBlocks(
        schedule.blocks,
        nowMin,
      );
    }
    return false;
  }

  TimeOfDay? _currentBlockEndTime(ScheduleModel schedule) {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final nowMin = now.hour * 60 + now.minute;
    for (final block in schedule.blocks) {
      if (_isMinuteInsideBlock(block, nowMin)) {
        return block.endTime;
      }
    }
    return null;
  }

  TimeOfDay? _nextBlockStartTime(ScheduleModel schedule) {
    if (schedule.blocks.isEmpty) return null;
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final nowMin = now.hour * 60 + now.minute;

    ScheduleBlock? bestBlock;
    int? bestDelta;
    for (final block in schedule.blocks) {
      final delta = block.startMinutes >= nowMin
          ? block.startMinutes - nowMin
          : (1440 - nowMin) + block.startMinutes;
      if (bestDelta == null || delta < bestDelta) {
        bestDelta = delta;
        bestBlock = block;
      }
    }
    return bestBlock?.startTime;
  }

  String _buildScheduleStatus(ScheduleModel schedule) {
    if (!schedule.isActive) {
      return 'Block now to reactivate';
    }

    if (schedule.type == ScheduleType.usageLimit) {
      final totalMinutes = schedule.durationLimit?.inMinutes ?? 0;
      if (totalMinutes <= 0) return 'Usage limit pending';
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      if (hours > 0 && minutes > 0) {
        return 'Daily cap ${hours}h ${minutes}m';
      }
      if (hours > 0) return 'Daily cap ${hours}h';
      return 'Daily cap ${minutes}m';
    }

    if (schedule.blocks.isEmpty) {
      return 'No focus windows';
    }

    if (!schedule.days.contains(DateTime.now().weekday)) {
      return 'Active on selected days';
    }

    final activeEnd = _currentBlockEndTime(schedule);
    if (activeEnd != null) {
      return 'Active till ${activeEnd.format(context)}';
    }

    final nextStart = _nextBlockStartTime(schedule);
    if (nextStart != null) {
      return 'Next block ${nextStart.format(context)}';
    }
    return 'Active on selected days';
  }

  IconData _blockTypeIcon(ScheduleType type) {
    return type == ScheduleType.timeBlock
        ? PhosphorIcons.clock()
        : PhosphorIcons.hourglassLow();
  }

  String _blockTypeLabel(ScheduleType type) {
    return switch (type) {
      ScheduleType.timeBlock => 'Time block',
      ScheduleType.usageLimit => 'Usage limit',
      ScheduleType.launchCount => 'Launch count',
    };
  }

  String _daySummary(List<int> days) {
    if (days.isEmpty) return 'No days';
    final normalized = days.toSet().toList()..sort();
    const weekdays = <int>[1, 2, 3, 4, 5];
    if (normalized.length == 7) return 'Daily';
    if (normalized.length == 5 &&
        normalized.every((day) => weekdays.contains(day))) {
      return 'Weekdays';
    }
    if (normalized.length == 2 &&
        normalized.contains(6) &&
        normalized.contains(7)) {
      return 'Weekends';
    }
    if (normalized.length == 1) {
      const labels = <int, String>{
        1: 'Mon',
        2: 'Tue',
        3: 'Wed',
        4: 'Thu',
        5: 'Fri',
        6: 'Sat',
        7: 'Sun',
      };
      return labels[normalized.first] ?? 'Custom';
    }
    return '${normalized.length} days';
  }

  Future<void> _activateScheduleNow(ScheduleModel schedule) async {
    try {
      if (schedule.isActive) {
        await ScheduleService.syncWithNative();
      } else {
        await ScheduleService.saveSchedule(schedule.copyWith(isActive: true));
      }
      if (!mounted) return;
      await _loadSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Regime enforcement synced now.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to activate: $e')));
    }
  }

  Future<void> _duplicateSchedule(ScheduleModel schedule) async {
    final copy = ScheduleModel(
      id: const Uuid().v4(),
      name: '${schedule.name} Copy',
      type: schedule.type,
      targetApps: List<String>.from(schedule.targetApps),
      days: List<int>.from(schedule.days),
      blocks: List<ScheduleBlock>.from(schedule.blocks),
      durationLimit: schedule.durationLimit,
      isActive: true,
      emoji: schedule.emoji,
    );
    try {
      await ScheduleService.saveSchedule(copy);
      if (!mounted) return;
      await _loadSchedules();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Regime duplicated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Duplicate failed: $e')));
    }
  }

  Future<void> _openRegimePleaComposer({
    required ScheduleModel schedule,
    required bool deleteMode,
  }) async {
    final reasonController = TextEditingController();
    var selectedMinutes = 15;
    final durationOptions = <int>[5, 10, 20, 30];

    final request = await showModalBottomSheet<_RegimePleaRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deleteMode
                        ? 'Delete regime via tribunal'
                        : 'Beg for a break',
                    style: AppTheme.h3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    deleteMode
                        ? 'Explain why this regime should be removed.'
                        : 'Request temporary relief from this regime.',
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  if (!deleteMode) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: durationOptions
                          .map((minutes) {
                            final selected = selectedMinutes == minutes;
                            return ChoiceChip(
                              label: Text('$minutes min'),
                              selected: selected,
                              onSelected: (_) {
                                setSheetState(() => selectedMinutes = minutes);
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    maxLength: 180,
                    decoration: AppTheme.defaultInputDecoration(
                      labelText: 'Reason',
                      hintText: deleteMode
                          ? 'Why should this regime be deleted?'
                          : 'Why do you need a break?',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: AppTheme.secondaryButtonStyle,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final reason = reasonController.text.trim();
                            if (reason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Add a reason for the tribunal.',
                                  ),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(
                              sheetContext,
                              _RegimePleaRequest(
                                reason: reason,
                                durationMinutes: deleteMode
                                    ? 5
                                    : selectedMinutes,
                              ),
                            );
                          },
                          style: deleteMode
                              ? AppTheme.dangerButtonStyle
                              : AppTheme.primaryButtonStyle,
                          child: Text(
                            deleteMode ? 'Request delete' : 'Send plea',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    reasonController.dispose();

    if (request == null) return;

    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    try {
      final userData = await AuthService.getUserData();
      final squadId = (userData?['squadId'] as String?)?.trim();
      final nickname = (userData?['nickname'] as String?)?.trim();
      if (squadId == null || squadId.isEmpty) {
        throw const PleaNoSquadException();
      }

      final pleaId = await SquadService.createPlea(
        uid: uid,
        userName: nickname?.isNotEmpty == true ? nickname! : 'A Member',
        squadId: squadId,
        appName: deleteMode
            ? 'Delete ${schedule.name}'
            : '${schedule.name} break',
        packageName: deleteMode
            ? 'regime-delete:${schedule.id}'
            : 'regime:${schedule.id}',
        durationMinutes: request.durationMinutes,
        reason: request.reason,
      );
      if (!mounted) return;
      context.go('/tribunal/$pleaId');
    } on PleaNoSquadException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: SnackBarAction(
            label: 'Open Squad',
            onPressed: () => context.go('/squad'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tribunal request failed: $e')));
    }
  }

  Future<void> _showScheduleActionSheet(ScheduleModel schedule) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    PhosphorIcons.lockSimple(),
                    color: context.scheme.primary,
                  ),
                  title: Text('Block now', style: AppTheme.baseMedium),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _activateScheduleNow(schedule);
                  },
                ),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.hourglassHigh(),
                    color: context.scheme.primary,
                  ),
                  title: Text('Beg for a break', style: AppTheme.baseMedium),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openRegimePleaComposer(
                      schedule: schedule,
                      deleteMode: false,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.copy(),
                    color: context.scheme.primary,
                  ),
                  title: Text('Duplicate', style: AppTheme.baseMedium),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _duplicateSchedule(schedule);
                  },
                ),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.trash(),
                    color: context.colors.danger,
                  ),
                  title: Text(
                    'Delete',
                    style: AppTheme.baseMedium.copyWith(
                      color: context.colors.danger,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openRegimePleaComposer(
                      schedule: schedule,
                      deleteMode: true,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    final isBlocking = _isCurrentlyBlocking(schedule);
    final hasTemporaryApproval = schedule.targetApps.any(
      _temporaryApprovedPackages.contains,
    );
    final borderColor = hasTemporaryApproval
        ? context.colors.success
        : (isBlocking
              ? context.scheme.primary
              : context.scheme.outlineVariant.withValues(alpha: 0.6));
    final statusColor = hasTemporaryApproval
        ? context.colors.success
        : (isBlocking ? context.scheme.primary : context.colors.textSecondary);
    final statusLabel = hasTemporaryApproval
        ? 'Temporarily unlocked'
        : _buildScheduleStatus(schedule);
    final typeLabel = _blockTypeLabel(schedule.type);
    final dayLabel = _daySummary(schedule.days);
    final blockCount = schedule.type == ScheduleType.timeBlock
        ? '${schedule.blocks.length} blocks'
        : 'Daily cap';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        await context.push('/regime/edit', extra: schedule);
        if (!mounted) return;
        _loadSchedules();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: isBlocking ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: context.scheme.onSurface.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _blockTypeIcon(schedule.type),
                        size: 14,
                        color: context.scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        typeLabel,
                        style: AppTheme.xsBold.copyWith(
                          color: context.scheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    PhosphorIcons.dotsThree(),
                    color: context.colors.textSecondary,
                  ),
                  onPressed: () => _showScheduleActionSheet(schedule),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.center,
              child: Text(
                schedule.emoji,
                style: AppTheme.xxlMedium.copyWith(fontSize: 64, height: 1),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              schedule.name,
              textAlign: TextAlign.center,
              style: AppTheme.lgBold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: AppTheme.smMedium.copyWith(color: statusColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: context.scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStackedIcons(schedule.targetApps)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.scheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$dayLabel • $blockCount',
                    style: AppTheme.xsMedium.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            _buildGhostRestrictionNotice(schedule.targetApps),
          ],
        ),
      ),
    );
  }

  Widget _buildGhostRestrictionNotice(List<String> packages) {
    if (packages.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<List<AppInfo>>(
      future: Future.wait(
        packages.map((package) => AppDiscoveryService.getAppDetails(package)),
      ),
      builder: (context, snapshot) {
        final apps = snapshot.data;
        if (apps == null || apps.isEmpty) return const SizedBox.shrink();

        final ghosts = apps
            .where((app) => app.isGhost || app.name == AppInfo.ghostAppName)
            .toList(growable: false);
        if (ghosts.isEmpty) return const SizedBox.shrink();

        final packageSummary = ghosts
            .map((app) => app.packageName)
            .where((pkg) => pkg.trim().isNotEmpty)
            .join(', ');

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.ghost(),
                      size: 14,
                      color: context.colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        packageSummary.isEmpty
                            ? AppInfo.ghostAppName
                            : '${AppInfo.ghostAppName} • $packageSummary',
                        style: AppTheme.xsMedium.copyWith(
                          color: context.colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Restriction remains active',
                  style: AppTheme.xsBold.copyWith(color: context.colors.danger),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackedIcons(List<String> packages) {
    final icons = packages.take(5).toList();
    if (icons.isEmpty) {
      return Text(
        'No apps selected',
        style: AppTheme.smRegular.copyWith(color: context.colors.textSecondary),
      );
    }
    final width = 28 + ((icons.length - 1) * 20);
    return SizedBox(
      height: 32,
      width: width.toDouble(),
      child: Stack(
        children: List.generate(icons.length, (i) {
          return Positioned(
            left: i * 20.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _temporaryApprovedPackages.contains(icons[i])
                      ? context.colors.success
                      : context.scheme.surface,
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
              color: context.scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: _temporaryApprovedPackages.contains(packageName)
                  ? Border.all(color: context.colors.success, width: 1)
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
        color: context.colors.textSecondary.withValues(alpha: 0.55),
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
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _RegimePleaRequest {
  final String reason;
  final int durationMinutes;

  const _RegimePleaRequest({
    required this.reason,
    required this.durationMinutes,
  });
}
