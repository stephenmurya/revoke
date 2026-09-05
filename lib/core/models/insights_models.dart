import 'taper_plan_model.dart';
import 'usage_insights_model.dart';

class InsightsOverview {
  const InsightsOverview({required this.snapshot, required this.appNames});

  final UsageInsightsSnapshot snapshot;
  final Map<String, String> appNames;
}

class ReduceInsight {
  const ReduceInsight({required this.plan, required this.usage});

  final TaperPlanModel plan;
  final UsageInsightsSnapshot usage;

  List<int> plannedMinutes() {
    return usage.buckets
        .map((bucket) {
          final date = DateTime.fromMillisecondsSinceEpoch(bucket.startMs);
          return plan.limitFor(date);
        })
        .toList(growable: false);
  }
}

class OverrideInsightSummary {
  const OverrideInsightSummary({
    required this.total,
    required this.approved,
    required this.rejected,
    required this.approvedMinutes,
    required this.byAuthority,
  });

  final int total;
  final int approved;
  final int rejected;
  final int approvedMinutes;
  final Map<String, int> byAuthority;
}

class InsightsAdvancedData {
  const InsightsAdvancedData({
    this.reduceInsights = const <ReduceInsight>[],
    this.overrideSummary,
  });

  final List<ReduceInsight> reduceInsights;
  final OverrideInsightSummary? overrideSummary;
}
