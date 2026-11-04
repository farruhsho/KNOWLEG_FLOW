import 'question_model.dart';

/// Outcome of one practice question.
enum PracticeOutcome { correct, wrong, skipped }

class PracticeAnswer {
  final QuestionModel question;
  final String? selectedOptionId;
  final PracticeOutcome outcome;
  final int elapsedSeconds;

  const PracticeAnswer({
    required this.question,
    required this.selectedOptionId,
    required this.outcome,
    this.elapsedSeconds = 0,
  });

  bool get isCorrect => outcome == PracticeOutcome.correct;
  bool get isWrong => outcome == PracticeOutcome.wrong;
  bool get isSkipped => outcome == PracticeOutcome.skipped;
}

/// Where a practice session came from (for "retry" and analytics).
enum PracticeKind { subject, quick, lesson, mistakes }

/// A finished practice session. Purely client-side bookkeeping: the score
/// shown from it is a practice percentage, never an ORT score (EXAM-03).
class PracticeSessionResult {
  final String sessionId;
  final PracticeKind kind;
  final String? subjectId;
  final String? refId; // lesson id for lesson practice
  final List<PracticeAnswer> answers;
  final DateTime startedAt;
  final DateTime finishedAt;

  const PracticeSessionResult({
    required this.sessionId,
    required this.kind,
    required this.answers,
    required this.startedAt,
    required this.finishedAt,
    this.subjectId,
    this.refId,
  });

  int get total => answers.length;
  int get correct => answers.where((a) => a.isCorrect).length;
  int get wrong => answers.where((a) => a.isWrong).length;
  int get skipped => answers.where((a) => a.isSkipped).length;
  int get answered => total - skipped;

  /// Points earned and possible (QuestionModel.points; 1 by default).
  int get points => answers.where((a) => a.isCorrect).fold(0, (s, a) => s + a.question.points);
  int get maxPoints => answers.fold(0, (s, a) => s + a.question.points);

  int get elapsedSeconds {
    final s = finishedAt.difference(startedAt).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// Longest run of consecutive correct answers (feeds the cosmetic
  /// "5 in a row" quest — GAM-18).
  int get bestCorrectRun {
    var best = 0, run = 0;
    for (final a in answers) {
      if (a.isCorrect) {
        run++;
        if (run > best) best = run;
      } else if (a.isWrong) {
        run = 0;
      }
    }
    return best;
  }
}
