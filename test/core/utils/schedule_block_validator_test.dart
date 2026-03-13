import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/models/schedule_model.dart';
import 'package:revoke/core/utils/schedule_block_validator.dart';

void main() {
  group('ScheduleBlockValidator.validate', () {
    test('accepts non-overlapping blocks with allowed gaps', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 13, minute: 0),
          endTime: TimeOfDay(hour: 17, minute: 0),
        ),
      ];

      final result = ScheduleBlockValidator.validate(blocks);
      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
    });

    test('rejects overlapping blocks', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 11, minute: 30),
          endTime: TimeOfDay(hour: 13, minute: 0),
        ),
      ];

      final result = ScheduleBlockValidator.validate(blocks);
      expect(result.isValid, isFalse);
      expect(
        result.issues.where((issue) => issue.message.contains('overlap')),
        isNotEmpty,
      );
    });

    test('handles cross-midnight overlap detection', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 22, minute: 0),
          endTime: TimeOfDay(hour: 2, minute: 0),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 1, minute: 30),
          endTime: TimeOfDay(hour: 3, minute: 0),
        ),
      ];

      final result = ScheduleBlockValidator.validate(blocks);
      expect(result.isValid, isFalse);
      expect(
        result.issues.where((issue) => issue.message.contains('overlap')),
        isNotEmpty,
      );
    });

    test('respects optional minimum duration rule', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 10, minute: 0),
          endTime: TimeOfDay(hour: 10, minute: 10),
        ),
      ];

      final result = ScheduleBlockValidator.validate(
        blocks,
        minimumDuration: const Duration(minutes: 15),
      );
      expect(result.isValid, isFalse);
      expect(
        result.issues.where((issue) => issue.message.contains('at least 15')),
        isNotEmpty,
      );
    });
  });

  group('ScheduleBlockValidator timeline helpers', () {
    final blocks = <ScheduleBlock>[
      const ScheduleBlock(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 12, minute: 0),
      ),
      const ScheduleBlock(
        startTime: TimeOfDay(hour: 13, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
      ),
    ];

    test('detects minute inside block and outside block', () {
      expect(
        ScheduleBlockValidator.isMinuteWithinBlocks(blocks, 9 * 60 + 30),
        isTrue,
      );
      expect(
        ScheduleBlockValidator.isMinuteWithinBlocks(blocks, 12 * 60 + 30),
        isFalse,
      );
    });

    test('computes time until current block end', () {
      final remaining = ScheduleBlockValidator.minutesUntilCurrentBlockEnd(
        blocks,
        11 * 60,
      );
      expect(remaining, 60);
    });

    test('computes time until next block start', () {
      final untilNext = ScheduleBlockValidator.minutesUntilNextBlockStart(
        blocks,
        12 * 60 + 15,
      );
      expect(untilNext, 45);
    });
  });
}
