import 'package:flutter/foundation.dart';

import 'json_utils.dart';

/// A `{ru, ky, en}` map as stored in blueprints and variants. Also accepts a
/// plain string (treated as language-neutral).
@immutable
class LocalizedText {
  final Map<String, String> values;

  const LocalizedText(this.values);

  static const empty = LocalizedText({});

  factory LocalizedText.fromJson(Object? json) {
    if (json is String) return LocalizedText({'': json});
    final map = asJsonMap(json);
    final out = <String, String>{};
    map.forEach((k, v) {
      final s = asString(v);
      if (s != null && s.trim().isNotEmpty) out[k] = s;
    });
    return LocalizedText(out);
  }

  bool get isEmpty => values.isEmpty;

  /// Text in [lang], falling back to ru → ky → en → anything.
  String resolve(String lang, {String fallback = ''}) {
    if (values.isEmpty) return fallback;
    return values[lang] ??
        values[''] ??
        values['ru'] ??
        values['ky'] ??
        values['en'] ??
        values.values.first;
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(
      values.entries.map((e) => Object.hash(e.key, e.value)));
}
