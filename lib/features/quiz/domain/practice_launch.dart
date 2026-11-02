import '../../../shared/models/mistake_model.dart';
import '../../../shared/models/practice_session_model.dart';

/// What a practice session should contain. Passed to `/quiz/:id` as route
/// `extra` (the router keeps building `QuizPage(quizId:)`; the page reads
/// the extra itself), so the page constructor stays unchanged.
class PracticeLaunch {
  final PracticeKind kind;
  final String? subjectId;
  final List<String> questionIds;
  final String? refId;

  /// Mistake items being reviewed, by question id (for the SRS step).
  final Map<String, MistakeItem> mistakes;

  const PracticeLaunch({
    required this.kind,
    this.subjectId,
    this.questionIds = const [],
    this.refId,
    this.mistakes = const {},
  });

  const PracticeLaunch.subject(String this.subjectId)
      : kind = PracticeKind.subject,
        questionIds = const [],
        refId = null,
        mistakes = const {};

  const PracticeLaunch.quick()
      : kind = PracticeKind.quick,
        subjectId = null,
        questionIds = const [],
        refId = null,
        mistakes = const {};

  /// Launch from route `extra`; falls back to a subject practice for
  /// [quizId] when the extra is missing (deep link, web refresh).
  static PracticeLaunch fromRoute(String quizId, Object? extra) {
    if (extra is PracticeLaunch) return extra;
    if (extra is Map) {
      final ids = extra['questionIds'];
      final kindName = extra['kind'];
      final kind = PracticeKind.values.firstWhere(
        (k) => k.name == kindName,
        orElse: () => ids is List && ids.isNotEmpty ? PracticeKind.lesson : PracticeKind.subject,
      );
      return PracticeLaunch(
        kind: kind,
        subjectId: extra['subjectId'] is String ? extra['subjectId'] as String : quizId,
        questionIds: ids is List ? ids.map((e) => e.toString()).toList() : const [],
        refId: extra['refId'] is String ? extra['refId'] as String : null,
      );
    }
    return PracticeLaunch.subject(quizId);
  }
}
