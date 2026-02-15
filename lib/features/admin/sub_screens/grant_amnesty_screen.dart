import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../squad/widgets/squad_member_card.dart';
import '../widgets/admin_user_directory.dart';

class GrantAmnestyScreen extends StatelessWidget {
  const GrantAmnestyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminUserDirectory(
      title: 'Grant Amnesty',
      searchHintText: 'Select user for amnesty',
      onUserTap: (user) => _showGrantAmnestySheet(context, user),
    );
  }

  Future<void> _showGrantAmnestySheet(
    BuildContext context,
    UserModel user,
  ) async {
    final theme = Theme.of(context);
    bool granting = false;
    final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SquadMemberCard(
                    member: user,
                    margin: EdgeInsets.zero,
                    trailing: const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Grant immunity to this user?',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: granting
                        ? null
                        : () async {
                            setModalState(() => granting = true);
                            try {
                              await functions
                                  .httpsCallable('grantAmnesty')
                                  .call({'targetUserId': user.uid});
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Amnesty granted.'),
                                ),
                              );
                            } on FirebaseFunctionsException catch (e) {
                              if (!sheetContext.mounted) return;
                              final message = e.message ?? e.code;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text('Failed: $message')),
                              );
                              setModalState(() => granting = false);
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                              setModalState(() => granting = false);
                            }
                          },
                    child: Text(granting ? 'Granting...' : 'Grant Amnesty'),
                  ),
                  TextButton(
                    onPressed: granting
                        ? null
                        : () => Navigator.of(sheetContext).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
