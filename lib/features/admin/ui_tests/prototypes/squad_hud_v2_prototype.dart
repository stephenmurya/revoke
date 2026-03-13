import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/theme_extensions.dart';

class SquadHudV2Prototype extends StatelessWidget {
  final bool useMockData;

  const SquadHudV2Prototype({super.key, this.useMockData = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.prototypeBannerColor,
        foregroundColor: AppTheme.prototypeBannerOnColor,
        title: Text(
          'PROTOTYPE: Squad HUD v2',
          style: AppTheme.h3.copyWith(color: AppTheme.prototypeBannerOnColor),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppTheme.prototypeBannerColor.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              useMockData
                  ? 'Prototype Mode: Mock data enabled'
                  : 'Prototype Mode: Live data disabled',
              style: AppTheme.smBold.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text('Squad HUD 2.0 Sandbox - Ready for UI ingestion.'),
            ),
          ),
        ],
      ),
    );
  }
}
