/// `config/pricing` (ARCHITECTURE.md §1.6): Google Play product id → credits
/// granted, plus the number of free exams per account. Prices themselves live
/// in Play Console (the client always shows `ProductDetails.price`); this
/// config only maps products to credits. Written only via `adminUpdatePricing`.
///
/// Phase 4 (§10.3): `web_products` = `{id: {credits, amount_som, enabled}}` —
/// the products and prices of the website store (`BILLING_MODE=web`). The
/// base price is fixed by the owner: `exam_single` = 1 credit = 1 full mock
/// exam = [kBasePriceSom] som.
library;

/// Default credits per product (ARCHITECTURE.md §1.6 table).
const Map<String, int> kDefaultProductCredits = {
  'exam_single': 1,
  'exam_pack_5': 5,
  'exam_pack_10': 10,
};

/// `free_exams_per_user` range `adminUpdatePricing` accepts
/// (functions/src/domain/entitlements.ts `FREE_EXAMS_PER_USER_MIN/MAX`); a
/// value outside it is rejected with VALIDATION_FAILED. The student client
/// reads the same bound (billing `PricingConfig.maxFreeExamsPerUser`).
const int kFreeExamsPerUserMin = 0;
const int kFreeExamsPerUserMax = 5;

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

  /// `config/pricing.web_products` (§10.3); [kDefaultWebProducts] when the
  /// map is missing ([webProductsExist] = false).
  final Map<String, WebProductConfig> webProducts;

  /// `false` when `web_products` is not stored yet (defaults shown — the
  /// server reads the same defaults).
  final bool webProductsExist;

  const PricingConfig({
    required this.products,
    required this.freeExamsPerUser,
    this.exists = true,
    this.webProducts = kDefaultWebProducts,
    this.webProductsExist = false,
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
    final rawWeb = raw['web_products'];
    return PricingConfig(
      products: products,
      freeExamsPerUser:
          _int(raw['free_exams_per_user'] ?? raw['freeExamsPerUser']) ?? 1,
      webProducts: rawWeb is Map ? parseWebProducts(rawWeb) : kDefaultWebProducts,
      webProductsExist: rawWeb is Map,
    );
  }

  PricingConfig copyWith({Map<String, int>? products, int? freeExamsPerUser}) =>
      PricingConfig(
        products: products ?? this.products,
        freeExamsPerUser: freeExamsPerUser ?? this.freeExamsPerUser,
        exists: exists,
        webProducts: webProducts,
        webProductsExist: webProductsExist,
      );

  /// Validation mirrored from the server: only known products, 1..100
  /// credits each, `exam_single` grants exactly one exam (1 credit = 1 test),
  /// [kFreeExamsPerUserMin]..[kFreeExamsPerUserMax] free exams per user.
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
    if (freeExamsPerUser < kFreeExamsPerUserMin || freeExamsPerUser > kFreeExamsPerUserMax) {
      issues.add(PricingIssue.freeRange);
    }
    return issues.toList();
  }
}

// --- Web store products (§10.3) ---------------------------------------------

/// The owner's base price: `exam_single` = 1 credit = 1 full mock exam.
/// Changing it needs the owner's consent (`confirmBasePriceChange`).
const String kBaseWebProductId = 'exam_single';
const int kBasePriceSom = 100;

/// Ranges `adminUpdatePricing` accepts for `webProducts`
/// (functions/src/payments/orders.ts `WEB_CREDITS_*`, `WEB_AMOUNT_*`).
const int kWebCreditsMin = 1;
const int kWebCreditsMax = 50;
const int kWebAmountMin = 1;
const int kWebAmountMax = 100000;

/// Product ids the server accepts (`/^[a-z0-9_.]{1,64}$/`).
final RegExp kWebProductIdPattern = RegExp(r'^[a-z0-9_.]{1,64}$');

class WebProductConfig {
  final int credits;
  final int amountSom;
  final bool enabled;

  const WebProductConfig({required this.credits, required this.amountSom, required this.enabled});

  /// Stored shape (`amount_som`; the server also accepts `amountSom`).
  Map<String, Object> toMap() => {'credits': credits, 'amount_som': amountSom, 'enabled': enabled};

  WebProductConfig copyWith({int? credits, int? amountSom, bool? enabled}) => WebProductConfig(
        credits: credits ?? this.credits,
        amountSom: amountSom ?? this.amountSom,
        enabled: enabled ?? this.enabled,
      );

  @override
  bool operator ==(Object other) =>
      other is WebProductConfig &&
      other.credits == credits &&
      other.amountSom == amountSom &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(credits, amountSom, enabled);
}

/// §10.3 defaults: packs stay disabled until the owner approves their prices.
const Map<String, WebProductConfig> kDefaultWebProducts = {
  'exam_single': WebProductConfig(credits: 1, amountSom: kBasePriceSom, enabled: true),
  'exam_pack_5': WebProductConfig(credits: 5, amountSom: 450, enabled: false),
  'exam_pack_10': WebProductConfig(credits: 10, amountSom: 800, enabled: false),
};

/// Stored `web_products` → products, dropping invalid entries (as the server
/// does: integer credits / amount in range, boolean `enabled`).
Map<String, WebProductConfig> parseWebProducts(Map raw) {
  final out = <String, WebProductConfig>{};
  raw.forEach((k, v) {
    if (k is! String || !kWebProductIdPattern.hasMatch(k) || v is! Map) return;
    final credits = v['credits'];
    final amount = v['amount_som'] ?? v['amountSom'];
    final enabled = v['enabled'];
    if (credits is! num || credits != credits.truncate()) return;
    if (amount is! num || amount != amount.truncate()) return;
    if (enabled is! bool) return;
    final c = credits.toInt();
    final a = amount.toInt();
    if (c < kWebCreditsMin || c > kWebCreditsMax || a < kWebAmountMin || a > kWebAmountMax) return;
    out[k] = WebProductConfig(credits: c, amountSom: a, enabled: enabled);
  });
  return out;
}

/// Display order of web products: the base product first, then by credits.
List<String> orderedWebProductIds(Iterable<String> ids, Map<String, WebProductConfig> products) =>
    ids.toSet().toList()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a == kBaseWebProductId) return -1;
        if (b == kBaseWebProductId) return 1;
        final c = (products[a]?.credits ?? 0).compareTo(products[b]?.credits ?? 0);
        return c != 0 ? c : a.compareTo(b);
      });

abstract final class WebPricingIssue {
  static const creditsRange = 'web_credits_range';
  static const amountRange = 'web_amount_range';
  static const baseMissing = 'web_base_missing';
  static const baseCredits = 'web_base_credits';
  static const invalidId = 'web_invalid_id';
}

/// Validation mirrored from `parseWebProductsUpdate`, plus the CMS rule that
/// `exam_single` grants exactly one credit (1 credit = 1 test). The base
/// *price* is not an issue here — see [basePriceChanged].
List<String> validateWebProducts(Map<String, WebProductConfig> products) {
  final issues = <String>{};
  products.forEach((id, p) {
    if (!kWebProductIdPattern.hasMatch(id)) issues.add(WebPricingIssue.invalidId);
    if (p.credits < kWebCreditsMin || p.credits > kWebCreditsMax) issues.add(WebPricingIssue.creditsRange);
    if (p.amountSom < kWebAmountMin || p.amountSom > kWebAmountMax) issues.add(WebPricingIssue.amountRange);
  });
  final base = products[kBaseWebProductId];
  if (base == null) {
    issues.add(WebPricingIssue.baseMissing);
  } else if (base.credits != 1) {
    issues.add(WebPricingIssue.baseCredits);
  }
  return issues.toList();
}

/// Whether [products] move `exam_single` away from [kBasePriceSom] — the
/// change needs the owner's consent, a typed confirmation in the CMS and
/// `confirmBasePriceChange: true` for the server.
bool basePriceChanged(Map<String, WebProductConfig> products) {
  final base = products[kBaseWebProductId];
  return base != null && base.amountSom != kBasePriceSom;
}

/// Whether the typed confirmation [typed] repeats the new base price
/// [amountSom] (digits only; spaces and the currency are ignored).
bool basePriceConfirmationMatches(String typed, int amountSom) {
  final digits = typed.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isNotEmpty && digits == '$amountSom';
}

/// `adminUpdatePricing({webProducts, confirmBasePriceChange?})` payload: the
/// whole map (the server replaces `web_products` as a whole);
/// `confirmBasePriceChange` only when the base price differs from
/// [kBasePriceSom] (the server requires it then — also when the price was
/// already changed earlier and only another product is edited now).
Map<String, Object> webPricingPayload(Map<String, WebProductConfig> products) => {
      'webProducts': {for (final e in products.entries) e.key: e.value.toMap()},
      if (basePriceChanged(products)) 'confirmBasePriceChange': true,
    };

/// Whether [a] and [b] hold the same products with the same values.
bool sameWebProducts(Map<String, WebProductConfig> a, Map<String, WebProductConfig> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
