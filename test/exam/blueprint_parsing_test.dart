import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_blueprint.dart';

/// Parses the real bundled asset (the offline fallback the client ships).
List<ExamBlueprint> loadAsset() {
  final raw = File('assets/data/exam_blueprints.json').readAsStringSync();
  return ExamBlueprint.listFromJson(jsonDecode(raw));
}

void main() {
  group('exam_blueprints.json', () {
    late List<ExamBlueprint> all;
    setUpAll(() => all = loadAsset());

    test('contains all 10 blueprints of the 2026 cycle', () {
      expect(all.map((b) => b.id).toSet(), {
        'ort_main_2026',
        'ort_subject_chemistry_2026',
        'ort_subject_biology_2026',
        'ort_subject_physics_2026',
        'ort_subject_math_2026',
        'ort_subject_history_2026',
        'ort_subject_english_2026',
        'ort_subject_kyrgyz_lit_2026',
        'ort_subject_russian_lit_2026',
        'ort_state_language_2026',
      });
      expect(all.where((b) => b.kind == BlueprintKind.main), hasLength(1));
      expect(all.where((b) => b.kind == BlueprintKind.subject), hasLength(8));
      expect(all.where((b) => b.kind == BlueprintKind.stateLanguage), hasLength(1));
      expect(all.every((b) => b.isActive && b.examYear == 2026), isTrue);
    });

    test('main test is 150 questions / 215 minutes in the official order', () {
      final main = all.firstWhere((b) => b.id == 'ort_main_2026');
      expect(main.totalQuestions, 150);
      expect(main.totalMinutes, 215);
      expect(main.sections.map((s) => s.id).toList(),
          ['math', 'verbal', 'reading', 'grammar']);
      expect(main.sections.map((s) => (s.questionCount, s.durationMinutes)).toList(),
          [(60, 90), (30, 30), (30, 60), (30, 35)]);
      expect(main.forwardOnlyAcrossSections, isTrue);
      expect(main.freeNavigationWithinSection, isTrue);
      expect(main.languages, ['ru', 'ky']);
      expect(main.rules.calculatorsAllowed, isFalse);
      expect(main.scoring.officialScaleKnown, isFalse);
      expect(main.scoring.disclaimer.resolve('ru'), contains('Не является официальным'));
      expect(main.scoring.disclaimer.resolve('ky'), isNotEmpty);
    });

    test('math section has comparison (4 fixed options) and problems (5 options)', () {
      final math = all.firstWhere((b) => b.id == 'ort_main_2026').sectionById('math')!;
      expect(math.allowScratchpad, isTrue);
      expect(math.parts, hasLength(2));
      final comparison = math.parts[0];
      expect(comparison.itemType, ExamItemType.quantitativeComparison);
      expect(comparison.questionCount, 30);
      expect(comparison.optionsPerQuestion, 4);
      expect(comparison.fixedOptions.map((o) => o.id).toList(), ['A', 'B', 'C', 'D']);
      expect(comparison.fixedOptions.first.text.resolve('ky'), contains('мамыча'));
      final problems = math.parts[1];
      expect(problems.itemType, ExamItemType.singleChoice);
      expect(problems.optionsPerQuestion, 5);
      expect(problems.fixedOptions, isEmpty);
      // Positional part mapping.
      expect(math.partForIndex(0).id, 'math_comparison');
      expect(math.partForIndex(29).id, 'math_comparison');
      expect(math.partForIndex(30).id, 'math_problems');
      expect(math.partForIndex(999).id, 'math_problems');
    });

    test('verbal parts are flagged as unverified assumptions; reading uses passages', () {
      final main = all.firstWhere((b) => b.id == 'ort_main_2026');
      final verbal = main.sectionById('verbal')!;
      expect(verbal.parts.map((p) => p.itemType).toList(),
          [ExamItemType.analogy, ExamItemType.completion]);
      expect(verbal.parts.every((p) => !p.verified), isTrue);
      expect(verbal.allowScratchpad, isFalse);
      final reading = main.sectionById('reading')!;
      expect(reading.usesPassages, isTrue);
      expect(reading.lineNumberingEvery, 5);
      expect(reading.parts.single.itemType, ExamItemType.textBased);
    });

    test('subject tests: one section each with the published size and time', () {
      final expected = {
        'chemistry': (40, 80),
        'biology': (40, 60),
        'physics': (40, 80),
        'math': (40, 80),
        'history': (40, 60),
        'english': (50, 60),
        'kyrgyz_lit': (40, 60),
        'russian_lit': (40, 60),
      };
      for (final e in expected.entries) {
        final bp = all.firstWhere((b) => b.subjectId == e.key && b.kind == BlueprintKind.subject);
        expect(bp.sections, hasLength(1), reason: bp.id);
        expect((bp.totalQuestions, bp.totalMinutes), e.value, reason: bp.id);
        expect(bp.optionsPerQuestion, 4, reason: bp.id);
      }
      expect(all.firstWhere((b) => b.subjectId == 'english').languages, ['en']);
      expect(all.firstWhere((b) => b.subjectId == 'kyrgyz_lit').languages, ['ky']);
      expect(all.firstWhere((b) => b.subjectId == 'russian_lit').languages, ['ru']);
    });

    test('state language test: 50 q / 60 min, Kyrgyz only, level-based scoring', () {
      final s = all.firstWhere((b) => b.id == 'ort_state_language_2026');
      expect((s.totalQuestions, s.totalMinutes), (50, 60));
      expect(s.languages, ['ky']);
      expect(s.scoring.isLevelBased, isTrue);
      expect(s.scoring.levelCutoffsKnown, isFalse);
      expect(s.scoring.levels.map((l) => l.level).toList(), [1, 2, 3, 4]);
      expect(s.languageFor('ru'), 'ky');
    });

    test('raw map is kept for offline persistence and re-parses identically', () {
      final main = all.firstWhere((b) => b.id == 'ort_main_2026');
      final again = ExamBlueprint.fromJson(jsonDecode(jsonEncode(main.raw)));
      expect(again.id, main.id);
      expect(again.totalQuestions, 150);
      expect(again.sections[0].parts[0].fixedOptions, hasLength(4));
    });
  });

  group('tolerant parsing', () {
    test('accepts a bare list and skips broken entries', () {
      final list = ExamBlueprint.listFromJson([
        {'id': 'x', 'sections': [
          {'id': 's1', 'order': 2, 'question_count': 5, 'duration_minutes': 10},
          {'id': 's0', 'order': 1, 'question_count': 3, 'duration_minutes': 5},
        ]},
        {'id': '', 'sections': []},
        'garbage',
      ]);
      expect(list, hasLength(1));
      final bp = list.single;
      expect(bp.sections.map((s) => s.id).toList(), ['s0', 's1']);
      // A section without parts gets a single implicit part.
      expect(bp.sections.first.parts.single.questionCount, 3);
      expect(bp.kind, BlueprintKind.unknown);
      expect(bp.languages, ['ru']);
      expect(bp.forwardOnlyAcrossSections, isTrue);
    });

    test('scratchpad falls back to rules.scratchpad_sections', () {
      final bp = ExamBlueprint.fromJson({
        'id': 'y',
        'rules': {'scratchpad_sections': ['a']},
        'sections': [
          {'id': 'a', 'question_count': 1, 'duration_minutes': 1},
          {'id': 'b', 'question_count': 1, 'duration_minutes': 1},
        ],
      });
      expect(bp.sectionById('a')!.allowScratchpad, isTrue);
      expect(bp.sectionById('b')!.allowScratchpad, isFalse);
    });
  });
}
