import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Model for region data structure from JSON
class RegionData {
  final String oblast;
  final List<DistrictData> districts;

  const RegionData({
    required this.oblast,
    required this.districts,
  });

  factory RegionData.fromJson(Map<String, dynamic> json) {
    return RegionData(
      oblast: json['oblast'] ?? '',
      districts: (json['districts'] as List<dynamic>?)
              ?.map((d) => DistrictData.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'oblast': oblast,
      'districts': districts.map((d) => d.toJson()).toList(),
    };
  }
}

class DistrictData {
  final String name;
  final List<String> settlements;

  const DistrictData({
    required this.name,
    required this.settlements,
  });

  factory DistrictData.fromJson(Map<String, dynamic> json) {
    return DistrictData(
      name: json['name'] ?? '',
      settlements: (json['settlements'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'settlements': settlements,
    };
  }
}
