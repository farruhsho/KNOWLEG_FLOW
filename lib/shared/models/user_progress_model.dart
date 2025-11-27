import 'package:cloud_firestore/cloud_firestore.dart';

/// Модель прогресса пользователя
class UserProgressModel {
  final String userId;
  final int testsCompleted;
  final int averageScore;
  final int streakDays;
  final int totalStudyHours;
  final Map<String, double> subjectProgress; // subjectId -> progress (0.0 - 1.0)
  final List<String> completedLessons;
  final DateTime? lastActivityDate;
  final DateTime? lastStreakUpdate; // For proper streak calculation
  final Map<String, int> weeklyTrends; // week -> average score
  final Map<String, int> monthlyTrends; // month -> average score
  final Map<String, int> errorsByTopic; // topic -> error count
  final int aiPredictedScore; // AI-predicted ORT score (0-200)
  final String level; // 'beginner', 'intermediate', 'expert'

  UserProgressModel({
    required this.userId,
    required this.testsCompleted,
    required this.averageScore,
    required this.streakDays,
    required this.totalStudyHours,
    required this.subjectProgress,
    required this.completedLessons,
    this.lastActivityDate,
    this.lastStreakUpdate,
    this.weeklyTrends = const {},
    this.monthlyTrends = const {},
    this.errorsByTopic = const {},
    this.aiPredictedScore = 0,
    this.level = 'beginner',
  });

  /// Создать из Firestore
  factory UserProgressModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserProgressModel(
      userId: id,
      testsCompleted: data['testsCompleted'] ?? 0,
      averageScore: data['averageScore'] ?? 0,
      streakDays: data['streakDays'] ?? 0,
      totalStudyHours: data['totalStudyHours'] ?? 0,
      subjectProgress: Map<String, double>.from(data['subjectProgress'] ?? {}),
      completedLessons: List<String>.from(data['completedLessons'] ?? []),
      lastActivityDate: data['lastActivityDate'] != null
          ? (data['lastActivityDate'] as Timestamp).toDate()
          : null,
      lastStreakUpdate: data['lastStreakUpdate'] != null
          ? (data['lastStreakUpdate'] as Timestamp).toDate()
          : null,
      weeklyTrends: Map<String, int>.from(data['weeklyTrends'] ?? {}),
      monthlyTrends: Map<String, int>.from(data['monthlyTrends'] ?? {}),
      errorsByTopic: Map<String, int>.from(data['errorsByTopic'] ?? {}),
      aiPredictedScore: data['aiPredictedScore'] ?? 0,
      level: data['level'] ?? 'beginner',
    );
  }

  /// Конвертировать в Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'testsCompleted': testsCompleted,
      'averageScore': averageScore,
      'streakDays': streakDays,
      'totalStudyHours': totalStudyHours,
      'subjectProgress': subjectProgress,
      'completedLessons': completedLessons,
      'lastActivityDate': lastActivityDate != null
          ? Timestamp.fromDate(lastActivityDate!)
          : FieldValue.serverTimestamp(),
      'lastStreakUpdate': lastStreakUpdate != null
          ? Timestamp.fromDate(lastStreakUpdate!)
          : null,
      'weeklyTrends': weeklyTrends,
      'monthlyTrends': monthlyTrends,
      'errorsByTopic': errorsByTopic,
      'aiPredictedScore': aiPredictedScore,
      'level': level,
    };
  }

  /// Копировать с изменениями
  UserProgressModel copyWith({
    String? userId,
    int? testsCompleted,
    int? averageScore,
    int? streakDays,
    int? totalStudyHours,
    Map<String, double>? subjectProgress,
    List<String>? completedLessons,
    DateTime? lastActivityDate,
    DateTime? lastStreakUpdate,
    Map<String, int>? weeklyTrends,
    Map<String, int>? monthlyTrends,
    Map<String, int>? errorsByTopic,
    int? aiPredictedScore,
    String? level,
  }) {
    return UserProgressModel(
      userId: userId ?? this.userId,
      testsCompleted: testsCompleted ?? this.testsCompleted,
      averageScore: averageScore ?? this.averageScore,
      streakDays: streakDays ?? this.streakDays,
      totalStudyHours: totalStudyHours ?? this.totalStudyHours,
      subjectProgress: subjectProgress ?? this.subjectProgress,
      completedLessons: completedLessons ?? this.completedLessons,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      lastStreakUpdate: lastStreakUpdate ?? this.lastStreakUpdate,
      weeklyTrends: weeklyTrends ?? this.weeklyTrends,
      monthlyTrends: monthlyTrends ?? this.monthlyTrends,
      errorsByTopic: errorsByTopic ?? this.errorsByTopic,
      aiPredictedScore: aiPredictedScore ?? this.aiPredictedScore,
      level: level ?? this.level,
    );
  }

  /// Calculate user level based on average score
  String calculateLevel() {
    if (averageScore >= 160) return 'expert'; // 80%+ of max ORT score (200)
    if (averageScore >= 120) return 'intermediate'; // 60-80%
    return 'beginner'; // <60%
  }

  /// Check if streak should be incremented
  bool shouldIncrementStreak() {
    if (lastStreakUpdate == null) return true;
    final now = DateTime.now();
    final lastUpdate = lastStreakUpdate!;
    final daysSinceUpdate = now.difference(lastUpdate).inDays;
    return daysSinceUpdate >= 1 && daysSinceUpdate <= 1; // Exactly 1 day
  }

  /// Check if streak should be reset
  bool shouldResetStreak() {
    if (lastStreakUpdate == null) return false;
    final now = DateTime.now();
    final daysSinceUpdate = now.difference(lastStreakUpdate!).inDays;
    return daysSinceUpdate > 1; // More than 1 day = streak broken
  }
}
