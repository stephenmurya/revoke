import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/premium_models.dart';
import '../../core/services/premium_billing_service.dart';
import '../../core/services/premium_entitlement_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key, this.reason});

  final String? reason;

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  PremiumPlan _selected = PremiumPlan.prepaid30d;
  final _billing = PremiumBillingService.instance;
  final _entitlement = PremiumEntitlementService.instance;

  @override
  void initState() {
    super.initState();
    _billing.refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Premium'),
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Close Premium',
          icon: Icon(PhosphorIcons.x),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RevokeSpacing.lg,
          RevokeSpacing.md,
          RevokeSpacing.lg,
          RevokeSpacing.xxl,
        ),
        children: [
          Text(
            _entitlement.hasPremium ? 'Extend Premium' : 'Make more room to change',
            style: context.text.pageTitle,
          ),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            widget.reason ??
                'Premium gives you the tools to make a deeper, more supported Commitment.',
            style: context.text.bodySecondary.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: RevokeSpacing.xl),
          const _PremiumBenefits(),
          const SizedBox(height: RevokeSpacing.xxl),
          Text('Choose prepaid access', style: context.text.sectionTitle),
          const SizedBox(height: RevokeSpacing.sm),
          ValueListenableBuilder<List<PremiumPlanOption>>(
            valueListenable: _billing.plans,
            builder: (context, plans, _) {
              if (plans.isEmpty) {
                return ValueListenableBuilder<PremiumBillingState>(
                  valueListenable: _billing.state,
                  builder: (context, state, _) => RevokeSurface(
                    padding: const EdgeInsets.all(RevokeSpacing.lg),
                    child: Row(
                      children: [
                        if (state.isLoading)
                          SizedBox(
                            width: RevokeIconSizes.standard,
                            height: RevokeIconSizes.standard,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.accent,
                            ),
                          )
                        else
                          Icon(
                            PhosphorIcons.storefront,
                            color: context.colors.textMuted,
                            size: RevokeIconSizes.emphasis,
                          ),
                        const SizedBox(width: RevokeSpacing.md),
                        Expanded(
                          child: Text(
                            state.isLoading
                                ? 'Loading localized plans…'
                                : state.error ??
                                    state.message ??
                                    'Premium plans are not available yet.',
                            style: context.text.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final option in plans) ...[
                    _PremiumPlanTile(
                      option: option,
                      selected: _selected == option.plan,
                      onTap: () => setState(() => _selected = option.plan),
                    ),
                    if (option != plans.last)
                      const SizedBox(height: RevokeSpacing.sm),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: RevokeSpacing.md),
          Text(
            'Prepaid access. It does not renew automatically. Google Play shows the final localized price before confirmation.',
            style: context.text.caption.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: RevokeSpacing.xl),
          ValueListenableBuilder<PremiumBillingState>(
            valueListenable: _billing.state,
            builder: (context, state, _) {
              PremiumPlanOption? option;
              for (final item in _billing.plans.value) {
                if (item.plan == _selected) option = item;
              }
              return RevokeButton(
                label: option == null
                    ? 'Choose a plan'
                    : 'Continue with ${option.price}',
                icon: PhosphorIcons.arrowRight,
                loading: state.isPurchasing,
                onPressed: option == null || state.isPurchasing
                    ? null
                    : () => _purchase(_selected),
              );
            },
          ),
          const SizedBox(height: RevokeSpacing.sm),
          RevokeButton(
            label: 'Restore purchases',
            variant: RevokeButtonVariant.tertiary,
            onPressed: _billing.state.value.isPurchasing
                ? null
                : _billing.restorePurchases,
          ),
          ValueListenableBuilder<PremiumBillingState>(
            valueListenable: _billing.state,
            builder: (context, state, _) {
              if (state.error == null && state.message == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: RevokeSpacing.md),
                child: Text(
                  state.error ?? state.message!,
                  textAlign: TextAlign.center,
                  style: context.text.caption.copyWith(
                    color: state.error == null
                        ? context.colors.textSecondary
                        : context.colors.destructive,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _purchase(PremiumPlan plan) async {
    PremiumPlanOption? option;
    for (final item in _billing.plans.value) {
      if (item.plan == plan) option = item;
    }
    if (option == null || !mounted) return;

    // This dialog is intentionally shown for every purchase attempt. An
    // earlier acknowledgement is auditable, but never suppresses the next
    // required disclosure.
    final acknowledged = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var understood = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Before you continue'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${option!.plan.displayLabel} Premium is prepaid digital access for ${option.plan.durationLabel}. The final localized price is shown by Google Play.',
                    style: context.text.body,
                  ),
                  const SizedBox(height: RevokeSpacing.md),
                  Text(
                    'Premium access does not renew automatically. This purchase does not create Commitment Credits, a cash balance, or a transferable account value.',
                    style: context.text.bodySecondary.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: RevokeSpacing.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: understood,
                    onChanged: (value) =>
                        setDialogState(() => understood = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('I understand and want to continue.'),
                  ),
                ],
              ),
            ),
            actions: [
              RevokeButton(
                label: 'Cancel',
                variant: RevokeButtonVariant.tertiary,
                expand: false,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
              RevokeButton(
                label: 'I understand, continue',
                expand: false,
                onPressed: understood
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
              ),
            ],
          ),
        );
      },
    );

    if (acknowledged != true || !mounted) return;
    await _billing.purchasePlan(plan);
  }
}

class _PremiumBenefits extends StatelessWidget {
  const _PremiumBenefits();

  @override
  Widget build(BuildContext context) {
    const benefits = <String>[
      'Reduce Commitments with a measured plan.',
      'Create additional Protect Commitments.',
      'Use AI Architect and Circle authority where available.',
    ];
    return Column(
      children: [
        for (final benefit in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: RevokeSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  PhosphorIcons.checkCircle,
                  color: context.colors.accent,
                  size: RevokeIconSizes.standard,
                ),
                const SizedBox(width: RevokeSpacing.md),
                Expanded(child: Text(benefit, style: context.text.body)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PremiumPlanTile extends StatelessWidget {
  const _PremiumPlanTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PremiumPlanOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '${option.plan.displayLabel}, ${option.price}',
      child: InkWell(
        onTap: onTap,
        borderRadius: RevokeRadii.cardRadius,
        child: RevokeSurface(
          color: selected ? context.colors.accentSoft : null,
          bordered: selected,
          padding: const EdgeInsets.all(RevokeSpacing.lg),
          child: Row(
            children: [
              Icon(
                selected
                    ? PhosphorIcons.radioButton
                    : PhosphorIcons.circle,
                color: selected
                    ? context.colors.accent
                    : context.colors.textMuted,
                size: RevokeIconSizes.emphasis,
              ),
              const SizedBox(width: RevokeSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.plan.displayLabel, style: context.text.cardTitle),
                    const SizedBox(height: RevokeSpacing.xs),
                    Text(
                      '${option.plan.durationLabel} · prepaid',
                      style: context.text.caption.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(option.price, style: context.text.numericStat),
            ],
          ),
        ),
      ),
    );
  }
}
