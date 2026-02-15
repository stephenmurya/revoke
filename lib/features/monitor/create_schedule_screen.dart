import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/schedule_model.dart';
import '../../core/services/schedule_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/app_discovery_service.dart';
import 'app_list_screen.dart';
import 'widgets/single_app_icon.dart';

class CreateScheduleScreen extends StatefulWidget {
  final ScheduleModel? existingSchedule;
  const CreateScheduleScreen({super.key, this.existingSchedule});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _nameController = TextEditingController();
  ScheduleType _selectedType = ScheduleType.timeBlock;
  List<int> _selectedDays = [1, 2, 3, 4, 5];
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  int _limitHours = 1;
  int _limitMinutes = 0;
  Set<String> _selectedPackages = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      final s = widget.existingSchedule!;
      _nameController.text = s.name;
      _selectedType = s.type;
      _selectedDays = List.from(s.days);
      _startTime = s.startTime ?? _startTime;
      _endTime = s.endTime ?? _endTime;
      _selectedPackages = Set.from(s.targetApps);
      if (s.durationLimit != null) {
        _limitHours = s.durationLimit!.inHours;
        _limitMinutes = s.durationLimit!.inMinutes % 60;
      }
    }
    AppDiscoveryService.prefetch();
  }

  void _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a name')));
      return;
    }
    if (_selectedPackages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select apps')));
      return;
    }

    final schedule = ScheduleModel(
      id: widget.existingSchedule?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      type: _selectedType,
      targetApps: _selectedPackages.toList(),
      days: _selectedDays,
      startTime: _selectedType == ScheduleType.timeBlock ? _startTime : null,
      endTime: _selectedType == ScheduleType.timeBlock ? _endTime : null,
      durationLimit: _selectedType == ScheduleType.usageLimit
          ? Duration(hours: _limitHours, minutes: _limitMinutes)
          : null,
      // Always activate immediately after save; user can disable later.
      isActive: true,
    );

    await ScheduleService.saveSchedule(schedule);
    if (!mounted) return;
    // Local-first: go back immediately; cloud save happens in the background.
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingSchedule == null ? 'New regime' : 'Edit regime',
          style: AppTheme.h3,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'SAVE REGIME',
              style: AppTheme.baseMedium.copyWith(
                color: AppSemanticColors.accentText,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Name'),
            TextField(
              controller: _nameController,
              style: AppTheme.bodyLarge,
              decoration: AppTheme.defaultInputDecoration(
                hintText: 'e.g., Deep work',
              ),
            ),
            const SizedBox(height: 32),

            _buildLabel('Type'),
            Row(
              children: [
                _buildTypeButton(ScheduleType.timeBlock),
                const SizedBox(width: 12),
                _buildTypeButton(ScheduleType.usageLimit),
              ],
            ),
            const SizedBox(height: 32),

            if (_selectedType == ScheduleType.timeBlock) ...[
              _buildLabel('Blocking hours'),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Apps will be blocked during this time',
                  style: AppTheme.smRegular.copyWith(
                    color: AppSemanticColors.mutedText,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker(
                      'Block from',
                      _startTime,
                      (t) => setState(() => _startTime = t),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimePicker(
                      'Block until',
                      _endTime,
                      (t) => setState(() => _endTime = t),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _buildLabel('Daily limit'),
              Row(
                children: [
                  _buildDurationPicker(
                    'HRS',
                    _limitHours,
                    (v) => setState(() => _limitHours = v),
                    24,
                  ),
                  const SizedBox(width: 16),
                  _buildDurationPicker(
                    'MINS',
                    _limitMinutes,
                    (v) => setState(() => _limitMinutes = v),
                    60,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),

            _buildLabel('Active days'),
            _buildDaySelector(),
            const SizedBox(height: 32),

            _buildLabel('Target apps'),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<Set<String>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AppListScreen(initialSelection: _selectedPackages),
                  ),
                );
                if (result != null) setState(() => _selectedPackages = result);
              },
              icon: const Icon(Icons.apps, color: AppSemanticColors.accent),
              label: Text('Select target apps', style: AppTheme.lgMedium.copyWith(color: AppSemanticColors.accent)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppSemanticColors.surface,
                side: const BorderSide(color: AppSemanticColors.accent, width: 1),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedPackages.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedPackages.length,
                  itemBuilder: (context, index) {
                    final pkg = _selectedPackages.elementAt(index);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppSemanticColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SingleAppIcon(packageName: pkg, size: 24),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTheme.smMedium.copyWith(color: AppSemanticColors.accentText),
      ),
    );
  }

  Widget _buildTypeButton(ScheduleType type) {
    final active = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? AppSemanticColors.accent : AppSemanticColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            type.label,
            textAlign: TextAlign.center,
            style: active ? AppTheme.baseBold.copyWith(
              color: AppSemanticColors.onAccentText,
            ) : AppTheme.baseMedium.copyWith(
              color: AppSemanticColors.primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onPicked,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppSemanticColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppSemanticColors.secondaryText,
              ),
            ),
            Text(time.format(context), style: AppTheme.lgBold),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPicker(
    String label,
    int value,
    Function(int) onChanged,
    int max,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppSemanticColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButton<int>(
          value: value,
          underline: const SizedBox(),
          isExpanded: true,
          dropdownColor: AppSemanticColors.surface,
          items: List.generate(
            max,
            (i) => DropdownMenuItem(
              value: i,
              child: Text('$i $label', style: AppTheme.bodyMedium),
            ),
          ),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    final shortDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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
              }
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? AppSemanticColors.accent : AppSemanticColors.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              shortDays[index],
              style: selected ? AppTheme.baseBold.copyWith(
                color: selected
                    ? AppSemanticColors.onAccentText
                    : AppSemanticColors.primaryText,
              ) : AppTheme.baseMedium.copyWith(
                color: AppSemanticColors.primaryText,
              ),
            ),
          ),
        );
      }),
    );
  }
}
