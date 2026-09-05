import 'package:flutter/foundation.dart';

import 'commitment_draft.dart';

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

  /// Retained for migration of Phase 4 records. New users use commitmentDraft.
  firstCommitment,
  commitmentDraft,
  enforcementPermissions,
  intervention,
  overrideAuthority,
  circleSetup,
  commitmentReview,
  premium,
  creditBacking,
  readyToActivate,
  review,
  complete,
}

@immutable
class OnboardingState {
  const OnboardingState({
    this.version = 3,
    this.step = OnboardingStep.welcome,
    this.nickname,
    this.intent,
    this.firstCommitmentId,
    this.commitmentDraft,
    this.overrideAuthority = 'self',
    this.circleId,
    this.selectedCircleMemberIds = const <String>[],
    this.creditBackingSelected = false,
    this.creditBackingAmount,
    this.creditGracePolicy,
    this.createdAt,
    this.updatedAt,
  });

  final int version;
  final OnboardingStep step;
  final String? nickname;
  final String? intent;
  final String? firstCommitmentId;
  final CommitmentDraft? commitmentDraft;
  final String overrideAuthority;
  final String? circleId;
  final List<String> selectedCircleMemberIds;
  final bool creditBackingSelected;
  final int? creditBackingAmount;
  final String? creditGracePolicy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isComplete => step == OnboardingStep.complete;

  OnboardingState copyWith({
    int? version,
    OnboardingStep? step,
    String? nickname,
    String? intent,
    String? firstCommitmentId,
    CommitmentDraft? commitmentDraft,
    String? overrideAuthority,
    String? circleId,
    List<String>? selectedCircleMemberIds,
    bool? creditBackingSelected,
    int? creditBackingAmount,
    String? creditGracePolicy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OnboardingState(
      version: version ?? this.version,
      step: step ?? this.step,
      nickname: nickname ?? this.nickname,
      intent: intent ?? this.intent,
      firstCommitmentId: firstCommitmentId ?? this.firstCommitmentId,
      commitmentDraft: commitmentDraft ?? this.commitmentDraft,
      overrideAuthority: overrideAuthority ?? this.overrideAuthority,
      circleId: circleId ?? this.circleId,
      selectedCircleMemberIds:
          selectedCircleMemberIds ?? this.selectedCircleMemberIds,
      creditBackingSelected:
          creditBackingSelected ?? this.creditBackingSelected,
      creditBackingAmount: creditBackingAmount ?? this.creditBackingAmount,
      creditGracePolicy: creditGracePolicy ?? this.creditGracePolicy,
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
    'commitmentDraft': commitmentDraft?.toJson(),
    'overrideAuthority': overrideAuthority,
    'circleId': circleId,
    'selectedCircleMemberIds': selectedCircleMemberIds,
    'creditBackingSelected': creditBackingSelected,
    'creditBackingAmount': creditBackingAmount,
    'creditGracePolicy': creditGracePolicy,
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
      commitmentDraft: _draft(json['commitmentDraft']),
      overrideAuthority: _string(json['overrideAuthority']) ?? 'self',
      circleId: _string(json['circleId']),
      selectedCircleMemberIds: _strings(json['selectedCircleMemberIds']),
      creditBackingSelected: json['creditBackingSelected'] == true,
      creditBackingAmount: _integer(json['creditBackingAmount']),
      creditGracePolicy: _string(json['creditGracePolicy']),
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

  static int? _integer(dynamic value) {
    return switch (value) {
      num() => value.toInt(),
      String() => int.tryParse(value),
      _ => null,
    };
  }

  static List<String> _strings(dynamic value) =>
      (value is List ? value : const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);

  static CommitmentDraft? _draft(dynamic value) {
    if (value is! Map) return null;
    try {
      return CommitmentDraft.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
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
