import '../../core/utils/json_read.dart';

/// Correct/total for one section or topic of an exam result.
class ExamPartResult {
  final String id;
  final int correct;
  final int total;
  const ExamPartResult(this.id, this.correct, this.total);

  double? get accuracy => total > 0 ? correct / total : null;
}

/// Read-only summary of `exam_attempts/{attemptId}` (server-written,
/// ARCHITECTURE.md §1.4) for the progress screen.
class ExamAttemptSummary {
  final String id;
  final String blueprintId;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int correct;
  final int total;
  final double? percent;
  final List<ExamPartResult> sections;
  final List<ExamPartResult> topics;
  final List<String> weakTopics;

  const ExamAttemptSummary({
    required this.id,
    required this.blueprintId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.correct = 0,
    this.total = 0,
    this.percent,
    this.sections = const [],
    this.topics = const [],
    this.weakTopics = const [],
  });

  bool get isCompleted => status == 'completed' && total > 0;

  /// Direction key used by `user_stats.best_exam_percent` ("ort_main" for
  /// "ort_main_2026"): the blueprint id without its trailing year.
  String get direction => blueprintId.replaceFirst(RegExp(r'_\d{4}$'), '');

  factory ExamAttemptSummary.fromMap(String id, Map<String, dynamic> m) {
    final result = JsonRead.map(m, ['result']) ?? const {};
    List<ExamPartResult> parts(String key, String idKey) {
      final raw = result[key];
      if (raw is! List) return const [];
      return raw
          .map(JsonRead.asMap)
          .whereType<Map<String, dynamic>>()
          .map((p) => ExamPartResult(
                JsonRead.stringOr(p, [idKey]),
                JsonRead.intOr(p, ['correct'], 0),
                JsonRead.intOr(p, ['total'], 0),
              ))
          .where((p) => p.id.isNotEmpty)
          .toList();
    }

    final correct = JsonRead.intOr(result, ['correct'], 0);
    final total = JsonRead.intOr(result, ['total'], 0);
    return ExamAttemptSummary(
      id: id,
      blueprintId: JsonRead.stringOr(m, ['blueprint_id']),
      status: JsonRead.stringOr(m, ['status']),
      startedAt: JsonRead.date(m, ['started_at']),
      completedAt: JsonRead.date(m, ['completed_at']),
      correct: correct,
      total: total,
      percent: JsonRead.decimal(result, ['percent']) ?? (total > 0 ? correct * 100 / total : null),
      sections: parts('sections', 'section_id'),
      topics: parts('topics', 'topic_id'),
      weakTopics: JsonRead.stringList(result, ['weak_topics']),
    );
  }
}
