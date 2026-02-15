import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/utils/theme_extensions.dart';

class SettingsOptionTile extends StatelessWidget {
  const SettingsOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final PhosphorIconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final neutral = context.colors.textSecondary;
    final subtitleText = (subtitle ?? '').trim();
    final hasSubtitle = subtitleText.isNotEmpty;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          PhosphorIcon(icon, size: 22, color: neutral),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: (context.text.titleMedium ?? const TextStyle()).copyWith(
                    color: context.scheme.onSurface,
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style:
                        (context.text.bodySmall ?? const TextStyle()).copyWith(
                      color: neutral,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              PhosphorIcon(
                PhosphorIcons.caretRight(),
                size: 18,
                color: neutral.withValues(alpha: 0.7),
              ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: row,
        ),
      ),
    );
  }
}
