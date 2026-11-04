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
  // Authorization role: 'student' (default) | 'admin'. Provisioned server-side
  // (Firestore console / admin tooling); the client NEVER writes this field — it
  // is intentionally excluded from toFirestore(). firestore.rules `isAdmin()` and
  // the router admin-gate both trust this value. See CTO_AUDIT_REPORT.md §3.
  final String role;
  final List<String> aiRecommendations; // Personalized study suggestions
  /// Daily study goal chosen in onboarding/profile: 10, 20 or 30 minutes.
  final int? dailyGoalMinutes;
  /// Target score band chosen in onboarding/profile: '110+', '150+', '190+'.
  final String? goalBand;
  /// When the onboarding questionnaire was saved for this account.
  final DateTime? onboardingCompletedAt;
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
    this.role = 'student',
    this.aiRecommendations = const [],
    this.dailyGoalMinutes,
    this.goalBand,
    this.onboardingCompletedAt,
    required this.createdAt,
    required this.lastActive,
  });

  /// Grade value stored for school graduates (matches AppConstants).
  static const int gradeGraduate = 0;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return UserModel.fromMap(doc.id, data);
  }

  /// Tolerant parser (MODEL-01): Firestore stores whole numbers as int, older
  /// documents may hold strings, and some fields may be missing entirely.
  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: parseString(data['name']) ?? '',
      email: parseString(data['email']) ?? '',
      phone: parseString(data['phone']),
      studentId: parseString(data['student_id']),
      grade: parseInt(data['grade']) ?? 11,
      school: parseString(data['school']),
      preferredLanguage: parseString(data['preferred_language']) ?? 'ru',
      targetUniversities: parseStringList(data['target_universities']),
      weakSubjects: _doubleMap(data['weak_subjects']),
      subscription: SubscriptionModel.fromMap(parseMap(data['subscription'])),
      linkedAccounts: LinkedAccounts.fromMap(parseMap(data['linked_accounts'])),
      region: parseRegion(data['region']),
      regionLastUpdated: parseDate(data['region_last_updated']),
      level: parseString(data['level']) ?? 'beginner',
      role: parseString(data['role']) ?? 'student',
      aiRecommendations: parseStringList(data['ai_recommendations']),
      dailyGoalMinutes: parseInt(data['daily_goal_minutes']),
      goalBand: parseString(data['goal_band']),
      onboardingCompletedAt: parseDate(data['onboarding_completed_at']),
      createdAt: parseDate(data['created_at']) ?? DateTime.now(),
      lastActive: parseDate(data['last_active']) ?? DateTime.now(),
    );
  }

  static String? parseString(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static int? parseInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static Map<String, dynamic> parseMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, value) => MapEntry(k.toString(), value));
    return const {};
  }

  static List<String> parseStringList(Object? v) {
    if (v is Iterable) {
      return v.where((e) => e != null).map((e) => e.toString()).toList();
    }
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  static Map<String, double> _doubleMap(Object? v) {
    final result = <String, double>{};
    parseMap(v).forEach((key, value) {
      if (value is num) {
        result[key] = value.toDouble();
      } else if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) result[key] = parsed;
      }
    });
    return result;
  }

  static DateTime? parseDate(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static RegionModel? parseRegion(Object? v) {
    if (v is Map) {
      final region = RegionModel.fromMap(parseMap(v));
      return region.oblast.isEmpty ? null : region;
    }
    // Legacy UserSettingsModel stored the oblast as a plain string.
    if (v is String && v.isNotEmpty) {
      return RegionModel(oblast: v, district: '', settlement: '');
    }
    return null;
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
      if (dailyGoalMinutes != null) 'daily_goal_minutes': dailyGoalMinutes,
      if (goalBand != null) 'goal_band': goalBand,
      if (onboardingCompletedAt != null)
        'onboarding_completed_at': Timestamp.fromDate(onboardingCompletedAt!),
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
    String? role,
    List<String>? aiRecommendations,
    int? dailyGoalMinutes,
    String? goalBand,
    DateTime? onboardingCompletedAt,
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
      role: role ?? this.role,
      aiRecommendations: aiRecommendations ?? this.aiRecommendations,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      goalBand: goalBand ?? this.goalBand,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
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
        role,
        aiRecommendations,
        dailyGoalMinutes,
        goalBand,
        onboardingCompletedAt,
        createdAt,
        lastActive,
      ];

  /// True when the user has filled in the onboarding questionnaire (or set a
  /// goal in the profile).
  bool get hasStudyProfile =>
      onboardingCompletedAt != null ||
      dailyGoalMinutes != null ||
      goalBand != null;
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
      tier: map['tier'] is String ? map['tier'] as String : 'free',
      expiresAt: UserModel.parseDate(map['expires_at']),
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
      parents: UserModel.parseStringList(map['parents']),
      teachers: UserModel.parseStringList(map['teachers']),
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
