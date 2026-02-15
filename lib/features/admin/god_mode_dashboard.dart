import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'sub_screens/admin_ledger_screen.dart';
import 'sub_screens/adjust_score_screen.dart';
import 'sub_screens/broadcast_mandate_screen.dart';
import 'sub_screens/grant_amnesty_screen.dart';

class GodModeDashboard extends StatefulWidget {
  const GodModeDashboard({super.key});

  @override
  State<GodModeDashboard> createState() => _GodModeDashboardState();
}

class _GodModeDashboardState extends State<GodModeDashboard> {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  bool _runningSimulation = false;
  int _userCount = 0;
  int _mockUserCount = 0;
  int _activeTrialCount = 0;
  int _squadCount = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _checkingAdmin = false;
        _isAdmin = false;
      });
      return;
    }

    bool isAdmin = false;
    try {
      final token = await user.getIdTokenResult(true);
      isAdmin = token.claims?['admin'] == true;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _checkingAdmin = false;
    });

    if (isAdmin) {
      await _refreshStats();
    }
  }

  Future<int> _countQuery(Query<Map<String, dynamic>> query) async {
    try {
      final aggregate = await query.count().get();
      return aggregate.count ?? 0;
    } catch (_) {
      final snapshot = await query.get();
      return snapshot.size;
    }
  }

  Future<void> _refreshStats() async {
    final usersQuery = FirebaseFirestore.instance.collection('users');
    final mockUsersQuery = FirebaseFirestore.instance
        .collection('users')
        .where('isMockUser', isEqualTo: true);
    final activeTrialsQuery = FirebaseFirestore.instance
        .collection('pleas')
        .where('status', isEqualTo: 'active');
    final squadsQuery = FirebaseFirestore.instance.collection('squads');

    final results = await Future.wait([
      _countQuery(usersQuery),
      _countQuery(mockUsersQuery),
      _countQuery(activeTrialsQuery),
      _countQuery(squadsQuery),
    ]);

    if (!mounted) return;
    setState(() {
      _userCount = results[0];
      _mockUserCount = results[1];
      _activeTrialCount = results[2];
      _squadCount = results[3];
    });
  }

  Future<void> _openScreen(Widget child) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => child));
    await _refreshStats();
  }

  Future<void> _runSimulation() async {
    if (_runningSimulation) return;
    setState(() => _runningSimulation = true);
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    try {
      final result = await functions.httpsCallable('createMockTribunal').call();
      final data = Map<String, dynamic>.from(result.data as Map? ?? const {});
      final pleaId = (data['pleaId'] as String?)?.trim();
      if (!mounted) return;
      if (pleaId != null && pleaId.isNotEmpty) {
        await context.push('/tribunal/$pleaId');
        if (!mounted) return;
        try {
          await functions.httpsCallable('destroyMockTribunal').call({
            'pleaId': pleaId,
          });
        } catch (_) {}
        await _refreshStats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulation generated with no plea ID.'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = e.message ?? e.code;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Simulation failed: $message')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Simulation failed: $e')));
    } finally {
      if (mounted) setState(() => _runningSimulation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_checkingAdmin) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          title: const Text('System Command Center'),
        ),
        body: Center(
          child: Text(
            'Admin access required',
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.error),
          ),
        ),
      );
    }

    final actions = <_DashboardAction>[
      _DashboardAction(
        icon: Icons.notifications_active_rounded,
        label: 'Broadcast',
        onTap: () => _openScreen(const BroadcastMandateScreen()),
      ),
      _DashboardAction(
        icon: Icons.tune_rounded,
        label: 'Focus Score',
        onTap: () => _openScreen(const AdjustScoreScreen()),
      ),
      _DashboardAction(
        icon: Icons.lock_open_rounded,
        label: 'Grant Amnesty',
        onTap: () => _openScreen(const GrantAmnestyScreen()),
      ),
      _DashboardAction(
        icon: Icons.list_alt_rounded,
        label: 'Shame Ledger',
        onTap: () => _openScreen(const AdminLedgerScreen()),
      ),
      _DashboardAction(
        icon: Icons.gavel_rounded,
        label: 'Active Trials',
        onTap: () => _openScreen(const _ActiveTribunalsScreen()),
      ),
      _DashboardAction(
        icon: Icons.science_rounded,
        label: _runningSimulation ? 'Running...' : 'Simulation',
        onTap: _runSimulation,
      ),
    ];
    final truePopulation = (_userCount - _mockUserCount).clamp(0, _userCount);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text('System Command Center'),
        actions: [
          IconButton(
            onPressed: _refreshStats,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live System Metrics', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(label: 'Global Population', value: truePopulation),
                _StatCard(label: 'Active Trials', value: _activeTrialCount),
                _StatCard(label: 'Squads Online', value: _squadCount),
              ],
            ),
            const SizedBox(height: 22),
            Text('Command Rail', style: textTheme.titleMedium),
            const SizedBox(height: 10),
            GridView.builder(
              itemCount: actions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 126,
              ),
              itemBuilder: (context, index) {
                return _ActionCapsule(action: actions[index], fullWidth: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTribunalsScreen extends StatelessWidget {
  const _ActiveTribunalsScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = FirebaseFirestore.instance
        .collection('pleas')
        .where('status', isEqualTo: 'active');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text('Active Trials'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load active trials',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          final docs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.of(
                snapshot.data?.docs ?? const [],
              )..sort((a, b) {
                final aDate = _asDateTime(a.data()['createdAt']);
                final bDate = _asDateTime(b.data()['createdAt']);
                return bDate.compareTo(aDate);
              });

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No active tribunals',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final appName = (data['appName'] as String?)?.trim();
              final userName = (data['userName'] as String?)?.trim();
              final reason = (data['reason'] as String?)?.trim();
              final duration = (data['durationMinutes'] as num?)?.toInt() ?? 0;
              final voteCounts = Map<String, dynamic>.from(
                data['voteCounts'] as Map? ?? const {},
              );
              final accept = (voteCounts['accept'] as num?)?.toInt() ?? 0;
              final reject = (voteCounts['reject'] as num?)?.toInt() ?? 0;

              return Card(
                color: theme.colorScheme.surface,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () => context.push('/tribunal/${docs[index].id}'),
                  title: Text(
                    '${appName?.isNotEmpty == true ? appName : 'Unknown App'} - ${duration}m',
                  ),
                  subtitle: Text(
                    '${userName?.isNotEmpty == true ? userName : 'Unknown User'}\n'
                    '${reason?.isNotEmpty == true ? reason : 'No reason'}\n'
                    '$accept Approve / $reject Reject',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            value.toString(),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCapsule extends StatelessWidget {
  const _ActionCapsule({required this.action, this.fullWidth = false});

  final _DashboardAction action;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        width: fullWidth ? double.infinity : 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(action.icon, color: colorScheme.primary, size: 24),
            Text(
              action.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
