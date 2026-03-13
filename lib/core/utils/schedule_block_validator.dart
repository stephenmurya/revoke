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

class ScheduleBlockValidator {
  static const int _minutesPerDay = 1440;

  static ScheduleBlockValidationResult validate(
    List<ScheduleBlock> blocks, {
    Duration? minimumDuration = const Duration(minutes: 15),
  }) {
    final byIndex = <int, Set<String>>{};
    final segments = <_BlockSegment>[];

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

      if (block.crossesMidnight) {
        segments.add(
          _BlockSegment(
            index: i,
            start: block.startMinutes,
            end: _minutesPerDay,
          ),
        );
        segments.add(_BlockSegment(index: i, start: 0, end: block.endMinutes));
      } else {
        segments.add(
          _BlockSegment(
            index: i,
            start: block.startMinutes,
            end: block.endMinutes,
          ),
        );
      }
    }

    final sorted = List<_BlockSegment>.from(segments)
      ..sort((a, b) {
        final byStart = a.start.compareTo(b.start);
        if (byStart != 0) return byStart;
        return a.end.compareTo(b.end);
      });

    for (var i = 1; i < sorted.length; i++) {
      final previous = sorted[i - 1];
      final current = sorted[i];
      if (previous.index == current.index) continue;
      if (current.start < previous.end) {
        _addIssue(byIndex, previous.index, 'Block overlaps another block.');
        _addIssue(byIndex, current.index, 'Block overlaps another block.');
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

  static void _addIssue(
    Map<int, Set<String>> byIndex,
    int blockIndex,
    String message,
  ) {
    byIndex.putIfAbsent(blockIndex, () => <String>{}).add(message);
  }
}

class _BlockSegment {
  final int index;
  final int start;
  final int end;

  const _BlockSegment({
    required this.index,
    required this.start,
    required this.end,
  });
}
