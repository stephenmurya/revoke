import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/plea_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/circle_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

class OverrideHistoryScreen extends StatelessWidget {
  const OverrideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Override History'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: StreamBuilder<List<PleaModel>>(
        stream: CircleService.watchOverrideHistory(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const RevokeLoadingState(label: 'Loading Override History');
          }
          final requests = snapshot.data ?? const <PleaModel>[];
          if (requests.isEmpty) {
            return const RevokeEmptyState(
              title: 'No Override History',
              message:
                  'Requests you make for temporary access will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              RevokeSpacing.lg,
              RevokeSpacing.sm,
              RevokeSpacing.lg,
              RevokeSpacing.xxl,
            ),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const RevokeDivider(),
            itemBuilder: (context, index) {
              final request = requests[index];
              final status = request.status.trim().toLowerCase();
              final authority = request.authority == 'legacy'
                  ? 'Previous request'
                  : request.authority == 'circle'
                  ? 'Circle'
                  : request.authority == 'ai'
                  ? 'AI Architect'
                  : 'Self';
              return RevokeSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            request.appName,
                            style: context.text.cardTitle,
                          ),
                        ),
                        RevokePill(label: _statusLabel(status)),
                      ],
                    ),
                    const SizedBox(height: RevokeSpacing.sm),
                    Text(
                      '$authority · ${request.durationMinutes} minutes',
                      style: context.text.bodySecondary.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    if (request.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: RevokeSpacing.sm),
                      Text(request.reason, style: context.text.bodySecondary),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'approved' => 'Approved',
    'rejected' => 'Not approved',
    'pending' => 'Reviewing',
    'active' => 'Awaiting Circle',
    _ => 'Recorded',
  };
}
