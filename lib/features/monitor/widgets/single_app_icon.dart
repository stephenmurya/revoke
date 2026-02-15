import 'package:flutter/material.dart';
import '../../../core/services/app_discovery_service.dart';
import 'dart:typed_data';

import '../../../core/utils/theme_extensions.dart';

class SingleAppIcon extends StatelessWidget {
  final String packageName;
  final double size;

  const SingleAppIcon({super.key, required this.packageName, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppInfo>(
      future: AppDiscoveryService.getAppDetails(packageName),
      builder: (context, snapshot) {
        // Handle errors gracefully - show fallback icon instead of error
        if (snapshot.hasError) {
          return Icon(
            Icons.android,
            size: size,
            color: context.colors.textSecondary,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.scheme.primary,
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.icon != null) {
          return Image.memory(
            Uint8List.fromList(snapshot.data!.icon!),
            width: size,
            height: size,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.android,
                size: size,
                color: context.colors.textSecondary,
              );
            },
          );
        }

        return Icon(Icons.android, size: size, color: context.colors.textSecondary);
      },
    );
  }
}
