import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/circle_models.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/circle_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import '../commitments/commitment_presentation.dart';

class OverridePolicyScreen extends StatefulWidget {
  const OverridePolicyScreen({super.key, required this.commitment});

  final CommitmentViewModel commitment;

  @override
  State<OverridePolicyScreen> createState() => _OverridePolicyScreenState();
}

class _OverridePolicyScreenState extends State<OverridePolicyScreen> {
  late Future<CommitmentOverridePolicy> _policyFuture;
  OverrideAuthority _authority = OverrideAuthority.self;
  final Set<String> _selectedMemberIds = <String>{};
  final Set<String> _sharedMemberIds = <String>{};
  bool _loaded = false;
  bool _saving = false;
  late Future<Map<String, dynamic>?> _userFuture;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.currentUser?.uid ?? '';
    _policyFuture = CircleService.getPolicy(
      uid: uid,
      commitmentId: widget.commitment.id,
    );
    _userFuture = AuthService.getUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Override Authority'),
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(PhosphorIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<CommitmentOverridePolicy>(
        future: _policyFuture,
        builder: (context, policySnapshot) {
          if (policySnapshot.connectionState == ConnectionState.waiting) {
            return const RevokeLoadingState(label: 'Loading authority');
          }
          if (!_loaded && policySnapshot.hasData) {
            _loaded = true;
            _authority = policySnapshot.data!.authority;
            _selectedMemberIds.addAll(policySnapshot.data!.selectedMemberIds);
            _sharedMemberIds.addAll(policySnapshot.data!.sharedMemberIds);
          }
          return FutureBuilder<Map<String, dynamic>?>(
            future: _userFuture,
            builder: (context, userSnapshot) {
              final circleId =
                  (userSnapshot.data?['squadId'] as String?)?.trim() ?? '';
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  RevokeSpacing.lg,
                  RevokeSpacing.sm,
                  RevokeSpacing.lg,
                  RevokeSpacing.xxl,
                ),
                children: [
                  Text(widget.commitment.name, style: context.text.pageTitle),
                  const SizedBox(height: RevokeSpacing.sm),
                  Text(
                    'Choose who can decide a short access request for this Commitment.',
                    style: context.text.bodySecondary.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: RevokeSpacing.xl),
                  for (final authority in OverrideAuthority.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: RevokeSpacing.sm),
                      child: _AuthorityChoice(
                        authority: authority,
                        selected: _authority == authority,
                        onTap: () => setState(() => _authority = authority),
                      ),
                    ),
                  if (_authority == OverrideAuthority.circle &&
                      circleId.isEmpty)
                    RevokeSurface(
                      color: context.colors.warning.withValues(alpha: 0.10),
                      child: Text(
                        'Create or join a Circle before selecting Circle decisions.',
                        style: context.text.bodySecondary,
                      ),
                    ),
                  if (circleId.isNotEmpty) ...[
                    const SizedBox(height: RevokeSpacing.lg),
                    StreamBuilder<List<CircleMemberSummary>>(
                      stream: CircleService.watchMembers(circleId),
                      builder: (context, snapshot) {
                        final uid = AuthService.currentUser?.uid;
                        final allMembers =
                            (snapshot.data ?? const <CircleMemberSummary>[])
                                .where((member) => member.uid != uid)
                                .toList();
                        final votingMembers = allMembers
                            .where(
                              (member) => member.has(
                                CirclePermission.voteOnOverrideRequests,
                              ),
                            )
                            .toList();
                        final sharingMembers = allMembers
                            .where(
                              (member) => member.has(
                                CirclePermission.viewCommitmentSummary,
                              ),
                            )
                            .toList();
                        if (snapshot.hasError ||
                            snapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const RevokeLoadingState(
                            label: 'Loading Circle members',
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_authority == OverrideAuthority.circle) ...[
                              Text(
                                'Eligible voters',
                                style: context.text.sectionTitle,
                              ),
                              const SizedBox(height: RevokeSpacing.sm),
                              if (votingMembers.isEmpty)
                                const Text(
                                  'No Circle members currently have voting permission.',
                                )
                              else
                                _MemberCheckboxList(
                                  members: votingMembers,
                                  selectedIds: _selectedMemberIds,
                                  subtitle: 'Can vote on Override Requests',
                                  onChanged: (member, selected) => setState(() {
                                    if (selected) {
                                      _selectedMemberIds.add(member.uid);
                                    } else {
                                      _selectedMemberIds.remove(member.uid);
                                    }
                                  }),
                                ),
                              const SizedBox(height: RevokeSpacing.xl),
                            ],
                            Text(
                              'Share Commitment summary',
                              style: context.text.sectionTitle,
                            ),
                            const SizedBox(height: RevokeSpacing.xs),
                            Text(
                              'Only selected members can see this Commitment summary.',
                              style: context.text.bodySecondary.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: RevokeSpacing.sm),
                            if (sharingMembers.isEmpty)
                              const Text(
                                'No Circle members currently have summary-view permission.',
                              )
                            else
                              _MemberCheckboxList(
                                members: sharingMembers,
                                selectedIds: _sharedMemberIds,
                                subtitle: 'View shared Commitment summary',
                                onChanged: (member, selected) => setState(() {
                                  if (selected) {
                                    _sharedMemberIds.add(member.uid);
                                  } else {
                                    _sharedMemberIds.remove(member.uid);
                                  }
                                }),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: RevokeSpacing.xxl),
                  RevokeButton(
                    label: 'Save authority',
                    loading: _saving,
                    onPressed: _saving ? null : () => _save(circleId),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _save(String circleId) async {
    if (_authority == OverrideAuthority.circle &&
        (circleId.isEmpty || _selectedMemberIds.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one eligible Circle member.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await CircleService.setPolicy(
        commitmentId: widget.commitment.id,
        authority: _authority,
        selectedMemberIds: _authority == OverrideAuthority.circle
            ? _selectedMemberIds.toList()
            : const [],
        sharedMemberIds: _sharedMemberIds.toList(),
      );
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authority could not be saved: $error')),
        );
      }
    }
  }
}

class _AuthorityChoice extends StatelessWidget {
  const _AuthorityChoice({
    required this.authority,
    required this.selected,
    required this.onTap,
  });

  final OverrideAuthority authority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${authority.label}: ${authority.description}',
      child: InkWell(
        onTap: onTap,
        borderRadius: RevokeRadii.cardRadius,
        child: RevokeSurface(
          color: selected ? context.colors.accentSoft : null,
          bordered: selected,
          child: Row(
            children: [
              Icon(
                selected ? PhosphorIcons.radioButtonFill : PhosphorIcons.circle,
                color: selected
                    ? context.colors.accent
                    : context.colors.textMuted,
                size: RevokeIconSizes.standard,
              ),
              const SizedBox(width: RevokeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authority.label, style: context.text.cardTitle),
                    const SizedBox(height: RevokeSpacing.xs),
                    Text(
                      authority.description,
                      style: context.text.bodySecondary.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCheckboxList extends StatelessWidget {
  const _MemberCheckboxList({
    required this.members,
    required this.selectedIds,
    required this.subtitle,
    required this.onChanged,
  });

  final List<CircleMemberSummary> members;
  final Set<String> selectedIds;
  final String subtitle;
  final void Function(CircleMemberSummary member, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return RevokeSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < members.length; index++) ...[
            CheckboxListTile(
              value: selectedIds.contains(members[index].uid),
              title: Text(members[index].displayName),
              subtitle: Text(subtitle),
              onChanged: (selected) =>
                  onChanged(members[index], selected == true),
            ),
            if (index < members.length - 1) const RevokeDivider(),
          ],
        ],
      ),
    );
  }
}
