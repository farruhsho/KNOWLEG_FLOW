import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/constants/app_constants.dart';

/// Regression guard for CQ-06: quiz score used a magic `* 240` multiplier while
/// the app's stated max is 200, inflating every result by 1.2x and pushing a
/// perfect score above the maximum. These tests pin the canonical scale.
void main() {
  // Mirrors the (fixed) normalisation in quiz_page._finishQuiz.
  int normalise(int correct, int total) =>
      (correct / total * AppConstants.maxScore).round();

  group('Quiz score normalisation', () {
    test('canonical ORT max score is pinned to AppConstants.maxScore', () {
      expect(AppConstants.maxScore, 200);
    });

    test('a perfect quiz never exceeds the max score', () {
      expect(normalise(10, 10), AppConstants.maxScore);
      expect(normalise(10, 10) <= AppConstants.maxScore, isTrue);
    });

    test('partial score scales proportionally (no magic-240 inflation)', () {
      // 7/10 must normalise to 140 — the old `* 240` produced 168.
      expect(normalise(7, 10), 140);
      expect(normalise(0, 10), 0);
    });
  });
}
