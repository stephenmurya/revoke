import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:revoke/core/models/premium_models.dart';

void main() {
  test('Premium entitlement requires a future server expiry', () {
    final entitlement = PremiumEntitlement.fromFirestore({
      'active': true,
      'premiumUntil': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
      'verifiedAt': Timestamp.now(),
      'plan': 'prepaid-30d',
    });

    expect(entitlement.active, isTrue);
    expect(entitlement.plan, PremiumPlan.prepaid30d);
  });

  test('expired cached entitlement cannot extend itself', () {
    final entitlement = PremiumEntitlement.fromCacheJson({
      'active': true,
      'premiumUntil': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      'verifiedAt': DateTime.now()
          .subtract(const Duration(days: 31))
          .toIso8601String(),
      'plan': 'prepaid-30d',
    });

    expect(entitlement.active, isFalse);
    expect(entitlement.status, 'free');
  });
}
