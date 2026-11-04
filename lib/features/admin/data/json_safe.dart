import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts Firestore values into JSON-encodable ones (CMS-17): Timestamps
/// and DateTimes become ISO-8601 strings, GeoPoints `{lat, lng}`, document
/// references their path, Blobs are dropped. Maps and lists are converted
/// recursively.
Object? jsonSafe(Object? value) {
  if (value == null || value is String || value is bool || value is num) {
    return value;
  }
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is GeoPoint) return {'lat': value.latitude, 'lng': value.longitude};
  if (value is DocumentReference) return value.path;
  if (value is Map) {
    return {
      for (final e in value.entries)
        if (e.key is String) e.key as String: jsonSafe(e.value),
    };
  }
  if (value is Iterable) return [for (final e in value) jsonSafe(e)];
  if (value is Blob) return null;
  return value.toString();
}
