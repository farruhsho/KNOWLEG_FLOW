import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/constants/app_constants.dart';
import 'package:knowledge_flow/shared/models/mistake_model.dart';

void main() {
  final now = DateTime.utc(2026, 11, 2, 6);
  const base = MistakeItem(questionId: 'q1', source: MistakeSource.practice, subjectId: 'math');

  test('intervals follow the contract 1 → 3 → 7 → 14 → 30', () {
    expect(AppConstants.srsIntervals, [1, 3, 7, 14, 30]);
  });

  test('correct reviews walk the ladder and resolve after 30 days', () {
    var item = base.copyWith(intervalDays: 1, nextReviewAt: now);
    final seen = <int>[];
    while (!item.resolved) {
      item = MistakeSrs.afterCorrect(item, now);
      if (!item.resolved) {
        seen.add(item.intervalDays);
        expect(item.nextReviewAt, now.add(Duration(days: item.intervalDays)));
      }
    }
    expect(seen, [3, 7, 14, 30]);
  });

  test('a wrong answer resets to the first interval and counts the error', () {
    final mid = base.copyWith(intervalDays: 14, wrongCount: 2);
    final after = MistakeSrs.afterWrong(mid, now);
    expect(after.intervalDays, 1);
    expect(after.wrongCount, 3);
    expect(after.resolved, isFalse);
    expect(after.nextReviewAt, now.add(const Duration(days: 1)));
  });

  test('due logic', () {
    expect(base.copyWith(nextReviewAt: now).isDue(now), isTrue);
    expect(base.copyWith(nextReviewAt: now.add(const Duration(hours: 1))).isDue(now), isFalse);
    expect(base.copyWith(nextReviewAt: now, resolved: true).isDue(now), isFalse);
  });

  test('parsing tolerates missing fields; exam items are read-only', () {
    final m = MistakeItem.fromMap('q9', {'source': 'exam', 'attempt_id': 'a1', 'wrong_count': 2.0});
    expect(m.questionId, 'q9');
    expect(m.source, MistakeSource.exam);
    expect(m.clientWritable, isFalse);
    expect(m.wrongCount, 2);
    expect(m.attemptId, 'a1');
  });
}
