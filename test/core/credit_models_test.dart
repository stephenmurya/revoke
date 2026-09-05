import 'package:flutter_test/flutter_test.dart';
import 'package:revoke/core/models/credit_models.dart';

void main() {
  test('Credit products map to fixed quantities', () {
    expect(CreditPurchaseProduct.fromProductId('credits_50')?.amount, 50);
    expect(CreditPurchaseProduct.fromProductId('credits_100')?.amount, 100);
    expect(CreditPurchaseProduct.fromProductId('premium'), isNull);
  });

  test('wallet projection clamps invalid server values', () {
    final wallet = CreditWallet.fromFirestore({
      'availableCredits': -10,
      'lockedCredits': 20,
    });
    expect(wallet.availableCredits, 0);
    expect(wallet.lockedCredits, 20);
  });

  test('Credit wallet separates available and locked values', () {
    const wallet = CreditWallet(availableCredits: 30, lockedCredits: 20);
    expect(wallet.totalCredits, 50);
    expect(wallet.copyWith(lockedCredits: 0).availableCredits, 30);
  });
}
