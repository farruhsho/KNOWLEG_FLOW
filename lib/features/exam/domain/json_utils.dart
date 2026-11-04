/// Tolerant JSON helpers shared by the exam domain parsers.
///
/// Payloads arrive from three places with slightly different shapes: callable
/// results (`Map<Object?, Object?>`, numbers that may be int or double,
/// Timestamps serialised as `{_seconds, _nanoseconds}`), Firestore documents
/// (converted to JSON-safe maps by the data layer) and the bundled asset file.
/// None of these helpers throw on unexpected input; they fall back to a
/// neutral value so one malformed field cannot take down a whole screen.
library;

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

/// Recursively converts callable results (`Map<Object?, Object?>`, nested
/// lists) into `Map<String, dynamic>` / `List<dynamic>`.
Object? deepJson(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), deepJson(v)));
  }
  if (value is List) return value.map(deepJson).toList();
  return value;
}

List<dynamic> asJsonList(Object? value) => value is List ? value : const [];

String? asString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  return null;
}

double? asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) return value == 'true';
  if (value is num) return value != 0;
  return fallback;
}

/// First non-null value among [keys] (supports camelCase and snake_case
/// spellings of the same field).
Object? pick(Map<String, dynamic> map, List<String> keys) {
  for (final k in keys) {
    final v = map[k];
    if (v != null) return v;
  }
  return null;
}

/// Epoch milliseconds from an int/double (ms), an ISO-8601 string, a
/// [DateTime], or a serialised Timestamp map (`{_seconds, _nanoseconds}` or
/// `{seconds, nanoseconds}`).
int? asEpochMs(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is DateTime) return value.millisecondsSinceEpoch;
  if (value is String) {
    final n = int.tryParse(value);
    if (n != null) return n;
    return DateTime.tryParse(value)?.millisecondsSinceEpoch;
  }
  if (value is Map) {
    final m = asJsonMap(value);
    final s = asInt(m['_seconds'] ?? m['seconds']);
    final ns = asInt(m['_nanoseconds'] ?? m['nanoseconds']) ?? 0;
    if (s != null) return s * 1000 + ns ~/ 1000000;
  }
  return null;
}

List<String> asStringList(Object? value) => asJsonList(value)
    .map(asString)
    .whereType<String>()
    .toList(growable: false);
