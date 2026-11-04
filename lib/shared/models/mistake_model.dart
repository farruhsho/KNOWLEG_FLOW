import '../../core/constants/app_constants.dart';
import '../../core/utils/json_read.dart';

enum MistakeSource { practice, exam }

/// One entry of the "Ошибки и повторение" queue:
/// `user_mistakes/{uid}/items/{questionId}` (ARCHITECTURE.md §1, note).
class MistakeItem {
  final String questionId;
  final MistakeSource source;
  final String subjectId;
  final String sectionId;
  final String? topicId;
  final int wrongCount;
  final DateTime? lastWrongAt;
  final DateTime? nextReviewAt;
  final int intervalDays;
  final bool resolved;
  final String? attemptId;

  const MistakeItem({
    required this.questionId,
    required this.source,
    this.subjectId = '',
    this.sectionId = '',
    this.topicId,
    this.wrongCount = 1,
    this.lastWrongAt,
    this.nextReviewAt,
    this.intervalDays = 1,
    this.resolved = false,
    this.attemptId,
  });

  factory MistakeItem.fromMap(String docId, Map<String, dynamic> m) {
    final src = JsonRead.string(m, ['source']);
    return MistakeItem(
      questionId: JsonRead.string(m, ['question_id', 'questionId']) ?? docId,
      source: src == 'exam' ? MistakeSource.exam : MistakeSource.practice,
      subjectId: JsonRead.stringOr(m, ['subject_id', 'subjectId']),
      sectionId: JsonRead.stringOr(m, ['section_id', 'sectionId']),
      topicId: JsonRead.string(m, ['topic_id', 'topicId']),
      wrongCount: JsonRead.intOr(m, ['wrong_count'], 1),
      lastWrongAt: JsonRead.date(m, ['last_wrong_at']),
      nextReviewAt: JsonRead.date(m, ['next_review_at']),
      intervalDays: JsonRead.intOr(m, ['interval_days'], 1),
      resolved: JsonRead.boolean(m, ['resolved']) ?? false,
      attemptId: JsonRead.string(m, ['attempt_id', 'attemptId']),
    );
  }

  /// Only practice-sourced items may be written by the client (rules).
  bool get clientWritable => source == MistakeSource.practice;

  bool isDue(DateTime now) =>
      !resolved && (nextReviewAt == null || !nextReviewAt!.isAfter(now));

  MistakeItem copyWith({
    int? wrongCount,
    DateTime? lastWrongAt,
    DateTime? nextReviewAt,
    int? intervalDays,
    bool? resolved,
  }) =>
      MistakeItem(
        questionId: questionId,
        source: source,
        subjectId: subjectId,
        sectionId: sectionId,
        topicId: topicId,
        wrongCount: wrongCount ?? this.wrongCount,
        lastWrongAt: lastWrongAt ?? this.lastWrongAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        intervalDays: intervalDays ?? this.intervalDays,
        resolved: resolved ?? this.resolved,
        attemptId: attemptId,
      );
}

/// Spaced repetition for the mistakes queue: 1 → 3 → 7 → 14 → 30 days
/// (AppConstants.srsIntervals). A wrong answer resets the item to the first
/// interval; a correct review moves it one step; a correct review at the
/// last step resolves it.
abstract final class MistakeSrs {
  static List<int> get intervals => AppConstants.srsIntervals;

  /// Interval that follows [currentDays], or null when the item is done.
  static int? nextInterval(int currentDays) {
    for (final d in intervals) {
      if (d > currentDays) return d;
    }
    return null;
  }

  static MistakeItem afterWrong(MistakeItem item, DateTime now) {
    final first = intervals.first;
    return item.copyWith(
      wrongCount: item.wrongCount + 1,
      lastWrongAt: now,
      intervalDays: first,
      nextReviewAt: now.add(Duration(days: first)),
      resolved: false,
    );
  }

  static MistakeItem afterCorrect(MistakeItem item, DateTime now) {
    final next = nextInterval(item.intervalDays);
    if (next == null) return item.copyWith(resolved: true);
    return item.copyWith(
      intervalDays: next,
      nextReviewAt: now.add(Duration(days: next)),
    );
  }

  /// Fields for a fresh practice mistake (no prior state needed, so the
  /// write can be a blind merge inside the finish batch).
  static ({int intervalDays, DateTime nextReviewAt}) firstSchedule(DateTime now) {
    final first = intervals.first;
    return (intervalDays: first, nextReviewAt: now.add(Duration(days: first)));
  }
}
