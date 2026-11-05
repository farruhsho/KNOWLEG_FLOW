import 'package:cloud_firestore/cloud_firestore.dart';

/// Tolerant readers for documents written by different backend versions.
/// Every reader returns a safe default instead of throwing on a type
/// mismatch, so one malformed field never breaks a whole screen.
abstract final class FirestoreValues {
  static int readInt(Object? v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? num.tryParse(v.trim())?.toInt() ?? fallback;
    return fallback;
  }

  static bool readBool(Object? v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      switch (v.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'yes':
          return true;
        case 'false':
        case '0':
        case 'no':
          return false;
      }
    }
    return fallback;
  }

  static String? readString(Object? v) {
    if (v == null) return null;
    if (v is String) return v.isEmpty ? null : v;
    return v.toString();
  }

  /// Accepts a Firestore [Timestamp], a [DateTime], epoch milliseconds or an
  /// ISO-8601 string.
  static DateTime? readDate(Object? v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v);
    if (v is Map) {
      // Timestamps serialised through JSON / callables: {_seconds, _nanoseconds}.
      final s = v['_seconds'] ?? v['seconds'];
      if (s is num) return DateTime.fromMillisecondsSinceEpoch((s * 1000).toInt());
    }
    return null;
  }

  static Map<String, dynamic>? readMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return null;
  }
}
