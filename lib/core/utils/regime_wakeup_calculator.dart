import '../models/schedule_model.dart';

class RegimeWakeupCalculator {
  static int? computeNextWakeupTimestampMs(
    Iterable<ScheduleModel> schedules, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    DateTime? earliest;

    for (final schedule in schedules) {
      if (!schedule.isActive) continue;
      final candidate = _nextWakeupForSchedule(schedule, reference);
      if (candidate == null) continue;
      if (earliest == null || candidate.isBefore(earliest)) {
        earliest = candidate;
      }
    }

    return earliest?.millisecondsSinceEpoch;
  }

  static DateTime? _nextWakeupForSchedule(
    ScheduleModel schedule,
    DateTime now,
  ) {
    final days = schedule.days.toSet();
    if (days.isEmpty) return null;

    return switch (schedule.type) {
      ScheduleType.timeBlock => _nextTimeBlockStart(schedule, days, now),
      ScheduleType.usageLimit => _nextUsageLimitDayStart(days, now),
      ScheduleType.launchCount => null,
    };
  }

  static DateTime? _nextTimeBlockStart(
    ScheduleModel schedule,
    Set<int> days,
    DateTime now,
  ) {
    if (schedule.blocks.isEmpty) return null;

    final today = DateTime(now.year, now.month, now.day);
    DateTime? nextStart;

    for (var offset = 0; offset <= 7; offset++) {
      final candidateDay = today.add(Duration(days: offset));
      if (!days.contains(candidateDay.weekday)) continue;

      for (final block in schedule.blocks) {
        final candidate = DateTime(
          candidateDay.year,
          candidateDay.month,
          candidateDay.day,
          block.startTime.hour,
          block.startTime.minute,
        );
        if (!candidate.isAfter(now)) continue;
        if (nextStart == null || candidate.isBefore(nextStart)) {
          nextStart = candidate;
        }
      }
    }

    return nextStart;
  }

  static DateTime? _nextUsageLimitDayStart(Set<int> days, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    for (var offset = 1; offset <= 7; offset++) {
      final candidateDay = today.add(Duration(days: offset));
      if (days.contains(candidateDay.weekday)) {
        return candidateDay;
      }
    }

    return null;
  }
}
