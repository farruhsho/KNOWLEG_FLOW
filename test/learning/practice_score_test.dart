import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/quiz/domain/practice_score.dart';
import 'package:knowledge_flow/l10n/app_localizations.dart';
import 'package:knowledge_flow/l10n/app_localizations_en.dart';
import 'package:knowledge_flow/l10n/app_localizations_ky.dart';
import 'package:knowledge_flow/l10n/app_localizations_ru.dart';

void main() {
  final locales = <String, AppLocalizations>{
    'ru': AppLocalizationsRu(),
    'ky': AppLocalizationsKy(),
    'en': AppLocalizationsEn(),
  };
  // Words that would present a practice set as an exam score (EXAM-03).
  final forbidden = RegExp(r'ОРТ|ЖРТ|ORT|балл|score|упай|200|из 200', caseSensitive: false);

  test('practice score labels never present an ORT score', () {
    for (final entry in locales.entries) {
      for (var total = 0; total <= 12; total++) {
        for (var correct = 0; correct <= total; correct++) {
          final labels = PracticeScore(correct: correct, total: total).scoreLabels(entry.value);
          for (final label in labels) {
            expect(forbidden.hasMatch(label), isFalse, reason: '${entry.key}: "$label"');
          }
        }
      }
    }
  });

  test('the separate disclaimer says it is not an ORT score', () {
    expect(locales['ru']!.learnPracticeNotOrtNote, contains('не балл ОРТ'));
    expect(locales['ky']!.learnPracticeNotOrtNote, contains('баллы эмес'));
    expect(locales['en']!.learnPracticeNotOrtNote, contains('not an ORT score'));
  });

  test('percentage is a plain practice percentage (no 0–200 scaling)', () {
    expect(const PracticeScore(correct: 7, total: 10).percent, 70);
    expect(const PracticeScore(correct: 10, total: 10).percent, 100);
    expect(const PracticeScore(correct: 2, total: 3).percent, 67);
    expect(const PracticeScore(correct: 0, total: 0).percent, 0); // no NaN (EXAM-15)
    expect(const PracticeScore(correct: 12, total: 10).percent, 100);
  });

  test('labels contain the real numbers', () {
    final l = locales['ru']!;
    const s = PracticeScore(correct: 7, total: 10);
    expect(s.headline(l), 'Практика: 70%');
    expect(s.summary(l), '7 из 10 верно');
  });
}
