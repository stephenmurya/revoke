import 'package:flutter/material.dart';

import '../../core/utils/theme_extensions.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            title.toUpperCase(),
            style: context.text.headlineMedium?.copyWith(
                  color: context.scheme.primary,
                ) ??
                TextStyle(color: context.scheme.primary),
          ),
        ),
      ),
    );
  }
}
