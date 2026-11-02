import 'package:flutter/widgets.dart';

/// Language used for *learning content* (question stems, lessons, handbook).
///
/// Content is authored in Russian and Kyrgyz (some docs also carry English).
/// A Kyrgyz UI shows Kyrgyz content when it exists and falls back to Russian;
/// everything else falls back to Russian, which every document has.
String contentLanguageOf(BuildContext context) =>
    contentLanguageFor(Localizations.maybeLocaleOf(context)?.languageCode);

String contentLanguageFor(String? languageCode) {
  switch (languageCode) {
    case 'ky':
    case 'kg':
      return 'ky';
    case 'en':
      return 'en';
    default:
      return 'ru';
  }
}

/// Picks the best string from a localized map: [lang] → ru → ky → en → any.
String pickLocalized(Map<String, String> values, String lang) {
  String? ok(String? s) => (s == null || s.trim().isEmpty) ? null : s;
  return ok(values[lang]) ??
      ok(values['ru']) ??
      ok(values['ky']) ??
      ok(values['en']) ??
      values.values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
}
