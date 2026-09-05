import 'package:flutter/material.dart';

import 'schedule_model.dart';
import 'taper_plan_model.dart';

/// The persisted onboarding representation of a Commitment before activation.
///
/// This is deliberately a configuration object, not a second enforcement
/// model. It carries enough information to resume the flow after process death
/// and materializes the existing ScheduleModel/TaperPlanModel only at the
/// coordinated activation boundary.
class CommitmentDraft {
  const CommitmentDraft({
    required this.type,
    required this.name,
    required this.targetApps,
    required this.days,
    required this.scheduleId,
    this.planId,
    this.protectMode = 'limit',
    this.durationLimitMinutes,
    this.startMinute,
    this.endMinute,
    this.baselineDailyMinutes,
    this.targetDailyMinutes,
    this.durationDays,
  });

  final String type;
  final String name;
  final List<String> targetApps;
  final List<int> days;
  final String scheduleId;
  final String? planId;
  final String protectMode;
  final int? durationLimitMinutes;
  final int? startMinute;
  final int? endMinute;
  final int? baselineDailyMinutes;
  final int? targetDailyMinutes;
  final int? durationDays;

  bool get isReduce => type == 'reduce';
  bool get isProtectPeriod => !isReduce && protectMode == 'period';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'name': name,
    'targetApps': targetApps,
    'days': days,
    'scheduleId': scheduleId,
    'planId': planId,
    'protectMode': protectMode,
    'durationLimitMinutes': durationLimitMinutes,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'baselineDailyMinutes': baselineDailyMinutes,
    'targetDailyMinutes': targetDailyMinutes,
    'durationDays': durationDays,
  };

  factory CommitmentDraft.fromJson(Map<String, dynamic> json) {
    int? integer(dynamic value) {
      return switch (value) {
        num() => value.toInt(),
        String() => int.tryParse(value),
        _ => null,
      };
    }

    List<String> strings(dynamic value) => (value is List ? value : const [])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);

    List<int> integers(dynamic value) =>
        (value is List ? value : const [])
            .map(integer)
            .whereType<int>()
            .where((day) => day >= 1 && day <= 7)
            .toSet()
            .toList()
          ..sort();

    final rawType = json['type']?.toString().trim().toLowerCase();
    final scheduleId = json['scheduleId']?.toString().trim() ?? '';
    if ((rawType != 'reduce' && rawType != 'protect') || scheduleId.isEmpty) {
      throw const FormatException('INVALID_COMMITMENT_DRAFT');
    }
    return CommitmentDraft(
      type: rawType!,
      name: json['name']?.toString().trim() ?? '',
      targetApps: strings(json['targetApps']),
      days: integers(json['days']),
      scheduleId: scheduleId,
      planId: json['planId']?.toString().trim(),
      protectMode: json['protectMode']?.toString().trim() == 'period'
          ? 'period'
          : 'limit',
      durationLimitMinutes: integer(json['durationLimitMinutes']),
      startMinute: integer(json['startMinute']),
      endMinute: integer(json['endMinute']),
      baselineDailyMinutes: integer(json['baselineDailyMinutes']),
      targetDailyMinutes: integer(json['targetDailyMinutes']),
      durationDays: integer(json['durationDays']),
    );
  }

  ScheduleModel toProtectSchedule() {
    if (isReduce) {
      throw StateError('Reduce drafts materialize as taper plans.');
    }
    final start = _time(startMinute ?? 9 * 60);
    final end = _time(endMinute ?? 17 * 60);
    return ScheduleModel(
      id: scheduleId,
      name: _effectiveName,
      type: isProtectPeriod ? ScheduleType.timeBlock : ScheduleType.usageLimit,
      targetApps: List<String>.from(targetApps),
      days: List<int>.from(days)..sort(),
      blocks: isProtectPeriod
          ? <ScheduleBlock>[ScheduleBlock(startTime: start, endTime: end)]
          : const <ScheduleBlock>[],
      durationLimit: isProtectPeriod
          ? null
          : Duration(minutes: durationLimitMinutes ?? 30),
      isActive: true,
      emoji: ScheduleModel.defaultEmoji,
    );
  }

  TaperPlanModel toReducePlan() {
    if (!isReduce) throw StateError('Protect drafts do not materialize plans.');
    final planIdValue = planId?.trim();
    if (planIdValue == null || planIdValue.isEmpty) {
      throw const FormatException('MISSING_TAPER_PLAN_ID');
    }
    final now = DateTime.now();
    return TaperPlanModel(
      id: planIdValue,
      scheduleId: scheduleId,
      name: _effectiveName,
      status: 'active',
      targetApps: List<String>.from(targetApps),
      baselineDailyMinutes: baselineDailyMinutes ?? 0,
      targetDailyMinutes: targetDailyMinutes ?? 0,
      durationDays: durationDays ?? 28,
      startDate: DateTime(now.year, now.month, now.day),
      createdAt: now,
      updatedAt: now,
    );
  }

  String get _effectiveName =>
      name.trim().isEmpty ? 'My Commitment' : name.trim();

  static TimeOfDay _time(int minute) {
    final safe = minute.clamp(0, 1439).toInt();
    return TimeOfDay(hour: safe ~/ 60, minute: safe % 60);
  }
}
