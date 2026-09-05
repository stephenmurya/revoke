import 'package:flutter_test/flutter_test.dart';

import 'package:revoke/core/models/circle_models.dart';

void main() {
  test('Circle presets expand to safe supported permissions', () {
    final observer = circlePresetPermissions(CirclePreset.observer);
    final partner = circlePresetPermissions(CirclePreset.accountabilityPartner);

    expect(observer[CirclePermission.viewCommitmentSummary.wireName], isTrue);
    expect(observer[CirclePermission.voteOnOverrideRequests.wireName], isFalse);
    expect(partner[CirclePermission.voteOnOverrideRequests.wireName], isTrue);
    expect(
      partner[CirclePermission.participateInOverrideDiscussion.wireName],
      isTrue,
    );
  });

  test(
    'unsupported permission fields are not retained in member summaries',
    () {
      final member = CircleMemberSummary.fromJson({
        'uid': 'member-1',
        'displayName': 'Alex',
        'permissions': {
          'viewCommitmentSummary': true,
          'viewCreditBackingAmount': true,
          'email': true,
        },
      }, 'member-1');

      expect(member.has(CirclePermission.viewCommitmentSummary), isTrue);
      expect(
        member.permissions.containsKey('viewCreditBackingAmount'),
        isFalse,
      );
      expect(member.permissions.containsKey('email'), isFalse);
    },
  );

  test('override authority and quorum are deterministic', () {
    expect(
      OverrideAuthorityX.fromWireName('system_warden'),
      OverrideAuthority.self,
    );
    expect(OverrideAuthorityX.fromWireName('AI'), OverrideAuthority.ai);
    expect(circleMajority(1), 1);
    expect(circleMajority(2), 2);
    expect(circleMajority(3), 2);
    expect(circleMajority(4), 3);
  });

  test(
    'Commitment policy keeps authority and sharing assignments separate',
    () {
      final policy = CommitmentOverridePolicy.fromJson({
        'authority': 'circle',
        'selectedMemberIds': ['voter-1'],
        'sharedMemberIds': ['observer-1'],
      }, 'commitment-1');

      expect(policy.authority, OverrideAuthority.circle);
      expect(policy.selectedMemberIds, ['voter-1']);
      expect(policy.sharedMemberIds, ['observer-1']);
    },
  );
}
