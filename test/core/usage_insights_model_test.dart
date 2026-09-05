import 'package:flutter_test/flutter_test.dart';

import 'package:revoke/core/models/usage_insights_model.dart';

void main() {
  test('usage snapshot preserves comparison and recorded-day metadata', () {
    final snapshot = UsageInsightsSnapshot.fromJson({
      'mode': 'trend',
      'periodDays': 7,
      'comparisonAvailable': true,
      'observedDays': 7,
      'trendDeltaMinutes': -24,
      'buckets': [
        {
          'index': 0,
          'startMs': 1,
          'endMs': 2,
          'label': 'Mon',
          'isFuture': false,
          'minutes': 42,
        },
      ],
    });

    expect(snapshot.comparisonAvailable, isTrue);
    expect(snapshot.observedDays, 7);
    expect(snapshot.trendDeltaMinutes, -24);
    expect(snapshot.buckets.single.minutes, 42);
  });

  test('empty snapshot does not claim a comparison exists', () {
    final snapshot = UsageInsightsSnapshot.empty(mode: 'trend', periodDays: 7);

    expect(snapshot.comparisonAvailable, isFalse);
    expect(snapshot.observedDays, 0);
    expect(snapshot.buckets, isEmpty);
  });
}
