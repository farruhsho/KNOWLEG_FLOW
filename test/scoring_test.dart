import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/quiz/domain/practice_score.dart';
import 'package:knowledge_flow/shared/models/practice_session_model.dart';
import 'package:knowledge_flow/shared/models/question_model.dart';

/// EXAM-17: tests the real practice scoring code (not a local copy of a
/// formula). Practice is scored as correct/total and shown as a percentage;
/// it is never scaled to a 0–200 "ORT score" (EXAM-03). Exam scoring is
/// server-side (examSubmitSection) and tested with the backend.
QuestionModel _q(String id, {int points = 1}) => QuestionModel.fromMap(id, {
      'stem': {'ru': id},
      'options': [
        {'id': 'A', 'text': 'a'},
        {'id': 'B', 'text': 'b'},
      ],
      'correct_answer': 'A',
      'points': points,
    });

PracticeAnswer _a(QuestionModel q, PracticeOutcome o) =>
    PracticeAnswer(question: q, selectedOptionId: o == PracticeOutcome.skipped ? null : 'A', outcome: o);

void main() {
  final start = DateTime.utc(2026, 11, 2, 6);

  PracticeSessionResult session(List<PracticeAnswer> answers) => PracticeSessionResult(
        sessionId: 's',
        kind: PracticeKind.quick,
        answers: answers,
        startedAt: start,
        finishedAt: start.add(const Duration(minutes: 5)),
      );

  test('7 of 10 correct is 70% practice, not 140 of 200', () {
    final answers = [
      for (var i = 0; i < 10; i++) _a(_q('q$i'), i < 7 ? PracticeOutcome.correct : PracticeOutcome.wrong),
    ];
    final r = session(answers);
    final score = PracticeScore(correct: r.correct, total: r.total);
    expect(r.correct, 7);
    expect(score.percent, 70);
  });

  test('skipped questions count in the total but not as wrong', () {
    final r = session([
      _a(_q('1'), PracticeOutcome.correct),
      _a(_q('2'), PracticeOutcome.skipped),
      _a(_q('3'), PracticeOutcome.wrong),
    ]);
    expect(r.total, 3);
    expect(r.answered, 2);
    expect(r.wrong, 1);
    expect(r.skipped, 1);
    expect(PracticeScore(correct: r.correct, total: r.total).percent, 33);
  });

  test('question points are honoured for weighted totals', () {
    final r = session([
      _a(_q('1', points: 2), PracticeOutcome.correct),
      _a(_q('2', points: 2), PracticeOutcome.wrong),
      _a(_q('3'), PracticeOutcome.correct),
    ]);
    expect(r.points, 3);
    expect(r.maxPoints, 5);
  });

  test('a perfect set never exceeds 100% and an empty set is 0%', () {
    final r = session([for (var i = 0; i < 5; i++) _a(_q('$i'), PracticeOutcome.correct)]);
    expect(PracticeScore(correct: r.correct, total: r.total).percent, 100);
    expect(const PracticeScore(correct: 0, total: 0).percent, 0);
    expect(r.elapsedSeconds, 300);
  });
}
