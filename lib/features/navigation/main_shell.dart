import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import '../../core/widgets/revoke_credits_pill.dart';
import '../../core/services/credit_service.dart';

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
      padding: const EdgeInsets.only(right: RevokeSpacing.sm),
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

          return SizedBox(
            width: RevokeTouchTargets.minimum,
            height: RevokeTouchTargets.minimum,
            child: IconButton(
              tooltip: 'Profile',
              padding: const EdgeInsets.all(RevokeSpacing.xs),
              onPressed: () => context.push('/profile'),
              icon: CircleAvatar(
                radius: RevokeIconSizes.account / 2,
                backgroundColor: context.colors.accentSoft,
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(photoUrl)
                    : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Text(
                        initial.toUpperCase(),
                        style:
                            (context.text.labelMedium ??
                                    Theme.of(context).textTheme.labelMedium ??
                                    const TextStyle())
                                .copyWith(color: context.colors.accent),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only show the HUD header on the shell root tabs.
    // Avoid using `.uri.toString()` here, because query params can change while
    // still being on the same tab, and non-go_router pushes won't update it.
    final String location = GoRouterState.of(context).matchedLocation;
    final bool showHudTopBar = _isShellRootLocation(location);
    int selectedIndex = 0;
    if (location == '/commitments') {
      selectedIndex = 1;
    } else if (location == '/squad') {
      selectedIndex = 2;
    } else if (location == '/insights') {
      selectedIndex = 3;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showHudTopBar
          ? AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              elevation: RevokeElevation.none,
              automaticallyImplyLeading: false,
              title: Text(
                _pageTitle(location),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                ValueListenableBuilder(
                  valueListenable: CreditService.instance.wallet,
                  builder: (context, wallet, _) => RevokeCreditsPill(
                    availableCredits: wallet.availableCredits,
                    onPressed: () => context.push('/credits'),
                  ),
                ),
                const SizedBox(width: RevokeSpacing.xs),
                RevokeIconButton(
                  tooltip: 'Notifications',
                  icon: PhosphorIcons.notification,
                  onPressed: () => context.push('/notifications'),
                ),
                _buildProfileAvatar(context),
              ],
            )
          : null,
      body: widget.child,
      bottomNavigationBar: showHudTopBar
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                const destinations = [
                  '/home',
                  '/commitments',
                  '/squad',
                  '/insights',
                ];
                context.go(destinations[index]);
              },
              destinations: [
                NavigationDestination(
                  icon: PhosphorIcon(PhosphorIcons.monitor),
                  selectedIcon: PhosphorIcon(PhosphorIcons.monitorFill),
                  label: 'Today',
                ),
                NavigationDestination(
                  icon: PhosphorIcon(PhosphorIcons.checkCircle),
                  selectedIcon: PhosphorIcon(PhosphorIcons.checkCircleFill),
                  label: 'Commitments',
                ),
                NavigationDestination(
                  icon: PhosphorIcon(PhosphorIcons.users),
                  selectedIcon: PhosphorIcon(PhosphorIcons.usersFill),
                  label: 'Circle',
                ),
                NavigationDestination(
                  icon: PhosphorIcon(PhosphorIcons.chartBar),
                  selectedIcon: PhosphorIcon(PhosphorIcons.chartBarFill),
                  label: 'Insights',
                ),
              ],
            )
          : null,
    );
  }

  bool _isShellRootLocation(String location) {
    return location == '/home' ||
        location == '/commitments' ||
        location == '/squad' ||
        location == '/insights';
  }

  String _pageTitle(String location) {
    switch (location) {
      case '/commitments':
        return 'Commitments';
      case '/squad':
        return 'Circle';
      case '/insights':
        return 'Insights';
      case '/home':
      default:
        return 'Today';
    }
  }
}
