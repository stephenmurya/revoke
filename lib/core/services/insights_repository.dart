import 'dart:async';

import '../models/insights_models.dart';
import '../models/usage_insights_model.dart';
import 'app_discovery_service.dart';
import 'auth_service.dart';
import 'circle_service.dart';
import 'taper_plan_service.dart';
import 'usage_insights_service.dart';

/// Read-only aggregation boundary for the Insights product surface.
///
/// Native UsageStats is authoritative for usage. Local taper plans and the
/// server-backed override history remain separate sources and are only joined
/// into view data here. This keeps the screen from coordinating many calls or
/// inventing a shared analytics authority.
class InsightsRepository {
  const InsightsRepository._();

  static DateTime latestCompleteDay() {
    final today = DateTime.now();
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 1));
  }

  static Future<InsightsOverview> loadOverview({
    required int periodDays,
  }) async {
    final snapshot = await UsageInsightsService.refresh(
      mode: 'trend',
      anchorDate: latestCompleteDay(),
      periodDays: periodDays,
    );
    final apps = await AppDiscoveryService.getApps();
    final names = <String, String>{
      for (final app in apps) app.packageName: app.name,
    };
    return InsightsOverview(snapshot: snapshot, appNames: names);
  }

  static Future<InsightsAdvancedData> loadAdvanced({
    required int periodDays,
  }) async {
    final plans = await TaperPlanService.getActivePlansForCapability();
    final reducePlans = <ReduceInsight>[];
    for (final plan in plans.take(5)) {
      final usage = await UsageInsightsService.refresh(
        mode: 'trend',
        anchorDate: latestCompleteDay(),
        periodDays: periodDays,
        packageNames: plan.targetApps,
      );
      if (usage.hasUsageAccess) {
        reducePlans.add(ReduceInsight(plan: plan, usage: usage));
      }
    }

    OverrideInsightSummary? overrideSummary;
    final uid = AuthService.currentUser?.uid.trim() ?? '';
    if (uid.isNotEmpty) {
      try {
        final requests = await CircleService.watchOverrideHistory(
          uid,
        ).first.timeout(const Duration(seconds: 5));
        final start = latestCompleteDay().subtract(
          Duration(days: periodDays - 1),
        );
        final end = latestCompleteDay().add(const Duration(days: 1));
        final periodRequests = requests.where((request) {
          return !request.createdAt.isBefore(start) &&
              request.createdAt.isBefore(end);
        });
        final byAuthority = <String, int>{};
        var approved = 0;
        var rejected = 0;
        var approvedMinutes = 0;
        for (final request in periodRequests) {
          final authority = switch (request.authority) {
            'ai' => 'AI Architect',
            'circle' => 'Circle',
            'self' => 'Self',
            _ => 'Previous request',
          };
          byAuthority[authority] = (byAuthority[authority] ?? 0) + 1;
          final status = request.status.trim().toLowerCase();
          if (status == 'approved' || status == 'resolved_approved') {
            approved++;
            approvedMinutes += request.durationMinutes;
          } else if (status == 'rejected' || status == 'resolved_rejected') {
            rejected++;
          }
        }
        overrideSummary = OverrideInsightSummary(
          total: periodRequests.length,
          approved: approved,
          rejected: rejected,
          approvedMinutes: approvedMinutes,
          byAuthority: byAuthority,
        );
      } catch (_) {
        // Optional Premium data does not block the truthful usage overview.
      }
    }

    return InsightsAdvancedData(
      reduceInsights: reducePlans,
      overrideSummary: overrideSummary,
    );
  }

  static Future<UsageInsightsSnapshot> loadPackageOverview({
    required String packageName,
    required int periodDays,
  }) {
    return UsageInsightsService.refresh(
      mode: 'trend',
      anchorDate: latestCompleteDay(),
      packageName: packageName,
      periodDays: periodDays,
    );
  }
}
