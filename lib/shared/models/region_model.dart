import 'package:equatable/equatable.dart';

/// Model for user's geographic region (Oblast → District → Settlement)
class RegionModel extends Equatable {
  final String oblast;
  final String district;
  final String settlement;

  const RegionModel({
    required this.oblast,
    required this.district,
    required this.settlement,
  });

  factory RegionModel.fromMap(Map<String, dynamic> map) {
    return RegionModel(
      oblast: map['oblast'] ?? '',
      district: map['district'] ?? '',
      settlement: map['settlement'] ?? '',
    );
  }

  factory RegionModel.fromFirestore(Map<String, dynamic> data) {
    return RegionModel(
      oblast: data['oblast'] ?? '',
      district: data['district'] ?? '',
      settlement: data['settlement'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'oblast': oblast,
      'district': district,
      'settlement': settlement,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toMap();
  }

  RegionModel copyWith({
    String? oblast,
    String? district,
    String? settlement,
  }) {
    return RegionModel(
      oblast: oblast ?? this.oblast,
      district: district ?? this.district,
      settlement: settlement ?? this.settlement,
    );
  }

  /// Get full region path as string
  String get fullPath => '$oblast / $district / $settlement';

  @override
  List<Object?> get props => [oblast, district, settlement];

  @override
  String toString() => fullPath;
}

/// Display name from `title: {ru, ky, en}` in [lang], falling back to the
/// canonical (Russian) stored value (UX-11).
String _pickTitle(Map<String, String> title, String lang, String fallback) {
  final v = title[lang] ?? title['ru'];
  return (v == null || v.trim().isEmpty) ? fallback : v;
}

Map<String, String> _parseTitle(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.value is String && (e.value as String).trim().isNotEmpty)
        e.key.toString(): e.value as String,
  };
}

/// One oblast (or city) from `assets/data/kg_regions.json`.
///
/// [oblast] is the canonical stored value (`users/{uid}.region.oblast`, also
/// the server's leaderboard `region_id`) and never changes; [title] holds the
/// localized display names.
class RegionData {
  final String id;
  final String oblast;
  final Map<String, String> title;
  final List<DistrictData> districts;

  const RegionData({
    this.id = '',
    required this.oblast,
    this.title = const {},
    required this.districts,
  });

  /// Name to show in [lang] ('ru' | 'ky' | 'en').
  String label(String lang) => _pickTitle(title, lang, oblast);

  factory RegionData.fromJson(Map<String, dynamic> json) {
    return RegionData(
      id: json['id']?.toString() ?? '',
      oblast: json['oblast'] ?? '',
      title: _parseTitle(json['title']),
      districts: (json['districts'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((d) => DistrictData.fromJson(Map<String, dynamic>.from(d)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'oblast': oblast,
      if (title.isNotEmpty) 'title': title,
      'districts': districts.map((d) => d.toJson()).toList(),
    };
  }
}

class DistrictData {
  final String id;
  final String name;
  final Map<String, String> title;
  final List<String> settlements;

  const DistrictData({
    this.id = '',
    required this.name,
    this.title = const {},
    required this.settlements,
  });

  /// Name to show in [lang]; [name] stays the stored value.
  String label(String lang) => _pickTitle(title, lang, name);

  factory DistrictData.fromJson(Map<String, dynamic> json) {
    return DistrictData(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      title: _parseTitle(json['title']),
      settlements: (json['settlements'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      if (title.isNotEmpty) 'title': title,
      'settlements': settlements,
    };
  }
}

/// Display name in [lang] of a stored oblast value (profile header, …).
/// Unknown values are shown as stored.
String regionDisplayName(List<RegionData> regions, String oblast, String lang) {
  for (final r in regions) {
    if (r.oblast == oblast) return r.label(lang);
  }
  return oblast;
}
