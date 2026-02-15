import 'package:flutter/material.dart';

import '../../core/services/theme_service.dart';
import '../../core/theme/app_theme.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  static const Map<int, String> _accentNames = <int, String>{
    0xFFFF4500: 'Blaze',
    0xFFD50000: 'Crimson',
    0xFF76FF03: 'Biohazard',
    0xFF00E5FF: 'Protocol',
    0xFFFFD600: 'Voltage',
    0xFFD500F9: 'Sovereign',
    0xFFFF1744: 'Plasma',
    0xFF2979FF: 'Cobalt',
    0xFF90A4AE: 'Stealth',
    0xFF1DE9B6: 'Mint',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _PreviewCard(scheme: scheme),
            const SizedBox(height: 16),
            _Section(
              title: 'Regime Mode',
              subtitle: 'Day Shift vs Night Shift. Or obey the system.',
              child: _ThemeModePicker(scheme: scheme),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'System Accent',
              subtitle: 'Choose the color your squad will fear.',
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.lgMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTheme.bodySmall.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.70),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: AppTheme.smBold.copyWith(letterSpacing: 1.1)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.shield_rounded, color: scheme.onPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Focus Score', style: AppTheme.baseMedium),
                      const SizedBox(height: 2),
                      Text('842', style: AppTheme.xlBold),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('ENFORCE'),
                ),
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: svc.themeMode,
      builder: (context, mode, _) {
        return Column(
          children: [
            _ModeCard(
              scheme: scheme,
              title: 'System',
              subtitle: 'Obey device settings.',
              icon: Icons.settings_suggest_rounded,
              selected: mode == ThemeMode.system,
              onTap: () => svc.setThemeMode(ThemeMode.system),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              scheme: scheme,
              title: 'Day Shift',
              subtitle: 'Light mode.',
              icon: Icons.wb_sunny_rounded,
              selected: mode == ThemeMode.light,
              onTap: () => svc.setThemeMode(ThemeMode.light),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              scheme: scheme,
              title: 'Night Shift',
              subtitle: 'Dark mode.',
              icon: Icons.nights_stay_rounded,
              selected: mode == ThemeMode.dark,
              onTap: () => svc.setThemeMode(ThemeMode.dark),
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
      color: selected ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
                  color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 12),
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
                Icon(Icons.check_circle_rounded, color: scheme.primary, size: 20)
              else
                Icon(
                  Icons.circle_outlined,
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
                label: AppearanceScreen._accentNames[color.toARGB32()] ?? 'Accent',
                onTap: () => svc.setAccentColor(color),
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
    final Brightness bubbleBrightness =
        ThemeData.estimateBrightnessForColor(color);
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
          Material(
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
                    ? Icon(Icons.check_rounded, color: checkColor, size: 24)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
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
