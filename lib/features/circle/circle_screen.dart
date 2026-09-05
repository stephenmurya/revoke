import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/circle_models.dart';
import '../../core/models/plea_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/circle_service.dart';
import '../../core/services/squad_service.dart';
import '../../core/services/premium_entitlement_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key});

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> {
  late Future<Map<String, dynamic>?> _userFuture;
  late Future<List<Map<String, dynamic>>> _sharedCommitmentsFuture;
  final Set<String> _summaryRefreshes = <String>{};

  @override
  void initState() {
    super.initState();
    _userFuture = AuthService.getUserData();
    _sharedCommitmentsFuture = CircleService.getSharedCommitmentSummaries();
  }

  void _reload() {
    setState(() {
      _userFuture = AuthService.getUserData();
      _sharedCommitmentsFuture = CircleService.getSharedCommitmentSummaries();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _userFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const RevokeLoadingState(label: 'Loading Circle');
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final circleId = (data['squadId'] as String?)?.trim() ?? '';
        final circleCode = (data['squadCode'] as String?)?.trim() ?? '';
        if (circleId.isEmpty) {
          return _CircleEmptyState(
            onCreate: _createCircle,
            onJoin: _showJoinDialog,
          );
        }

        if (_summaryRefreshes.add(circleId)) {
          unawaited(
            CircleService.ensureMemberSummaries(circleId).catchError((_) {}),
          );
        }

        return _CircleBody(
          circleId: circleId,
          circleCode: circleCode,
          sharedCommitmentsFuture: _sharedCommitmentsFuture,
          onRefresh: () async => _reload(),
        );
      },
    );
  }

  Future<void> _createCircle() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final premium = PremiumEntitlementService.instance;
    if (premium.state.value.isLoading) await premium.refresh();
    if (!premium.hasPremium) {
      if (mounted) {
        context.push(
          '/premium',
          extra: 'Creating a Circle is available with Premium.',
        );
      }
      return;
    }
    try {
      await SquadService.createSquad(uid);
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Your Circle is ready.')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Circle could not be created: $error')),
      );
    }
  }

  Future<void> _showJoinDialog() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a Circle'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Circle code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;
    try {
      await SquadService.joinSquad(code);
      if (mounted) _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Circle could not be joined: $error')),
      );
    }
  }
}

class _CircleEmptyState extends StatelessWidget {
  const _CircleEmptyState({required this.onCreate, required this.onJoin});

  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        RevokeSpacing.lg,
        RevokeSpacing.xl,
        RevokeSpacing.lg,
        RevokeSpacing.xxl,
      ),
      children: [
        Text('Accountability Circle', style: context.text.headlineSmall),
        const SizedBox(height: RevokeSpacing.sm),
        Text(
          'Circle is optional. Invite people you trust when shared accountability would help.',
          style: context.text.bodySecondary.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: RevokeSpacing.xxl),
        RevokeSurface(
          padding: const EdgeInsets.all(RevokeSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PhosphorIcons.usersThree,
                color: context.colors.accent,
                size: RevokeIconSizes.feature,
              ),
              const SizedBox(height: RevokeSpacing.lg),
              Text('No Circle yet', style: context.text.sectionTitle),
              const SizedBox(height: RevokeSpacing.sm),
              Text(
                'Your Commitments work on their own. Create or join a Circle only when you want other people involved.',
                style: context.text.bodySecondary.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: RevokeSpacing.xl),
              RevokeButton(
                label: 'Create Circle',
                icon: PhosphorIcons.plus,
                onPressed: onCreate,
              ),
              const SizedBox(height: RevokeSpacing.sm),
              RevokeButton(
                label: 'Join with a code',
                variant: RevokeButtonVariant.secondary,
                onPressed: onJoin,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleBody extends StatelessWidget {
  const _CircleBody({
    required this.circleId,
    required this.circleCode,
    required this.sharedCommitmentsFuture,
    required this.onRefresh,
  });

  final String circleId;
  final String circleCode;
  final Future<List<Map<String, dynamic>>> sharedCommitmentsFuture;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid ?? '';
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colors.accent,
      child: ListView(
        key: const PageStorageKey<String>('circle-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          RevokeSpacing.lg,
          RevokeSpacing.sm,
          RevokeSpacing.lg,
          RevokeSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Your Circle', style: context.text.headlineSmall),
              ),
              RevokeIconButton(
                icon: PhosphorIcons.clockCounterClockwise,
                tooltip: 'Override History',
                onPressed: () => context.push('/override-history'),
              ),
            ],
          ),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            'Members only see the Commitment information and requests you choose to share.',
            style: context.text.bodySecondary.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          if (circleCode.isNotEmpty) ...[
            const SizedBox(height: RevokeSpacing.md),
            RevokePill(
              icon: PhosphorIcons.key,
              label: circleCode,
              color: context.colors.accent,
              semanticLabel: 'Circle invite code $circleCode',
            ),
          ],
          const SizedBox(height: RevokeSpacing.xl),
          const RevokeSectionHeader(title: 'Members'),
          const SizedBox(height: RevokeSpacing.sm),
          StreamBuilder<List<CircleMemberSummary>>(
            stream: CircleService.watchMembers(circleId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return RevokeSurface(
                  child: Text(
                    'Member information is temporarily unavailable.',
                    style: context.text.bodySecondary,
                  ),
                );
              }
              final members = snapshot.data ?? const <CircleMemberSummary>[];
              if (members.isEmpty) {
                return const RevokeSurface(
                  child: Text('Circle members are syncing. Pull to refresh.'),
                );
              }
              final isOwner = members.any(
                (member) => member.uid == uid && member.role == 'owner',
              );
              return RevokeSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < members.length; index++) ...[
                      _CircleMemberRow(
                        member: members[index],
                        onTap: () => _showMemberSheet(
                          context,
                          circleId,
                          members[index],
                          canManage: isOwner && members[index].uid != uid,
                        ),
                      ),
                      if (index < members.length - 1) const RevokeDivider(),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: RevokeSpacing.xl),
          const RevokeSectionHeader(title: 'Shared Commitments'),
          const SizedBox(height: RevokeSpacing.sm),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: sharedCommitmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const RevokeLoadingState(
                  label: 'Loading shared Commitments',
                );
              }
              final shared = snapshot.data ?? const <Map<String, dynamic>>[];
              if (snapshot.hasError || shared.isEmpty) {
                return Text(
                  'Commitments shared with you will appear here.',
                  style: context.text.bodySecondary.copyWith(
                    color: context.colors.textMuted,
                  ),
                );
              }
              return RevokeSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < shared.length; index++) ...[
                      ListTile(
                        title: Text(
                          shared[index]['name']?.toString() ?? 'Commitment',
                        ),
                        subtitle: Text(
                          '${shared[index]['ownerName'] ?? 'Circle member'} · ${shared[index]['summary'] ?? 'Shared summary'}',
                        ),
                        trailing: shared[index]['targetAppCount'] is num
                            ? Text('${shared[index]['targetAppCount']} apps')
                            : null,
                      ),
                      if (index < shared.length - 1) const RevokeDivider(),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: RevokeSpacing.xl),
          const RevokeSectionHeader(title: 'Override Requests'),
          const SizedBox(height: RevokeSpacing.sm),
          StreamBuilder<List<PleaModel>>(
            stream: CircleService.watchVisibleOverrideRequests(uid),
            builder: (context, snapshot) {
              final requests = snapshot.data ?? const <PleaModel>[];
              if (requests.isEmpty) {
                return Text(
                  'Requests shared with you will appear here.',
                  style: context.text.bodySecondary.copyWith(
                    color: context.colors.textMuted,
                  ),
                );
              }
              return RevokeSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < requests.length; index++) ...[
                      ListTile(
                        minVerticalPadding: RevokeSpacing.md,
                        title: Text(requests[index].appName),
                        subtitle: Text(
                          '${requests[index].durationMinutes} minutes · ${requests[index].authority == 'circle' ? 'Circle decision' : 'AI review'}',
                        ),
                        trailing: Icon(
                          PhosphorIcons.caretRight,
                          color: context.colors.textMuted,
                        ),
                        onTap: () =>
                            context.push('/tribunal/${requests[index].id}'),
                      ),
                      if (index < requests.length - 1) const RevokeDivider(),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: RevokeSpacing.xl),
          RevokeButton(
            label: 'Leave Circle',
            variant: RevokeButtonVariant.secondary,
            onPressed: () => _leaveCircle(context),
          ),
        ],
      ),
    );
  }

  static Future<void> _showMemberSheet(
    BuildContext context,
    String circleId,
    CircleMemberSummary member, {
    required bool canManage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CircleMemberSheet(
        circleId: circleId,
        member: member,
        canManage: canManage,
      ),
    );
  }

  Future<void> _leaveCircle(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Circle?'),
        content: const Text(
          'You will no longer receive shared requests or Circle updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await CircleService.leaveCircle(circleId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You left the Circle.')));
      await onRefresh();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Circle could not be left: $error')),
      );
    }
  }
}

class _CircleMemberRow extends StatelessWidget {
  const _CircleMemberRow({required this.member, required this.onTap});

  final CircleMemberSummary member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = member.role == 'owner' ? 'Owner' : member.preset.label;
    return Semantics(
      button: true,
      label: '${member.displayName}, $role',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(RevokeSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                radius: RevokeIconSizes.standard,
                backgroundColor: context.colors.accentSoft,
                child: Text(
                  member.displayName.substring(0, 1).toUpperCase(),
                  style: context.text.label.copyWith(
                    color: context.colors.accent,
                  ),
                ),
              ),
              const SizedBox(width: RevokeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.displayName, style: context.text.cardTitle),
                    const SizedBox(height: RevokeSpacing.xs),
                    Text(
                      role,
                      style: context.text.caption.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.caretRight,
                size: RevokeIconSizes.standard,
                color: context.colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleMemberSheet extends StatefulWidget {
  const _CircleMemberSheet({
    required this.circleId,
    required this.member,
    required this.canManage,
  });

  final String circleId;
  final CircleMemberSummary member;
  final bool canManage;

  @override
  State<_CircleMemberSheet> createState() => _CircleMemberSheetState();
}

class _CircleMemberSheetState extends State<_CircleMemberSheet> {
  late CirclePreset _preset;
  late Map<String, bool> _permissions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _preset = widget.member.preset;
    _permissions = {
      ...circlePresetPermissions(_preset),
      ...widget.member.permissions,
    };
  }

  @override
  Widget build(BuildContext context) {
    final manageablePermissions = CirclePermission.values;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          RevokeSpacing.lg,
          RevokeSpacing.lg,
          RevokeSpacing.lg,
          RevokeSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.member.displayName, style: context.text.pageTitle),
              const SizedBox(height: RevokeSpacing.xs),
              Text(
                widget.member.role == 'owner'
                    ? 'Circle owner'
                    : 'Circle member',
                style: context.text.bodySecondary.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: RevokeSpacing.sm),
              TextButton.icon(
                onPressed: () => _showHistory(context),
                icon: const Icon(Icons.history),
                label: const Text('View shared Override History'),
              ),
              const SizedBox(height: RevokeSpacing.xl),
              Text('Permission preset', style: context.text.sectionTitle),
              const SizedBox(height: RevokeSpacing.sm),
              DropdownButtonFormField<CirclePreset>(
                initialValue: _preset,
                decoration: const InputDecoration(labelText: 'Preset'),
                items: CirclePreset.values
                    .map(
                      (preset) => DropdownMenuItem(
                        value: preset,
                        child: Text(preset.label),
                      ),
                    )
                    .toList(),
                onChanged: widget.canManage
                    ? (preset) {
                        if (preset == null) return;
                        setState(() {
                          _preset = preset;
                          _permissions = circlePresetPermissions(preset);
                        });
                      }
                    : null,
              ),
              const SizedBox(height: RevokeSpacing.lg),
              for (final permission in manageablePermissions)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(permission.label),
                  value: _permissions[permission.wireName] == true,
                  onChanged: !widget.canManage
                      ? null
                      : (value) => setState(
                          () => _permissions[permission.wireName] = value,
                        ),
                ),
              if (widget.canManage) ...[
                const SizedBox(height: RevokeSpacing.md),
                RevokeButton(
                  label: 'Save permissions',
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await CircleService.updateMemberPermissions(
        circleId: widget.circleId,
        memberUid: widget.member.uid,
        preset: _preset,
        permissions: _permissions,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permissions could not be saved: $error')),
        );
      }
    }
  }

  Future<void> _showHistory(BuildContext context) async {
    try {
      final history = await CircleService.getMemberOverrideHistory(
        widget.member.uid,
      );
      if (!mounted || !context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${widget.member.displayName} · Override History'),
          content: SizedBox(
            width: double.maxFinite,
            child: history.isEmpty
                ? const Text('No shared history is available.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['appName']?.toString() ?? 'App'),
                        subtitle: Text(
                          '${item['status'] ?? 'Recorded'} · ${item['durationMinutes'] ?? 0} minutes',
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Override History is not shared: $error')),
        );
      }
    }
  }
}
