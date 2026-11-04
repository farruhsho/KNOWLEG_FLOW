import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/data/json_safe.dart';
import 'package:knowledge_flow/features/admin/data/models/subject_doc.dart';
import 'package:knowledge_flow/features/admin/domain/exam_question.dart';
import 'package:knowledge_flow/features/admin/domain/lesson_doc.dart';
import 'package:knowledge_flow/features/admin/domain/localized_text.dart';
import 'package:knowledge_flow/features/admin/domain/pricing_config.dart';
import 'package:knowledge_flow/features/admin/domain/review_workflow.dart';
import 'package:knowledge_flow/features/admin/presentation/widgets/math_markdown.dart';
import 'package:knowledge_flow/shared/models/lesson_model.dart';
import 'package:knowledge_flow/shared/models/subject_model.dart';

ExamQuestionDoc _q({List<ExamOption>? options, String stem = r'Найдите $x$', String? passage}) =>
    ExamQuestionDoc(
      id: 'q1',
      subjectId: 'math',
      sectionId: 'math',
      partId: 'math_problems',
      topicId: 'math.quadratic_equations',
      language: 'ru',
      stem: stem,
      options: options ??
          const [
            ExamOption('A', '1'),
            ExamOption('B', '2'),
            ExamOption('C', '3'),
            ExamOption('D', '4'),
            ExamOption('E', '5'),
          ],
      passageId: passage,
    );

void main() {
  group('localized text (CMS-12, FB-31)', () {
    test('kg is read as ky; explicit ky wins', () {
      expect(readLocalized({'ru': 'а', 'kg': 'б'}), {'ru': 'а', 'ky': 'б'});
      expect(readLocalized({'ky': 'в', 'kg': 'б'}), {'ky': 'в'});
      expect(readLocalized('строка'), {'ru': 'строка'});
      expect(readLocalized(null), isEmpty);
    });

    test('merge keeps untouched translations and removes emptied ones', () {
      final merged = mergeLocalized({'ru': 'Старое', 'ky': 'Эски', 'en': 'Old'}, {'ru': 'Новое', 'ky': ''});
      expect(merged, {'ru': 'Новое', 'en': 'Old'});
    });
  });

  group('exam question', () {
    test('valid question passes; option count follows the blueprint part', () {
      const key = ExamKeyDoc(correct: 'B');
      expect(validateExamQuestion(_q(), key, expectedOptions: 5), isEmpty);
      expect(validateExamQuestion(_q(), key, expectedOptions: 4), [ExamQuestionIssue.optionsCount]);
    });

    test('missing key, wrong key, duplicates, empty option, passage', () {
      expect(validateExamQuestion(_q(), const ExamKeyDoc()), [ExamQuestionIssue.correctRequired]);
      expect(validateExamQuestion(_q(), const ExamKeyDoc(correct: 'Z')),
          [ExamQuestionIssue.correctNotInOptions]);
      final dup = _q(options: const [ExamOption('A', '1'), ExamOption('A', '')]);
      expect(validateExamQuestion(dup, const ExamKeyDoc(correct: 'A')),
          containsAll([ExamQuestionIssue.optionDuplicate, ExamQuestionIssue.optionEmpty]));
      expect(validateExamQuestion(_q(), const ExamKeyDoc(correct: 'A'), needsPassage: true),
          [ExamQuestionIssue.passageRequired]);
      expect(validateExamQuestion(_q(passage: 'p1'), const ExamKeyDoc(correct: 'A'), needsPassage: true),
          isEmpty);
    });

    test('content hash is stable and depends on the key', () {
      final a = computeContentHash(_q(), 'A');
      expect(a, startsWith('sha256:'));
      expect(computeContentHash(_q(), 'A'), a);
      expect(computeContentHash(_q(), 'B'), isNot(a));
      expect(computeContentHash(_q(stem: 'Другой'), 'A'), isNot(a));
    });

    test('tolerant reader: camelCase, kg language, Timestamp-like dates', () {
      final q = ExamQuestionDoc.fromMap('id1', {
        'subjectId': 'history',
        'sectionId': 'history',
        'topicId': 'history.medieval',
        'language': 'kg',
        'stem': 'Текст',
        'options': ['a', 'b'],
        'review': {'status': 'methodologist_approved', 'reviewed_at': _FakeTimestamp(DateTime(2026, 5, 1))},
      });
      expect(q.language, 'ky');
      expect(q.options.map((o) => o.id), ['A', 'B']);
      expect(q.review.status, ReviewStatus.methodologistApproved);
      expect(q.review.reviewedAt, DateTime(2026, 5, 1));
    });

    test('key reader accepts snake and camel case', () {
      final k = ExamKeyDoc.fromMap({
        'correctAnswer': 'c',
        'wrongOptionNotes': {'a': 'нет', 'b': ''},
        'solution_steps': ['1', ' ', '2'],
      });
      expect(k.correct, 'C');
      expect(k.wrongOptionNotes, {'A': 'нет'});
      expect(k.solutionSteps, ['1', '2']);
    });

    test('AI drafts are always saved as draft with source ai', () {
      final d = parseAiDraft(
        {
          'stem': r'Сумма корней $x^2-5x+6=0$?',
          'options': [
            {'id': 'A', 'text': '5'},
            {'id': 'B', 'text': '6'},
            {'id': 'C', 'text': '-5'},
            {'id': 'D', 'text': '1'},
          ],
          'review': {'status': 'methodologist_approved'},
          'key': {'correct': 'a', 'explanation': 'Виет'},
        },
        id: 'new1',
        subjectId: 'math',
        sectionId: 'math',
        partId: 'math_problems',
        topicId: 'math.quadratic_equations',
        difficulty: 2,
        language: 'ru',
        type: 'single_choice',
      );
      expect(d.question.review.status, ReviewStatus.draft);
      expect(d.question.source.kind, 'ai');
      expect(d.question.subjectId, 'math');
      expect(d.question.partId, 'math_problems');
      expect(d.question.difficulty, 2);
      expect(d.key.correct, 'A');
      expect(d.key.explanation, 'Виет');
    });
  });

  group('lessons (CMS-05/12/13, FB-21)', () {
    test('legacy lesson body becomes a section; save keeps the student model readable', () {
      final legacy = LessonDoc.fromMap('l1', {
        'id': 'l1',
        'subjectId': 'math',
        'title': {'ru': 'Дроби', 'en': 'Fractions'},
        'content': {'ru': 'Старый текст', 'en': 'Old text'},
        'order': 3,
        'createdAt': '2025-09-01T00:00:00.000Z',
        'createdBy': 'seed',
        'mediaUrls': ['https://a/b.png'],
      });
      expect(legacy.sections.single.body, {'ru': 'Старый текст', 'en': 'Old text'});

      final edited = legacy.copyWith(
        title: mergeLocalized(legacy.title, {'ru': 'Дроби', 'ky': 'Бөлчөктөр'}),
        summary: {'ru': 'Кратко'},
      );
      final written = edited.toWrite(actor: 'admin1');
      expect(written['title'], {'ru': 'Дроби', 'en': 'Fractions', 'ky': 'Бөлчөктөр'});
      expect(written['content'], {'ru': 'Кратко\n\nСтарый текст', 'en': 'Old text'});
      expect(written['createdAt'], '2025-09-01T00:00:00.000Z');
      expect(written['createdBy'], 'seed');
      expect(written['mediaUrls'], ['https://a/b.png']);

      // The current student LessonModel casts strictly — it must accept it.
      final student = LessonModel.fromFirestore(Map<String, dynamic>.from(written));
      expect(student.id, 'l1');
      expect(student.subjectId, 'math');
      expect(student.order, 3);
      expect(student.getContent('ru'), contains('Старый текст'));
    });

    test('new lesson writes structured fields and an ISO createdAt', () {
      const doc = LessonDoc(
        id: 'new1',
        subjectId: 'physics',
        title: {'ru': 'Кинематика', 'ky': 'Кинематика'},
        sections: [
          LessonSection(title: {'ru': 'Скорость'}, body: {'ru': r'$v = s/t$', 'ky': r'$v = s/t$'}),
        ],
        formulas: [LessonFormula(latex: r'v = \frac{s}{t}')],
        commonMistakes: [
          {'ru': 'Путают путь и перемещение'},
        ],
        practiceQuestionIds: ['q1', 'q2'],
      );
      expect(doc.validate(), isEmpty);
      final w = doc.toWrite(actor: 'u', now: DateTime.utc(2026, 11, 4));
      expect(w['createdAt'], '2026-11-04T00:00:00.000Z');
      expect(w['createdBy'], 'u');
      expect(w['content'], {'ru': '## Скорость\n\n\$v = s/t\$', 'ky': '\$v = s/t\$'});
      expect(w['practice_question_ids'], ['q1', 'q2']);
      expect((w['formulas'] as List).single, {'latex': r'v = \frac{s}{t}', 'caption': <String, String>{}});
      final student = LessonModel.fromFirestore(Map<String, dynamic>.from(w));
      expect(student.title['ky'], 'Кинематика');
    });

    test('validation', () {
      const empty = LessonDoc(id: 'x', subjectId: '');
      expect(empty.validate(),
          containsAll([LessonIssue.subjectRequired, LessonIssue.titleRequired, LessonIssue.contentRequired]));
      const badUrl = LessonDoc(
        id: 'x',
        subjectId: 'm',
        title: {'ru': 't'},
        summary: {'ru': 's'},
        videoUrl: 'javascript:alert(1)',
      );
      expect(badUrl.validate(), [LessonIssue.urlInvalid]);
    });
  });

  group('subjects (CMS-06/21)', () {
    test('every write is readable by the student SubjectModel', () {
      final legacy = SubjectDoc.fromMap('chemistry', {
        'name': {'ru': 'Химия', 'kg': 'Химия'},
        'is_active': true,
        'total_lessons': 4,
      });
      expect(legacy.title, {'ru': 'Химия', 'ky': 'Химия'});
      final written = legacy.toWrite(isNew: false)..remove('updated_at');
      final student = SubjectModel.fromFirestore(Map<String, dynamic>.from(written));
      expect(student.id, 'chemistry');
      expect(student.getTitle('ky'), 'Химия');
      expect(student.totalLessons, 4);
      expect(student.icon, isNotEmpty);
    });

    test('id pattern', () {
      expect(SubjectDoc.idPattern.hasMatch('kyrgyz_lit'), isTrue);
      expect(SubjectDoc.idPattern.hasMatch('Math'), isFalse);
      expect(SubjectDoc.idPattern.hasMatch('m'), isFalse);
      expect(SubjectDoc.idPattern.hasMatch('1math'), isFalse);
    });
  });

  group('pricing', () {
    test('defaults and validation mirror the server rules', () {
      expect(PricingConfig.defaults.products, {'exam_single': 1, 'exam_pack_5': 5, 'exam_pack_10': 10});
      expect(PricingConfig.defaults.validate(), isEmpty);
      final bad = PricingConfig.fromMap({
        'products': {'exam_single': 2, 'exam_pack_5': 0, 'gift': 3},
        'free_exams_per_user': 20,
      });
      expect(bad.validate(), containsAll([
        PricingIssue.singleMustBeOne,
        PricingIssue.creditsRange,
        PricingIssue.unknownProduct,
        PricingIssue.freeRange,
      ]));
      final nested = PricingConfig.fromMap({
        'products': {'exam_pack_10': {'credits': 12}},
        'freeExamsPerUser': 1,
      });
      expect(nested.products['exam_pack_10'], 12);
      expect(nested.validate(), isEmpty);
    });
  });

  test('jsonSafe converts dates (CMS-17)', () {
    final out = jsonSafe({
      'a': DateTime.utc(2026, 1, 2),
      'b': [1, 'x', null],
      'c': {'d': true},
    });
    expect(out, {
      'a': '2026-01-02T00:00:00.000Z',
      'b': [1, 'x', null],
      'c': {'d': true},
    });
  });

  group('math markdown parser', () {
    test('inline, display, bold and escaped dollars', () {
      expect(parseMathMarkdown(r'Найти $x^2$ и **жирно** $$\int f$$ цена \$5'), const [
        MdSeg(MdSegKind.text, 'Найти '),
        MdSeg(MdSegKind.inlineMath, 'x^2'),
        MdSeg(MdSegKind.text, ' и '),
        MdSeg(MdSegKind.bold, 'жирно'),
        MdSeg(MdSegKind.text, ' '),
        MdSeg(MdSegKind.displayMath, r'\int f'),
        MdSeg(MdSegKind.text, r' цена $5'),
      ]);
    });

    test('unclosed delimiters stay literal', () {
      expect(parseMathMarkdown(r'цена $5 и **не'), const [MdSeg(MdSegKind.text, r'цена $5 и **не')]);
    });
  });
}

class _FakeTimestamp {
  _FakeTimestamp(this._d);
  final DateTime _d;
  DateTime toDate() => _d;
}
