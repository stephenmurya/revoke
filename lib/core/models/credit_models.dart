import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditPurchaseProduct {
  credits50('credits_50', 50),
  credits100('credits_100', 100);

  const CreditPurchaseProduct(this.productId, this.amount);

  final String productId;
  final int amount;

  static CreditPurchaseProduct? fromProductId(String? value) {
    final normalized = value?.trim();
    for (final product in values) {
      if (product.productId == normalized) return product;
    }
    return null;
  }
}

class CreditWallet {
  const CreditWallet({
    required this.availableCredits,
    required this.lockedCredits,
  });

  const CreditWallet.empty() : availableCredits = 0, lockedCredits = 0;

  final int availableCredits;
  final int lockedCredits;

  int get totalCredits => availableCredits + lockedCredits;

  factory CreditWallet.fromFirestore(Map<String, dynamic>? data) {
    final source = data ?? const <String, dynamic>{};
    return CreditWallet(
      availableCredits:
          (((source['availableCredits'] ?? source['available_credits']) as num?)
                      ?.toInt()
                      .clamp(0, 100000000) ??
                  0)
              .toInt(),
      lockedCredits:
          (((source['lockedCredits'] ?? source['locked_credits']) as num?)
                      ?.toInt()
                      .clamp(0, 100000000) ??
                  0)
              .toInt(),
    );
  }

  CreditWallet copyWith({int? availableCredits, int? lockedCredits}) =>
      CreditWallet(
        availableCredits: (availableCredits ?? this.availableCredits)
            .clamp(0, 100000000)
            .toInt(),
        lockedCredits: (lockedCredits ?? this.lockedCredits)
            .clamp(0, 100000000)
            .toInt(),
      );
}

class CreditLedgerEntry {
  const CreditLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String type;
  final int amount;
  final DateTime? createdAt;
  final String? description;

  factory CreditLedgerEntry.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDate = data['createdAt'];
    final createdAt = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is String
        ? DateTime.tryParse(rawDate)
        : null;
    return CreditLedgerEntry(
      id: id,
      type: (data['type'] as String?)?.trim() ?? 'CREDIT_ACTIVITY',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      description: data['description'] as String?,
    );
  }
}

class CreditBackingSummary {
  const CreditBackingSummary({
    required this.id,
    required this.commitmentId,
    required this.lockedCredits,
    required this.status,
    this.endAt,
  });

  final String id;
  final String commitmentId;
  final int lockedCredits;
  final String status;
  final DateTime? endAt;

  factory CreditBackingSummary.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime? readDate(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return CreditBackingSummary(
      id: id,
      commitmentId: (data['commitmentId'] as String?)?.trim() ?? '',
      lockedCredits: (data['lockedCredits'] as num?)?.toInt() ?? 0,
      status: (data['status'] as String?)?.trim() ?? 'LOCKED',
      endAt: readDate(data['endAt']),
    );
  }
}
