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
  final DateTime generatedAt;

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
    required this.generatedAt,
  });

  factory MemberRapSheetSnapshot.fromMap(Map<String, dynamic> data) {
    final protocolsRaw = (data['activeProtocols'] as List?) ?? const [];
    final blacklistRaw = (data['blacklistApps'] as List?) ?? const [];
    final pleaStatsRaw = Map<String, dynamic>.from(
      data['pleaStats'] as Map? ?? const {},
    );
    final generatedAtMs = (data['generatedAtMs'] as num?)?.toInt();

    return MemberRapSheetSnapshot(
      targetUid: (data['targetUid'] as String?)?.trim() ?? '',
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
      generatedAt: generatedAtMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(generatedAtMs),
    );
  }
}
