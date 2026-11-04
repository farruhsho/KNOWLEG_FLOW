import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/quiz/domain/practice_controller.dart';
import 'package:knowledge_flow/features/quiz/domain/practice_launch.dart';
import 'package:knowledge_flow/shared/models/practice_session_model.dart';
import 'package:knowledge_flow/shared/models/question_model.dart';

QuestionModel _q(String id, {String key = 'A', int points = 1}) => QuestionModel.fromMap(id, {
      'subject_id': 'math',
      'stem': {'ru': 'Вопрос $id'},
      'options': [
        {'id': 'A', 'text': 'a'},
        {'id': 'B', 'text': 'b'},
      ],
      if (key.isNotEmpty) 'correct_answer': key,
      'points': points,
    });

void main() {
  var clock = DateTime.utc(2026, 11, 2, 6);
  DateTime now() => clock;

  test('instant feedback, skip, finish and honest totals', () async {
    final c = PracticeController(
      launch: const PracticeLaunch.subject('math'),
      loader: (_) async => [_q('1'), _q('2', key: 'B'), _q('3'), _q('bad', key: '')],
      clock: now,
    );
    await c.load();
    expect(c.status, PracticeStatus.running);
    expect(c.total, 3, reason: 'ungradable question is skipped');

    c.select('A'); // correct
    expect(c.currentAnswer!.isCorrect, isTrue);
    c.select('B'); // locked, ignored
    expect(c.currentAnswer!.selectedOptionId, 'A');
    clock = clock.add(const Duration(seconds: 30));
    c.next();

    c.select('A'); // wrong (key B)
    expect(c.currentAnswer!.isWrong, isTrue);
    c.next();

    clock = clock.add(const Duration(seconds: 30));
    c.skip(); // last question -> finishes
    expect(c.status, PracticeStatus.finished);

    final r = c.result!;
    expect(r.total, 3);
    expect(r.correct, 1);
    expect(r.wrong, 1);
    expect(r.skipped, 1);
    expect(r.answered, 2);
    expect(r.elapsedSeconds, 60);
    expect(r.kind, PracticeKind.subject);
    expect(r.subjectId, 'math');
  });

  test('finishing early counts only seen questions', () async {
    final c = PracticeController(
      launch: const PracticeLaunch.quick(),
      loader: (_) async => [_q('1'), _q('2'), _q('3')],
      clock: now,
    );
    await c.load();
    c.select('A');
    final r = c.finish();
    expect(r.total, 1);
    expect(r.correct, 1);
  });

  test('empty and error states', () async {
    final empty = PracticeController(launch: const PracticeLaunch.quick(), loader: (_) async => [], clock: now);
    await empty.load();
    expect(empty.status, PracticeStatus.empty);

    final failing = PracticeController(
      launch: const PracticeLaunch.quick(),
      loader: (_) async => throw StateError('offline'),
      clock: now,
    );
    await failing.load();
    expect(failing.status, PracticeStatus.error);
  });

  test('points and best correct run come from real answers', () async {
    final c = PracticeController(
      launch: const PracticeLaunch.quick(),
      loader: (_) async => [_q('1', points: 2), _q('2'), _q('3'), _q('4')],
      clock: now,
    );
    await c.load();
    c.select('A');
    c.next();
    c.select('A');
    c.next();
    c.select('B'); // wrong
    c.next();
    c.select('A');
    c.next();
    final r = c.result!;
    expect(r.points, 4);
    expect(r.maxPoints, 5);
    expect(r.bestCorrectRun, 2);
  });

  test('route extra parsing keeps the constructor unchanged', () {
    expect(PracticeLaunch.fromRoute('physics', null).subjectId, 'physics');
    final l = PracticeLaunch.fromRoute('math', {'questionIds': ['a', 'b'], 'refId': 'l1'});
    expect(l.kind, PracticeKind.lesson);
    expect(l.questionIds, ['a', 'b']);
  });
}
