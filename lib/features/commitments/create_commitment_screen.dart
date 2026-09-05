import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/schedule_model.dart';
import '../../core/models/taper_plan_model.dart';
import '../../core/models/commitment_draft.dart';
import '../../core/native_bridge.dart';
import '../../core/services/app_discovery_service.dart';
import '../../core/services/schedule_service.dart';
import '../../core/services/taper_plan_service.dart';
import '../../core/services/premium_entitlement_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/schedule_block_validator.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import 'commitment_presentation.dart';

class CreateCommitmentScreen extends StatefulWidget {
  const CreateCommitmentScreen({
    super.key,
    this.existingSchedule,
    this.existingPlan,
    this.onboardingMode = false,
    this.initialType,
  });

  final ScheduleModel? existingSchedule;
  final TaperPlanModel? existingPlan;

  /// Keeps the shared creation engine usable from the first-Commitment flow.
  final bool onboardingMode;
  final CommitmentType? initialType;

  @override
  State<CreateCommitmentScreen> createState() => _CreateCommitmentScreenState();
}

class _CreateCommitmentScreenState extends State<CreateCommitmentScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  CommitmentType? _type;
  int _step = 0;
  int _durationDays = 28;
  int _baselineMinutes = 0;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  List<int> _days = <int>[1, 2, 3, 4, 5];
  Set<String> _selectedPackages = <String>{};
  List<AppInfo> _apps = const <AppInfo>[];
  bool _appsLoading = false;
  bool _appsRequested = false;
  bool _baselineLoading = false;
  bool _saving = false;
  String? _error;
  String _search = '';

  bool get _isEditing => widget.existingSchedule != null;
  bool get _isReduce => _type == CommitmentType.reduce;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSchedule;
    _nameController = TextEditingController(text: existing?.name ?? '');
    if (widget.initialType != null) {
      _type = widget.initialType;
      _step = 1;
    }
    if (existing != null) {
      _type = widget.existingPlan == null
          ? CommitmentType.protect
          : CommitmentType.reduce;
      _step = 1;
      _selectedPackages = existing.targetApps.toSet();
      _days = List<int>.from(existing.days);
      if (existing.type == ScheduleType.timeBlock &&
          existing.blocks.isNotEmpty) {
        _startTime = existing.blocks.first.startTime;
        _endTime = existing.blocks.first.endTime;
        _protectMode = _ProtectMode.period;
      } else {
        _limitController.text = (existing.durationLimit?.inMinutes ?? 30)
            .toString();
        _protectMode = _ProtectMode.limit;
      }
      final plan = widget.existingPlan;
      if (plan != null) {
        _baselineMinutes = plan.baselineDailyMinutes;
        _targetController.text = plan.targetDailyMinutes.toString();
        _durationDays = _closestDuration(plan.durationDays);
      }
    }
    _searchController.addListener(() {
      if (mounted) {
        setState(() => _search = _searchController.text.trim().toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _limitController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Commitment' : _title),
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(PhosphorIcons.arrowLeft),
          onPressed: _goBack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(step: _step, total: 4),
            Expanded(
              child: Column(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        RevokeSpacing.lg,
                        RevokeSpacing.sm,
                        RevokeSpacing.lg,
                        0,
                      ),
                      child: RevokeSurface(
                        color: context.colors.warning.withValues(alpha: 0.10),
                        child: Text(_error!, style: context.text.bodyMedium),
                      ),
                    ),
                  Expanded(child: _buildStep()),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  String get _title {
    if (_step == 0) return 'Create Commitment';
    if (_step == 1) return 'Choose apps';
    if (_step == 2) return _isReduce ? 'Set your target' : 'Set your boundary';
    return 'Review Commitment';
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildIntentStep();
      case 1:
        return _buildAppStep();
      case 2:
        return _buildConfigurationStep();
      default:
        return _buildReviewStep();
    }
  }

  Widget _buildIntentStep() {
    return ListView(
      padding: const EdgeInsets.all(RevokeSpacing.lg),
      children: [
        Text('What do you want to do?', style: context.text.headlineSmall),
        const SizedBox(height: RevokeSpacing.sm),
        Text(
          'Choose the kind of boundary that fits your goal.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: RevokeSpacing.xl),
        _IntentOption(
          icon: PhosphorIcons.trendDown,
          title: 'Reduce',
          description: 'Gradually use selected apps less over a defined plan.',
          selected: _type == CommitmentType.reduce,
          onTap: () => setState(() => _type = CommitmentType.reduce),
        ),
        const SizedBox(height: RevokeSpacing.md),
        _IntentOption(
          icon: PhosphorIcons.shieldCheck,
          title: 'Protect',
          description: 'Create a clear boundary Revoke can enforce.',
          selected: _type == CommitmentType.protect,
          onTap: () => setState(() => _type = CommitmentType.protect),
        ),
      ],
    );
  }

  Widget _buildAppStep() {
    if (_apps.isEmpty && !_appsLoading && !_appsRequested) {
      _appsRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadApps());
    }
    if (_appsLoading) {
      return const RevokeLoadingState(label: 'Loading installed apps');
    }
    final visible = _apps.where((app) {
      if (_search.isEmpty) return true;
      return app.name.toLowerCase().contains(_search) ||
          app.packageName.toLowerCase().contains(_search);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RevokeSpacing.lg,
            RevokeSpacing.sm,
            RevokeSpacing.lg,
            RevokeSpacing.md,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search installed apps',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: Icon(PhosphorIcons.x),
                      onPressed: _searchController.clear,
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RevokeSpacing.lg),
          child: Text(
            '${_selectedPackages.length} selected',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: RevokeSpacing.sm),
        Expanded(
          child: visible.isEmpty
              ? const RevokeEmptyState(title: 'No matching apps')
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final app = visible[index];
                    final selected = _selectedPackages.contains(
                      app.packageName,
                    );
                    return _AppSelectionRow(
                      app: app,
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedPackages.remove(app.packageName);
                        } else {
                          _selectedPackages.add(app.packageName);
                        }
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConfigurationStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        RevokeSpacing.lg,
        RevokeSpacing.sm,
        RevokeSpacing.lg,
        RevokeSpacing.xxl,
      ),
      children: [
        if (_isReduce)
          _buildReduceConfiguration()
        else
          _buildProtectConfiguration(),
      ],
    );
  }

  Widget _buildReduceConfiguration() {
    final target = int.tryParse(_targetController.text) ?? 0;
    final hasBaseline = _baselineMinutes >= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Measured starting point', style: context.text.titleMedium),
        const SizedBox(height: RevokeSpacing.xs),
        if (_baselineLoading)
          const LinearProgressIndicator()
        else if (!hasBaseline)
          RevokeSurface(
            color: context.colors.warning.withValues(alpha: 0.10),
            child: Text(
              _error ??
                  'Revoke needs Usage Access data for these apps before it can build a plan.',
              style: context.text.bodyMedium,
            ),
          )
        else
          Text(
            '${_formatMinutes(_baselineMinutes)} per day on average',
            style: AppTheme.numericDisplay,
          ),
        const SizedBox(height: RevokeSpacing.xl),
        Text('Daily target', style: context.text.titleMedium),
        const SizedBox(height: RevokeSpacing.xs),
        Text(
          'Set the final daily allowance. Revoke will taper toward it.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: RevokeSpacing.md),
        TextField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes per day'),
          onChanged: (_) => setState(() {}),
        ),
        if (hasBaseline) ...[
          const SizedBox(height: RevokeSpacing.md),
          Slider(
            value: target.clamp(5, _baselineMinutes).toDouble(),
            min: 5,
            max: _baselineMinutes.toDouble(),
            divisions: ((_baselineMinutes - 5) / 5)
                .floor()
                .clamp(1, 287)
                .toInt(),
            label: '$target min',
            onChanged: (value) {
              final next = (value / 5).round() * 5;
              _targetController.text = next.toString();
              setState(() {});
            },
          ),
        ],
        const SizedBox(height: RevokeSpacing.lg),
        Text('Taper duration', style: context.text.titleMedium),
        const SizedBox(height: RevokeSpacing.sm),
        _DurationChoices(
          value: _durationDays,
          onChanged: (value) => setState(() => _durationDays = value),
        ),
      ],
    );
  }

  Widget _buildProtectConfiguration() {
    final isTime = _protectMode == _ProtectMode.period;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What kind of boundary?', style: context.text.titleMedium),
        const SizedBox(height: RevokeSpacing.sm),
        SegmentedButton<_ProtectMode>(
          segments: const [
            ButtonSegment(
              value: _ProtectMode.limit,
              label: Text('Daily limit'),
            ),
            ButtonSegment(
              value: _ProtectMode.period,
              label: Text('Protected period'),
            ),
          ],
          selected: <_ProtectMode>{
            isTime ? _ProtectMode.period : _ProtectMode.limit,
          },
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            setState(() => _protectMode = selection.first);
          },
        ),
        const SizedBox(height: RevokeSpacing.xl),
        if (isTime) _buildPeriodFields() else _buildLimitFields(),
      ],
    );
  }

  _ProtectMode _protectMode = _ProtectMode.limit;

  Widget _buildLimitFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Keep usage below a daily limit.', style: context.text.bodyMedium),
        const SizedBox(height: RevokeSpacing.md),
        TextField(
          controller: _limitController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes per day'),
        ),
        const SizedBox(height: RevokeSpacing.xl),
        _buildDayPicker(),
      ],
    );
  }

  Widget _buildPeriodFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stay off selected apps during this period.',
          style: context.text.bodyMedium,
        ),
        const SizedBox(height: RevokeSpacing.md),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: 'Starts',
                value: _startTime,
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: RevokeSpacing.md),
            Expanded(
              child: _TimeButton(
                label: 'Ends',
                value: _endTime,
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
        const SizedBox(height: RevokeSpacing.xl),
        _buildDayPicker(),
      ],
    );
  }

  Widget _buildDayPicker() {
    const labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Active days', style: context.text.titleMedium),
        const SizedBox(height: RevokeSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final day = index + 1;
            final selected = _days.contains(day);
            return Semantics(
              label:
                  '${_dayName(day)} ${selected ? 'selected' : 'not selected'}',
              child: ChoiceChip(
                label: Text(labels[index]),
                selected: selected,
                onSelected: (value) => setState(() {
                  if (value) {
                    _days = {..._days, day}.toList()..sort();
                  } else {
                    _days.remove(day);
                  }
                }),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final appNames = _selectedAppNames;
    final preview = _isReduce ? _previewPlan() : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        RevokeSpacing.lg,
        RevokeSpacing.sm,
        RevokeSpacing.lg,
        RevokeSpacing.xxl,
      ),
      children: [
        Text('Make it yours', style: context.text.titleMedium),
        const SizedBox(height: RevokeSpacing.md),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Commitment name'),
        ),
        const SizedBox(height: RevokeSpacing.xl),
        RevokeSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isReduce ? 'Reduce' : 'Protect',
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.accent,
                ),
              ),
              const SizedBox(height: RevokeSpacing.sm),
              Text(appNames.join(', '), style: context.text.titleMedium),
              const SizedBox(height: RevokeSpacing.md),
              if (_isReduce && preview != null) ...[
                Text(
                  'Starting point · ${_formatMinutes(_baselineMinutes)} per day',
                ),
                Text(
                  'Target · ${_formatMinutes(preview.targetDailyMinutes)} per day',
                ),
                Text('Duration · ${_durationDays ~/ 7} weeks'),
                const SizedBox(height: RevokeSpacing.lg),
                const RevokeSectionHeader(title: 'Plan preview'),
                const SizedBox(height: RevokeSpacing.sm),
                ..._previewRows(preview),
              ] else if (_protectMode == _ProtectMode.limit) ...[
                Text('Daily limit · ${_formatMinutes(_limitMinutes)}'),
                Text(_daysLabel),
              ] else ...[
                Text(
                  'Protected period · ${_timeLabel(_startTime)}–${_timeLabel(_endTime)}',
                ),
                Text(_daysLabel),
              ],
            ],
          ),
        ),
        const SizedBox(height: RevokeSpacing.lg),
        Text(
          'Revoke will save this Commitment locally first, then synchronize it to the existing enforcement system.',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Widget> _previewRows(TaperPlanModel plan) {
    final indices = <int>{
      0,
      plan.durationDays ~/ 3,
      (plan.durationDays * 2) ~/ 3,
      plan.durationDays - 1,
    }.toList()..sort();
    return indices.map((index) {
      final value =
          plan.dailyLimits[index.clamp(0, plan.dailyLimits.length - 1)];
      return Padding(
        padding: const EdgeInsets.only(bottom: RevokeSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text('Day ${index + 1}')),
            Text(_formatMinutes(value), style: AppTheme.numericStat),
          ],
        ),
      );
    }).toList();
  }

  Widget? _buildBottomBar() {
    if (_step == 0 && _type == null) return null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RevokeSpacing.lg,
          RevokeSpacing.sm,
          RevokeSpacing.lg,
          RevokeSpacing.lg,
        ),
        child: Row(
          children: [
            Expanded(
              child: RevokeButton(
                label: _step == 0 ? 'Cancel' : 'Back',
                variant: RevokeButtonVariant.secondary,
                onPressed: _goBack,
              ),
            ),
            const SizedBox(width: RevokeSpacing.md),
            Expanded(
              child: RevokeButton(
                label: _step == 3 ? 'Activate' : 'Continue',
                loading: _saving,
                onPressed: _saving ? null : _goNext,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadApps() async {
    setState(() => _appsLoading = true);
    final apps = await AppDiscoveryService.getApps();
    if (!mounted) return;
    setState(() {
      _apps = apps.where((app) => !app.isSystemApp && !app.isGhost).toList();
      _appsLoading = false;
    });
  }

  Future<void> _loadBaseline() async {
    if (!_isReduce ||
        widget.existingPlan != null ||
        _selectedPackages.isEmpty) {
      return;
    }
    setState(() {
      _baselineLoading = true;
      _error = null;
    });
    try {
      final permissions = await NativeBridge.checkPermissions();
      if (permissions['usage_stats'] != true) {
        if (mounted) {
          setState(
            () =>
                _error = 'Grant Usage Access to measure your current behavior.',
          );
        }
        return;
      }
      final results = await Future.wait(
        _selectedPackages.map(
          (packageName) => NativeBridge.getUsageInsights(
            mode: 'week',
            anchorDateMs: DateTime.now().millisecondsSinceEpoch,
            packageName: packageName,
            periodDays: 7,
          ),
        ),
      );
      final minutes = results.fold<int>(0, (total, result) {
        final value = result['averageDailyMinutes'];
        return total + (value is num ? value.toInt() : 0);
      });
      if (mounted) {
        setState(() {
          _baselineMinutes = minutes;
          if (minutes >= 5 && _targetController.text.trim().isEmpty) {
            _targetController.text = (minutes * 0.5)
                .round()
                .clamp(5, minutes)
                .toString();
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Current usage could not be measured. Check Usage Access and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _baselineLoading = false);
      }
    }
  }

  Future<void> _goNext() async {
    if (_step == 0) {
      if (_type == null) return;
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_selectedPackages.isEmpty) {
        setState(() => _error = 'Select at least one app.');
        return;
      }
      if (_isReduce) await _loadBaseline();
      if (!mounted) return;
      if (_isReduce && _baselineMinutes < 5) return;
      setState(() {
        _error = null;
        _step = 2;
      });
      return;
    }
    if (_step == 2) {
      if (!_validateConfiguration()) return;
      setState(() => _step = 3);
      return;
    }
    await _save();
  }

  bool _validateConfiguration() {
    if (_days.isEmpty) {
      setState(() => _error = 'Select at least one active day.');
      return false;
    }
    if (_isReduce) {
      final target = int.tryParse(_targetController.text.trim()) ?? 0;
      if (_baselineMinutes < 5) {
        setState(
          () => _error =
              'A measured starting point is required before a Reduce plan can be activated.',
        );
        return false;
      }
      if (target < 5 || target >= _baselineMinutes) {
        setState(
          () => _error = 'Set a target below the measured starting point.',
        );
        return false;
      }
      return true;
    }
    if (_protectMode == _ProtectMode.limit) {
      if (_limitMinutes < 5 || _limitMinutes > 1440) {
        setState(
          () => _error = 'Set a daily limit between 5 minutes and 24 hours.',
        );
        return false;
      }
      return true;
    }
    final result = ScheduleBlockValidator.validate(<ScheduleBlock>[
      ScheduleBlock(startTime: _startTime, endTime: _endTime),
    ], minimumDuration: const Duration(minutes: 15));
    if (!result.isValid) {
      setState(
        () => _error =
            result.firstError ??
            'Choose a protected period of at least 15 minutes.',
      );
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validateConfiguration()) return;
    final name = _nameController.text.trim().isEmpty
        ? _defaultName
        : _nameController.text.trim();

    // Onboarding owns commercial, authority, and final activation sequencing.
    // Return a durable configuration draft instead of creating an active
    // schedule that could exist while the user is still deciding.
    if (widget.onboardingMode && !_isEditing) {
      if (mounted) Navigator.pop(context, _buildDraft(name));
      return;
    }

    if (!_isEditing) {
      final entitlement = PremiumEntitlementService.instance;
      if (entitlement.state.value.isLoading) await entitlement.refresh();
      if (_isReduce && !entitlement.hasPremium) {
        if (mounted) {
          context.push(
            '/premium',
            extra: 'Reduce Commitments are available with Premium.',
          );
        }
        return;
      }
      if (!_isReduce && !entitlement.hasPremium) {
        final existingSchedules = await ScheduleService.getSchedules();
        final activeTaperPlans =
            await TaperPlanService.getActivePlansForCapability();
        final taperScheduleIds = activeTaperPlans
            .map((plan) => plan.scheduleId)
            .where((id) => id.trim().isNotEmpty)
            .toSet();
        final activeProtectCount = existingSchedules.where((schedule) {
          final active = schedule.isActive != false;
          return active &&
              !taperScheduleIds.contains(schedule.id) &&
              (schedule.type == ScheduleType.timeBlock ||
                  schedule.type == ScheduleType.usageLimit);
        }).length;
        if (!entitlement.canCreateProtect(
          activeProtectCount: activeProtectCount,
        )) {
          if (mounted) {
            context.push(
              '/premium',
              extra: 'Premium lets you add more active Protect Commitments.',
            );
          }
          return;
        }
      }
      if (_isReduce || entitlement.hasPremium) {
        try {
          final allowed = await entitlement.assertServerCapability(
            _isReduce ? 'reduce_commitment' : 'additional_protect_commitment',
          );
          if (!allowed) {
            if (mounted) {
              context.push(
                '/premium',
                extra: 'This Commitment requires Premium.',
              );
            }
            return;
          }
        } catch (_) {
          if (mounted) {
            setState(
              () => _error =
                  'Premium access could not be verified. Check your connection and try again.',
            );
          }
          return;
        }
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? savedId;
    try {
      if (_isReduce) {
        final existing = widget.existingPlan;
        final plan = existing == null
            ? TaperPlanService.buildLinearPlan(
                name: name,
                targetApps: _selectedPackages.toList(),
                baselineDailyMinutes: _baselineMinutes,
                targetDailyMinutes: int.parse(_targetController.text.trim()),
                durationDays: _durationDays,
              )
            : existing.copyWith(
                name: name,
                targetApps: _selectedPackages.toList(),
                baselineDailyMinutes: _baselineMinutes,
                targetDailyMinutes: int.parse(_targetController.text.trim()),
                durationDays: _durationDays,
                updatedAt: DateTime.now(),
              );
        await TaperPlanService.savePlanLocalFirst(plan);
        savedId = plan.scheduleId;
      } else {
        final existing = widget.existingSchedule;
        final isTime = _protectMode == _ProtectMode.period;
        final schedule = ScheduleModel(
          id: existing?.id ?? const Uuid().v4(),
          name: name,
          type: isTime ? ScheduleType.timeBlock : ScheduleType.usageLimit,
          targetApps: _selectedPackages.toList(),
          days: List<int>.from(_days)..sort(),
          blocks: isTime
              ? <ScheduleBlock>[
                  ScheduleBlock(startTime: _startTime, endTime: _endTime),
                ]
              : const <ScheduleBlock>[],
          durationLimit: isTime ? null : Duration(minutes: _limitMinutes),
          isActive: existing?.isActive ?? true,
          emoji: existing?.emoji ?? ScheduleModel.defaultEmoji,
          activatedAt: existing?.activatedAt,
        );
        await ScheduleService.saveSchedule(schedule);
        savedId = schedule.id;
      }
      if (mounted) Navigator.pop(context, savedId);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'The Commitment could not be saved. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  CommitmentDraft _buildDraft(String name) {
    if (_isReduce) {
      final planId = const Uuid().v4();
      return CommitmentDraft(
        type: CommitmentType.reduce.name,
        name: name,
        targetApps: _selectedPackages.toList(),
        days: List<int>.from(_days)..sort(),
        scheduleId: 'taper_schedule_$planId',
        planId: planId,
        baselineDailyMinutes: _baselineMinutes,
        targetDailyMinutes: int.parse(_targetController.text.trim()),
        durationDays: _durationDays,
      );
    }
    return CommitmentDraft(
      type: CommitmentType.protect.name,
      name: name,
      targetApps: _selectedPackages.toList(),
      days: List<int>.from(_days)..sort(),
      scheduleId: const Uuid().v4(),
      protectMode: _protectMode == _ProtectMode.period ? 'period' : 'limit',
      durationLimitMinutes: _protectMode == _ProtectMode.limit
          ? _limitMinutes
          : null,
      startMinute: _startTime.hour * 60 + _startTime.minute,
      endMinute: _endTime.hour * 60 + _endTime.minute,
    );
  }

  void _goBack() {
    if (_step == 0 || (_step == 1 && _isEditing)) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  TaperPlanModel? _previewPlan() {
    if (_baselineMinutes < 5) return null;
    final target = int.tryParse(_targetController.text.trim());
    if (target == null || target < 5 || target >= _baselineMinutes) return null;
    return TaperPlanModel(
      id: 'preview',
      scheduleId: 'preview',
      targetApps: _selectedPackages.toList(),
      baselineDailyMinutes: _baselineMinutes,
      targetDailyMinutes: target,
      durationDays: _durationDays,
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      status: 'active',
      name: _nameController.text.trim().isEmpty
          ? _defaultName
          : _nameController.text.trim(),
    );
  }

  List<String> get _selectedAppNames {
    final byPackage = {for (final app in _apps) app.packageName: app.name};
    return _selectedPackages.map((pkg) => byPackage[pkg] ?? pkg).toList();
  }

  String get _defaultName {
    final names = _selectedAppNames;
    final subject = names.isEmpty
        ? 'selected apps'
        : names.take(2).join(' and ');
    return '${_isReduce ? 'Reduce' : 'Protect'} $subject';
  }

  int get _limitMinutes => int.tryParse(_limitController.text.trim()) ?? 0;
  String get _daysLabel =>
      _days.length == 7 ? 'Every day' : _days.map(_dayName).join(' · ');

  static String _dayName(int day) => const <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][day - 1];
  static String _timeLabel(TimeOfDay time) {
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _formatMinutes(int minutes) {
    final safe = minutes.clamp(0, 1440).toInt();
    final hours = safe ~/ 60;
    final remainder = safe % 60;
    if (hours == 0) return '$remainder min';
    if (remainder == 0) return '$hours hr';
    return '$hours hr $remainder min';
  }

  static int _closestDuration(int days) {
    const options = <int>[14, 28, 42, 56];
    return options.reduce(
      (a, b) => (days - a).abs() <= (days - b).abs() ? a : b,
    );
  }
}

enum _ProtectMode { limit, period }

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.total});
  final int step;
  final int total;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RevokeSpacing.lg,
        RevokeSpacing.sm,
        RevokeSpacing.lg,
        0,
      ),
      child: LinearProgressIndicator(value: (step + 1) / total),
    );
  }
}

class _IntentOption extends StatelessWidget {
  const _IntentOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $description',
      child: InkWell(
        onTap: onTap,
        borderRadius: RevokeRadii.cardRadius,
        child: RevokeSurface(
          color: selected ? context.colors.accentSoft : null,
          bordered: selected,
          child: Row(
            children: [
              Icon(
                icon,
                size: RevokeIconSizes.feature,
                color: context.colors.accent,
              ),
              const SizedBox(width: RevokeSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    const SizedBox(height: RevokeSpacing.xs),
                    Text(
                      description,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(PhosphorIcons.check, color: context.colors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppSelectionRow extends StatelessWidget {
  const _AppSelectionRow({
    required this.app,
    required this.selected,
    required this.onTap,
  });
  final AppInfo app;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: app.name,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RevokeSpacing.lg,
            vertical: RevokeSpacing.sm,
          ),
          child: Row(
            children: [
              _AppIcon(app: app),
              const SizedBox(width: RevokeSpacing.md),
              Expanded(child: Text(app.name, style: context.text.bodyLarge)),
              Checkbox(value: selected, onChanged: (_) => onTap()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app});
  final AppInfo app;
  @override
  Widget build(BuildContext context) {
    if (app.icon != null && app.icon!.isNotEmpty) {
      return ClipRRect(
        borderRadius: RevokeRadii.controlRadius,
        child: Image.memory(
          Uint8List.fromList(app.icon!),
          width: RevokeIconSizes.feature,
          height: RevokeIconSizes.feature,
        ),
      );
    }
    return Icon(
      PhosphorIcons.androidLogo,
      size: RevokeIconSizes.feature,
      color: context.colors.textMuted,
    );
  }
}

class _DurationChoices extends StatelessWidget {
  const _DurationChoices({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    const options = <int>[14, 28, 42, 56];
    return Wrap(
      spacing: RevokeSpacing.sm,
      runSpacing: RevokeSpacing.sm,
      children: options
          .map(
            (days) => ChoiceChip(
              label: Text('${days ~/ 7} weeks'),
              selected: value == days,
              onSelected: (_) => onChanged(days),
            ),
          )
          .toList(),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, RevokeTouchTargets.minimum),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: RevokeSpacing.lg,
          vertical: RevokeSpacing.md,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          Text(value.format(context), style: context.text.titleMedium),
        ],
      ),
    );
  }
}
