import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/circle_models.dart';
import '../models/plea_model.dart';

/// User-facing Circle and Override API.
///
/// The compatibility boundary is deliberate: Circle reads use sanitized member
/// summaries, while Commitments and native enforcement continue to use the
/// existing schedule-backed services. Membership, permissions, policy, and
/// override resolution are mutated by Cloud Functions.
class CircleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'us-central1',
  );

  static CollectionReference<Map<String, dynamic>> _membersRef(
    String circleId,
  ) => _firestore.collection('squads').doc(circleId).collection('members');

  static CollectionReference<Map<String, dynamic>> _policiesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('commitmentPolicies');

  static Stream<List<CircleMemberSummary>> watchMembers(String circleId) {
    final id = circleId.trim();
    if (id.isEmpty) return Stream.value(const <CircleMemberSummary>[]);
    return _membersRef(id)
        .orderBy('displayName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CircleMemberSummary.fromJson(doc.data(), doc.id))
              .toList(growable: false),
        );
  }

  static Future<void> ensureMemberSummaries(String circleId) async {
    await _functions.httpsCallable('ensureCircleMemberSummaries').call({
      'circleId': circleId.trim(),
    });
  }

  static Stream<List<PleaModel>> watchVisibleOverrideRequests(String uid) {
    final id = uid.trim();
    if (id.isEmpty) return Stream.value(const <PleaModel>[]);
    return _firestore
        .collection('pleas')
        .where('visibleToUids', arrayContains: id)
        .where('status', whereIn: const ['active', 'pending'])
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PleaModel.fromJson(doc.data(), doc.id))
              .toList(growable: false),
        );
  }

  static Stream<List<PleaModel>> watchOverrideHistory(String uid) {
    final id = uid.trim();
    if (id.isEmpty) return Stream.value(const <PleaModel>[]);
    return _firestore
        .collection('pleas')
        .where('userId', isEqualTo: id)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PleaModel.fromJson(doc.data(), doc.id))
              .toList(growable: false),
        );
  }

  static Future<CommitmentOverridePolicy> getPolicy({
    required String uid,
    required String commitmentId,
  }) async {
    final id = commitmentId.trim();
    if (id.isEmpty) return CommitmentOverridePolicy.self(id);
    final snapshot = await _policiesRef(uid.trim()).doc(id).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return CommitmentOverridePolicy.self(id);
    }
    return CommitmentOverridePolicy.fromJson(snapshot.data()!, id);
  }

  static Future<void> setPolicy({
    required String commitmentId,
    required OverrideAuthority authority,
    List<String> selectedMemberIds = const [],
    List<String> sharedMemberIds = const [],
  }) async {
    await _functions.httpsCallable('setCommitmentOverridePolicy').call({
      'commitmentId': commitmentId.trim(),
      'authority': authority.wireName,
      'selectedMemberIds': selectedMemberIds,
      'sharedMemberIds': sharedMemberIds,
    });
  }

  static Future<List<Map<String, dynamic>>>
  getSharedCommitmentSummaries() async {
    final result = await _functions
        .httpsCallable('getSharedCommitmentSummaries')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map? ?? const {});
    final raw = data['commitments'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<void> updateMemberPermissions({
    required String circleId,
    required String memberUid,
    required CirclePreset preset,
    required Map<String, bool> permissions,
  }) async {
    final supported = <String, bool>{};
    for (final permission in CirclePermission.values) {
      supported[permission.wireName] = permissions[permission.wireName] == true;
    }
    await _functions.httpsCallable('setCircleMemberPermissions').call({
      'circleId': circleId.trim(),
      'memberUid': memberUid.trim(),
      'preset': preset.wireName,
      'permissions': supported,
    });
  }

  static Future<void> leaveCircle(String circleId) async {
    await _functions.httpsCallable('leaveCircle').call({
      'circleId': circleId.trim(),
    });
  }

  static Future<List<Map<String, dynamic>>> getMemberOverrideHistory(
    String memberUid,
  ) async {
    final result = await _functions
        .httpsCallable('getCircleMemberOverrideHistory')
        .call({'targetUid': memberUid.trim()});
    final data = Map<String, dynamic>.from(result.data as Map? ?? const {});
    final raw = data['history'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Future<String> createOverrideRequest({
    required String commitmentId,
    required OverrideAuthority authority,
    required String appName,
    required String packageName,
    required int durationMinutes,
    required String reason,
  }) async {
    final result = await _functions
        .httpsCallable('createOverrideRequest')
        .call({
          'commitmentId': commitmentId.trim(),
          'authority': authority.wireName,
          'appName': appName.trim(),
          'packageName': packageName.trim(),
          'durationMinutes': durationMinutes,
          'reason': reason.trim(),
        });
    final data = Map<String, dynamic>.from(result.data as Map? ?? const {});
    final id = (data['pleaId'] as String?)?.trim();
    if (id == null || id.isEmpty) {
      throw Exception('Override request was not created.');
    }
    return id;
  }

  static Future<void> recordSelfOverride({
    required String commitmentId,
    required String appName,
    required String packageName,
    required int durationMinutes,
    required String reason,
    String? localRequestId,
  }) async {
    await _functions.httpsCallable('recordSelfOverride').call({
      'commitmentId': commitmentId.trim(),
      'appName': appName.trim(),
      'packageName': packageName.trim(),
      'durationMinutes': durationMinutes,
      'reason': reason.trim(),
      if (localRequestId != null && localRequestId.trim().isNotEmpty)
        'idempotencyKey': localRequestId.trim(),
    });
  }
}
