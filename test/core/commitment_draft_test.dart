import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/models/commitment_draft.dart';
import 'package:revoke/core/models/schedule_model.dart';

void main() {
  test(
    'Protect daily-limit draft materializes the native usage-limit shape',
    () {
      const draft = CommitmentDraft(
        type: 'protect',
        name: 'No social after work',
        targetApps: ['com.example.social'],
        days: [1, 2, 3, 4, 5],
        scheduleId: 'schedule-1',
        durationLimitMinutes: 30,
      );

      final schedule = draft.toProtectSchedule();

      expect(schedule.id, 'schedule-1');
      expect(schedule.type, ScheduleType.usageLimit);
      expect(schedule.durationLimit, const Duration(minutes: 30));
      expect(schedule.blocks, isEmpty);
    },
  );

  test('Protect period draft materializes the native time-block shape', () {
    const draft = CommitmentDraft(
      type: 'protect',
      name: 'No social during work',
      targetApps: ['com.example.social'],
      days: [1, 2, 3, 4, 5],
      scheduleId: 'schedule-2',
      protectMode: 'period',
      startMinute: 540,
      endMinute: 1020,
    );

    final schedule = draft.toProtectSchedule();

    expect(schedule.type, ScheduleType.timeBlock);
    expect(schedule.blocks.single.startMinutes, 540);
    expect(schedule.blocks.single.endMinutes, 1020);
    expect(schedule.durationLimit, isNull);
  });
}
