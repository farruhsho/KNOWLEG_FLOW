import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/shared/models/question_model.dart';
import 'package:knowledge_flow/shared/services/question_pool.dart';

Map<String, dynamic> _doc({
  Map<String, dynamic> extra = const {},
  bool withKey = true,
}) =>
    {
      'subject_id': 'math',
      'section_id': 'math',
      'stem': {'ru': 'Сколько будет 2 + 2?', 'ky': '2 + 2 канча болот?'},
      'options': [
        {'id': 'A', 'text': {'ru': '3'}},
        {'id': 'B', 'text': {'ru': '4'}},
        {'id': 'C', 'text': {'ru': '5'}},
      ],
      if (withKey) 'correct_answer': 'B',
      'difficulty': 2,
      ...extra,
    };

void main() {
  group('QuestionModel parsing', () {
    test('reads snake_case and camelCase subject id', () {
      expect(QuestionModel.fromMap('q1', _doc()).subjectId, 'math');
      final camel = Map<String, dynamic>.from(_doc())
        ..remove('subject_id')
        ..['subjectId'] = 'physics';
      expect(QuestionModel.fromMap('q1', camel).subjectId, 'physics');
    });

    test('accepts every spelling of the answer key', () {
      for (final key in ['correct_answer', 'correctAnswer', 'correct']) {
        final m = Map<String, dynamic>.from(_doc(withKey: false))..[key] = 'B';
        final q = QuestionModel.fromMap('q', m);
        expect(q.correctAnswer, 'B', reason: key);
        expect(q.isGradable, isTrue, reason: key);
      }
    });

    test('derives the key from an is_correct option flag', () {
      final m = _doc(withKey: false, extra: {
        'options': [
          {'id': 'A', 'text': 'x', 'is_correct': false},
          {'id': 'B', 'text': 'y', 'isCorrect': true},
        ],
      });
      expect(QuestionModel.fromMap('q', m).correctAnswer, 'B');
    });

    test('missing answer key is NOT defaulted to A and is not gradable (FB-05)', () {
      final q = QuestionModel.fromMap('q', _doc(withKey: false));
      expect(q.correctAnswer, isEmpty);
      expect(q.isGradable, isFalse);
    });

    test('a key that matches no option is not gradable', () {
      final q = QuestionModel.fromMap('q', _doc(extra: {'correct_answer': 'E'}));
      expect(q.isGradable, isFalse);
    });

    test('difficulty is clamped to the 1–3 scale (EXAM-16)', () {
      expect(QuestionModel.fromMap('q', _doc(extra: {'difficulty': 5})).difficulty, 3);
      expect(QuestionModel.fromMap('q', _doc(extra: {'difficulty': 0})).difficulty, 1);
      expect(QuestionModel.fromMap('q', _doc(extra: {'difficulty': 2.0})).difficulty, 2);
    });

    test('plain-string stem and string options are accepted', () {
      final q = QuestionModel.fromMap('q', {
        'subject_id': 'math',
        'language': 'ky',
        'stem': 'Суроо',
        'options': ['бир', 'эки'],
        'correct_answer': 'A',
      });
      expect(q.getStem('ky'), 'Суроо');
      expect(q.options.map((o) => o.id), ['A', 'B']);
      expect(q.isGradable, isTrue);
    });

    test('content language: ky when available, ru fallback (EXAM-11)', () {
      final q = QuestionModel.fromMap('q', _doc());
      expect(q.getStem('ky'), '2 + 2 канча болот?');
      expect(q.getStem('ru'), 'Сколько будет 2 + 2?');
      expect(q.options[1].getText('ky'), '4'); // only ru present
      expect(q.getStem('en'), 'Сколько будет 2 + 2?');
    });

    test('legacy "kg" key is read as Kyrgyz', () {
      final q = QuestionModel.fromMap('q', _doc(extra: {
        'stem': {'ru': 'Вопрос', 'kg': 'Суроо'},
      }));
      expect(q.getStem('ky'), 'Суроо');
    });
  });

  group('QuestionType round trip (EXAM-13, CMS-18)', () {
    test('every type survives wireName and enum name parsing', () {
      for (final t in QuestionType.values) {
        expect(QuestionTypeX.parse(t.wireName), t, reason: t.wireName);
        expect(QuestionTypeX.parse(t.name), t, reason: t.name);
        expect(QuestionTypeX.parse('QuestionType.${t.name}'), t);
      }
    });

    test('legacy aliases', () {
      expect(QuestionTypeX.parse('mcq'), QuestionType.singleChoice);
      expect(QuestionTypeX.parse('tf'), QuestionType.trueFalse);
      expect(QuestionTypeX.parse('fill_blank'), QuestionType.completion);
      expect(QuestionTypeX.parse(null), QuestionType.singleChoice);
      expect(QuestionTypeX.parse('something-else'), QuestionType.singleChoice);
    });

    test('toFirestore writes snake_case and parses back to the same type', () {
      final q = QuestionModel.fromMap('q', _doc(extra: {'type': 'textBased'}));
      expect(q.type, QuestionType.textBased);
      final written = q.toFirestore();
      expect(written['type'], 'text_based');
      expect(QuestionModel.fromMap('q', {...written, 'created_at': null, 'updated_at': null}).type,
          QuestionType.textBased);
    });

    test('toJson/fromJson keeps the type', () {
      final q = QuestionModel.fromMap('q', _doc(extra: {'type': 'multiple_choice'}));
      expect(QuestionModel.fromJson(q.toJson()).type, QuestionType.multipleChoice);
    });
  });

  group('QuestionPool.isServable (FB-18, EXAM-12)', () {
    test('legacy documents without flags are servable', () {
      expect(QuestionPool.isServable(_doc()), isTrue);
    });
    test('inactive questions are skipped', () {
      expect(QuestionPool.isServable(_doc(extra: {'is_active': false})), isFalse);
      expect(QuestionPool.isServable(_doc(extra: {'isActive': false})), isFalse);
    });
    test('unverified AI drafts are skipped, verified ones served', () {
      expect(QuestionPool.isServable(_doc(extra: {'is_ai_generated': true, 'is_verified': false})), isFalse);
      expect(QuestionPool.isServable(_doc(extra: {'isAiGenerated': true})), isFalse);
      expect(QuestionPool.isServable(_doc(extra: {'is_ai_generated': true, 'is_verified': true})), isTrue);
    });
    test('draft / rejected review states are skipped', () {
      expect(QuestionPool.isServable(_doc(extra: {'review': {'status': 'draft'}})), isFalse);
      expect(QuestionPool.isServable(_doc(extra: {'review': {'status': 'rejected'}})), isFalse);
      expect(QuestionPool.isServable(_doc(extra: {'review': {'status': 'methodologist_approved'}})), isTrue);
    });
  });
}
