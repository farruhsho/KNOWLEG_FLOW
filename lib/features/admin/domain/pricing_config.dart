/// `config/pricing` (ARCHITECTURE.md §1.6): Google Play product id → credits
/// granted, plus the number of free exams per account. Prices themselves live
/// in Play Console (the client always shows `ProductDetails.price`); this
/// config only maps products to credits. Written only via `adminUpdatePricing`.
library;

/// Default credits per product (ARCHITECTURE.md §1.6 table).
const Map<String, int> kDefaultProductCredits = {
  'exam_single': 1,
  'exam_pack_5': 5,
  'exam_pack_10': 10,
};

abstract final class PricingIssue {
  static const creditsRange = 'credits_range';
  static const freeRange = 'free_range';
  static const unknownProduct = 'unknown_product';
  static const singleMustBeOne = 'single_must_be_one';
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  if (v is Map) return _int(v['credits']);
  return null;
}

class PricingConfig {
  final Map<String, int> products;
  final int freeExamsPerUser;

  /// `false` when `config/pricing` does not exist yet (defaults shown).
  final bool exists;

  const PricingConfig({
    required this.products,
    required this.freeExamsPerUser,
    this.exists = true,
  });

  static const PricingConfig defaults = PricingConfig(
    products: kDefaultProductCredits,
    freeExamsPerUser: 1,
    exists: false,
  );

  factory PricingConfig.fromMap(Map? raw) {
    if (raw == null) return defaults;
    final products = <String, int>{...kDefaultProductCredits};
    final p = raw['products'];
    if (p is Map) {
      p.forEach((k, v) {
        final c = _int(v);
        if (k is String && c != null) products[k] = c;
      });
    }
    return PricingConfig(
      products: products,
      freeExamsPerUser:
          _int(raw['free_exams_per_user'] ?? raw['freeExamsPerUser']) ?? 1,
    );
  }

  PricingConfig copyWith({Map<String, int>? products, int? freeExamsPerUser}) =>
      PricingConfig(
        products: products ?? this.products,
        freeExamsPerUser: freeExamsPerUser ?? this.freeExamsPerUser,
        exists: exists,
      );

  /// Validation mirrored from the server: only known products, 1..100
  /// credits each, `exam_single` grants exactly one exam (1 credit = 1 test),
  /// 0..10 free exams per user.
  List<String> validate({Set<String> knownProducts = const {
    'exam_single',
    'exam_pack_5',
    'exam_pack_10',
  }}) {
    final issues = <String>{};
    products.forEach((id, credits) {
      if (!knownProducts.contains(id)) issues.add(PricingIssue.unknownProduct);
      if (credits < 1 || credits > 100) issues.add(PricingIssue.creditsRange);
    });
    if (products['exam_single'] != null && products['exam_single'] != 1) {
      issues.add(PricingIssue.singleMustBeOne);
    }
    if (freeExamsPerUser < 0 || freeExamsPerUser > 10) issues.add(PricingIssue.freeRange);
    return issues.toList();
  }
}
