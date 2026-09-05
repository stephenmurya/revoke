import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/models/credit_models.dart';
import '../../core/services/credit_service.dart';
import '../../core/services/premium_billing_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';

class CreditDetailsScreen extends StatefulWidget {
  const CreditDetailsScreen({super.key});

  @override
  State<CreditDetailsScreen> createState() => _CreditDetailsScreenState();
}

class _CreditDetailsScreenState extends State<CreditDetailsScreen> {
  final _creditService = CreditService.instance;
  final _billing = PremiumBillingService.instance;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _billing.refreshProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits'),
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(PhosphorIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          RevokeSpacing.lg,
          RevokeSpacing.sm,
          RevokeSpacing.lg,
          RevokeSpacing.xxl,
        ),
        children: [
          ValueListenableBuilder(
            valueListenable: _creditService.wallet,
            builder: (context, wallet, _) => RevokeSurface(
              bordered: false,
              color: context.colors.accentSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Credits', style: context.text.label),
                  const SizedBox(height: RevokeSpacing.xs),
                  Text(
                    '${wallet.availableCredits}',
                    style: context.text.numericDisplay,
                  ),
                  const SizedBox(height: RevokeSpacing.md),
                  Text(
                    'Locked Credits  ${wallet.lockedCredits}',
                    style: context.text.bodySecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RevokeSpacing.xl),
          const RevokeSectionHeader(title: 'Buy Credits'),
          const SizedBox(height: RevokeSpacing.sm),
          ValueListenableBuilder(
            valueListenable: _billing.creditProducts,
            builder: (context, products, _) {
              if (products.isEmpty) {
                return Text(
                  'Credit products will appear here when Google Play is configured for this account.',
                  style: context.text.bodySecondary,
                );
              }
              return Column(
                children: [
                  for (final product in products) ...[
                    _ProductRow(
                      product: product,
                      onTap: () => _confirmPurchase(product),
                    ),
                    if (product != products.last) const RevokeDivider(),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: RevokeSpacing.xl),
          const RevokeSectionHeader(title: 'Redeem for Premium'),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            '100 Credits provide 30 days of Premium access. Redeem in a fixed amount when you are ready.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: RevokeSpacing.md),
          ValueListenableBuilder(
            valueListenable: _creditService.wallet,
            builder: (context, wallet, _) => Wrap(
              spacing: RevokeSpacing.sm,
              runSpacing: RevokeSpacing.sm,
              children: [10, 50, 100]
                  .map(
                    (amount) => OutlinedButton(
                      onPressed: _redeeming || wallet.availableCredits < amount
                          ? null
                          : () => _redeem(amount),
                      child: Text('$amount Credits'),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: RevokeSpacing.xl),
          const RevokeSectionHeader(title: 'History'),
          const SizedBox(height: RevokeSpacing.sm),
          StreamBuilder(
            stream: _creditService.historyStream(),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <CreditLedgerEntry>[];
              if (entries.isEmpty) {
                return Text(
                  'Credit activity will appear here.',
                  style: context.text.bodySecondary,
                );
              }
              return RevokeSurface(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      ListTile(
                        title: Text(_label(entries[i].type)),
                        subtitle: Text(entries[i].description ?? ''),
                        trailing: Text(
                          '${entries[i].amount > 0 ? '+' : ''}${entries[i].amount}',
                        ),
                      ),
                      if (i < entries.length - 1) const RevokeDivider(),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurchase(ProductDetails product) async {
    var confirmed = false;
    confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => _CreditPurchaseDisclosure(product: product),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    final model = CreditPurchaseProduct.fromProductId(product.id);
    if (model == null) return;
    await _creditService.purchase(model);
  }

  Future<void> _redeem(int amount) async {
    setState(() => _redeeming = true);
    try {
      await _creditService.redeem(amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$amount Credits redeemed for Premium access.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _label(String type) => switch (type) {
    'CREDIT_PURCHASE' => 'Credits purchased',
    'CREDIT_LOCK' => 'Credits locked',
    'CREDIT_RELEASE' => 'Credits returned',
    'CREDIT_FORFEITURE' => 'Credits forfeited',
    'PREMIUM_REDEMPTION' => 'Premium redeemed',
    'PURCHASE_REVERSAL' => 'Purchase reversed',
    _ => 'Credit activity',
  };
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});
  final ProductDetails product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final credits =
        CreditPurchaseProduct.fromProductId(product.id)?.amount ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$credits Credits', style: context.text.cardTitle),
      subtitle: const Text('Digital Credits for eligible Revoke Commitments'),
      trailing: TextButton(onPressed: onTap, child: Text(product.price)),
    );
  }
}

class _CreditPurchaseDisclosure extends StatefulWidget {
  const _CreditPurchaseDisclosure({required this.product});
  final ProductDetails product;

  @override
  State<_CreditPurchaseDisclosure> createState() =>
      _CreditPurchaseDisclosureState();
}

class _CreditPurchaseDisclosureState extends State<_CreditPurchaseDisclosure> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Before you buy Credits'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revoke Credits are digital in-app Credits. They cannot be withdrawn, transferred, exchanged for cash, or redeemed outside Revoke. They have no external cash value.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: RevokeSpacing.md),
            Text(
              'Credits can back eligible Revoke Commitments. Successful eligible Commitments return locked Credits to your Revoke wallet. Failed eligible Commitments can permanently forfeit those locked Credits. Credits can also be redeemed for Revoke Premium access time.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: RevokeSpacing.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (value) => setState(() => _understood = value == true),
              title: const Text('I understand how Revoke Credits work.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _understood ? () => Navigator.pop(context, true) : null,
          child: Text('Continue for ${widget.product.price}'),
        ),
      ],
    );
  }
}
