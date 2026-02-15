import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/admin_user_directory.dart';

class AdminLedgerScreen extends StatelessWidget {
  const AdminLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('users')
        .orderBy('focusScore', descending: false);

    return AdminUserDirectory(
      title: 'Shame Ledger',
      query: query,
      searchHintText: 'Search ledger entries',
      emptyText: 'No users available',
      onUserTap: (user) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.nickname ?? user.fullName ?? user.uid}: ${user.focusScore} focus',
            ),
          ),
        );
      },
    );
  }
}
