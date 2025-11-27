import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Model for regional rankings (oblast/district/village level)
class RegionalRankingModel extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String oblast; // Region
  final String district; // District
  final String village; // Village/City
  final int totalScore; // Cumulative ORT score
  final int testsCompleted;
  final int averageScore;
  final int globalRank;
  final int oblastRank;
  final int districtRank;
  final int villageRank;
  final double globalPercentile; // Top X% globally
  final double regionalPercentile; // Top X% in region
  final DateTime lastUpdated;

  const RegionalRankingModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.oblast,
    required this.district,
    required this.village,
    required this.totalScore,
    required this.testsCompleted,
    required this.averageScore,
    this.globalRank = 0,
    this.oblastRank = 0,
    this.districtRank = 0,
    this.villageRank = 0,
    this.globalPercentile = 0.0,
    this.regionalPercentile = 0.0,
    required this.lastUpdated,
  });

  factory RegionalRankingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegionalRankingModel(
      id: doc.id,
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? '',
      oblast: data['oblast'] ?? '',
      district: data['district'] ?? '',
      village: data['village'] ?? '',
      totalScore: data['total_score'] ?? 0,
      testsCompleted: data['tests_completed'] ?? 0,
      averageScore: data['average_score'] ?? 0,
      globalRank: data['global_rank'] ?? 0,
      oblastRank: data['oblast_rank'] ?? 0,
      districtRank: data['district_rank'] ?? 0,
      villageRank: data['village_rank'] ?? 0,
      globalPercentile: (data['global_percentile'] ?? 0.0).toDouble(),
      regionalPercentile: (data['regional_percentile'] ?? 0.0).toDouble(),
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'user_name': userName,
      'oblast': oblast,
      'district': district,
      'village': village,
      'total_score': totalScore,
      'tests_completed': testsCompleted,
      'average_score': averageScore,
      'global_rank': globalRank,
      'oblast_rank': oblastRank,
      'district_rank': districtRank,
      'village_rank': villageRank,
      'global_percentile': globalPercentile,
      'regional_percentile': regionalPercentile,
      'last_updated': Timestamp.fromDate(lastUpdated),
    };
  }

  RegionalRankingModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? oblast,
    String? district,
    String? village,
    int? totalScore,
    int? testsCompleted,
    int? averageScore,
    int? globalRank,
    int? oblastRank,
    int? districtRank,
    int? villageRank,
    double? globalPercentile,
    double? regionalPercentile,
    DateTime? lastUpdated,
  }) {
    return RegionalRankingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      oblast: oblast ?? this.oblast,
      district: district ?? this.district,
      village: village ?? this.village,
      totalScore: totalScore ?? this.totalScore,
      testsCompleted: testsCompleted ?? this.testsCompleted,
      averageScore: averageScore ?? this.averageScore,
      globalRank: globalRank ?? this.globalRank,
      oblastRank: oblastRank ?? this.oblastRank,
      districtRank: districtRank ?? this.districtRank,
      villageRank: villageRank ?? this.villageRank,
      globalPercentile: globalPercentile ?? this.globalPercentile,
      regionalPercentile: regionalPercentile ?? this.regionalPercentile,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        oblast,
        district,
        village,
        totalScore,
        testsCompleted,
        averageScore,
        globalRank,
        oblastRank,
        districtRank,
        villageRank,
        globalPercentile,
        regionalPercentile,
        lastUpdated,
      ];
}

/// Kyrgyzstan geographic data for region selection
class KyrgyzstanRegion extends Equatable {
  final String oblast;
  final List<String> districts;
  final Map<String, List<String>> villages; // district -> villages/cities

  const KyrgyzstanRegion({
    required this.oblast,
    required this.districts,
    required this.villages,
  });

  factory KyrgyzstanRegion.fromMap(Map<String, dynamic> map) {
    return KyrgyzstanRegion(
      oblast: map['oblast'] ?? '',
      districts: List<String>.from(map['districts'] ?? []),
      villages: Map<String, List<String>>.from(
        (map['villages'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, List<String>.from(value as List)),
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'oblast': oblast,
      'districts': districts,
      'villages': villages,
    };
  }

  @override
  List<Object?> get props => [oblast, districts, villages];
}

/// Static data for Kyrgyzstan regions (7 oblasts + 2 cities)
class KyrgyzstanGeoData {
  static final List<KyrgyzstanRegion> regions = [
    KyrgyzstanRegion(
      oblast: 'Бишкек',
      districts: ['Ленинский', 'Октябрьский', 'Первомайский', 'Свердловский'],
      villages: {
        'Ленинский': ['Центр', 'Восток'],
        'Октябрьский': ['Центр', 'Запад'],
        'Первомайский': ['Центр', 'Юг'],
        'Свердловский': ['Центр', 'Север'],
      },
    ),
    KyrgyzstanRegion(
      oblast: 'Ош',
      districts: ['Центральный', 'Северный', 'Южный'],
      villages: {
        'Центральный': ['Центр'],
        'Северный': ['Север'],
        'Южный': ['Юг'],
      },
    ),
    KyrgyzstanRegion(
      oblast: 'Чуйская область',
      districts: ['Аламединский', 'Жайылский', 'Кеминский', 'Московский', 'Панфиловский', 'Сокулукский'],
      villages: {
        'Аламединский': ['Кара-Жыгач', 'Лебединовка'],
        'Жайылский': ['Кант', 'Беловодское'],
        'Кеминский': ['Кемин', 'Орловка'],
        'Московский': ['Беловодское', 'Ивановка'],
        'Панфиловский': ['Каинды', 'Лебединовка'],
        'Сокулукский': ['Сокулук', 'Военно-Антоновка'],
      },
    ),
    // Add more oblasts as needed...
  ];

  static List<String> get oblastNames => regions.map((r) => r.oblast).toList();

  static KyrgyzstanRegion? getRegion(String oblast) {
    try {
      return regions.firstWhere((r) => r.oblast == oblast);
    } catch (e) {
      return null;
    }
  }
}
