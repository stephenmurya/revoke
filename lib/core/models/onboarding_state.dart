import 'package:flutter/foundation.dart';

/// Versioned, explicit progress for the v2 onboarding journey.
///
/// This record is intentionally independent of nickname, Circle membership,
/// or Android permission state. Those values can help complete a step, but
/// they never decide whether onboarding is complete.
enum OnboardingStep {
  welcome,
  authentication,
  identity,
  usagePermission,
  realityCheck,
  intent,
  firstCommitment,
  enforcementPermissions,
  intervention,
  review,
  complete,
}

@immutable
class OnboardingState {
  const OnboardingState({
    this.version = 2,
    this.step = OnboardingStep.welcome,
    this.nickname,
    this.intent,
    this.firstCommitmentId,
    this.createdAt,
    this.updatedAt,
  });

  final int version;
  final OnboardingStep step;
  final String? nickname;
  final String? intent;
  final String? firstCommitmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isComplete => step == OnboardingStep.complete;

  OnboardingState copyWith({
    int? version,
    OnboardingStep? step,
    String? nickname,
    String? intent,
    String? firstCommitmentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OnboardingState(
      version: version ?? this.version,
      step: step ?? this.step,
      nickname: nickname ?? this.nickname,
      intent: intent ?? this.intent,
      firstCommitmentId: firstCommitmentId ?? this.firstCommitmentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': version,
    'step': step.name,
    'nickname': nickname,
    'intent': intent,
    'firstCommitmentId': firstCommitmentId,
    'createdAtMs': createdAt?.millisecondsSinceEpoch,
    'updatedAtMs': updatedAt?.millisecondsSinceEpoch,
  };

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final rawStep = (json['step'] as String?)?.trim();
    final step = OnboardingStep.values.firstWhere(
      (candidate) => candidate.name == rawStep,
      orElse: () => OnboardingStep.welcome,
    );
    return OnboardingState(
      version: (json['version'] as num?)?.toInt() ?? 2,
      step: step,
      nickname: _string(json['nickname']),
      intent: _string(json['intent']),
      firstCommitmentId: _string(json['firstCommitmentId']),
      createdAt: _date(json['createdAtMs']),
      updatedAt: _date(json['updatedAtMs']),
    );
  }

  static String? _string(dynamic value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static DateTime? _date(dynamic value) {
    if (value is! num || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
}

/// Pure routing policy so auth/onboarding decisions can be tested without
/// booting Firebase or invoking Android platform channels.
class OnboardingRoutePolicy {
  const OnboardingRoutePolicy._();

  static String? redirect({
    required bool authenticated,
    required bool complete,
    required String location,
    bool forceAuth = false,
  }) {
    final isOnboarding = location == '/onboarding';
    if (!authenticated) return isOnboarding ? null : '/onboarding';
    if (forceAuth && isOnboarding) return null;
    if (complete) {
      return location == '/' || isOnboarding ? '/home' : null;
    }
    return isOnboarding ? null : '/onboarding';
  }
}
