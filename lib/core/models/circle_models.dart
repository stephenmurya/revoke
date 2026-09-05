import 'package:cloud_firestore/cloud_firestore.dart';

enum CirclePermission {
  viewCommitmentSummary,
  viewOverrideHistory,
  receiveOverrideRequests,
  participateInOverrideDiscussion,
  voteOnOverrideRequests,
  receiveAccountabilityNotifications,
}

extension CirclePermissionX on CirclePermission {
  String get wireName {
    switch (this) {
      case CirclePermission.viewCommitmentSummary:
        return 'viewCommitmentSummary';
      case CirclePermission.viewOverrideHistory:
        return 'viewOverrideHistory';
      case CirclePermission.receiveOverrideRequests:
        return 'receiveOverrideRequests';
      case CirclePermission.participateInOverrideDiscussion:
        return 'participateInOverrideDiscussion';
      case CirclePermission.voteOnOverrideRequests:
        return 'voteOnOverrideRequests';
      case CirclePermission.receiveAccountabilityNotifications:
        return 'receiveAccountabilityNotifications';
    }
  }

  String get label {
    switch (this) {
      case CirclePermission.viewCommitmentSummary:
        return 'View Commitment summary';
      case CirclePermission.viewOverrideHistory:
        return 'View Override History';
      case CirclePermission.receiveOverrideRequests:
        return 'Receive Override Requests';
      case CirclePermission.participateInOverrideDiscussion:
        return 'Join override discussion';
      case CirclePermission.voteOnOverrideRequests:
        return 'Vote on Override Requests';
      case CirclePermission.receiveAccountabilityNotifications:
        return 'Receive accountability notifications';
    }
  }

  static CirclePermission? fromWireName(String value) {
    for (final permission in CirclePermission.values) {
      if (permission.wireName == value) return permission;
    }
    return null;
  }
}

enum CirclePreset { observer, accountabilityPartner, guardian, custom }

extension CirclePresetX on CirclePreset {
  String get wireName => switch (this) {
    CirclePreset.observer => 'observer',
    CirclePreset.accountabilityPartner => 'accountabilityPartner',
    CirclePreset.guardian => 'guardian',
    CirclePreset.custom => 'custom',
  };

  String get label => switch (this) {
    CirclePreset.observer => 'Observer',
    CirclePreset.accountabilityPartner => 'Accountability partner',
    CirclePreset.guardian => 'Guardian',
    CirclePreset.custom => 'Custom',
  };

  static CirclePreset fromWireName(String? value) => switch (value) {
    'observer' => CirclePreset.observer,
    'accountabilityPartner' => CirclePreset.accountabilityPartner,
    'guardian' => CirclePreset.guardian,
    _ => CirclePreset.custom,
  };
}

Map<String, bool> circlePresetPermissions(CirclePreset preset) {
  final all = {
    for (final permission in CirclePermission.values) permission.wireName: true,
  };
  switch (preset) {
    case CirclePreset.observer:
      return {
        CirclePermission.viewCommitmentSummary.wireName: true,
        CirclePermission.viewOverrideHistory.wireName: true,
        CirclePermission.receiveOverrideRequests.wireName: false,
        CirclePermission.participateInOverrideDiscussion.wireName: false,
        CirclePermission.voteOnOverrideRequests.wireName: false,
        CirclePermission.receiveAccountabilityNotifications.wireName: true,
      };
    case CirclePreset.accountabilityPartner:
      return {...all, CirclePermission.viewOverrideHistory.wireName: true};
    case CirclePreset.guardian:
      return all;
    case CirclePreset.custom:
      return {
        CirclePermission.viewCommitmentSummary.wireName: true,
        CirclePermission.viewOverrideHistory.wireName: false,
        CirclePermission.receiveOverrideRequests.wireName: false,
        CirclePermission.participateInOverrideDiscussion.wireName: false,
        CirclePermission.voteOnOverrideRequests.wireName: false,
        CirclePermission.receiveAccountabilityNotifications.wireName: false,
      };
  }
}

class CircleMemberSummary {
  const CircleMemberSummary({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    required this.preset,
    required this.permissions,
    this.updatedAt,
  });

  final String uid;
  final String displayName;
  final String avatarUrl;
  final String role;
  final CirclePreset preset;
  final Map<String, bool> permissions;
  final DateTime? updatedAt;

  bool has(CirclePermission permission) =>
      permissions[permission.wireName] == true;

  factory CircleMemberSummary.fromJson(
    Map<String, dynamic> json,
    String docId,
  ) {
    final rawPermissions = json['permissions'];
    final permissions = <String, bool>{};
    if (rawPermissions is Map) {
      rawPermissions.forEach((key, value) {
        if (key is String &&
            value is bool &&
            CirclePermissionX.fromWireName(key) != null) {
          permissions[key] = value;
        }
      });
    }
    final rawUpdatedAt = json['updatedAt'];
    return CircleMemberSummary(
      uid: (json['uid'] as String?)?.trim().isNotEmpty == true
          ? (json['uid'] as String).trim()
          : docId,
      displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? (json['displayName'] as String).trim()
          : 'Circle member',
      avatarUrl: (json['avatarUrl'] as String?)?.trim() ?? '',
      role: (json['role'] as String?)?.trim() ?? 'member',
      preset: CirclePresetX.fromWireName(json['preset'] as String?),
      permissions: Map.unmodifiable(permissions),
      updatedAt: rawUpdatedAt is Timestamp ? rawUpdatedAt.toDate() : null,
    );
  }
}

enum OverrideAuthority { self, ai, circle }

extension OverrideAuthorityX on OverrideAuthority {
  String get wireName => name;

  String get label => switch (this) {
    OverrideAuthority.self => 'Self',
    OverrideAuthority.ai => 'AI Architect',
    OverrideAuthority.circle => 'Circle',
  };

  String get description => switch (this) {
    OverrideAuthority.self =>
      'A deliberate, short access request you decide for yourself.',
    OverrideAuthority.ai =>
      'A sanitized request is assessed by the AI Architect.',
    OverrideAuthority.circle => 'Selected Circle members decide by majority.',
  };

  static OverrideAuthority fromWireName(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'ai' || 'ai_architect' => OverrideAuthority.ai,
        'circle' => OverrideAuthority.circle,
        _ => OverrideAuthority.self,
      };
}

class CommitmentOverridePolicy {
  const CommitmentOverridePolicy({
    required this.commitmentId,
    required this.authority,
    required this.selectedMemberIds,
    required this.sharedMemberIds,
    this.updatedAt,
  });

  final String commitmentId;
  final OverrideAuthority authority;
  final List<String> selectedMemberIds;
  final List<String> sharedMemberIds;
  final DateTime? updatedAt;

  const CommitmentOverridePolicy.self(String commitmentId)
    : this(
        commitmentId: commitmentId,
        authority: OverrideAuthority.self,
        selectedMemberIds: const [],
        sharedMemberIds: const [],
      );

  factory CommitmentOverridePolicy.fromJson(
    Map<String, dynamic> json,
    String commitmentId,
  ) {
    final rawIds = json['selectedMemberIds'] ?? json['eligibleMemberIds'];
    final rawSharedIds = json['sharedMemberIds'];
    return CommitmentOverridePolicy(
      commitmentId: commitmentId,
      authority: OverrideAuthorityX.fromWireName(json['authority'] as String?),
      selectedMemberIds: rawIds is List
          ? rawIds
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()
          : const [],
      sharedMemberIds: rawSharedIds is List
          ? rawSharedIds
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList()
          : const [],
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'authority': authority.wireName,
    'selectedMemberIds': selectedMemberIds,
    'sharedMemberIds': sharedMemberIds,
  };
}

int circleMajority(int eligibleVoterCount) =>
    eligibleVoterCount <= 0 ? 0 : (eligibleVoterCount ~/ 2) + 1;
