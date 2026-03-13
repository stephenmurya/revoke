import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/schedule_model.dart';
import '../../core/native_bridge.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_block_validator.dart';
import '../../core/utils/theme_extensions.dart';
import 'app_list_screen.dart';
import 'widgets/single_app_icon.dart';

enum _BlockGroup { timeBlock, usageWindow }

class CreateScheduleScreen extends StatefulWidget {
  final ScheduleModel? existingSchedule;
  const CreateScheduleScreen({super.key, this.existingSchedule});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  static const Duration _minimumBlockDuration = Duration(minutes: 15);
  static const int _minutesPerDay = 1440;
  static const int _usageLimitMinuteInterval = 5;

  final TextEditingController _nameController = TextEditingController();
  final List<int> _hourlyUsage = List<int>.filled(24, 0);

  ScheduleType _selectedType = ScheduleType.timeBlock;
  int _stepIndex = 0;

  List<ScheduleBlock> _timeBlocks = const <ScheduleBlock>[
    ScheduleBlock(
      startTime: TimeOfDay(hour: 9, minute: 0),
      endTime: TimeOfDay(hour: 12, minute: 0),
    ),
  ];
  List<ScheduleBlock> _usageWindows = const <ScheduleBlock>[];
  bool _usageLimitAllDay = true;
  Duration _usageLimit = const Duration(minutes: 30);

  List<int> _selectedDays = <int>[1, 2, 3, 4, 5];
  Set<String> _selectedPackages = <String>{};
  String _selectedEmoji = ScheduleModel.defaultEmoji;

  Map<int, List<String>> _timeBlockErrors = const <int, List<String>>{};
  Map<int, List<String>> _usageWindowErrors = const <int, List<String>>{};

  bool _loadingUsagePattern = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSchedule;
    if (existing != null) {
      _nameController.text = existing.name;
      _selectedType = existing.type;
      _selectedDays = List<int>.from(existing.days);
      _selectedPackages = Set<String>.from(existing.targetApps);
      _selectedEmoji = existing.emoji;

      if (existing.type == ScheduleType.timeBlock) {
        if (existing.blocks.isNotEmpty) {
          _timeBlocks = List<ScheduleBlock>.from(existing.blocks);
        }
      } else {
        _usageLimit = _normalizeUsageLimitForPicker(
          existing.durationLimit ?? const Duration(minutes: 30),
        );
        if (existing.blocks.isNotEmpty) {
          _usageLimitAllDay = false;
          _usageWindows = List<ScheduleBlock>.from(existing.blocks);
        }
      }
    }

    AppDiscoveryService.prefetch();
    _refreshErrors(_BlockGroup.timeBlock);
    _refreshErrors(_BlockGroup.usageWindow);
    _loadUsagePattern();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsagePattern() async {
    try {
      final pattern = await NativeBridge.getHourlyUsagePattern();
      if (!mounted) return;
      for (var i = 0; i < math.min(pattern.length, 24); i++) {
        _hourlyUsage[i] = math.max(0, pattern[i]);
      }
    } catch (_) {
      // Keep neutral timeline when usage data is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _loadingUsagePattern = false;
        });
      }
    }
  }

  List<ScheduleBlock> _blocksFor(_BlockGroup group) {
    return group == _BlockGroup.timeBlock ? _timeBlocks : _usageWindows;
  }

  void _setBlocksFor(_BlockGroup group, List<ScheduleBlock> value) {
    if (group == _BlockGroup.timeBlock) {
      _timeBlocks = value;
    } else {
      _usageWindows = value;
    }
  }

  Map<int, List<String>> _errorsFor(_BlockGroup group) {
    return group == _BlockGroup.timeBlock
        ? _timeBlockErrors
        : _usageWindowErrors;
  }

  void _setErrorsFor(_BlockGroup group, Map<int, List<String>> errors) {
    if (group == _BlockGroup.timeBlock) {
      _timeBlockErrors = errors;
    } else {
      _usageWindowErrors = errors;
    }
  }

  Duration _normalizeUsageLimitForPicker(Duration duration) {
    final maxMinutes = _minutesPerDay - _usageLimitMinuteInterval;
    final rawMinutes = duration.inMinutes.clamp(0, maxMinutes);
    if (rawMinutes == 0) {
      return const Duration(minutes: _usageLimitMinuteInterval);
    }

    final roundedMinutes =
        (rawMinutes / _usageLimitMinuteInterval).round() *
        _usageLimitMinuteInterval;
    final normalizedMinutes = roundedMinutes.clamp(
      _usageLimitMinuteInterval,
      maxMinutes,
    );
    return Duration(minutes: normalizedMinutes);
  }

  TimeOfDay _fromMinutes(int minutes) {
    final normalized =
        ((minutes % _minutesPerDay) + _minutesPerDay) % _minutesPerDay;
    return TimeOfDay(hour: normalized ~/ 60, minute: normalized % 60);
  }

  int _roundToQuarterHour(int minute) {
    final rounded = (minute / 15).round() * 15;
    return ((rounded % _minutesPerDay) + _minutesPerDay) % _minutesPerDay;
  }

  String _formatBlockRange(ScheduleBlock block) {
    return '${block.startTime.format(context)} - ${block.endTime.format(context)}';
  }

  void _refreshErrors(_BlockGroup group) {
    final result = ScheduleBlockValidator.validate(
      _blocksFor(group),
      minimumDuration: _minimumBlockDuration,
    );
    final grouped = <int, List<String>>{};
    for (final issue in result.issues) {
      grouped
          .putIfAbsent(issue.blockIndex, () => <String>[])
          .add(issue.message);
    }
    _setErrorsFor(group, grouped);
  }

  bool _validateBlocks(
    _BlockGroup group, {
    required bool atLeastOne,
    bool showMessage = true,
  }) {
    final blocks = _blocksFor(group);
    if (atLeastOne && blocks.isEmpty) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one time block.')),
        );
      }
      return false;
    }

    final result = ScheduleBlockValidator.validate(
      blocks,
      minimumDuration: _minimumBlockDuration,
    );
    final grouped = <int, List<String>>{};
    for (final issue in result.issues) {
      grouped
          .putIfAbsent(issue.blockIndex, () => <String>[])
          .add(issue.message);
    }

    setState(() {
      _setErrorsFor(group, grouped);
    });

    if (!result.isValid) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.firstError ?? 'Fix invalid time blocks.'),
          ),
        );
      }
      return false;
    }
    return true;
  }

  bool _validateConditionStep({bool showMessage = true}) {
    if (_selectedDays.isEmpty) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one active day.')),
        );
      }
      return false;
    }

    if (_selectedType == ScheduleType.timeBlock) {
      return _validateBlocks(
        _BlockGroup.timeBlock,
        atLeastOne: true,
        showMessage: showMessage,
      );
    }

    if (_usageLimit.inMinutes <= 0) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set a valid usage limit.')),
        );
      }
      return false;
    }

    if (!_usageLimitAllDay) {
      return _validateBlocks(
        _BlockGroup.usageWindow,
        atLeastOne: true,
        showMessage: showMessage,
      );
    }

    return true;
  }

  bool _validateRegimeDetails({bool showMessage = true}) {
    if (_nameController.text.trim().isEmpty) {
      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter a regime name.')));
      }
      return false;
    }

    if (_selectedPackages.isEmpty) {
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one target app.')),
        );
      }
      return false;
    }

    return true;
  }

  Future<void> _goNext() async {
    if (_stepIndex == 0) {
      setState(() => _stepIndex = 1);
      return;
    }
    if (_stepIndex == 1) {
      if (!_validateConditionStep()) return;
      setState(() => _stepIndex = 2);
      return;
    }
  }

  void _goBack() {
    if (_stepIndex == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _stepIndex -= 1;
    });
  }

  Future<void> _saveRegime() async {
    if (_saving) return;
    if (!_validateConditionStep()) return;
    if (!_validateRegimeDetails()) return;

    setState(() {
      _saving = true;
    });

    try {
      final schedule = ScheduleModel(
        id: widget.existingSchedule?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        type: _selectedType,
        targetApps: _selectedPackages.toList(growable: false),
        days: List<int>.from(_selectedDays)..sort(),
        blocks: _selectedType == ScheduleType.timeBlock
            ? List<ScheduleBlock>.from(_timeBlocks)
            : (_usageLimitAllDay
                  ? const <ScheduleBlock>[]
                  : List<ScheduleBlock>.from(_usageWindows)),
        durationLimit: _selectedType == ScheduleType.usageLimit
            ? _usageLimit
            : null,
        isActive: true,
        emoji: _selectedEmoji,
      );

      await ScheduleService.saveSchedule(schedule);
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _addTimeBlock(_BlockGroup group) {
    final blocks = List<ScheduleBlock>.from(_blocksFor(group));
    var startMinutes = 9 * 60;
    if (blocks.isNotEmpty) {
      startMinutes = blocks.last.endMinutes;
    }

    for (var i = 0; i < 24; i++) {
      final start = _roundToQuarterHour(startMinutes + (i * 60));
      final end = _roundToQuarterHour(start + 60);
      if (start == end) continue;
      final candidate = ScheduleBlock(
        startTime: _fromMinutes(start),
        endTime: _fromMinutes(end),
      );
      final nextBlocks = List<ScheduleBlock>.from(blocks)..add(candidate);
      final valid = ScheduleBlockValidator.validate(
        nextBlocks,
        minimumDuration: _minimumBlockDuration,
      ).isValid;
      if (valid) {
        setState(() {
          _setBlocksFor(group, nextBlocks);
          _refreshErrors(group);
        });
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to find space for another block.')),
    );
  }

  void _removeTimeBlock(_BlockGroup group, int index) {
    final blocks = List<ScheduleBlock>.from(_blocksFor(group));
    if (blocks.length <= 1) return;
    blocks.removeAt(index);
    setState(() {
      _setBlocksFor(group, blocks);
      _refreshErrors(group);
    });
  }

  Future<void> _editTimeBlock(_BlockGroup group, int index) async {
    final blocks = List<ScheduleBlock>.from(_blocksFor(group));
    if (index < 0 || index >= blocks.length) return;

    final current = blocks[index];
    final pickedStart = await showTimePicker(
      context: context,
      initialTime: current.startTime,
    );
    if (pickedStart == null || !mounted) return;

    final pickedEnd = await showTimePicker(
      context: context,
      initialTime: current.endTime,
    );
    if (pickedEnd == null || !mounted) return;

    final nextBlocks = List<ScheduleBlock>.from(blocks);
    nextBlocks[index] = ScheduleBlock(
      startTime: pickedStart,
      endTime: pickedEnd,
    );

    final result = ScheduleBlockValidator.validate(
      nextBlocks,
      minimumDuration: _minimumBlockDuration,
    );
    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.firstError ?? 'Invalid block.')),
      );
      return;
    }

    setState(() {
      _setBlocksFor(group, nextBlocks);
      _refreshErrors(group);
    });
  }

  int? _peakUsageHour() {
    var hour = -1;
    var value = 0;
    for (var i = 0; i < _hourlyUsage.length; i++) {
      if (_hourlyUsage[i] > value) {
        value = _hourlyUsage[i];
        hour = i;
      }
    }
    if (hour < 0 || value <= 0) return null;
    return hour;
  }

  int? _longestBlockIndex(List<ScheduleBlock> blocks) {
    if (blocks.isEmpty) return null;
    var bestIndex = 0;
    var bestDuration = blocks[0].duration.inMinutes;
    for (var i = 1; i < blocks.length; i++) {
      final duration = blocks[i].duration.inMinutes;
      if (duration > bestDuration) {
        bestDuration = duration;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  void _applyPeakSuggestion(_BlockGroup group) {
    final peakHour = _peakUsageHour();
    if (peakHour == null) return;

    final start = peakHour * 60;
    final end = (start + 60) % _minutesPerDay;
    final nextBlocks = List<ScheduleBlock>.from(_blocksFor(group))
      ..add(
        ScheduleBlock(
          startTime: _fromMinutes(start),
          endTime: _fromMinutes(end),
        ),
      );

    final result = ScheduleBlockValidator.validate(
      nextBlocks,
      minimumDuration: _minimumBlockDuration,
    );
    if (!result.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peak hour overlaps another block.')),
      );
      return;
    }

    setState(() {
      _setBlocksFor(group, nextBlocks);
      _refreshErrors(group);
    });
  }

  void _applyBreakSuggestion(_BlockGroup group) {
    final blocks = List<ScheduleBlock>.from(_blocksFor(group));
    final longestIndex = _longestBlockIndex(blocks);
    if (longestIndex == null) return;

    final block = blocks[longestIndex];
    final totalMinutes = block.duration.inMinutes;
    if (totalMinutes < 180) return;

    final breakMinutes = totalMinutes >= 300 ? 30 : 15;
    final first = (totalMinutes - breakMinutes) ~/ 2;
    final second = totalMinutes - breakMinutes - first;
    if (first < 15 || second < 15) return;

    final firstEnd = (block.startMinutes + first) % _minutesPerDay;
    final secondStart = (firstEnd + breakMinutes) % _minutesPerDay;

    final split = <ScheduleBlock>[
      ScheduleBlock(
        startTime: block.startTime,
        endTime: _fromMinutes(firstEnd),
      ),
      ScheduleBlock(
        startTime: _fromMinutes(secondStart),
        endTime: block.endTime,
      ),
    ];

    final nextBlocks = List<ScheduleBlock>.from(blocks)
      ..removeAt(longestIndex)
      ..insertAll(longestIndex, split);

    final result = ScheduleBlockValidator.validate(
      nextBlocks,
      minimumDuration: _minimumBlockDuration,
    );
    if (!result.isValid) return;

    setState(() {
      _setBlocksFor(group, nextBlocks);
      _refreshErrors(group);
    });
  }

  Future<void> _openEmojiPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose regime icon', style: AppTheme.h3),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ScheduleModel.curatedEmojis
                    .map((emoji) {
                      return GestureDetector(
                        onTap: () => Navigator.pop(sheetContext, emoji),
                        child: Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.scheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: context.scheme.primary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Text(emoji, style: AppTheme.xlBold),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectedEmoji = selected;
    });
  }

  void _removeTargetPackage(String packageName) {
    final normalized = packageName.trim();
    if (normalized.isEmpty || !_selectedPackages.contains(normalized)) return;
    setState(() {
      _selectedPackages = Set<String>.from(_selectedPackages)
        ..remove(normalized);
    });
  }

  Future<String?> _openReplacementPicker(String ghostPackage) async {
    final normalizedGhost = ghostPackage.trim();
    if (normalizedGhost.isEmpty) return null;

    final apps = await AppDiscoveryService.getApps(forceRefresh: true);
    final candidates =
        apps
            .where((app) => !app.isGhost)
            .where((app) {
              final pkg = app.packageName.trim();
              if (pkg.isEmpty || pkg == normalizedGhost) return false;
              return !_selectedPackages.contains(pkg);
            })
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    if (candidates.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No replacement apps available right now.'),
        ),
      );
      return null;
    }

    if (!mounted) return null;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Replace uninstalled app', style: AppTheme.h3),
                const SizedBox(height: 6),
                Text(
                  'Pick a replacement target app.',
                  style: AppTheme.smRegular.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: context.scheme.outlineVariant,
                    ),
                    itemBuilder: (itemContext, index) {
                      final app = candidates[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.scheme.outlineVariant,
                            ),
                          ),
                          child: ClipOval(
                            child: SingleAppIcon(
                              packageName: app.packageName,
                              size: 28,
                            ),
                          ),
                        ),
                        title: Text(app.name, style: AppTheme.baseMedium),
                        subtitle: Text(
                          app.packageName,
                          style: AppTheme.xsRegular.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext, app.packageName);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _replaceGhostPackage(String ghostPackage) async {
    final replacement = await _openReplacementPicker(ghostPackage);
    if (replacement == null || !mounted) return;

    setState(() {
      _selectedPackages = Set<String>.from(_selectedPackages)
        ..remove(ghostPackage.trim())
        ..add(replacement.trim());
    });
  }

  Widget _buildGhostRestrictionManager() {
    if (_selectedPackages.isEmpty) return const SizedBox.shrink();

    final packages = _selectedPackages.toList(growable: false);
    return FutureBuilder<List<AppInfo>>(
      future: Future.wait(
        packages.map((package) => AppDiscoveryService.getAppDetails(package)),
      ),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null || data.isEmpty) return const SizedBox.shrink();

        final ghostApps = data
            .where((app) => app.isGhost || app.name == AppInfo.ghostAppName)
            .toList(growable: false);
        if (ghostApps.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ghostApps
              .map((app) {
                final packageName = app.packageName.trim();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.scheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              PhosphorIcons.ghost(),
                              size: 16,
                              color: context.colors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                packageName.isEmpty
                                    ? AppInfo.ghostAppName
                                    : '${AppInfo.ghostAppName} • $packageName',
                                style: AppTheme.smMedium.copyWith(
                                  color: context.colors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Restriction remains active',
                          style: AppTheme.xsBold.copyWith(
                            color: context.colors.danger,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: packageName.isEmpty
                                    ? null
                                    : () => _replaceGhostPackage(packageName),
                                icon: Icon(
                                  PhosphorIcons.arrowsClockwise(),
                                  size: 16,
                                ),
                                label: const Text('Replace'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: context.scheme.primary,
                                  side: BorderSide(
                                    color: context.scheme.outlineVariant,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: packageName.isEmpty
                                    ? null
                                    : () => _removeTargetPackage(packageName),
                                icon: Icon(PhosphorIcons.trash(), size: 16),
                                label: const Text('Remove'),
                                style: TextButton.styleFrom(
                                  foregroundColor: context.colors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildConditionCard() {
    final typeLabel = _selectedType == ScheduleType.timeBlock
        ? 'Time block'
        : 'Usage limit';
    final typeIcon = _selectedType == ScheduleType.timeBlock
        ? PhosphorIcons.clock()
        : PhosphorIcons.hourglassLow();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: context.scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(typeIcon, size: 14, color: context.scheme.primary),
              ),
              const SizedBox(width: 8),
              Text(typeLabel, style: AppTheme.baseBold),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Days',
            style: AppTheme.xsBold.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedDays
                .map((day) => _buildConditionPill(_dayShort(day)))
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Text(
            _selectedType == ScheduleType.timeBlock ? 'Focus windows' : 'Limit',
            style: AppTheme.xsBold.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (_selectedType == ScheduleType.timeBlock)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeBlocks
                  .map((block) => _buildConditionPill(_formatBlockRange(block)))
                  .toList(growable: false),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConditionPill(
                  '${_formatDurationShort(_usageLimit)} daily',
                ),
                if (_usageLimitAllDay) ...[
                  const SizedBox(height: 8),
                  _buildConditionPill('All day access window'),
                ] else ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _usageWindows
                        .map(
                          (block) =>
                              _buildConditionPill(_formatBlockRange(block)),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConditionPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTheme.smMedium.copyWith(color: context.colors.textPrimary),
      ),
    );
  }

  String _formatDurationShort(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  String _dayShort(int day) {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final safe = day.clamp(1, 7);
    return labels[safe - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForStep(), style: AppTheme.h3),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _buildStepContent(),
        ),
      ),
      bottomNavigationBar: _stepIndex < 2
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _goBack,
                        style: AppTheme.secondaryButtonStyle,
                        child: Text(_stepIndex == 0 ? 'Cancel' : 'Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _goNext,
                        style: AppTheme.primaryButtonStyle,
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  String _titleForStep() {
    if (_stepIndex == 0) return 'Select Blocking Type';
    if (_stepIndex == 1) {
      return _selectedType == ScheduleType.timeBlock
          ? 'Set Time Blocks'
          : 'Set Usage Limit';
    }
    return 'Regime Details';
  }

  Widget _buildStepContent() {
    switch (_stepIndex) {
      case 0:
        return _buildBlockingTypeStep();
      case 1:
        return _selectedType == ScheduleType.timeBlock
            ? _buildTimeBlockStep()
            : _buildUsageLimitStep();
      default:
        return _buildDetailsStep();
    }
  }

  Widget _buildBlockingTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose how this regime should enforce focus.',
          style: AppTheme.bodyMedium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _buildTypeOptionCard(
          type: ScheduleType.timeBlock,
          icon: PhosphorIcons.clock(),
          title: 'Time Block',
          description:
              'Great for blocking during set hours or days. e.g. 8:00-6:00 on weekdays.',
        ),
        const SizedBox(height: 12),
        _buildTypeOptionCard(
          type: ScheduleType.usageLimit,
          icon: PhosphorIcons.hourglassLow(),
          title: 'Usage Limit',
          description:
              'Helps control daily limit for time spent in apps. e.g. 30 mins for social media.',
        ),
      ],
    );
  }

  Widget _buildTypeOptionCard({
    required ScheduleType type,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = _selectedType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? context.scheme.primary.withValues(alpha: 0.10)
              : context.scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? context.scheme.primary
                : context.scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: context.scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.baseBold),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlockStep() {
    final peakHour = _peakUsageHour();
    final longest = _longestBlockIndex(_timeBlocks);
    final longestMinutes = longest == null
        ? 0
        : _timeBlocks[longest].duration.inMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Times'),
        Text(
          'Add one or more focus windows. Blocks cannot overlap, gaps are free.',
          style: AppTheme.smRegular.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        _buildTimePillList(_BlockGroup.timeBlock),
        const SizedBox(height: 12),
        _buildAddTimeButton(_BlockGroup.timeBlock),
        const SizedBox(height: 12),
        if (peakHour != null)
          _buildTipChip(
            icon: PhosphorIcons.lightning(),
            label:
                'Most usage occurs at ${_hourRangeText(peakHour)}. Add this block?',
            onTap: () => _applyPeakSuggestion(_BlockGroup.timeBlock),
          ),
        if (longestMinutes >= 180) ...[
          const SizedBox(height: 8),
          _buildTipChip(
            icon: PhosphorIcons.personSimpleTaiChi(),
            label:
                'Long block detected. Suggest a ${longestMinutes >= 300 ? 30 : 15} minute recovery break.',
            onTap: () => _applyBreakSuggestion(_BlockGroup.timeBlock),
          ),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Days'),
        _buildDaySelector(),
        const SizedBox(height: 24),
        _buildSectionTitle('Timeline'),
        _buildUsageTimeline(_timeBlocks),
      ],
    );
  }

  Widget _buildUsageLimitStep() {
    final peakHour = _peakUsageHour();
    final initialUsageLimit = _normalizeUsageLimitForPicker(_usageLimit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Daily Limit'),
        Text(
          'Set how much total time is allowed across selected apps.',
          style: AppTheme.smRegular.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: SizedBox(
            height: 160,
            child: CupertinoTimerPicker(
              mode: CupertinoTimerPickerMode.hm,
              initialTimerDuration: initialUsageLimit,
              minuteInterval: _usageLimitMinuteInterval,
              onTimerDurationChanged: (duration) {
                setState(() {
                  final next = _normalizeUsageLimitForPicker(
                    Duration(
                      hours: duration.inHours,
                      minutes: duration.inMinutes % 60,
                    ),
                  );
                  _usageLimit = next;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Times'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All day long', style: AppTheme.baseMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Allow usage at any time within the daily limit.',
                      style: AppTheme.smRegular.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _usageLimitAllDay,
                activeTrackColor: context.scheme.primary,
                activeThumbColor: context.scheme.onPrimary,
                onChanged: (value) {
                  setState(() {
                    _usageLimitAllDay = value;
                    if (!_usageLimitAllDay && _usageWindows.isEmpty) {
                      _usageWindows = const <ScheduleBlock>[
                        ScheduleBlock(
                          startTime: TimeOfDay(hour: 9, minute: 0),
                          endTime: TimeOfDay(hour: 17, minute: 0),
                        ),
                      ];
                    }
                    _refreshErrors(_BlockGroup.usageWindow);
                  });
                },
              ),
            ],
          ),
        ),
        if (!_usageLimitAllDay) ...[
          const SizedBox(height: 10),
          _buildTimePillList(_BlockGroup.usageWindow),
          const SizedBox(height: 12),
          _buildAddTimeButton(_BlockGroup.usageWindow),
          if (peakHour != null) ...[
            const SizedBox(height: 12),
            _buildTipChip(
              icon: PhosphorIcons.lightning(),
              label:
                  'High usage at ${_hourRangeText(peakHour)}. Add as an allowed window?',
              onTap: () => _applyPeakSuggestion(_BlockGroup.usageWindow),
            ),
          ],
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Days'),
        _buildDaySelector(),
        const SizedBox(height: 24),
        _buildSectionTitle('Tips'),
        _buildTipChip(
          icon: PhosphorIcons.lightbulb(),
          label: 'Start with realistic limits and tighten over time.',
          onTap: () {},
        ),
        const SizedBox(height: 8),
        _buildTipChip(
          icon: PhosphorIcons.brain(),
          label:
              'Combine usage limits with time windows for stronger guardrails.',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Center(
                  child: Text(
                    _selectedEmoji,
                    style: AppTheme.size4xlMedium.copyWith(
                      fontSize: 92,
                      height: 1,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: _openEmojiPicker,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.scheme.onSurface.withValues(alpha: .75),
                      shape: BoxShape.circle,
                      // border: Border.all(
                      //   color: context.scheme.surface,
                      //   width: 2,
                      // ),
                    ),
                    child: Icon(
                      PhosphorIcons.pencilSimple(),
                      size: 16,
                      color: context.colors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Regime Name'),
        TextField(
          controller: _nameController,
          style: AppTheme.bodyLarge,
          decoration: AppTheme.defaultInputDecoration(
            hintText: 'e.g., Deep Work',
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Condition'),
        _buildConditionCard(),
        const SizedBox(height: 24),
        _buildSectionTitle('Target Apps'),
        ElevatedButton.icon(
          onPressed: () async {
            final result = await Navigator.push<Set<String>>(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AppListScreen(initialSelection: _selectedPackages),
              ),
            );
            if (result == null || !mounted) return;
            setState(() {
              _selectedPackages = result;
            });
          },
          icon: Icon(
            PhosphorIcons.squaresFour(),
            color: context.scheme.primary,
          ),
          label: Text(
            _selectedPackages.isEmpty
                ? 'Select target apps'
                : 'Edit target apps',
            style: AppTheme.baseMedium.copyWith(color: context.scheme.primary),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            backgroundColor: context.scheme.surface,
            side: BorderSide(color: context.scheme.primary, width: 1),
          ),
        ),
        const SizedBox(height: 12),
        _buildSelectedAppIcons(),
        _buildGhostRestrictionManager(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveRegime,
            style: AppTheme.primaryButtonStyle,
            child: Text(_saving ? 'Saving...' : 'Save regime'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: AppTheme.smBold.copyWith(color: context.scheme.primary),
      ),
    );
  }

  Widget _buildTimePillList(_BlockGroup group) {
    final blocks = _blocksFor(group);
    final errors = _errorsFor(group);
    final showDelete = blocks.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(blocks.length, (index) {
        final block = blocks[index];
        final blockErrors = errors[index] ?? const <String>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: context.scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: blockErrors.isEmpty
                        ? context.scheme.outlineVariant
                        : context.colors.danger,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.clock(),
                      size: 18,
                      color: context.scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatBlockRange(block),
                        style: AppTheme.baseMedium,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        PhosphorIcons.pencilSimple(),
                        color: context.scheme.primary,
                        size: 18,
                      ),
                      onPressed: () => _editTimeBlock(group, index),
                    ),
                    if (showDelete)
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.trash(),
                          color: context.colors.danger,
                          size: 18,
                        ),
                        onPressed: () => _removeTimeBlock(group, index),
                      ),
                  ],
                ),
              ),
              if (blockErrors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    blockErrors.join(' '),
                    style: AppTheme.smRegular.copyWith(
                      color: context.colors.danger,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAddTimeButton(_BlockGroup group) {
    return Align(
      // alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _addTimeBlock(group),
        icon: Icon(PhosphorIcons.plusCircle(), color: context.scheme.primary),
        label: Text(
          'Add block',
          style: AppTheme.baseMedium.copyWith(color: context.scheme.primary),
        ),
      ),
    );
  }

  Widget _buildTipChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.colors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTheme.smMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageTimeline(List<ScheduleBlock> highlightedBlocks) {
    final hasUsage = _hourlyUsage.any((value) => value > 0);
    final maxUsage = _hourlyUsage.fold<int>(
      0,
      (max, value) => math.max(max, value),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loadingUsagePattern)
            Text(
              'Loading usage pattern...',
              style: AppTheme.smRegular.copyWith(
                color: context.colors.textSecondary,
              ),
            )
          else if (!hasUsage)
            Text(
              'No usage data yet. You can still set blocks manually.',
              style: AppTheme.smRegular.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (hour) {
                final value = _hourlyUsage[hour];
                final normalized = maxUsage == 0
                    ? 0.20
                    : (value / maxUsage).clamp(0.14, 1.0);
                final blocked = _isHourHighlighted(highlightedBlocks, hour);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: 90 * normalized,
                      decoration: BoxDecoration(
                        color: blocked
                            ? context.scheme.primary
                            : context.scheme.onSurface.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '00',
                style: AppTheme.xsMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              Text(
                '06',
                style: AppTheme.xsMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              Text(
                '12',
                style: AppTheme.xsMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              Text(
                '18',
                style: AppTheme.xsMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              Text(
                '24',
                style: AppTheme.xsMedium.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAppIcons() {
    if (_selectedPackages.isEmpty) {
      return Text(
        'No apps selected yet.',
        style: AppTheme.smRegular.copyWith(color: context.colors.textSecondary),
      );
    }

    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedPackages.length,
        itemBuilder: (context, index) {
          final packageName = _selectedPackages.elementAt(index);
          return Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.scheme.outlineVariant),
            ),
            child: ClipOval(
              child: SingleAppIcon(packageName: packageName, size: 34),
            ),
          );
        },
      ),
    );
  }

  bool _isHourHighlighted(List<ScheduleBlock> blocks, int hour) {
    if (blocks.isEmpty) return false;
    final startMinute = hour * 60;
    final endMinute = startMinute + 59;
    for (var minute = startMinute; minute <= endMinute; minute += 5) {
      if (ScheduleBlockValidator.isMinuteWithinBlocks(blocks, minute)) {
        return true;
      }
    }
    return false;
  }

  String _hourRangeText(int hour) {
    final start = TimeOfDay(hour: hour % 24, minute: 0);
    final end = TimeOfDay(hour: (hour + 1) % 24, minute: 0);
    return '${start.format(context)} - ${end.format(context)}';
  }

  Widget _buildDaySelector() {
    const shortDays = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final day = index + 1;
        final selected = _selectedDays.contains(day);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _selectedDays.remove(day);
              } else {
                _selectedDays.add(day);
                _selectedDays.sort();
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? context.scheme.primary : context.scheme.surface,
              border: Border.all(
                color: selected
                    ? context.scheme.primary
                    : context.scheme.outlineVariant,
              ),
            ),
            child: Text(
              shortDays[index],
              style: selected
                  ? AppTheme.baseBold.copyWith(color: context.scheme.onPrimary)
                  : AppTheme.baseMedium.copyWith(
                      color: context.scheme.onSurface,
                    ),
            ),
          ),
        );
      }),
    );
  }
}
