import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/services/settings_sync_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const Map<int, String> _accentNames = <int, String>{
    0xFFC2410C: 'Blaze',
    0xFFA61B1B: 'Crimson',
    0xFF175CD3: 'Cobalt',
    0xFF067647: 'Mint',
    0xFF6941C6: 'Violet',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            RevokeSpacing.lg,
            RevokeSpacing.sm,
            RevokeSpacing.lg,
            RevokeSpacing.xl,
          ),
          children: [
            _PreviewCard(scheme: scheme),
            const SizedBox(height: 16),
            _Section(
              title: 'Theme',
              subtitle: 'Choose light, dark, or follow the system.',
              child: _ThemeModePicker(scheme: scheme),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'Accent',
              subtitle: 'Choose a contrast-tested Revoke accent.',
              child: _AccentPicker(scheme: scheme),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: RevokeRadii.cardRadius,
        border: Border.all(color: context.colors.borderSubtle),
      ),
      padding: const EdgeInsets.all(RevokeSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.lgMedium),
          const SizedBox(height: RevokeSpacing.xs),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.70),
              height: 1.35,
            ),
          ),
          const SizedBox(height: RevokeSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: RevokeRadii.cardRadius,
        border: Border.all(color: context.colors.borderSubtle),
      ),
      padding: const EdgeInsets.all(RevokeSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: context.text.label),
          const SizedBox(height: RevokeSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: RevokeRadii.cardRadius,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
            ),
            padding: const EdgeInsets.all(RevokeSpacing.md),
            child: Row(
              children: [
                Container(
                  width: RevokeTouchTargets.minimum,
                  height: RevokeTouchTargets.minimum,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: RevokeRadii.controlRadius,
                  ),
                  child: Icon(PhosphorIcons.shield, color: scheme.onPrimary),
                ),
                const SizedBox(width: RevokeSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Usage Insights', style: AppTheme.baseMedium),
                      const SizedBox(height: RevokeSpacing.xs),
                      Text('7-day view', style: context.text.sectionTitle),
                    ],
                  ),
                ),
                ElevatedButton(onPressed: () {}, child: const Text('Insights')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final svc = ThemeService.instance;

    void setMode(ThemeMode mode) {
      unawaited(svc.setThemeMode(mode));
      unawaited(
        SettingsSyncService.syncThemeToCloud(
          themeMode: mode,
        ).catchError((_) {}),
      );
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: svc.themeMode,
      builder: (context, mode, _) {
        return Column(
          children: [
            _ModeCard(
              scheme: scheme,
              title: 'System',
              subtitle: 'Obey device settings.',
              icon: PhosphorIcons.slidersHorizontal,
              selected: mode == ThemeMode.system,
              onTap: () => setMode(ThemeMode.system),
            ),
            const SizedBox(height: RevokeSpacing.sm),
            _ModeCard(
              scheme: scheme,
              title: 'Day Shift',
              subtitle: 'Light mode.',
              icon: PhosphorIcons.sun,
              selected: mode == ThemeMode.light,
              onTap: () => setMode(ThemeMode.light),
            ),
            const SizedBox(height: RevokeSpacing.sm),
            _ModeCard(
              scheme: scheme,
              title: 'Night Shift',
              subtitle: 'Dark mode.',
              icon: PhosphorIcons.moonStars,
              selected: mode == ThemeMode.dark,
              onTap: () => setMode(ThemeMode.dark),
            ),
          ],
        );
      },
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.scheme,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ColorScheme scheme;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.14)
          : Colors.transparent,
      borderRadius: RevokeRadii.cardRadius,
      child: InkWell(
        borderRadius: RevokeRadii.cardRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: RevokeRadii.cardRadius,
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.75)
                  : scheme.onSurface.withValues(alpha: 0.10),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: RevokeRadii.controlRadius,
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? scheme.onPrimary
                      : scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: RevokeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.baseBold),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(PhosphorIcons.checkCircle, color: scheme.primary, size: 20)
              else
                Icon(
                  PhosphorIcons.circle,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final svc = ThemeService.instance;

    void setAccent(Color color) {
      unawaited(svc.setAccentColor(color));
      unawaited(
        SettingsSyncService.syncThemeToCloud(
          accentColor: color,
        ).catchError((_) {}),
      );
    }

    return ValueListenableBuilder<Color>(
      valueListenable: svc.accentColor,
      builder: (context, selectedAccent, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in ThemeService.accentPalette)
              _AccentSwatch(
                color: color,
                scheme: scheme,
                selected: color.toARGB32() == selectedAccent.toARGB32(),
                label:
                    AppearanceScreen._accentNames[color.toARGB32()] ?? 'Accent',
                onTap: () => setAccent(color),
              ),
          ],
        );
      },
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.scheme,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final ColorScheme scheme;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness bubbleBrightness = ThemeData.estimateBrightnessForColor(
      color,
    );
    final swatchScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: bubbleBrightness,
    );
    final Color checkColor = swatchScheme.onPrimary;

    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            selected: selected,
            label: '$label accent${selected ? ', selected' : ''}',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: selected
                          ? scheme.onSurface.withValues(alpha: 0.85)
                          : scheme.onSurface.withValues(alpha: 0.18),
                      width: selected ? 2.5 : 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: selected
                      ? Icon(PhosphorIcons.check, color: checkColor, size: 24)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.xsBold.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.80),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
