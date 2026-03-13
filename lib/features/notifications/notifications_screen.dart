import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/models/app_notification_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/in_app_notification_service.dart';
import '../../core/utils/theme_extensions.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isMarkingAllRead = false;

  Future<void> _markAllAsRead(String uid) async {
    if (_isMarkingAllRead) return;
    setState(() => _isMarkingAllRead = true);
    try {
      await InAppNotificationService.markAllAsRead(uid);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to mark notifications as read.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }

  Future<void> _handleNotificationTap(
    String uid,
    AppNotificationModel notification,
  ) async {
    if (!notification.isRead) {
      try {
        await InAppNotificationService.markAsRead(uid, notification.id);
      } catch (_) {}
    }

    final metadata = notification.metadata;
    final pleaId = (metadata?['pleaId'] as String?)?.trim();
    if (pleaId == null || pleaId.isEmpty) return;
    if (!mounted) return;
    context.push('/tribunal/$pleaId');
  }

  Map<String, List<AppNotificationModel>> _groupNotificationsByDate(
    List<AppNotificationModel> notifications,
  ) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final grouped = <String, List<AppNotificationModel>>{};

    for (final notification in notifications) {
      final timestamp = notification.timestamp.toLocal();
      late final String key;

      if (_isSameCalendarDay(timestamp, now)) {
        key = 'Today';
      } else if (_isSameCalendarDay(timestamp, yesterday)) {
        key = 'Yesterday';
      } else {
        key = DateFormat('MMMM d, yyyy').format(timestamp);
      }

      grouped
          .putIfAbsent(key, () => <AppNotificationModel>[])
          .add(notification);
    }

    return grouped;
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        final uid = user?.uid;

        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
            title: Text('Comms Log', style: context.text.titleLarge),
            actions: [
              IconButton(
                tooltip: 'Mark all read',
                onPressed: (uid == null || _isMarkingAllRead)
                    ? null
                    : () => _markAllAsRead(uid),
                icon: _isMarkingAllRead
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.accent,
                        ),
                      )
                    : PhosphorIcon(PhosphorIcons.checks()),
              ),
            ],
          ),
          body: uid == null
              ? Center(
                  child: Text(
                    'Sign in to view notifications.',
                    style: (context.text.bodyMedium ?? const TextStyle())
                        .copyWith(color: context.colors.textSecondary),
                  ),
                )
              : StreamBuilder<List<AppNotificationModel>>(
                  stream: InAppNotificationService.getUserNotifications(uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const _NotificationErrorState(
                        message:
                            'Comms Log unavailable. Check permissions/rules and retry.',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.colors.accent,
                        ),
                      );
                    }

                    final notifications =
                        snapshot.data ?? const <AppNotificationModel>[];
                    if (notifications.isEmpty) {
                      return const _EmptyNotificationsState();
                    }

                    final grouped = _groupNotificationsByDate(notifications);
                    final sections = grouped.entries.toList(growable: false);

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        final dateKey = section.key;
                        final items = section.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                index == 0 ? 16 : 24,
                                16,
                                8,
                              ),
                              child: Text(
                                dateKey,
                                style:
                                    (context.text.labelLarge ??
                                            const TextStyle())
                                        .copyWith(
                                          color: context.colors.textSecondary,
                                        ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: context.colors.textPrimary.withValues(
                                    alpha: 0.05,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.textPrimary
                                        .withValues(alpha: 0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0; i < items.length; i++) ...[
                                    _NotificationTile(
                                      notification: items[i],
                                      onTap: () =>
                                          _handleNotificationTap(uid, items[i]),
                                    ),
                                    if (i < items.length - 1)
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: context.colors.textPrimary
                                            .withValues(alpha: 0.05),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}

class _NotificationErrorState extends StatelessWidget {
  const _NotificationErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: (context.text.bodyMedium ?? const TextStyle()).copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.terminalWindow(),
              size: 72,
              color: context.colors.textSecondary.withValues(alpha: 0.24),
            ),
            const SizedBox(height: 14),
            Text(
              'COMMS LINK SECURE. NO INCOMING TRANSMISSIONS.',
              textAlign: TextAlign.center,
              style: (context.text.bodyMedium ?? const TextStyle()).copyWith(
                color: context.colors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForType(notification.type);
    final typeColor = _typeColor(context, notification.type);
    final timeLabel = DateFormat(
      'h:mm a',
    ).format(notification.timestamp.toLocal());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: PhosphorIcon(iconData, size: 18, color: typeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                notification.title,
                                style:
                                    context.text.labelLarge ??
                                    const TextStyle(),
                                softWrap: true,
                              ),
                            ),
                            if (!notification.isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(
                                  color: context.colors.accent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.colors.accent.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 0.4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeLabel,
                        style: (context.text.labelSmall ?? const TextStyle())
                            .copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.body,
                    style: (context.text.bodyMedium ?? const TextStyle())
                        .copyWith(height: 1.4),
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'plea':
        return PhosphorIcons.handsPraying();
      case 'verdict':
        return PhosphorIcons.gavel();
      case 'shame':
        return PhosphorIcons.warning();
      case 'support':
        return PhosphorIcons.handshake();
      case 'system':
        return PhosphorIcons.info();
      default:
        return PhosphorIcons.bell();
    }
  }

  Color _typeColor(BuildContext context, String type) {
    switch (type.toLowerCase()) {
      case 'plea':
        return context.colors.textPrimary;
      case 'verdict':
        return context.colors.accent;
      case 'shame':
        return context.colors.danger;
      case 'support':
        return context.colors.success;
      case 'system':
        return Colors.cyanAccent;
      default:
        return context.colors.textSecondary;
    }
  }
}
