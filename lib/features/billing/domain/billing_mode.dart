import 'package:flutter/foundation.dart' show kIsWeb;

/// How this build sells exam access. Chosen at build time:
///
/// ```sh
/// flutter build appbundle --dart-define=BILLING_MODE=play      # default
/// flutter build appbundle --dart-define=BILLING_MODE=external  # consumption-only
/// flutter build web       --dart-define=BILLING_MODE=web       # site payments
/// ```
///
/// `external` exists because Google Play does not support merchant accounts
/// registered in Kyrgyzstan (see ARCHITECTURE.md §5). In that mode the app must
/// not show purchase buttons, prices or links to an outside payment page; it
/// only shows the server-side balance and a neutral sentence.
///
/// `web` (ARCHITECTURE §10.3) is the Flutter web build on Firebase Hosting:
/// the store shows `config/pricing.web_products` with prices in som and pays
/// through the server's payment-provider adapter. It only takes effect in a
/// web build — any other platform built with `BILLING_MODE=web` falls back
/// to [external], so an Android app can never show site prices or links.
enum BillingMode {
  play,
  external,
  web;

  /// Raw value of the `BILLING_MODE` dart-define.
  static const String rawFromEnvironment =
      String.fromEnvironment('BILLING_MODE', defaultValue: 'play');

  /// The mode compiled into this build.
  static final BillingMode current = resolve(rawFromEnvironment, isWeb: kIsWeb);

  /// Unknown values fall back to [play] — the safe default for a Play build.
  static BillingMode parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'external':
        return BillingMode.external;
      case 'web':
        return BillingMode.web;
      default:
        return BillingMode.play;
    }
  }

  /// [parse], restricted to what the platform allows: [web] only in a web
  /// build; elsewhere it becomes [external] (no prices, no payment links).
  static BillingMode resolve(String? raw, {required bool isWeb}) {
    final mode = parse(raw);
    if (mode == BillingMode.web && !isWeb) return BillingMode.external;
    return mode;
  }

  /// Whether the app may show prices, purchase buttons and routes to the
  /// store as a way to pay (Google Play in [play], the site in [web]).
  bool get sellsInApp => this == play || this == web;

  /// Google Play Billing is used (and its purchase listener runs).
  bool get usesPlayBilling => this == play;

  /// Payments through `paymentCreateOrder` on the website (§10.3).
  bool get sellsOnWeb => this == web;
}
