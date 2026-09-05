import 'package:flutter/material.dart';

import '../theme/revoke_tokens.dart';
import '../utils/theme_extensions.dart';

enum RevokeButtonVariant { primary, secondary, tertiary, destructive }

class RevokeButton extends StatelessWidget {
  const RevokeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RevokeButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final RevokeButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final buttonChild = loading
        ? SizedBox(
            width: RevokeIconSizes.standard,
            height: RevokeIconSizes.standard,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foregroundColor(context),
            ),
          )
        : Text(label);

    final Widget button;
    switch (variant) {
      case RevokeButtonVariant.primary:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: _buttonStyle(context),
          child: icon == null
              ? buttonChild
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: RevokeIconSizes.standard),
                    const SizedBox(width: RevokeSpacing.sm),
                    buttonChild,
                  ],
                ),
        );
      case RevokeButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: _buttonStyle(context),
          child: icon == null
              ? buttonChild
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: RevokeIconSizes.standard),
                    const SizedBox(width: RevokeSpacing.sm),
                    buttonChild,
                  ],
                ),
        );
      case RevokeButtonVariant.tertiary:
        button = TextButton(
          onPressed: loading ? null : onPressed,
          style: _buttonStyle(context),
          child: icon == null
              ? buttonChild
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: RevokeIconSizes.standard),
                    const SizedBox(width: RevokeSpacing.sm),
                    buttonChild,
                  ],
                ),
        );
      case RevokeButtonVariant.destructive:
        button = ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: _buttonStyle(context),
          child: buttonChild,
        );
    }

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  ButtonStyle _buttonStyle(BuildContext context) {
    final colors = context.colors;
    final foreground = _foregroundColor(context);
    final base = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, RevokeTouchTargets.minimum),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: RevokeSpacing.xl,
          vertical: RevokeSpacing.md,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: RevokeRadii.controlRadius),
      ),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.labelLarge),
    );

    switch (variant) {
      case RevokeButtonVariant.primary:
        return base.copyWith(
          backgroundColor: WidgetStatePropertyAll(colors.accent),
          foregroundColor: WidgetStatePropertyAll(foreground),
          elevation: const WidgetStatePropertyAll(RevokeElevation.none),
        );
      case RevokeButtonVariant.secondary:
        return base.copyWith(
          foregroundColor: WidgetStatePropertyAll(colors.accent),
          side: WidgetStatePropertyAll(
            BorderSide(color: colors.borderSubtle, width: RevokeBorders.subtle),
          ),
        );
      case RevokeButtonVariant.tertiary:
        return base.copyWith(
          foregroundColor: WidgetStatePropertyAll(colors.accent),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: RevokeSpacing.sm,
              vertical: RevokeSpacing.md,
            ),
          ),
        );
      case RevokeButtonVariant.destructive:
        return base.copyWith(
          backgroundColor: WidgetStatePropertyAll(colors.destructive),
          foregroundColor: WidgetStatePropertyAll(context.scheme.onError),
          elevation: const WidgetStatePropertyAll(RevokeElevation.none),
        );
    }
  }

  Color _foregroundColor(BuildContext context) {
    if (variant == RevokeButtonVariant.destructive) {
      return context.scheme.onError;
    }
    if (variant == RevokeButtonVariant.secondary ||
        variant == RevokeButtonVariant.tertiary) {
      return context.colors.accent;
    }
    return Theme.of(context).colorScheme.onPrimary;
  }
}

class RevokeIconButton extends StatelessWidget {
  const RevokeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: RevokeIconSizes.emphasis),
      constraints: const BoxConstraints(
        minWidth: RevokeTouchTargets.minimum,
        minHeight: RevokeTouchTargets.minimum,
      ),
      padding: const EdgeInsets.all(RevokeSpacing.md),
      style: IconButton.styleFrom(
        foregroundColor: selected ? colors.accent : colors.textSecondary,
        backgroundColor: selected ? colors.accentSoft : Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: RevokeRadii.controlRadius,
        ),
      ),
    );
  }
}

class RevokeSurface extends StatelessWidget {
  const RevokeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(RevokeSpacing.xl),
    this.color,
    this.bordered = true,
    this.radius = RevokeRadii.cardRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool bordered;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: radius,
        border: bordered
            ? Border.all(
                color: colors.borderSubtle,
                width: RevokeBorders.subtle,
              )
            : null,
      ),
      child: child,
    );
  }
}

class RevokeSectionHeader extends StatelessWidget {
  const RevokeSectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    );
  }
}

class RevokeSettingRow extends StatelessWidget {
  const RevokeSettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final titleColor = destructive ? colors.destructive : colors.textPrimary;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RevokeSpacing.lg,
        vertical: RevokeSpacing.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: RevokeSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.cardTitle.copyWith(color: titleColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: RevokeSpacing.xs),
                  Text(
                    subtitle!,
                    style: context.text.bodySecondary.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: RevokeSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    final child = Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: subtitle == null ? title : '$title, $subtitle',
      child: content,
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: RevokeRadii.controlRadius,
      child: child,
    );
  }
}

enum RevokeStatusTone { neutral, accent, success, warning, destructive }

class RevokeStatusBanner extends StatelessWidget {
  const RevokeStatusBanner({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.tone = RevokeStatusTone.neutral,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final RevokeStatusTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (tone) {
      RevokeStatusTone.neutral => colors.textSecondary,
      RevokeStatusTone.accent => colors.accent,
      RevokeStatusTone.success => colors.success,
      RevokeStatusTone.warning => colors.warning,
      RevokeStatusTone.destructive => colors.destructive,
    };
    return RevokeSurface(
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(RevokeSpacing.lg),
      bordered: false,
      radius: RevokeRadii.controlRadius,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: RevokeIconSizes.emphasis, color: color),
          const SizedBox(width: RevokeSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.cardTitle.copyWith(color: color),
                ),
                const SizedBox(height: RevokeSpacing.xs),
                Text(
                  message,
                  style: context.text.bodySecondary.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: RevokeSpacing.sm),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RevokePill extends StatelessWidget {
  const RevokePill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = color ?? colors.textSecondary;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RevokeSpacing.md,
        vertical: RevokeSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: RevokeIconSizes.compact, color: foreground),
            const SizedBox(width: RevokeSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );

    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.10),
        borderRadius: RevokeRadii.pillRadius,
        border: Border.all(
          color: foreground.withValues(alpha: 0.22),
          width: RevokeBorders.subtle,
        ),
      ),
      child: content,
    );

    final result = onPressed == null
        ? child
        : Semantics(
            button: true,
            label: semanticLabel ?? label,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: RevokeTouchTargets.minimum,
              ),
              child: InkWell(
                onTap: onPressed,
                borderRadius: RevokeRadii.pillRadius,
                child: child,
              ),
            ),
          );
    return result;
  }
}

class RevokeDivider extends StatelessWidget {
  const RevokeDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: RevokeSpacing.lg,
      thickness: RevokeBorders.subtle,
      color: context.colors.borderSubtle,
    );
  }
}

class RevokeLoadingState extends StatelessWidget {
  const RevokeLoadingState({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: label,
        child: CircularProgressIndicator(color: context.colors.accent),
      ),
    );
  }
}

class RevokeEmptyState extends StatelessWidget {
  const RevokeEmptyState({
    super.key,
    required this.title,
    this.message,
    this.action,
  });

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RevokeSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: RevokeSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: RevokeSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class RevokeErrorState extends StatelessWidget {
  const RevokeErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return RevokeEmptyState(
      title: 'Something went wrong',
      message: message,
      action: onRetry == null
          ? null
          : RevokeButton(
              label: 'Try again',
              onPressed: onRetry,
              variant: RevokeButtonVariant.secondary,
              expand: false,
            ),
    );
  }
}

class RevokePageScaffold extends StatelessWidget {
  const RevokePageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.padding = const EdgeInsets.symmetric(horizontal: RevokeSpacing.lg),
    this.safeArea = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: body);
    if (safeArea) content = SafeArea(child: content);
    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
