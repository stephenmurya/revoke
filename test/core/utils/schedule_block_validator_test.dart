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

    test('rejects exact overlapping blocks', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
        ),
      ];

      final result = ScheduleBlockValidator.validate(blocks);
      expect(result.isValid, isFalse);
      expect(
        result.issues.where((issue) => issue.message.contains('overlap')),
        isNotEmpty,
      );
    });

    test('rejects partially overlapping blocks', () {
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
        result.issues
            .where((issue) => issue.message.contains('overlap'))
            .length,
        2,
      );
    });

    test('rejects engulfing overlapping blocks', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 8, minute: 0),
          endTime: TimeOfDay(hour: 18, minute: 0),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 10, minute: 0),
          endTime: TimeOfDay(hour: 12, minute: 0),
        ),
      ];

      final result = ScheduleBlockValidator.validate(blocks);
      expect(result.isValid, isFalse);
      expect(
        result.issues
            .where((issue) => issue.message.contains('overlap'))
            .length,
        2,
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

    test('rejects blocks shorter than fifteen minutes', () {
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

  group('ScheduleBlockValidator segment helpers', () {
    test(
      'splits a cross-midnight block into contiguous enforcement windows',
      () {
        final segments = ScheduleBlockValidator.toEnforcementSegments([
          const ScheduleBlock(
            startTime: TimeOfDay(hour: 22, minute: 0),
            endTime: TimeOfDay(hour: 2, minute: 0),
          ),
        ]);

        expect(segments, hasLength(2));
        expect(segments[0].blockIndex, 0);
        expect(segments[0].startMinute, 22 * 60);
        expect(segments[0].endMinute, 24 * 60);
        expect(segments[1].blockIndex, 0);
        expect(segments[1].startMinute, 0);
        expect(segments[1].endMinute, 2 * 60);
      },
    );

    test('sums total active duration across fragmented daily blocks', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 6, minute: 0),
          endTime: TimeOfDay(hour: 6, minute: 30),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 8, minute: 0),
          endTime: TimeOfDay(hour: 8, minute: 20),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 10, minute: 15),
          endTime: TimeOfDay(hour: 10, minute: 45),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 13, minute: 0),
          endTime: TimeOfDay(hour: 13, minute: 25),
        ),
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 18, minute: 10),
          endTime: TimeOfDay(hour: 18, minute: 50),
        ),
      ];

      final total = ScheduleBlockValidator.totalActiveDuration(blocks);
      expect(total, const Duration(minutes: 145));
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

    test('computes time until end of a cross-midnight block', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 22, minute: 0),
          endTime: TimeOfDay(hour: 2, minute: 0),
        ),
      ];

      final remaining = ScheduleBlockValidator.minutesUntilCurrentBlockEnd(
        blocks,
        23 * 60 + 30,
      );
      expect(remaining, 150);
    });

    test('computes time until next start for a cross-midnight block', () {
      final blocks = <ScheduleBlock>[
        const ScheduleBlock(
          startTime: TimeOfDay(hour: 22, minute: 0),
          endTime: TimeOfDay(hour: 2, minute: 0),
        ),
      ];

      final untilNext = ScheduleBlockValidator.minutesUntilNextBlockStart(
        blocks,
        3 * 60,
      );
      expect(untilNext, 19 * 60);
    });
  });
}
