import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_attempt.dart';
import 'package:knowledge_flow/features/exam/domain/exam_start.dart';

void main() {
  // The fresh intro page shows the rules of an attempt in progress in its own
  // style (ARCHITECTURE §10.2), read from exam_attempts.exam_style.
  test('AttemptSummary reads exam_style; missing or unknown means standard', () {
    Map<String, dynamic> doc([Object? style]) => {
          'variant_id': 'fresh_a1',
          'blueprint_id': 'ort_main_2026',
          'language': 'ru',
          'status': 'in_progress',
          if (style != null) 'exam_style': style,
        };
    expect(AttemptSummary.fromJson('a1', doc('strict')).examStyle, ExamStyle.strict);
    expect(AttemptSummary.fromJson('a1', doc('standard')).examStyle, ExamStyle.standard);
    expect(AttemptSummary.fromJson('a1', doc()).examStyle, ExamStyle.standard);
    expect(AttemptSummary.fromJson('a1', doc('exam')).examStyle, ExamStyle.standard);
  });
}
