/// Helpers for `{ru, ky, en}` text maps stored in Firestore.
///
/// FB-31: some legacy content used `kg` for Kyrgyz. Everything the CMS reads is
/// normalised to `ky`, and everything it writes uses `ky` only.
library;

const List<String> kContentLocales = ['ru', 'ky', 'en'];

/// Normalises a locale key (`kg` → `ky`, lower-case, trimmed).
String normalizeLocaleKey(String key) {
  final k = key.trim().toLowerCase();
  return k == 'kg' ? 'ky' : k;
}

/// Tolerant parser for a localized text field. Accepts a map (any value types
/// are stringified, empty values dropped) or a bare string (treated as `ru`).
Map<String, String> readLocalized(Object? raw, {String bareStringLocale = 'ru'}) {
  if (raw is String) {
    return raw.trim().isEmpty ? <String, String>{} : {bareStringLocale: raw};
  }
  if (raw is! Map) return <String, String>{};
  final out = <String, String>{};
  // Prefer an explicit `ky` over a legacy `kg` when both exist.
  raw.forEach((k, v) {
    if (k is! String || v == null) return;
    final key = normalizeLocaleKey(k);
    final value = v.toString();
    if (value.trim().isEmpty) return;
    if (k.trim().toLowerCase() == 'kg' && out.containsKey('ky')) return;
    out[key] = value;
  });
  return out;
}

/// Merges edited locale values over the original map so locales the editor
/// did not touch (or does not show) survive a save — CMS-12. A locale edited
/// to an empty string is removed.
Map<String, String> mergeLocalized(
  Map<String, String> original,
  Map<String, String> edited,
) {
  final out = <String, String>{...readLocalized(original)};
  edited.forEach((k, v) {
    final key = normalizeLocaleKey(k);
    if (v.trim().isEmpty) {
      out.remove(key);
    } else {
      out[key] = v;
    }
  });
  return out;
}

String localizedOf(Map<String, String> m, String locale) =>
    m[locale] ?? m['ru'] ?? m['ky'] ?? m['en'] ?? (m.isEmpty ? '' : m.values.first);
