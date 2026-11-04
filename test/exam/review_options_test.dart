import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_blueprint.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_review_page.dart';

import 'exam_test_fixtures.dart';

void main() {
  test('comparison items without options get the blueprint fixed options', () {
    final bp = ExamBlueprint.fromJson(twoSectionBlueprint);
    ReviewItem item(String id, String section, {bool withOptions = false}) =>
        ReviewItem.fromJson({
          'questionId': id,
          'sectionId': section,
          'stem': 's',
          'options': withOptions
              ? [
                  {'id': 'A', 'text': '1'},
                  {'id': 'B', 'text': '2'},
                ]
              : <Object>[],
          'userAnswer': 'A',
          'correct': 'B',
          'explanation': '',
        });
    final items = [
      item('q1', 'math'),
      item('q2', 'math'),
      item('q3', 'math', withOptions: true),
      item('v1', 'verbal'),
    ];
    final opts = reviewOptions(items, bp, 'ky');
    expect(opts[0].map((o) => o.id), ['A', 'B', 'C', 'D']);
    expect(opts[0].first.text, 'А чоң', reason: 'exam language, not UI');
    expect(opts[1], hasLength(4));
    expect(opts[2].map((o) => o.text), ['1', '2'], reason: 'own options win');
    expect(opts[3], isEmpty, reason: 'no fixed options for that part');
    expect(reviewOptions(items, null, 'ru')[0], isEmpty);
  });
}
