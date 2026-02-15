import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../squad/widgets/squad_member_card.dart';

class AdminUserDirectory extends StatefulWidget {
  const AdminUserDirectory({
    super.key,
    required this.title,
    required this.onUserTap,
    this.query,
    this.searchHintText = 'Search users',
    this.emptyText = 'No users found',
  });

  final String title;
  final Query<Map<String, dynamic>>? query;
  final ValueChanged<UserModel> onUserTap;
  final String searchHintText;
  final String emptyText;

  @override
  State<AdminUserDirectory> createState() => _AdminUserDirectoryState();
}

class _AdminUserDirectoryState extends State<AdminUserDirectory> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final query =
        widget.query ?? FirebaseFirestore.instance.collection('users');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchText = value.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: widget.searchHintText,
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load users: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          final users = docs
              .map(_toUserModel)
              .where((user) => _matchesSearch(user, _searchText))
              .toList();

          if (users.isEmpty) {
            return Center(
              child: Text(
                widget.emptyText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return SquadMemberCard(
                member: user,
                onTap: () => widget.onUserTap(user),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          user.focusScore.toString(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Focus Score',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  bool _matchesSearch(UserModel user, String query) {
    if (query.isEmpty) return true;
    final values = <String>[
      user.uid,
      user.nickname ?? '',
      user.fullName ?? '',
      user.email ?? '',
    ];
    return values.any((value) => value.toLowerCase().contains(query));
  }

  UserModel _toUserModel(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return UserModel(
      uid: (data['uid'] as String?)?.trim().isNotEmpty == true
          ? (data['uid'] as String).trim()
          : doc.id,
      email: (data['email'] as String?)?.trim(),
      fullName: (data['fullName'] as String?)?.trim(),
      photoUrl: (data['photoUrl'] as String?)?.trim(),
      nickname: (data['nickname'] as String?)?.trim(),
      focusScore: (data['focusScore'] as num?)?.toInt() ?? 0,
      squadId: (data['squadId'] as String?)?.trim(),
      squadCode: (data['squadCode'] as String?)?.trim(),
    );
  }
}
