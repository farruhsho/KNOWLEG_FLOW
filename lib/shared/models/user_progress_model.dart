import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/utils/json_read.dart';

/// Answered/correct counters for one subject or topic.
class PracticeTally {
  final int answered;
  final int correct;
  const PracticeTally({this.answered = 0, this.correct = 0});

  factory PracticeTally.fromMap(Map<String, dynamic> m) => PracticeTally(
        answered: JsonRead.intOr(m, ['answered'], 0),
        correct: JsonRead.intOr(m, ['correct'], 0),
      );

  /// Accuracy in 0..1, or null when nothing was answered.
  double? get accuracy => answered > 0 ? (correct / answered).clamp(0.0, 1.0) : null;
}

/// Firestore keys cannot contain '.', but topic ids do ("math.algebra").
abstract final class ProgressKeys {
  static String encode(String key) => key.replaceAll('.', '|');
  static String decode(String key) => key.replaceAll('|', '.');
}

/// Legacy per-user aggregates in `user_progress/{uid}` (owner read/write).
///
/// These are *practice* aggregates only; authoritative XP, level, streak and
/// exam results live in server-owned `user_stats` / `exam_attempts`. The
/// legacy `averageScore` (0–200) and `streakDays` fields are still parsed for
/// old documents but are no longer written or shown as an ORT score.
class UserProgressModel {
  final String userId;
  final int testsCompleted;
  final int averageScore;
  final int streakDays;
  final int totalStudyHours;
  final Map<String, double> subjectProgress; // subjectId -> progress (0.0 - 1.0)
  final List<String> completedLessons;
  final DateTime? lastActivityDate;
  final DateTime? lastStreakUpdate;
  final Map<String, int> weeklyTrends;
  final Map<String, int> monthlyTrends;
  final Map<String, int> errorsByTopic; // topic -> error count
  final int aiPredictedScore; // legacy, never written
  final String level;

  // Practice aggregates (written with FieldValue.increment at session end).
  final int practiceSessions;
  final int practiceAnswered;
  final int practiceCorrect;
  final int practiceSkipped;
  final int practiceSeconds;
  final Map<String, PracticeTally> practiceBySubject;
  final Map<String, PracticeTally> practiceByTopic;

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
    this.practiceSessions = 0,
    this.practiceAnswered = 0,
    this.practiceCorrect = 0,
    this.practiceSkipped = 0,
    this.practiceSeconds = 0,
    this.practiceBySubject = const {},
    this.practiceByTopic = const {},
  });

  factory UserProgressModel.empty(String userId) => UserProgressModel(
        userId: userId,
        testsCompleted: 0,
        averageScore: 0,
        streakDays: 0,
        totalStudyHours: 0,
        subjectProgress: const {},
        completedLessons: const [],
      );

  /// Создать из Firestore (tolerant of ints/doubles and missing fields).
  factory UserProgressModel.fromFirestore(Map<String, dynamic> data, String id) {
    Map<String, int> intMap(List<String> keys) {
      final m = JsonRead.map(data, keys) ?? const {};
      return {
        for (final e in m.entries)
          if (JsonRead.toInt(e.value) != null) ProgressKeys.decode(e.key): JsonRead.toInt(e.value)!,
      };
    }

    Map<String, PracticeTally> tallies(List<String> keys) {
      final m = JsonRead.map(data, keys) ?? const {};
      return {
        for (final e in m.entries)
          if (JsonRead.asMap(e.value) != null)
            ProgressKeys.decode(e.key): PracticeTally.fromMap(JsonRead.asMap(e.value)!),
      };
    }

    final sp = JsonRead.map(data, ['subjectProgress']) ?? const {};
    return UserProgressModel(
      userId: id,
      testsCompleted: JsonRead.intOr(data, ['testsCompleted'], 0),
      averageScore: JsonRead.intOr(data, ['averageScore'], 0),
      streakDays: JsonRead.intOr(data, ['streakDays'], 0),
      totalStudyHours: JsonRead.intOr(data, ['totalStudyHours'], 0),
      subjectProgress: {
        for (final e in sp.entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
      completedLessons: JsonRead.stringList(data, ['completedLessons', 'completed_lessons']),
      lastActivityDate: JsonRead.date(data, ['lastActivityDate']),
      lastStreakUpdate: JsonRead.date(data, ['lastStreakUpdate']),
      weeklyTrends: intMap(['weeklyTrends']),
      monthlyTrends: intMap(['monthlyTrends']),
      errorsByTopic: intMap(['errorsByTopic']),
      aiPredictedScore: JsonRead.intOr(data, ['aiPredictedScore'], 0),
      level: JsonRead.stringOr(data, ['level'], 'beginner'),
      practiceSessions: JsonRead.intOr(data, ['practice_sessions'], 0),
      practiceAnswered: JsonRead.intOr(data, ['practice_answered'], 0),
      practiceCorrect: JsonRead.intOr(data, ['practice_correct'], 0),
      practiceSkipped: JsonRead.intOr(data, ['practice_skipped'], 0),
      practiceSeconds: JsonRead.intOr(data, ['practice_seconds'], 0),
      practiceBySubject: tallies(['practice_by_subject']),
      practiceByTopic: tallies(['practice_by_topic']),
    );
  }

  /// Конвертировать в Firestore (legacy full-document shape).
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
      'lastStreakUpdate':
          lastStreakUpdate != null ? Timestamp.fromDate(lastStreakUpdate!) : null,
      'weeklyTrends': weeklyTrends,
      'monthlyTrends': monthlyTrends,
      'errorsByTopic': {
        for (final e in errorsByTopic.entries) ProgressKeys.encode(e.key): e.value,
      },
      'aiPredictedScore': aiPredictedScore,
      'level': level,
    };
  }

  /// Practice accuracy 0..1, or null when nothing was answered yet.
  double? get practiceAccuracy =>
      PracticeTally(answered: practiceAnswered, correct: practiceCorrect).accuracy;

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
      practiceSessions: practiceSessions,
      practiceAnswered: practiceAnswered,
      practiceCorrect: practiceCorrect,
      practiceSkipped: practiceSkipped,
      practiceSeconds: practiceSeconds,
      practiceBySubject: practiceBySubject,
      practiceByTopic: practiceByTopic,
    );
  }

  /// Level label derived from practice accuracy (not from an ORT scale).
  String calculateLevel() {
    final acc = practiceAccuracy;
    if (acc == null) return 'beginner';
    if (acc >= 0.8) return 'expert';
    if (acc >= 0.6) return 'intermediate';
    return 'beginner';
  }
}
