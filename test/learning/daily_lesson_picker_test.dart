import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/lessons/domain/daily_lesson_picker.dart';
import 'package:knowledge_flow/shared/models/lesson_model.dart';

LessonModel _lesson(String id) => LessonModel(
      id: id,
      subjectId: 'math',
      title: {'ru': id},
      content: const {},
      estimatedTimeMinutes: 10,
      order: 1,
      createdBy: 'test',
      createdAt: DateTime.utc(2026),
    );

void main() {
  final lessons = [for (var i = 0; i < 7; i++) _lesson('lesson_$i')];

  test('same day and inputs -> same lesson, regardless of input order (CMS-11)', () {
    final a = DailyLessonPicker.pick(lessons, dayNumber: 20500);
    final b = DailyLessonPicker.pick(lessons.reversed.toList(), dayNumber: 20500);
    expect(a!.id, b!.id);
  });

  test('consecutive days get different lessons and a full cycle has no repeats', () {
    final seen = <String>{};
    for (var d = 20500; d < 20500 + lessons.length; d++) {
      final pick = DailyLessonPicker.pick(lessons, dayNumber: d)!;
      expect(seen.add(pick.id), isTrue, reason: 'repeat on day $d');
    }
    expect(seen.length, lessons.length);
  });

  test('skips completed lessons, falls back to rotation when all are done', () {
    final today = DailyLessonPicker.pick(lessons, dayNumber: 20500)!;
    final next = DailyLessonPicker.pick(lessons, dayNumber: 20500, completed: {today.id})!;
    expect(next.id, isNot(today.id));
    final allDone = DailyLessonPicker.pick(lessons, dayNumber: 20500, completed: {for (final l in lessons) l.id});
    expect(allDone!.id, today.id);
  });

  test('empty pool -> null; duplicates ignored', () {
    expect(DailyLessonPicker.pick(const [], dayNumber: 1), isNull);
    expect(DailyLessonPicker.cycle([_lesson('a'), _lesson('a'), _lesson('b')]).length, 2);
  });
}
