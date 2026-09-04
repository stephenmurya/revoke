import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/models/schedule_model.dart';
import 'package:revoke/core/models/taper_plan_model.dart';
import 'package:revoke/core/services/theme_service.dart';
import 'package:revoke/core/theme/app_theme.dart';
import 'package:revoke/features/today/today_screen.dart';

void main() {
  testWidgets('Today gives users one clear action with no Commitments', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const TodayViewData()));

    expect(find.text('No active Commitments today'), findsOneWidget);
    expect(find.text('Create a Commitment'), findsOneWidget);
    expect(find.text('Focus Score'), findsNothing);
  });

  testWidgets('Today presents truthful usage and remaining time', (
    tester,
  ) async {
    final schedule = _schedule(type: ScheduleType.usageLimit);
    final data = TodayViewData(
      schedules: [schedule],
      usage: {
        schedule.id: const TodayUsageStatus(
          usedMillis: 40 * 60 * 1000,
          limitMillis: 80 * 60 * 1000,
        ),
      },
    );
    await tester.pumpWidget(_app(data));

    expect(find.text('40m used of 1h 20m'), findsOneWidget);
    expect(find.text('40m left'), findsOneWidget);
    expect(find.textContaining('daily usage limit'), findsOneWidget);
    expect(find.text('Focus Score'), findsNothing);
  });

  testWidgets('Today identifies an active protected period', (tester) async {
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final endMinute = (now.hour * 60 + now.minute + 1) % 1440;
    final schedule = _schedule(
      type: ScheduleType.timeBlock,
      blocks: [
        ScheduleBlock(
          startTime: now,
          endTime: TimeOfDay(hour: endMinute ~/ 60, minute: endMinute % 60),
        ),
      ],
    );
    await tester.pumpWidget(_app(TodayViewData(schedules: [schedule])));

    expect(find.text('A protected period is active'), findsOneWidget);
    expect(find.textContaining('Protected now'), findsOneWidget);
    expect(find.text('Active protections'), findsOneWidget);
  });

  testWidgets('Today gives monitoring degradation an actionable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const TodayViewData(accessibilityMissing: true)),
    );

    expect(find.text('Monitoring needs attention'), findsOneWidget);
    expect(find.text('Enforcement setup needs attention'), findsOneWidget);
    expect(find.text('Fix setup'), findsOneWidget);
  });

  testWidgets('Today gives an active taper plan first-class progress', (
    tester,
  ) async {
    final schedule = _schedule(type: ScheduleType.usageLimit);
    final now = DateTime.now();
    final plan = TaperPlanModel(
      id: 'plan-1',
      scheduleId: schedule.id,
      status: 'active',
      targetApps: schedule.targetApps,
      baselineDailyMinutes: 120,
      targetDailyMinutes: 60,
      durationDays: 14,
      startDate: DateTime(now.year, now.month, now.day),
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      _app(TodayViewData(schedules: [schedule], taperPlan: plan)),
    );

    expect(find.text('Day 1 of 14'), findsOneWidget);
    expect(find.textContaining("Today's allowance:"), findsOneWidget);
  });
}

Widget _app(TodayViewData data) {
  return MaterialApp(
    theme: AppTheme.create(
      brightness: Brightness.dark,
      accent: ThemeService.accentPalette.first,
    ),
    home: Scaffold(body: TodayContent(data: data)),
  );
}

ScheduleModel _schedule({
  required ScheduleType type,
  List<ScheduleBlock> blocks = const <ScheduleBlock>[],
}) {
  return ScheduleModel(
    id: 'schedule-${type.index}',
    name: type == ScheduleType.timeBlock ? 'Evening protection' : 'Social apps',
    type: type,
    targetApps: const <String>['com.example.social'],
    days: <int>[DateTime.now().weekday],
    blocks: blocks,
    durationLimit: type == ScheduleType.usageLimit
        ? const Duration(minutes: 80)
        : null,
    activatedAt: DateTime.now(),
  );
}
