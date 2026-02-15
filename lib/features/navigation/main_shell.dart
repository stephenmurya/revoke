import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_logo.dart';

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late Future<Map<String, dynamic>?> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = AuthService.getUserData();
  }

  Widget _buildProfileAvatar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _userDataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final photoUrl = (data?['photoUrl'] as String?)?.trim();
          final displayName =
              (data?['fullName'] as String?)?.trim() ??
              (data?['nickname'] as String?)?.trim() ??
              'U';
          final initial = displayName.isNotEmpty ? displayName[0] : 'U';

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => context.push('/controls'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: context.scheme.surface,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(
                      initial.toUpperCase(),
                      style: (context.text.labelMedium ??
                              Theme.of(context).textTheme.labelMedium ??
                              const TextStyle())
                          .copyWith(color: context.scheme.primary),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show the HUD header on the three shell root tabs.
    // Avoid using `.uri.toString()` here, because query params can change while
    // still being on the same tab, and non-go_router pushes won't update it.
    final String location = GoRouterState.of(context).matchedLocation;
    final bool showHudTopBar =
        location == '/home' || location == '/squad' || location == '/challenges';
    int selectedIndex = 0;
    if (location == '/challenges') {
      selectedIndex = 2;
    } else if (location == '/squad') {
      selectedIndex = 1;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showHudTopBar
          ? AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 16,
              title: Row(
                children: [
                  const RevokeLogo(size: 30),
                  const SizedBox(width: 10),
                  Text(
                    'REVOKE',
                    style: (context.text.titleMedium ?? const TextStyle()).copyWith(
                      color: context.scheme.onSurface.withValues(alpha: 0.78),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: PhosphorIcon(PhosphorIcons.notification()),
                    color: context.scheme.onSurface.withValues(alpha: 0.72),
                    tooltip: 'Notifications',
                  ),
                  IconButton(
                    onPressed: () => context.push('/analytics'),
                    icon: PhosphorIcon(PhosphorIcons.chartBar()),
                    color: context.scheme.onSurface.withValues(alpha: 0.72),
                    tooltip: 'Analytics',
                  ),
                  _buildProfileAvatar(context),
                ],
              ),
            )
          : null,
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/home');
              break;
            case 1:
              context.go('/squad');
              break;
            case 2:
              context.go('/challenges');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIcons.monitor()),
            activeIcon: PhosphorIcon(
              PhosphorIcons.monitor(PhosphorIconsStyle.fill),
            ),
            label: 'Regimes',
          ),
          BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIcons.users()),
            activeIcon: PhosphorIcon(
              PhosphorIcons.users(PhosphorIconsStyle.fill),
            ),
            label: 'Squad',
          ),
          BottomNavigationBarItem(
            icon: PhosphorIcon(PhosphorIcons.flag()),
            activeIcon: PhosphorIcon(
              PhosphorIcons.flag(PhosphorIconsStyle.fill),
            ),
            label: 'Challenges',
          ),
        ],
      ),
    );
  }
}
