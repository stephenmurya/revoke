import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/models/schedule_model.dart';
import 'package:revoke/core/models/taper_plan_model.dart';
import 'package:revoke/features/commitments/commitment_presentation.dart';

ScheduleModel _schedule({
  required ScheduleType type,
  String id = 'schedule-1',
  Duration? limit,
  List<ScheduleBlock> blocks = const <ScheduleBlock>[],
}) {
  return ScheduleModel(
    id: id,
    name: 'Social apps',
    type: type,
    targetApps: const <String>['com.example.social'],
    days: const <int>[1, 2, 3, 4, 5, 6, 7],
    durationLimit: limit,
    blocks: blocks,
  );
}

void main() {
  test('maps a usage-limit schedule to a Protect daily-limit Commitment', () {
    final view = CommitmentPresentationAdapter.fromSchedule(
      _schedule(
        type: ScheduleType.usageLimit,
        limit: const Duration(minutes: 30),
      ),
      now: DateTime(2026, 9, 4),
    );

    expect(view.type, CommitmentType.protect);
    expect(view.status, CommitmentStatus.active);
    expect(view.summary, contains('Daily limit'));
    expect(view.dailyLimitMinutes, 30);
  });

  test('maps a time-block schedule to a Protect period Commitment', () {
    final view = CommitmentPresentationAdapter.fromSchedule(
      _schedule(
        type: ScheduleType.timeBlock,
        blocks: const <ScheduleBlock>[
          ScheduleBlock(
            startTime: TimeOfDay(hour: 9, minute: 0),
            endTime: TimeOfDay(hour: 17, minute: 0),
          ),
        ],
      ),
      now: DateTime(2026, 9, 4),
    );

    expect(view.type, CommitmentType.protect);
    expect(view.summary, contains('9:00 AM'));
    expect(view.summary, contains('5:00 PM'));
  });

  test('maps a taper materialized schedule to Reduce with plan metadata', () {
    final plan = TaperPlanModel(
      id: 'plan-1',
      scheduleId: 'schedule-1',
      status: 'active',
      targetApps: const <String>['com.example.social'],
      baselineDailyMinutes: 120,
      targetDailyMinutes: 45,
      durationDays: 28,
      startDate: DateTime(2026, 9, 1),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
    final view = CommitmentPresentationAdapter.fromSchedule(
      _schedule(
        type: ScheduleType.usageLimit,
        limit: const Duration(minutes: 120),
      ),
      taperPlan: plan,
      now: DateTime(2026, 9, 4),
    );

    expect(view.type, CommitmentType.reduce);
    expect(view.taperPlan, plan);
    expect(view.reduceDay, 4);
    expect(view.summary, contains('Day 4 of 28'));
  });

  test('uses a conservative attention state for ambiguous legacy data', () {
    final view = CommitmentPresentationAdapter.fromSchedule(
      _schedule(type: ScheduleType.launchCount),
      now: DateTime(2026, 9, 4),
    );

    expect(view.type, CommitmentType.protect);
    expect(view.status, CommitmentStatus.needsAttention);
    expect(view.isLegacyAmbiguous, isTrue);
    expect(view.summary, contains('needs review'));
  });
}
