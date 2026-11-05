import '../../../shared/models/exam_attempt_summary.dart';
import '../../../shared/models/user_progress_model.dart';

enum RecommendationKind { dueMistakes, noExam, weakSubject, weakExamSection, weakTopic, moreData }

/// One evidence-based recommendation. The UI renders it as
/// "Рекомендуем …, потому что …" with the numbers below — nothing is invented.
class Recommendation {
  final RecommendationKind kind;
  final String? refId; // subject, section or topic id
  final int? percent;
  final int? count;
  const Recommendation(this.kind, {this.refId, this.percent, this.count});
}

/// Pure rules turning real data into recommendations (GAM-08).
abstract final class RecommendationEngine {
  static const int minSubjectAnswers = 10;
  static const int minTopicAnswers = 5;
  static const int reliableAnswers = 20;

  static List<Recommendation> build({
    required UserProgressModel? progress,
    required List<ExamAttemptSummary> attempts,
    required int dueMistakes,
    int max = 4,
  }) {
    final out = <Recommendation>[];
    final completed = attempts.where((a) => a.isCompleted).toList();

    if (dueMistakes > 0) out.add(Recommendation(RecommendationKind.dueMistakes, count: dueMistakes));

    // Weakest exam section across completed attempts.
    final sectionTotals = <String, (int, int)>{};
    for (final a in completed) {
      for (final s in a.sections) {
        final t = sectionTotals[s.id] ?? (0, 0);
        sectionTotals[s.id] = (t.$1 + s.correct, t.$2 + s.total);
      }
    }
    final weakSection = _weakest(sectionTotals, minTotal: 1, below: 0.6);
    if (weakSection != null) {
      out.add(Recommendation(RecommendationKind.weakExamSection, refId: weakSection.$1, percent: weakSection.$2));
    }

    // Weakest practice subject.
    final subjects = <String, (int, int)>{
      for (final e in (progress?.practiceBySubject ?? const <String, PracticeTally>{}).entries)
        e.key: (e.value.correct, e.value.answered),
    };
    final weakSubject = _weakest(subjects, minTotal: minSubjectAnswers, below: 0.7);
    if (weakSubject != null) {
      out.add(Recommendation(
        RecommendationKind.weakSubject,
        refId: weakSubject.$1,
        percent: weakSubject.$2,
        count: subjects[weakSubject.$1]!.$2,
      ));
    }

    // Weakest topic (practice + exams).
    final topics = <String, (int, int)>{
      for (final e in (progress?.practiceByTopic ?? const <String, PracticeTally>{}).entries)
        e.key: (e.value.correct, e.value.answered),
    };
    for (final a in completed) {
      for (final t in a.topics) {
        final cur = topics[t.id] ?? (0, 0);
        topics[t.id] = (cur.$1 + t.correct, cur.$2 + t.total);
      }
    }
    final weakTopic = _weakest(topics, minTotal: minTopicAnswers, below: 0.6);
    if (weakTopic != null) {
      out.add(Recommendation(RecommendationKind.weakTopic, refId: weakTopic.$1, percent: weakTopic.$2));
    }

    if (completed.isEmpty) out.add(const Recommendation(RecommendationKind.noExam));

    final answered = progress?.practiceAnswered ?? 0;
    if (answered < reliableAnswers) {
      out.add(Recommendation(RecommendationKind.moreData, count: reliableAnswers - answered));
    }
    return out.take(max).toList();
  }

  /// Id with the lowest accuracy among entries with at least [minTotal]
  /// answers, if that accuracy is below [below]. Returns (id, percent).
  static (String, int)? _weakest(Map<String, (int, int)> m, {required int minTotal, required double below}) {
    (String, double)? worst;
    for (final e in m.entries) {
      final (correct, total) = e.value;
      if (total < minTotal || total == 0) continue;
      final acc = correct / total;
      if (worst == null || acc < worst.$2) worst = (e.key, acc);
    }
    if (worst == null || worst.$2 >= below) return null;
    return (worst.$1, (worst.$2 * 100).round());
  }
}
