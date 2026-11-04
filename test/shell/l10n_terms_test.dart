import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// UX-01 / UX-04 / UX-05: copy that must stay true and consistent.
void main() {
  Map<String, String> arb(String locale) {
    final raw = jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final e in raw.entries)
        if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
    };
  }

  final en = arb('en');
  final ru = arb('ru');
  final ky = arb('ky');

  /// Student-facing keys (the admin CMS is Russian-only by design).
  Iterable<MapEntry<String, String>> student(Map<String, String> m) =>
      m.entries.where((e) => !e.key.startsWith('admin'));

  test('every template key is translated', () {
    expect(ru.keys.toSet().containsAll(en.keys), isTrue, reason: '${en.keys.toSet().difference(ru.keys.toSet())}');
    expect(ky.keys.toSet().containsAll(en.keys), isTrue, reason: '${en.keys.toSet().difference(ky.keys.toSet())}');
  });

  group('leaderboard copy matches the server (D10)', () {
    test('weekly / all-time: lessons, practice and mock exams count', () {
      expect(en['learnLeaderboardNotRanked'], contains('mock exams'));
      expect(en['learnLeaderboardNotRanked'], contains('practice'));
      expect(ru['learnLeaderboardNotRanked'], contains('пробные экзамены'));
      expect(ky['learnLeaderboardNotRanked'], contains('сынамык экзамендер'));
    });

    test('subject boards: only mock exams count', () {
      for (final m in [en, ru, ky]) {
        for (final k in ['learnLeaderboardSubjectNotRanked', 'learnLeaderboardSubjectEmptyBody', 'learnLeaderboardSubjectHint']) {
          expect(m[k], isNotNull, reason: k);
        }
      }
      expect(en['learnLeaderboardSubjectNotRanked'], contains('Only XP from mock exams'));
      expect(ru['learnLeaderboardSubjectNotRanked'], contains('только XP за пробные экзамены'));
      expect(ky['learnLeaderboardSubjectNotRanked'], contains('сынамык экзамендерден алынган XP гана'));
    });
  });

  group('Kyrgyz quality (UX-04)', () {
    test('quoted fixes', () {
      expect(ky['shellNavHome'], 'Башкы бет');
      expect(ky['tutorContextRemove'], isNot(contains('Тиркемени')));
      expect(ky['examResultRecommendation'], contains('кайталаңыз'));
      expect(ky['examResultRecommendation'], contains('{topic}'));
    });

    test('ЖРТ, not the Russian abbreviation, in student-facing Kyrgyz text', () {
      final offenders = [
        for (final e in student(ky))
          if (e.key != 'appName' && RegExp(r'(^|[^А-ЯЁӨҮҢа-яёөүң])ОРТ').hasMatch(e.value)) e.key,
      ];
      expect(offenders, isEmpty);
    });
  });

  test('Russian result advice uses the polite register (UX-04)', () {
    expect(ru['examResultRecommendation'], startsWith('Повторите'));
    expect(ru['examResultRecommendation'], contains('вернитесь'));
    expect(ru['examResultRecommendation'], contains('решите'));
  });

  group('one term per concept (UX-05)', () {
    test('ky: "сынамык экзамен", never "пробалык сынак"/"сынамык тест"', () {
      final offenders = [
        for (final e in student(ky))
          if (RegExp(r'[Пп]робалык|[Сс]ынак|[Сс]ынамык тест').hasMatch(e.value)) e.key,
      ];
      expect(offenders, isEmpty);
      expect(ky['learnExamResultsTitle'], 'Сынамык экзамендер');
      expect(ky['learnRecOpenExams'], 'Экзамендерге');
    });

    test('AI tutor: ИИ-репетитор (ru) / ЖИ-репетитор (ky) everywhere', () {
      expect([for (final e in student(ru)) if (e.value.contains('AI-')) e.key], isEmpty);
      expect([for (final e in student(ky)) if (e.value.contains('AI-')) e.key], isEmpty);
      expect(ru['shellQuickTutor'], ru['tutorTitle']);
      expect(ky['shellQuickTutor'], ky['tutorTitle']);
    });

    test('ru: the purchasable product is a "пробный экзамен"', () {
      expect([for (final e in student(ru)) if (e.value.contains('пробные тесты') || e.value.contains('Пробные тесты')) e.key], isEmpty);
    });
  });
}
