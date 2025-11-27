import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'region_model.dart';

class UserModel extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? studentId; // Student identification number
  final int grade;
  final String? school;
  final String preferredLanguage;
  final List<String> targetUniversities;
  final Map<String, double> weakSubjects;
  final SubscriptionModel subscription;
  final LinkedAccounts linkedAccounts;
  final RegionModel? region; // User's geographic location
  final DateTime? regionLastUpdated; // Track region update for yearly restriction
  final String level; // 'beginner', 'intermediate', 'expert'
  final List<String> aiRecommendations; // Personalized study suggestions
  final DateTime createdAt;
  final DateTime lastActive;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.studentId,
    required this.grade,
    this.school,
    required this.preferredLanguage,
    this.targetUniversities = const [],
    this.weakSubjects = const {},
    required this.subscription,
    required this.linkedAccounts,
    this.region,
    this.regionLastUpdated,
    this.level = 'beginner',
    this.aiRecommendations = const [],
    required this.createdAt,
    required this.lastActive,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'],
      studentId: data['student_id'],
      grade: data['grade'] ?? 11,
      school: data['school'],
      preferredLanguage: data['preferred_language'] ?? 'ru',
      targetUniversities: List<String>.from(data['target_universities'] ?? []),
      weakSubjects: Map<String, double>.from(data['weak_subjects'] ?? {}),
      subscription: SubscriptionModel.fromMap(data['subscription'] ?? {}),
      linkedAccounts: LinkedAccounts.fromMap(data['linked_accounts'] ?? {}),
      region: data['region'] != null ? RegionModel.fromMap(data['region']) : null,
      regionLastUpdated: (data['region_last_updated'] as Timestamp?)?.toDate(),
      level: data['level'] ?? 'beginner',
      aiRecommendations: List<String>.from(data['ai_recommendations'] ?? []),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActive: (data['last_active'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'student_id': studentId,
      'grade': grade,
      'school': school,
      'preferred_language': preferredLanguage,
      'target_universities': targetUniversities,
      'weak_subjects': weakSubjects,
      'subscription': subscription.toMap(),
      'linked_accounts': linkedAccounts.toMap(),
      'region': region?.toMap(),
      'region_last_updated': regionLastUpdated != null ? Timestamp.fromDate(regionLastUpdated!) : null,
      'level': level,
      'ai_recommendations': aiRecommendations,
      'created_at': Timestamp.fromDate(createdAt),
      'last_active': Timestamp.fromDate(lastActive),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? studentId,
    int? grade,
    String? school,
    String? preferredLanguage,
    List<String>? targetUniversities,
    Map<String, double>? weakSubjects,
    SubscriptionModel? subscription,
    LinkedAccounts? linkedAccounts,
    RegionModel? region,
    DateTime? regionLastUpdated,
    String? level,
    List<String>? aiRecommendations,
    DateTime? createdAt,
    DateTime? lastActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      studentId: studentId ?? this.studentId,
      grade: grade ?? this.grade,
      school: school ?? this.school,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      targetUniversities: targetUniversities ?? this.targetUniversities,
      weakSubjects: weakSubjects ?? this.weakSubjects,
      subscription: subscription ?? this.subscription,
      linkedAccounts: linkedAccounts ?? this.linkedAccounts,
      region: region ?? this.region,
      regionLastUpdated: regionLastUpdated ?? this.regionLastUpdated,
      level: level ?? this.level,
      aiRecommendations: aiRecommendations ?? this.aiRecommendations,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  /// Check if user can update region (once per year restriction)
  bool canUpdateRegion() {
    if (regionLastUpdated == null) return true;
    final daysSinceUpdate = DateTime.now().difference(regionLastUpdated!).inDays;
    return daysSinceUpdate >= 365; // 1 year
  }

  @override
  List<Object?> get props => [
        uid,
        name,
        email,
        phone,
        studentId,
        grade,
        school,
        preferredLanguage,
        targetUniversities,
        weakSubjects,
        subscription,
        linkedAccounts,
        region,
        regionLastUpdated,
        level,
        aiRecommendations,
        createdAt,
        lastActive,
      ];
}

class SubscriptionModel extends Equatable {
  final String tier; // 'free', 'monthly', 'yearly'
  final DateTime? expiresAt;

  const SubscriptionModel({
    this.tier = 'free',
    this.expiresAt,
  });

  factory SubscriptionModel.fromMap(Map<String, dynamic> map) {
    return SubscriptionModel(
      tier: map['tier'] ?? 'free',
      expiresAt: (map['expires_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tier': tier,
      'expires_at': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    };
  }

  bool get isActive {
    if (tier == 'free') return true;
    if (expiresAt == null) return false;
    return expiresAt!.isAfter(DateTime.now());
  }

  @override
  List<Object?> get props => [tier, expiresAt];
}

class LinkedAccounts extends Equatable {
  final List<String> parents;
  final List<String> teachers;

  const LinkedAccounts({
    this.parents = const [],
    this.teachers = const [],
  });

  factory LinkedAccounts.fromMap(Map<String, dynamic> map) {
    return LinkedAccounts(
      parents: List<String>.from(map['parents'] ?? []),
      teachers: List<String>.from(map['teachers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parents': parents,
      'teachers': teachers,
    };
  }

  @override
  List<Object?> get props => [parents, teachers];
}
