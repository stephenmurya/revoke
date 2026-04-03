class MemberRapSheetInfraction {
  final String kind;
  final String sourceId;
  final String status;
  final String appName;
  final String packageName;
  final int occurredAtMs;

  const MemberRapSheetInfraction({
    required this.kind,
    required this.sourceId,
    required this.status,
    required this.appName,
    required this.packageName,
    required this.occurredAtMs,
  });

  DateTime get occurredAt => DateTime.fromMillisecondsSinceEpoch(occurredAtMs);

  factory MemberRapSheetInfraction.fromMap(Map<String, dynamic> data) {
    return MemberRapSheetInfraction(
      kind: (data['kind'] as String?)?.trim() ?? '',
      sourceId: (data['sourceId'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? '',
      appName: (data['appName'] as String?)?.trim() ?? '',
      packageName: (data['packageName'] as String?)?.trim() ?? '',
      occurredAtMs: (data['occurredAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class MemberRapSheetSnapshot {
  final String targetUid;
  final String squadId;
  final List<String> activeProtocols;
  final int activeProtocolCount;
  final List<String> blacklistApps;
  final int blacklistCount;
  final int pleaTotal;
  final int pleaApproved;
  final int pleaRejected;
  final List<MemberRapSheetInfraction> latestInfractions;
  final DateTime updatedAt;
  final int version;

  const MemberRapSheetSnapshot({
    required this.targetUid,
    required this.squadId,
    required this.activeProtocols,
    required this.activeProtocolCount,
    required this.blacklistApps,
    required this.blacklistCount,
    required this.pleaTotal,
    required this.pleaApproved,
    required this.pleaRejected,
    required this.latestInfractions,
    required this.updatedAt,
    required this.version,
  });

  factory MemberRapSheetSnapshot.fromMap(Map<String, dynamic> data) {
    final protocolsRaw = (data['activeProtocols'] as List?) ?? const [];
    final blacklistRaw = (data['blacklistApps'] as List?) ?? const [];
    final infractionsRaw = (data['latestInfractions'] as List?) ?? const [];
    final pleaStatsRaw = Map<String, dynamic>.from(
      data['pleaStats'] as Map? ?? const {},
    );
    final updatedAtMs =
        (data['updatedAtMs'] as num?)?.toInt() ??
        (data['generatedAtMs'] as num?)?.toInt();

    return MemberRapSheetSnapshot(
      targetUid:
          (data['targetUid'] as String?)?.trim() ??
          (data['uid'] as String?)?.trim() ??
          '',
      squadId: (data['squadId'] as String?)?.trim() ?? '',
      activeProtocols: protocolsRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      activeProtocolCount:
          (data['activeProtocolCount'] as num?)?.toInt() ?? protocolsRaw.length,
      blacklistApps: blacklistRaw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      blacklistCount:
          (data['blacklistCount'] as num?)?.toInt() ?? blacklistRaw.length,
      pleaTotal: (pleaStatsRaw['total'] as num?)?.toInt() ?? 0,
      pleaApproved: (pleaStatsRaw['approved'] as num?)?.toInt() ?? 0,
      pleaRejected: (pleaStatsRaw['rejected'] as num?)?.toInt() ?? 0,
      latestInfractions: infractionsRaw
          .whereType<Map>()
          .map(
            (raw) => MemberRapSheetInfraction.fromMap(
              Map<String, dynamic>.from(raw),
            ),
          )
          .where((entry) => entry.kind.isNotEmpty && entry.occurredAtMs > 0)
          .toList(growable: false),
      updatedAt: updatedAtMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      version: (data['version'] as num?)?.toInt() ?? 1,
    );
  }
}
