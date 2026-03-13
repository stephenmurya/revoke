import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/models/schedule_model.dart';

void main() {
  group('ScheduleModel.fromJson', () {
    test(
      'migrates legacy single-window fields into blocks and default emoji',
      () {
        final model = ScheduleModel.fromJson({
          'id': 'legacy-1',
          'name': 'Legacy',
          'type': 0,
          'targetApps': ['com.social.app'],
          'days': [1, 2, 3],
          'startHour': 9,
          'startMinute': 0,
          'endHour': 12,
          'endMinute': 0,
          'isActive': true,
        });

        expect(model.type, ScheduleType.timeBlock);
        expect(model.blocks.length, 1);
        expect(
          model.blocks.first.startTime,
          const TimeOfDay(hour: 9, minute: 0),
        );
        expect(
          model.blocks.first.endTime,
          const TimeOfDay(hour: 12, minute: 0),
        );
        expect(model.emoji, ScheduleModel.defaultEmoji);
      },
    );

    test('parses blocks array and explicit emoji', () {
      final model = ScheduleModel.fromJson({
        'id': 'multi-1',
        'name': 'Deep Work',
        'type': 0,
        'targetApps': ['com.social.app'],
        'days': [1, 2, 3, 4, 5],
        'emoji': '🧠',
        'blocks': [
          {'startHour': 9, 'startMinute': 0, 'endHour': 12, 'endMinute': 0},
          {'startHour': 13, 'startMinute': 0, 'endHour': 17, 'endMinute': 0},
        ],
      });

      expect(model.blocks.length, 2);
      expect(model.emoji, '🧠');
      expect(model.blocks[1].startTime, const TimeOfDay(hour: 13, minute: 0));
    });
  });

  group('ScheduleModel.toJson', () {
    test('writes blocks and legacy first-window compatibility fields', () {
      const blockA = ScheduleBlock(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 12, minute: 0),
      );
      const blockB = ScheduleBlock(
        startTime: TimeOfDay(hour: 13, minute: 0),
        endTime: TimeOfDay(hour: 17, minute: 0),
      );

      final model = ScheduleModel(
        id: 'model-1',
        name: 'Focus',
        type: ScheduleType.timeBlock,
        targetApps: const ['com.social.app'],
        days: const [1, 2, 3, 4, 5],
        blocks: const [blockA, blockB],
        emoji: '🎯',
      );

      final json = model.toJson();
      expect(json['blocks'], isA<List<dynamic>>());
      expect((json['blocks'] as List).length, 2);
      expect(json['startHour'], 9);
      expect(json['endHour'], 12);
      expect(json['emoji'], '🎯');
    });
  });
}
