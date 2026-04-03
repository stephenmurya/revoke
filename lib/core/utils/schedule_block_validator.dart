import '../models/schedule_model.dart';

class ScheduleBlockValidationIssue {
  final int blockIndex;
  final String message;

  const ScheduleBlockValidationIssue({
    required this.blockIndex,
    required this.message,
  });
}

class ScheduleBlockValidationResult {
  final List<ScheduleBlockValidationIssue> issues;

  const ScheduleBlockValidationResult(this.issues);

  bool get isValid => issues.isEmpty;

  String? get firstError => issues.isEmpty ? null : issues.first.message;
}

class ScheduleBlockEnforcementSegment {
  final int blockIndex;
  final int startMinute;
  final int endMinute;

  const ScheduleBlockEnforcementSegment({
    required this.blockIndex,
    required this.startMinute,
    required this.endMinute,
  });
}

class ScheduleBlockValidator {
  static const int _minutesPerDay = 1440;

  static ScheduleBlockValidationResult validate(
    List<ScheduleBlock> blocks, {
    Duration? minimumDuration = const Duration(minutes: 15),
  }) {
    final byIndex = <int, Set<String>>{};

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final duration = block.duration;
      if (duration.inMinutes <= 0) {
        _addIssue(byIndex, i, 'Block cannot start and end at the same time.');
        continue;
      }

      if (minimumDuration != null && duration < minimumDuration) {
        _addIssue(
          byIndex,
          i,
          'Block must be at least ${minimumDuration.inMinutes} minutes.',
        );
      }
    }

    final sorted =
        List<ScheduleBlockEnforcementSegment>.from(
          toEnforcementSegments(blocks),
        )..sort((a, b) {
          final byStart = a.startMinute.compareTo(b.startMinute);
          if (byStart != 0) return byStart;
          return a.endMinute.compareTo(b.endMinute);
        });

    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];
      if (previous.blockIndex == current.blockIndex) continue;
      if (current.startMinute < previous.endMinute) {
        _addIssue(
          byIndex,
          previous.blockIndex,
          'Block overlaps another block.',
        );
        _addIssue(byIndex, current.blockIndex, 'Block overlaps another block.');
      }
    }

    final issues = <ScheduleBlockValidationIssue>[];
    for (final entry in byIndex.entries) {
      for (final message in entry.value) {
        issues.add(
          ScheduleBlockValidationIssue(blockIndex: entry.key, message: message),
        );
      }
    }
    issues.sort((a, b) {
      final byIndexSort = a.blockIndex.compareTo(b.blockIndex);
      if (byIndexSort != 0) return byIndexSort;
      return a.message.compareTo(b.message);
    });
    return ScheduleBlockValidationResult(issues);
  }

  static bool isMinuteWithinBlocks(
    List<ScheduleBlock> blocks,
    int minuteOfDay,
  ) {
    final now = minuteOfDay.clamp(0, _minutesPerDay - 1);
    for (final block in blocks) {
      final start = block.startMinutes;
      final end = block.endMinutes;
      if (start < end) {
        if (now >= start && now < end) return true;
      } else if (start > end) {
        if (now >= start || now < end) return true;
      }
    }
    return false;
  }

  static int? minutesUntilCurrentBlockEnd(
    List<ScheduleBlock> blocks,
    int minuteOfDay,
  ) {
    final now = minuteOfDay.clamp(0, _minutesPerDay - 1);
    int? shortest;
    for (final block in blocks) {
      final start = block.startMinutes;
      final end = block.endMinutes;
      int? distance;
      if (start < end) {
        if (now >= start && now < end) {
          distance = end - now;
        }
      } else if (start > end) {
        if (now >= start) {
          distance = (_minutesPerDay - now) + end;
        } else if (now < end) {
          distance = end - now;
        }
      }
      if (distance != null) {
        shortest = shortest == null
            ? distance
            : distance < shortest
            ? distance
            : shortest;
      }
    }
    return shortest;
  }

  static int? minutesUntilNextBlockStart(
    List<ScheduleBlock> blocks,
    int minuteOfDay,
  ) {
    if (blocks.isEmpty) return null;
    final now = minuteOfDay.clamp(0, _minutesPerDay - 1);
    int? shortest;
    for (final block in blocks) {
      final start = block.startMinutes;
      final distance = start >= now
          ? start - now
          : (_minutesPerDay - now) + start;
      shortest = shortest == null
          ? distance
          : distance < shortest
          ? distance
          : shortest;
    }
    return shortest;
  }

  static List<ScheduleBlockEnforcementSegment> toEnforcementSegments(
    List<ScheduleBlock> blocks,
  ) {
    final segments = <ScheduleBlockEnforcementSegment>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.duration.inMinutes <= 0) continue;
      if (block.crossesMidnight) {
        segments.add(
          ScheduleBlockEnforcementSegment(
            blockIndex: i,
            startMinute: block.startMinutes,
            endMinute: _minutesPerDay,
          ),
        );
        segments.add(
          ScheduleBlockEnforcementSegment(
            blockIndex: i,
            startMinute: 0,
            endMinute: block.endMinutes,
          ),
        );
      } else {
        segments.add(
          ScheduleBlockEnforcementSegment(
            blockIndex: i,
            startMinute: block.startMinutes,
            endMinute: block.endMinutes,
          ),
        );
      }
    }
    return segments;
  }

  static Duration totalActiveDuration(List<ScheduleBlock> blocks) {
    final totalMinutes = blocks.fold<int>(
      0,
      (sum, block) => sum + block.duration.inMinutes,
    );
    return Duration(minutes: totalMinutes);
  }

  static void _addIssue(
    Map<int, Set<String>> byIndex,
    int blockIndex,
    String message,
  ) {
    byIndex.putIfAbsent(blockIndex, () => <String>{}).add(message);
  }
}
