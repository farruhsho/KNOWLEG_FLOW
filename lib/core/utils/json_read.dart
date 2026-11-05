import 'package:cloud_firestore/cloud_firestore.dart';

/// Tolerant readers for Firestore / JSON maps.
///
/// Documents in this project were written by several generations of code
/// (camelCase vs snake_case keys, ints stored as doubles, dates stored as
/// ISO strings, Timestamps or epoch millis). Models parse through these
/// helpers so one odd document never red-screens a list.
abstract final class JsonRead {
  /// First non-null value among [keys].
  static Object? any(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) return v;
    }
    return null;
  }

  static String? string(Map<String, dynamic> m, List<String> keys) {
    final v = any(m, keys);
    if (v == null) return null;
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return null;
  }

  static String stringOr(Map<String, dynamic> m, List<String> keys,
          [String fallback = '']) =>
      string(m, keys) ?? fallback;

  static int? integer(Map<String, dynamic> m, List<String> keys) =>
      toInt(any(m, keys));

  static int intOr(Map<String, dynamic> m, List<String> keys, int fallback) =>
      integer(m, keys) ?? fallback;

  static double? decimal(Map<String, dynamic> m, List<String> keys) {
    final v = any(m, keys);
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static bool? boolean(Map<String, dynamic> m, List<String> keys) {
    final v = any(m, keys);
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
    }
    return null;
  }

  static DateTime? date(Map<String, dynamic> m, List<String> keys) =>
      toDate(any(m, keys));

  static List<String> stringList(Map<String, dynamic> m, List<String> keys) {
    final v = any(m, keys);
    if (v is List) {
      return v
          .where((e) => e != null)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  static Map<String, dynamic>? map(Map<String, dynamic> m, List<String> keys) {
    final v = any(m, keys);
    return asMap(v);
  }

  static Map<String, dynamic>? asMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return null;
  }

  static int? toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
    return null;
  }

  static DateTime? toDate(Object? v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) return DateTime.tryParse(v);
    if (v is Map) {
      // Serialized Timestamp: {_seconds, _nanoseconds} or {seconds, nanoseconds}.
      final s = toInt(v['_seconds'] ?? v['seconds']);
      if (s != null) return DateTime.fromMillisecondsSinceEpoch(s * 1000);
    }
    return null;
  }

  /// A localized value stored either as a plain string (single language) or
  /// as a `{ru, ky, en}` map. Plain strings are attributed to [defaultLang].
  static Map<String, String> localized(Object? v, {String defaultLang = 'ru'}) {
    if (v == null) return const {};
    if (v is String) return v.isEmpty ? const {} : {defaultLang: v};
    if (v is Map) {
      final out = <String, String>{};
      v.forEach((k, val) {
        if (val is String && val.isNotEmpty) {
          // Older admin code wrote 'kg' for Kyrgyz.
          final key = k.toString() == 'kg' ? 'ky' : k.toString();
          out.putIfAbsent(key, () => val);
        }
      });
      return out;
    }
    return const {};
  }
}
