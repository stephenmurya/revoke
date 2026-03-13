import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/theme_extensions.dart';
import 'prototypes/squad_hud_v2_prototype.dart';

class UITestDirectoryScreen extends StatelessWidget {
  final bool embedded;

  const UITestDirectoryScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      children: [
        ListTile(
          leading: Icon(PhosphorIcons.flask(), color: context.scheme.primary),
          title: Text('Squad HUD 2.0 (The Barracks)', style: AppTheme.baseBold),
          subtitle: Text(
            'Testing ground for the new Pillory and Squad Logs.',
            style: AppTheme.smRegular.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          trailing: Icon(
            PhosphorIcons.caretRight(),
            color: context.colors.textSecondary,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SquadHudV2Prototype(),
            ),
          ),
        ),
      ],
    );

    if (embedded) {
      return list;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('UI Tests'),
      ),
      body: list,
    );
  }
}
