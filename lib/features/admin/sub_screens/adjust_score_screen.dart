import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../squad/widgets/squad_member_card.dart';
import '../widgets/admin_user_directory.dart';

class AdjustScoreScreen extends StatelessWidget {
  const AdjustScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminUserDirectory(
      title: 'Adjust Focus Score',
      searchHintText: 'Search by name, nickname or UID',
      onUserTap: (user) => _showAdjustScoreSheet(context, user),
    );
  }

  Future<void> _showAdjustScoreSheet(
    BuildContext context,
    UserModel user,
  ) async {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: user.focusScore.toString());
    bool saving = false;

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
            final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
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
                    'Set new focus score',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.headlineSmall,
                    decoration: InputDecoration(
                      hintText: '500',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.28),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final score = int.tryParse(controller.text.trim());
                            if (score == null) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Enter a valid integer score.'),
                                ),
                              );
                              return;
                            }

                            setModalState(() => saving = true);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({'focusScore': score});
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Focus score updated.'),
                                ),
                              );
                            } catch (e) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                              setModalState(() => saving = false);
                            }
                          },
                    child: Text(saving ? 'Setting...' : 'Set Score'),
                  ),
                  TextButton(
                    onPressed: saving
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
