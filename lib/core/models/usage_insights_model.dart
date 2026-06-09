class UsageInsightBucket {
  final int index;
  final int startMs;
  final int endMs;
  final String label;
  final bool isFuture;
  final int usageMs;
  final int minutes;

  const UsageInsightBucket({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.label,
    required this.isFuture,
    required this.usageMs,
    required this.minutes,
  });

  factory UsageInsightBucket.fromJson(Map<String, dynamic> json) {
    return UsageInsightBucket(
      index: _intFromJson(json['index']),
      startMs: _intFromJson(json['startMs']),
      endMs: _intFromJson(json['endMs']),
      label: (json['label'] as String?)?.trim() ?? '',
      isFuture: json['isFuture'] == true,
      usageMs: _intFromJson(json['usageMs']),
      minutes: _intFromJson(json['minutes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'startMs': startMs,
      'endMs': endMs,
      'label': label,
      'isFuture': isFuture,
      'usageMs': usageMs,
      'minutes': minutes,
    };
  }
}

class UsageInsightApp {
  final String packageName;
  final int usageMs;
  final int minutes;

  const UsageInsightApp({
    required this.packageName,
    required this.usageMs,
    required this.minutes,
  });

  factory UsageInsightApp.fromJson(Map<String, dynamic> json) {
    return UsageInsightApp(
      packageName: (json['packageName'] as String?)?.trim() ?? '',
      usageMs: _intFromJson(json['usageMs']),
      minutes: _intFromJson(json['minutes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'packageName': packageName, 'usageMs': usageMs, 'minutes': minutes};
  }
}

class UsageInsightsSnapshot {
  final String mode;
  final String packageName;
  final int anchorDateMs;
  final int rangeStartMs;
  final int rangeEndMs;
  final int generatedAtMs;
  final bool hasUsageAccess;
  final int periodDays;
  final int totalUsageMs;
  final int totalMinutes;
  final int averageDailyUsageMs;
  final int averageDailyMinutes;
  final int trendDeltaMs;
  final int trendDeltaMinutes;
  final int trendPercent;
  final String trendDirection;
  final List<UsageInsightBucket> buckets;
  final Map<String, dynamic> peak;
  final List<UsageInsightApp> topApps;
  final int longestFocusMs;
  final int longestContinuousUseMs;

  const UsageInsightsSnapshot({
    required this.mode,
    required this.packageName,
    required this.anchorDateMs,
    required this.rangeStartMs,
    required this.rangeEndMs,
    required this.generatedAtMs,
    required this.hasUsageAccess,
    required this.periodDays,
    required this.totalUsageMs,
    required this.totalMinutes,
    required this.averageDailyUsageMs,
    required this.averageDailyMinutes,
    required this.trendDeltaMs,
    required this.trendDeltaMinutes,
    required this.trendPercent,
    required this.trendDirection,
    required this.buckets,
    required this.peak,
    required this.topApps,
    required this.longestFocusMs,
    required this.longestContinuousUseMs,
  });

  factory UsageInsightsSnapshot.empty({
    String mode = 'day',
    String packageName = '',
    int periodDays = 1,
  }) {
    return UsageInsightsSnapshot(
      mode: mode,
      packageName: packageName,
      anchorDateMs: 0,
      rangeStartMs: 0,
      rangeEndMs: 0,
      generatedAtMs: 0,
      hasUsageAccess: true,
      periodDays: periodDays,
      totalUsageMs: 0,
      totalMinutes: 0,
      averageDailyUsageMs: 0,
      averageDailyMinutes: 0,
      trendDeltaMs: 0,
      trendDeltaMinutes: 0,
      trendPercent: 0,
      trendDirection: 'flat',
      buckets: const <UsageInsightBucket>[],
      peak: const <String, dynamic>{},
      topApps: const <UsageInsightApp>[],
      longestFocusMs: 0,
      longestContinuousUseMs: 0,
    );
  }

  factory UsageInsightsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawBuckets = json['buckets'];
    final rawPeak = json['peak'];
    final rawTopApps = json['topApps'];
    return UsageInsightsSnapshot(
      mode: (json['mode'] as String?)?.trim() ?? 'day',
      packageName: (json['packageName'] as String?)?.trim() ?? '',
      anchorDateMs: _intFromJson(json['anchorDateMs']),
      rangeStartMs: _intFromJson(json['rangeStartMs']),
      rangeEndMs: _intFromJson(json['rangeEndMs']),
      generatedAtMs: _intFromJson(json['generatedAtMs']),
      hasUsageAccess: json['hasUsageAccess'] != false,
      periodDays: _intFromJson(json['periodDays'], fallback: 1),
      totalUsageMs: _intFromJson(json['totalUsageMs']),
      totalMinutes: _intFromJson(json['totalMinutes']),
      averageDailyUsageMs: _intFromJson(json['averageDailyUsageMs']),
      averageDailyMinutes: _intFromJson(json['averageDailyMinutes']),
      trendDeltaMs: _intFromJson(json['trendDeltaMs']),
      trendDeltaMinutes: _intFromJson(json['trendDeltaMinutes']),
      trendPercent: _intFromJson(json['trendPercent']),
      trendDirection: (json['trendDirection'] as String?)?.trim() ?? 'flat',
      buckets: rawBuckets is List
          ? rawBuckets
                .whereType<Map>()
                .map(
                  (item) => UsageInsightBucket.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const <UsageInsightBucket>[],
      peak: rawPeak is Map
          ? Map<String, dynamic>.from(rawPeak)
          : const <String, dynamic>{},
      topApps: rawTopApps is List
          ? rawTopApps
                .whereType<Map>()
                .map(
                  (item) =>
                      UsageInsightApp.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((app) => app.packageName.isNotEmpty)
                .toList(growable: false)
          : const <UsageInsightApp>[],
      longestFocusMs: _intFromJson(json['longestFocusMs']),
      longestContinuousUseMs: _intFromJson(json['longestContinuousUseMs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'packageName': packageName,
      'anchorDateMs': anchorDateMs,
      'rangeStartMs': rangeStartMs,
      'rangeEndMs': rangeEndMs,
      'generatedAtMs': generatedAtMs,
      'hasUsageAccess': hasUsageAccess,
      'periodDays': periodDays,
      'totalUsageMs': totalUsageMs,
      'totalMinutes': totalMinutes,
      'averageDailyUsageMs': averageDailyUsageMs,
      'averageDailyMinutes': averageDailyMinutes,
      'trendDeltaMs': trendDeltaMs,
      'trendDeltaMinutes': trendDeltaMinutes,
      'trendPercent': trendPercent,
      'trendDirection': trendDirection,
      'buckets': buckets.map((bucket) => bucket.toJson()).toList(),
      'peak': peak,
      'topApps': topApps.map((app) => app.toJson()).toList(),
      'longestFocusMs': longestFocusMs,
      'longestContinuousUseMs': longestContinuousUseMs,
    };
  }
}

int _intFromJson(dynamic value, {int fallback = 0}) {
  return switch (value) {
    num() => value.toInt(),
    String() => int.tryParse(value) ?? fallback,
    _ => fallback,
  };
}
