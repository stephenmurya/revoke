// The RadioGroup migration is not available in the repository's minimum
// Flutter SDK; retain the existing compatible controls for this phase.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../core/services/credit_service.dart';
import '../../core/theme/revoke_tokens.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/revoke_components.dart';
import '../commitments/commitment_presentation.dart';

class CreditBackingScreen extends StatefulWidget {
  const CreditBackingScreen({super.key, required this.commitment});
  final CommitmentViewModel commitment;

  @override
  State<CreditBackingScreen> createState() => _CreditBackingScreenState();
}

class _CreditBackingScreenState extends State<CreditBackingScreen> {
  int _amount = 10;
  String _gracePolicy = 'STRICT';
  bool _working = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final commitment = widget.commitment;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Back this Commitment'),
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(PhosphorIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(RevokeSpacing.lg),
        children: [
          Text(commitment.name, style: context.text.pageTitle),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            'Lock Credits behind this active Commitment. The terms are fixed for this run; the backend resolves the result from native evidence.',
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: RevokeSpacing.xl),
          const RevokeSectionHeader(title: 'Credits to lock'),
          const SizedBox(height: RevokeSpacing.sm),
          ValueListenableBuilder(
            valueListenable: CreditService.instance.wallet,
            builder: (context, wallet, _) => Column(
              children: [
                for (final amount in const [10, 20, 50, 100])
                  RadioListTile<int>(
                    value: amount,
                    groupValue: _amount,
                    onChanged: wallet.availableCredits >= amount
                        ? (value) => setState(() => _amount = value ?? amount)
                        : null,
                    title: Text('$amount Credits'),
                    subtitle: wallet.availableCredits < amount
                        ? const Text('Not enough available Credits')
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: RevokeSpacing.lg),
          const RevokeSectionHeader(title: 'Recovery policy'),
          RadioListTile<String>(
            value: 'STRICT',
            groupValue: _gracePolicy,
            onChanged: (value) => setState(() => _gracePolicy = value ?? 'STRICT'),
            title: const Text('Strict'),
            subtitle: const Text('A verified failure can forfeit the locked Credits.'),
          ),
          RadioListTile<String>(
            value: 'ONE',
            groupValue: _gracePolicy,
            onChanged: (value) => setState(() => _gracePolicy = value ?? 'ONE'),
            title: const Text('One recovery checkpoint'),
          ),
          RadioListTile<String>(
            value: 'THREE',
            groupValue: _gracePolicy,
            onChanged: (value) => setState(() => _gracePolicy = value ?? 'THREE'),
            title: const Text('Three recovery checkpoints'),
          ),
          if (_error != null) ...[
            const SizedBox(height: RevokeSpacing.md),
            RevokeSurface(
              color: context.colors.warning.withValues(alpha: 0.10),
              child: Text(_error!, style: context.text.bodyMedium),
            ),
          ],
          const SizedBox(height: RevokeSpacing.xl),
          RevokeButton(
            label: 'Confirm and lock $_amount Credits',
            icon: PhosphorIcons.lock,
            loading: _working,
            onPressed: _working ? null : _submit,
          ),
          const SizedBox(height: RevokeSpacing.sm),
          Text(
            'Locked Credits return after sufficient success evidence. If evidence is insufficient, they are returned without consuming recovery. A verified failure after recovery may forfeit them.',
            style: context.text.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await CreditService.instance.createBacking(
        commitmentId: widget.commitment.id,
        amount: _amount,
        gracePolicy: _gracePolicy,
      );
      if (mounted) context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}
