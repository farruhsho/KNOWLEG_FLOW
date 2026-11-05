import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Server-owned gamification stats (`user_stats/{uid}`, written only by
/// Cloud Functions — ARCHITECTURE §1.7). Parsed tolerantly.
@immutable
class UserStats {
  const UserStats({
    this.xp = 0,
    this.level = 1,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastActiveDay,
    this.todayXp = 0,
    this.dailyGoalXp = 0,
    this.examsCompleted = 0,
  });

  final int xp;
  final int level;
  final int currentStreak;
  final int bestStreak;

  /// 'yyyy-mm-dd' in Asia/Bishkek (UTC+6).
  final String? lastActiveDay;
  final int todayXp;
  final int dailyGoalXp;
  final int examsCompleted;

  static int _int(Object? v, [int fallback = 0]) =>
      v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

  factory UserStats.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const UserStats();
    final day = data['last_active_day'];
    return UserStats(
      xp: _int(data['xp']),
      level: _int(data['level'], 1),
      currentStreak: _int(data['current_streak']),
      bestStreak: _int(data['best_streak']),
      lastActiveDay: day is String && day.isNotEmpty ? day : null,
      todayXp: _int(data['today_xp']),
      dailyGoalXp: _int(data['daily_goal_xp']),
      examsCompleted: _int(data['exams_completed']),
    );
  }

  /// Calendar day in Bishkek (UTC+6, no DST) for [now].
  static String bishkekDay(DateTime now) {
    final b = now.toUtc().add(const Duration(hours: 6));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${b.year}-${two(b.month)}-${two(b.day)}';
  }

  bool _activeToday(DateTime now) => lastActiveDay == bishkekDay(now);

  bool _activeYesterday(DateTime now) =>
      lastActiveDay == bishkekDay(now.subtract(const Duration(days: 1)));

  /// The stored streak is only updated on activity, so a streak whose last
  /// active day is before yesterday is already broken: show 0, not a stale
  /// number.
  int effectiveStreak(DateTime now) =>
      _activeToday(now) || _activeYesterday(now) ? currentStreak : 0;

  /// `today_xp` belongs to `last_active_day`; it is 0 on any other day.
  int effectiveTodayXp(DateTime now) => _activeToday(now) ? todayXp : 0;

  /// Nothing has ever been recorded for this user.
  bool get isEmpty => xp == 0 && examsCompleted == 0 && lastActiveDay == null;
}

/// Latest completed exam attempt (`exam_attempts`, status `completed`).
@immutable
class LatestExamSummary {
  const LatestExamSummary({
    required this.attemptId,
    this.blueprintId,
    this.percent,
    this.correct,
    this.total,
    this.weakTopics = const [],
    this.completedAt,
  });

  final String attemptId;
  final String? blueprintId;
  final double? percent;
  final int? correct;
  final int? total;
  final List<String> weakTopics;
  final DateTime? completedAt;

  static LatestExamSummary? fromDoc(String id, Map<String, dynamic>? data) {
    if (data == null || data['status'] != 'completed') return null;
    final result = data['result'];
    final r = result is Map ? result : const {};
    final weak = r['weak_topics'];
    final completed = data['completed_at'];
    return LatestExamSummary(
      attemptId: id,
      blueprintId: data['blueprint_id'] is String ? data['blueprint_id'] as String : null,
      percent: r['percent'] is num ? (r['percent'] as num).toDouble() : null,
      correct: r['correct'] is num ? (r['correct'] as num).toInt() : null,
      total: r['total'] is num ? (r['total'] as num).toInt() : null,
      weakTopics: weak is List
          ? weak.whereType<String>().where((t) => t.isNotEmpty).toList()
          : const [],
      completedAt: completed is Timestamp
          ? completed.toDate()
          : (completed is DateTime ? completed : null),
    );
  }
}

/// What the "Next step" card recommends.
enum NextStepKind {
  /// No exam yet → take the free first full mock exam.
  firstMock,

  /// Latest exam has weak topics → study the weakest one.
  weakTopic,

  /// Exam done, nothing weak recorded → keep practising.
  practice,
}

@immutable
class NextStep {
  const NextStep(this.kind, {this.topicId});

  final NextStepKind kind;
  final String? topicId;

  @override
  bool operator ==(Object other) =>
      other is NextStep && other.kind == kind && other.topicId == topicId;

  @override
  int get hashCode => Object.hash(kind, topicId);

  @override
  String toString() => 'NextStep($kind, $topicId)';
}

/// Simple rule-based recommendation.
NextStep decideNextStep({
  required int examsCompleted,
  required LatestExamSummary? latest,
}) {
  if (latest == null) {
    return examsCompleted <= 0
        ? const NextStep(NextStepKind.firstMock)
        : const NextStep(NextStepKind.practice);
  }
  if (latest.weakTopics.isNotEmpty) {
    return NextStep(NextStepKind.weakTopic, topicId: latest.weakTopics.first);
  }
  return const NextStep(NextStepKind.practice);
}

/// 'math.quadratic_equations' → 'math'.
String topicArea(String topicId) {
  final dot = topicId.indexOf('.');
  return dot < 0 ? topicId : topicId.substring(0, dot);
}
