/// How this build sells exam access. Chosen at build time:
///
/// ```sh
/// flutter build appbundle --dart-define=BILLING_MODE=play      # default
/// flutter build appbundle --dart-define=BILLING_MODE=external  # consumption-only
/// ```
///
/// `external` exists because Google Play does not support merchant accounts
/// registered in Kyrgyzstan (see ARCHITECTURE.md §5). In that mode the app must
/// not show purchase buttons, prices or links to an outside payment page; it
/// only shows the server-side balance and a neutral sentence.
enum BillingMode {
  play,
  external;

  /// Raw value of the `BILLING_MODE` dart-define.
  static const String rawFromEnvironment =
      String.fromEnvironment('BILLING_MODE', defaultValue: 'play');

  /// The mode compiled into this build.
  static final BillingMode current = parse(rawFromEnvironment);

  /// Unknown values fall back to [play] — the safe default for a Play build.
  static BillingMode parse(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'external':
        return BillingMode.external;
      default:
        return BillingMode.play;
    }
  }

  bool get sellsInApp => this == BillingMode.play;
}
