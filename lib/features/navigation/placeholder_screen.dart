import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppSemanticColors.background,
      body: SafeArea(
        child: Center(
          child: Text(
            title.toUpperCase(),
            style: AppTheme.h2.copyWith(color: AppSemanticColors.accentText),
          ),
        ),
      ),
    );
  }
}
