import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'revoke_components.dart';

class RevokeCreditsPill extends StatelessWidget {
  const RevokeCreditsPill({
    super.key,
    this.availableCredits = 0,
    required this.onPressed,
  });

  final int availableCredits;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return RevokePill(
      label: availableCredits.toString(),
      icon: PhosphorIcons.coins,
      color: Theme.of(context).colorScheme.onSurface,
      onPressed: onPressed,
      semanticLabel: 'Available Credits: $availableCredits',
    );
  }
}
