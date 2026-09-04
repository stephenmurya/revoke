import 'package:flutter/material.dart';

import '../../core/models/schedule_model.dart';
import '../../core/models/taper_plan_model.dart';

/// The v2 user-facing vocabulary. Legacy schedule types stay below this
/// boundary so native enforcement can continue to consume ScheduleModel.
enum CommitmentType { reduce, protect }

enum CommitmentStatus { active, upcoming, paused, completed, needsAttention }

class CommitmentViewModel {
  const CommitmentViewModel({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.targetApps,
    required this.summary,
    required this.sourceScheduleIds,
    required this.sourceSchedule,
    this.nextTransition,
    this.taperPlan,
    this.dailyLimitMinutes,
    this.reduceDay,
    this.durationDays,
    this.isLegacyAmbiguous = false,
  });

  final String id;
  final String name;
  final CommitmentType type;
  final CommitmentStatus status;
  final List<String> targetApps;
  final String summary;
  final String? nextTransition;
  final List<String> sourceScheduleIds;
  final ScheduleModel sourceSchedule;
  final TaperPlanModel? taperPlan;
  final int? dailyLimitMinutes;
  final int? reduceDay;
  final int? durationDays;
  final bool isLegacyAmbiguous;

  bool get isReduce => type == CommitmentType.reduce;
  bool get isActive => status == CommitmentStatus.active;

  String get typeLabel => isReduce ? 'Reduce' : 'Protect';

  String get statusLabel {
    switch (status) {
      case CommitmentStatus.active:
        return 'Active';
      case CommitmentStatus.upcoming:
        return 'Upcoming';
      case CommitmentStatus.paused:
        return 'Paused';
      case CommitmentStatus.completed:
        return 'Completed';
      case CommitmentStatus.needsAttention:
        return 'Needs attention';
    }
  }
}

class CommitmentPresentationAdapter {
  const CommitmentPresentationAdapter._();

  static List<CommitmentViewModel> fromSchedules(
    List<ScheduleModel> schedules, {
    TaperPlanModel? taperPlan,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final result = schedules
        .map(
          (schedule) => fromSchedule(
            schedule,
            taperPlan: taperPlan?.scheduleId == schedule.id ? taperPlan : null,
            now: current,
          ),
        )
        .toList();
    result.sort((a, b) {
      final statusOrder = _statusOrder(
        a.status,
      ).compareTo(_statusOrder(b.status));
      if (statusOrder != 0) return statusOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  static CommitmentViewModel fromSchedule(
    ScheduleModel schedule, {
    TaperPlanModel? taperPlan,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final isAmbiguous =
        schedule.type == ScheduleType.launchCount ||
        schedule.targetApps.isEmpty ||
        (schedule.type == ScheduleType.usageLimit &&
            (schedule.durationLimit?.inMinutes ?? 0) <= 0);
    final type = taperPlan == null
        ? CommitmentType.protect
        : CommitmentType.reduce;
    final status = _statusFor(schedule, current, isAmbiguous);

    if (taperPlan != null) {
      final day = taperPlan.dayIndexFor(current) + 1;
      return CommitmentViewModel(
        id: schedule.id,
        name: schedule.name,
        type: type,
        status: status,
        targetApps: List.unmodifiable(schedule.targetApps),
        summary:
            'Day $day of ${taperPlan.durationDays} · ${_formatMinutes(taperPlan.limitFor(current))} today',
        nextTransition:
            'Target ${_formatMinutes(taperPlan.targetDailyMinutes)}',
        sourceScheduleIds: List.unmodifiable(<String>[schedule.id]),
        sourceSchedule: schedule,
        taperPlan: taperPlan,
        reduceDay: day,
        durationDays: taperPlan.durationDays,
        dailyLimitMinutes: taperPlan.limitFor(current),
        isLegacyAmbiguous: isAmbiguous,
      );
    }

    final summary = switch (schedule.type) {
      ScheduleType.timeBlock => _timeBlockSummary(schedule),
      ScheduleType.usageLimit =>
        'Daily limit · ${_formatMinutes(schedule.durationLimit?.inMinutes ?? 0)}',
      ScheduleType.launchCount => 'Existing protection needs review',
    };

    return CommitmentViewModel(
      id: schedule.id,
      name: schedule.name,
      type: CommitmentType.protect,
      status: status,
      targetApps: List.unmodifiable(schedule.targetApps),
      summary: summary,
      nextTransition: _nextTransition(schedule),
      sourceScheduleIds: List.unmodifiable(<String>[schedule.id]),
      sourceSchedule: schedule,
      dailyLimitMinutes: schedule.durationLimit?.inMinutes,
      isLegacyAmbiguous: isAmbiguous,
    );
  }

  static CommitmentStatus _statusFor(
    ScheduleModel schedule,
    DateTime now,
    bool isAmbiguous,
  ) {
    if (isAmbiguous) return CommitmentStatus.needsAttention;
    if (!schedule.isActive) return CommitmentStatus.paused;
    if (schedule.days.isEmpty || !schedule.days.contains(now.weekday)) {
      return CommitmentStatus.upcoming;
    }
    return CommitmentStatus.active;
  }

  static int _statusOrder(CommitmentStatus status) {
    switch (status) {
      case CommitmentStatus.needsAttention:
        return 0;
      case CommitmentStatus.active:
        return 1;
      case CommitmentStatus.upcoming:
        return 2;
      case CommitmentStatus.paused:
        return 3;
      case CommitmentStatus.completed:
        return 4;
    }
  }

  static String _time(TimeOfDay time) {
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  static String _timeBlockSummary(ScheduleModel schedule) {
    if (schedule.blocks.isEmpty) return 'Protected period';
    final first = schedule.blocks.first;
    final days = schedule.days.length == 7 ? 'Every day' : _days(schedule.days);
    return '$days · ${_time(first.startTime)}–${_time(first.endTime)}';
  }

  static String? _nextTransition(ScheduleModel schedule) {
    if (schedule.type != ScheduleType.timeBlock || schedule.blocks.isEmpty) {
      return null;
    }
    final block = schedule.blocks.first;
    return '${_time(block.startTime)}–${_time(block.endTime)}';
  }

  static String _days(List<int> days) {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days
        .where((day) => day >= 1 && day <= 7)
        .map((day) => labels[day - 1])
        .join(' · ');
  }

  static String _formatMinutes(int minutes) {
    final safe = minutes.clamp(0, 1440).toInt();
    final hours = safe ~/ 60;
    final remainder = safe % 60;
    if (hours == 0) return '${remainder}m';
    if (remainder == 0) return '${hours}h';
    return '${hours}h ${remainder}m';
  }
}
