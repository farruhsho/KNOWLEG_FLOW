import '../../../core/backend/backend_contract.dart';
import 'firestore_values.dart';

/// Display data for one product from `config/pricing.products`.
class ProductPresentation {
  final String productId;
  final int credits;

  /// Optional per-language label override (`{"ru": "...", "ky": "..."}`).
  final Map<String, String> label;

  /// Sort key; products without one keep the default order.
  final int order;

  const ProductPresentation({
    required this.productId,
    required this.credits,
    this.label = const {},
    this.order = 0,
  });

  /// The override for [languageCode], falling back to ru → en → any.
  String? labelFor(String languageCode) {
    if (label.isEmpty) return null;
    return label[languageCode] ?? label['ru'] ?? label['en'] ?? label.values.first;
  }
}

/// One product sold on the website (`config/pricing.web_products`, §10.3).
/// The amount is whatever the owner configured; the app never hard-codes a
/// price.
class WebProduct {
  final String productId;
  final int credits;

  /// Price in som (KGS), whole units.
  final int amountSom;
  final bool enabled;

  const WebProduct({
    required this.productId,
    required this.credits,
    required this.amountSom,
    required this.enabled,
  });

  /// Null for malformed entries (no credits or no positive price).
  static WebProduct? tryParse(String? id, Object? raw) {
    final m = FirestoreValues.readMap(raw);
    if (id == null || id.isEmpty || m == null) return null;
    final credits = FirestoreValues.readInt(m['credits'], fallback: 0);
    final amount =
        FirestoreValues.readInt(m['amount_som'] ?? m['amountSom'], fallback: 0);
    if (credits <= 0 || amount <= 0) return null;
    return WebProduct(
      productId: id,
      credits: credits,
      amountSom: amount,
      enabled: FirestoreValues.readBool(m['enabled']),
    );
  }
}

/// Client-side view of `config/pricing`. The server is the authority for how
/// many credits a purchase grants; this only drives the labels on the store
/// page. Google Play prices are never read from here — they always come from
/// Google Play; web prices come only from [webProducts].
class PricingConfig {
  final Map<String, ProductPresentation> products;

  /// Free full mock exams per account (`free_exams_per_user`). Display hint:
  /// the server applies the same value in `examStart`.
  final int freeExamsPerUser;

  /// Products sold on the website, keyed by product id (no defaults: with
  /// nothing configured the web store offers nothing).
  final Map<String, WebProduct> webProducts;

  const PricingConfig(
    this.products, {
    this.freeExamsPerUser = defaultFreeExamsPerUser,
    this.webProducts = const {},
  });

  /// Enabled web products, smallest pack first.
  List<WebProduct> get enabledWebProducts {
    final list = webProducts.values.where((p) => p.enabled).toList()
      ..sort((a, b) {
        final c = a.credits.compareTo(b.credits);
        return c != 0 ? c : a.productId.compareTo(b.productId);
      });
    return List.unmodifiable(list);
  }

  /// Server default when `config/pricing.free_exams_per_user` is missing or
  /// invalid (functions/src/handlers/exam.ts `readPricingFreeExams`).
  static const int defaultFreeExamsPerUser = 1;

  /// Largest value the server accepts (`adminUpdatePricing`, `examStart`).
  static const int maxFreeExamsPerUser = 5;

  /// Mirrors the server: an integer 0..5, anything else means the default.
  static int parseFreeExamsPerUser(Object? raw) {
    if (raw is num && raw.isFinite && raw == raw.truncateToDouble()) {
      final v = raw.toInt();
      if (v >= 0 && v <= maxFreeExamsPerUser) return v;
    }
    return defaultFreeExamsPerUser;
  }

  static const _defaultCredits = <String, int>{
    BillingProducts.examSingle: 1,
    BillingProducts.examPack5: 5,
    BillingProducts.examPack10: 10,
  };

  static final PricingConfig defaults = PricingConfig({
    for (final e in _defaultCredits.entries)
      e.key: ProductPresentation(productId: e.key, credits: e.value, order: e.value),
  });

  int creditsFor(String productId) =>
      products[productId]?.credits ?? _defaultCredits[productId] ?? 1;

  String? labelFor(String productId, String languageCode) =>
      products[productId]?.labelFor(languageCode);

  int orderFor(String productId) =>
      products[productId]?.order ?? _defaultCredits[productId] ?? 999;

  /// Accepts every shape the admin tooling might write:
  ///
  /// * `{products: {exam_single: 1, ...}}`
  /// * `{products: {exam_single: {credits: 1, label: {ru: ...}, order: 1}}}`
  /// * `{products: [{product_id: "exam_single", credits: 1, ...}]}`
  ///
  /// Unknown or malformed entries are ignored and the defaults fill the gaps.
  factory PricingConfig.fromMap(Map<String, dynamic>? data) {
    final result = <String, ProductPresentation>{...defaults.products};
    final raw = data?['products'];

    void put(String? id, Object? value) {
      if (id == null || id.isEmpty) return;
      if (value is num || value is String) {
        final credits = FirestoreValues.readInt(value, fallback: -1);
        if (credits <= 0) return;
        result[id] = ProductPresentation(
          productId: id,
          credits: credits,
          order: result[id]?.order ?? credits,
        );
        return;
      }
      final m = FirestoreValues.readMap(value);
      if (m == null) return;
      final credits = FirestoreValues.readInt(m['credits'], fallback: -1);
      final effectiveCredits =
          credits > 0 ? credits : (result[id]?.credits ?? _defaultCredits[id] ?? 0);
      if (effectiveCredits <= 0) return;
      final labelRaw = m['label'] ?? m['title'];
      final label = <String, String>{};
      if (labelRaw is String && labelRaw.trim().isNotEmpty) {
        label['ru'] = labelRaw.trim();
      } else if (labelRaw is Map) {
        labelRaw.forEach((k, v) {
          if (v is String && v.trim().isNotEmpty) label[k.toString()] = v.trim();
        });
      }
      result[id] = ProductPresentation(
        productId: id,
        credits: effectiveCredits,
        label: label,
        order: FirestoreValues.readInt(m['order'],
            fallback: result[id]?.order ?? effectiveCredits),
      );
    }

    if (raw is Map) {
      raw.forEach((k, v) => put(k.toString(), v));
    } else if (raw is List) {
      for (final item in raw) {
        final m = FirestoreValues.readMap(item);
        if (m == null) continue;
        put(FirestoreValues.readString(m['product_id'] ?? m['productId'] ?? m['id']), m);
      }
    }
    // Same lookup as the server: snake_case first, camelCase as a fallback.
    final Object? free = data?['free_exams_per_user'] ?? data?['freeExamsPerUser'];
    final web = <String, WebProduct>{};
    final rawWeb = data?['web_products'] ?? data?['webProducts'];
    if (rawWeb is Map) {
      rawWeb.forEach((k, v) {
        final p = WebProduct.tryParse(k.toString(), v);
        if (p != null) web[p.productId] = p;
      });
    } else if (rawWeb is List) {
      for (final item in rawWeb) {
        final m = FirestoreValues.readMap(item);
        if (m == null) continue;
        final p = WebProduct.tryParse(
            FirestoreValues.readString(m['product_id'] ?? m['productId'] ?? m['id']), m);
        if (p != null) web[p.productId] = p;
      }
    }
    return PricingConfig(
      result,
      freeExamsPerUser: parseFreeExamsPerUser(free),
      webProducts: Map.unmodifiable(web),
    );
  }
}
