import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/handbook/data/handbook_data.dart';
import 'package:knowledge_flow/features/handbook/data/ort_structure.dart';
import 'package:knowledge_flow/features/progress/domain/recommendations.dart';
import 'package:knowledge_flow/l10n/app_localizations_ky.dart';
import 'package:knowledge_flow/l10n/app_localizations_ru.dart';
import 'package:knowledge_flow/shared/models/lesson_model.dart';
import 'package:knowledge_flow/shared/models/subject_model.dart';
import 'package:knowledge_flow/shared/models/user_progress_model.dart';
import 'package:knowledge_flow/shared/widgets/math_markdown.dart';

void main() {
  group('ORT structure comes from the blueprint asset (CMS-08)', () {
    final facts = OrtStructureFacts.parse(
      jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()),
    );

    test('main test sections match the verified 2026 blueprint', () {
      expect(
        facts.mainSections.map((s) => '${s.id}:${s.questions}/${s.minutes}').toList(),
        ['math:60/90', 'verbal:30/30', 'reading:30/60', 'grammar:30/35'],
      );
      expect(facts.mainQuestions, 150);
      expect(facts.mainMinutes, 215);
      expect(facts.officialMaxScore, 245);
      expect(facts.thresholdUniversity, 110);
      expect(facts.thresholdSubjectTests, 60);
      expect(facts.subjectTests, isNotEmpty);
    });

    test('generated markdown uses those numbers in ru and ky', () {
      final ru = facts.structureMarkdown(AppLocalizationsRu(), 'ru');
      expect(ru, contains('60'));
      expect(ru, contains('90 мин'));
      expect(ru, contains('150'));
      final ky = facts.scoringMarkdown(AppLocalizationsKy(), 'ky');
      expect(ky, contains('245'));
      expect(ky, contains('ЖРТнын расмий баллы эмес'));
    });

    test('the handbook no longer hard-codes structure facts', () {
      final guide = HandbookData.byId('ort_guide')!;
      final generated = guide.sections.where((s) => s.generated != null).map((s) => s.id);
      expect(generated, containsAll(['structure', 'scoring']));
      final allText = guide.sections.expand((s) => s.body.values).join('\n');
      expect(allText.contains('240-250'), isFalse);
      expect(allText.contains('30 вопросов, 90 минут'), isFalse);
    });

    test('non-grammar categories have Kyrgyz bodies (CMS-07)', () {
      for (final c in HandbookData.categories.where((c) => c.id != 'grammar')) {
        for (final s in c.sections.where((s) => s.generated == null)) {
          expect(s.body['ky'], isNotNull, reason: '${c.id}/${s.id}');
        }
      }
    });
  });

  group('Markdown parsing (CMS-27)', () {
    test('blocks', () {
      final blocks = MarkdownBlock.parse('# Title\n\nText **bold** \$x^2\$\n- item\n1. first\n\$\$\na+b\n\$\$\n> quote');
      expect(blocks.map((b) => b.kind).toList(), [
        BlockKind.heading,
        BlockKind.paragraph,
        BlockKind.bullet,
        BlockKind.numbered,
        BlockKind.math,
        BlockKind.quote,
      ]);
      expect(blocks[4].text, 'a+b');
    });
    test('bold markers are not mistaken for bullets', () {
      expect(MarkdownBlock.parse('**Bold:** text').single.kind, BlockKind.paragraph);
    });
  });

  group('Tolerant subject / lesson parsing (CMS-21)', () {
    test('subject without description, icon or color does not throw', () {
      final s = SubjectModel.fromFirestore({'name': {'ru': 'Математика'}, 'order': 1.0}, id: 'math');
      expect(s.id, 'math');
      expect(s.getTitle('ky'), 'Математика');
      expect(s.icon, '');
      expect(s.order, 1);
    });

    test('legacy lesson with camelCase subjectId and ISO date', () {
      final l = LessonModel.fromFirestore({
        'subjectId': 'math',
        'title': {'ru': 'Урок', 'ky': 'Сабак'},
        'content': {'ru': 'Текст'},
        'estimatedTime': 30,
        'createdAt': '2024-01-01T00:00:00Z',
      }, id: 'daily');
      expect(l.id, 'daily');
      expect(l.subjectId, 'math');
      expect(l.getTitle('ky'), 'Сабак');
      expect(l.estimatedTimeMinutes, 30);
      expect(l.hasStructuredContent, isFalse);
    });

    test('structured lesson in per-language list form', () {
      final l = LessonModel.fromFirestore({
        'subject_id': 'math',
        'title': 'Квадратные уравнения',
        'summary': {'ru': 'Кратко', 'ky': 'Кыскача'},
        'sections': {
          'ru': [
            {'title': 'Определение', 'body': 'Текст'}
          ],
          'ky': [
            {'title': 'Аныктама', 'body': 'Текст ky'}
          ],
        },
        'formulas': [r'x = \frac{-b}{2a}', {'latex': 'D = b^2 - 4ac', 'title': {'ru': 'Дискриминант'}}],
        'examples': [
          {'problem': {'ru': 'Решите'}, 'solution': {'ru': 'Ответ'}}
        ],
        'common_mistakes': ['Знак'],
        'practice_question_ids': ['q1', 'q2'],
      }, id: 'l1');
      expect(l.hasStructuredContent, isTrue);
      expect(l.sections.single.title['ky'], 'Аныктама');
      expect(l.formulas.length, 2);
      expect(l.examples.single.solution['ru'], 'Ответ');
      expect(l.commonMistakes.single['ru'], 'Знак');
      expect(l.practiceQuestionIds, ['q1', 'q2']);
    });
  });

  group('Recommendations are evidence based (GAM-08)', () {
    test('weak subject is explained with its real accuracy', () {
      final p = UserProgressModel.empty('u').copyWith();
      final progress = UserProgressModel(
        userId: 'u',
        testsCompleted: 0,
        averageScore: 0,
        streakDays: 0,
        totalStudyHours: 0,
        subjectProgress: const {},
        completedLessons: const [],
        practiceAnswered: 40,
        practiceCorrect: 25,
        practiceBySubject: const {
          'math': PracticeTally(answered: 20, correct: 8),
          'physics': PracticeTally(answered: 20, correct: 17),
        },
      );
      expect(p.practiceAnswered, 0);
      final recs = RecommendationEngine.build(progress: progress, attempts: const [], dueMistakes: 3);
      expect(recs.first.kind, RecommendationKind.dueMistakes);
      final weak = recs.firstWhere((r) => r.kind == RecommendationKind.weakSubject);
      expect(weak.refId, 'math');
      expect(weak.percent, 40);
      expect(recs.any((r) => r.kind == RecommendationKind.noExam), isTrue);
      expect(recs.any((r) => r.kind == RecommendationKind.moreData), isFalse);
    });

    test('no data -> only honest "get more data" style advice', () {
      final recs = RecommendationEngine.build(progress: null, attempts: const [], dueMistakes: 0);
      expect(recs.map((r) => r.kind), [RecommendationKind.noExam, RecommendationKind.moreData]);
    });
  });
}
