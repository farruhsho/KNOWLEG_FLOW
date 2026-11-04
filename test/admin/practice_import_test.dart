import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/admin/domain/practice_question_codec.dart';

void main() {
  group('CSV import parsing', () {
    test('canonical header, comma separated', () {
      const csv = 'subject_id,type,difficulty,stem_ru,stem_ky,option_a_ru,option_b_ru,option_c_ru,correct_answer\n'
          'math,single_choice,2,Сколько будет 2+2?,2+2 канча болот?,3,4,5,B\n';
      final r = parsePracticeCsv(csv);
      expect(r.issues, isEmpty);
      expect(r.totalRows, 1);
      final q = r.valid.single;
      expect(q.subjectId, 'math');
      expect(q.type, 'single_choice');
      expect(q.difficulty, 2);
      expect(q.stem, {'ru': 'Сколько будет 2+2?', 'ky': '2+2 канча болот?'});
      expect(q.options.map((o) => o.id), ['A', 'B', 'C']);
      expect(q.correctAnswer, 'B');
    });

    test('Excel style: BOM, semicolons, CRLF, quoted multi-line cell, aliases', () {
      const csv = '﻿Subject;Question;A;B;C;D;Answer;Explanation_kg\r\n'
          'physics;"Тело падает\r\nс высоты \$h\$";1;2;3;4;c;Түшүндүрмө\r\n';
      final r = parsePracticeCsv(csv);
      expect(r.issues, isEmpty, reason: r.issues.toString());
      final q = r.valid.single;
      expect(q.subjectId, 'physics');
      expect(q.stem['ru'], 'Тело падает\nс высоты \$h\$');
      expect(q.options.length, 4);
      expect(q.correctAnswer, 'C');
      // FB-31: legacy `kg` columns are read as `ky`.
      expect(q.explanation, {'ky': 'Түшүндүрмө'});
    });

    test('tab separated and type normalisation', () {
      const csv = 'subject_id\ttype\tstem_ru\toption_a_ru\toption_b_ru\tcorrect_answers\n'
          'chemistry\tmultipleChoice\tВыберите металлы\tNa\tCl\tA\n';
      final q = parsePracticeCsv(csv).valid.single;
      expect(q.type, 'multiple_choice');
      expect(q.correctAnswers, ['A']);
    });

    test('invalid rows are reported with 1-based row numbers and skipped', () {
      const csv = 'subject_id,stem_ru,option_a_ru,option_b_ru,correct_answer,difficulty\n'
          'math,ok,1,2,A,1\n'
          ',no subject,1,2,A,1\n'
          'math,,1,2,A,1\n'
          'math,one option,1,,A,1\n'
          'math,bad key,1,2,E,1\n'
          'math,bad difficulty,1,2,A,7\n';
      final r = parsePracticeCsv(csv);
      expect(r.totalRows, 6);
      expect(r.valid.length, 1);
      expect(r.invalidRows, 5);
      final byRow = <int, Set<String>>{};
      for (final i in r.issues) {
        byRow.putIfAbsent(i.row, () => {}).add(i.code);
      }
      expect(byRow[2], {PracticeIssue.subjectRequired});
      expect(byRow[3], {PracticeIssue.stemRequired});
      expect(byRow[4], contains(PracticeIssue.optionsMin));
      expect(byRow[5], {PracticeIssue.correctNotInOptions});
      expect(byRow[6], {PracticeIssue.difficultyRange});
    });

    test('unknown type is rejected instead of silently becoming single_choice', () {
      const csv = 'subject_id,type,stem_ru,option_a_ru,option_b_ru,correct_answer\n'
          'math,essay,text,1,2,A\n';
      final r = parsePracticeCsv(csv);
      expect(r.valid, isEmpty);
      expect(r.issues.single.code, PracticeIssue.typeUnknown);
    });

    test('duplicate ids inside one file', () {
      const csv = 'id,subject_id,stem_ru,option_a_ru,option_b_ru,correct_answer\n'
          'q1,math,a,1,2,A\n'
          'q1,math,b,1,2,B\n';
      final r = parsePracticeCsv(csv);
      expect(r.valid.length, 1);
      expect(r.issues.single, isA<ImportIssue>().having((i) => i.row, 'row', 2));
    });

    test('empty and header-only files', () {
      expect(parsePracticeCsv('').issues.single.code, PracticeIssue.emptyFile);
      expect(parsePracticeCsv('subject_id,stem_ru\n').issues.single.code, PracticeIssue.emptyFile);
    });

    test('export → import round trip keeps every field', () {
      const original = PracticeQuestionDraft(
        id: 'abc',
        subjectId: 'math',
        sectionId: 'math2',
        topicId: 'math.fractions',
        type: 'multiple_choice',
        difficulty: 3,
        points: 2,
        stem: {'ru': 'Дроби, "кавычки", запятые', 'ky': 'Бөлчөктөр\nэки сап'},
        options: [
          PracticeOption('A', {'ru': '1/2'}),
          PracticeOption('B', {'ru': '2/4', 'ky': '2/4'}),
          PracticeOption('C', {'ru': '3/4'}),
        ],
        correctAnswer: 'A',
        correctAnswers: ['A', 'B'],
        explanation: {'ru': r'$\frac12 = \frac24$'},
        tags: ['fractions', 'easy'],
        isActive: false,
        imageUrl: 'https://example.com/a.png',
      );
      final csv = practiceQuestionsToCsv([original]);
      final back = parsePracticeCsv(csv).valid.single;
      expect(back.id, 'abc');
      expect(back.subjectId, 'math');
      expect(back.sectionId, 'math2');
      expect(back.topicId, 'math.fractions');
      expect(back.type, 'multiple_choice');
      expect(back.difficulty, 3);
      expect(back.points, 2);
      expect(back.stem, original.stem);
      expect(back.options.map((o) => o.text), original.options.map((o) => o.text));
      expect(back.correctAnswers, ['A', 'B']);
      expect(back.explanation, original.explanation);
      expect(back.tags, ['fractions', 'easy']);
      expect(back.isActive, isFalse);
      expect(back.imageUrl, 'https://example.com/a.png');
    });
  });

  group('JSON import', () {
    test('export shape with Firestore snake_case and per-option is_correct', () {
      final json = jsonEncode([
        {
          'id': 'x1',
          'subject_id': 'biology',
          'type': 'single_choice',
          'stem': {'ru': 'Клетка', 'kg': 'Клетка'},
          'options': [
            {'id': 'A', 'text': {'ru': 'да'}, 'is_correct': false},
            {'id': 'B', 'text': {'ru': 'нет'}, 'is_correct': true},
          ],
          'created_at': '2026-01-01T00:00:00.000Z',
        },
        {'subjectId': 'biology', 'question': 'camelCase', 'options': ['a', 'b'], 'correctAnswer': 'a'},
        'not an object',
      ]);
      final r = parsePracticeJson(json);
      expect(r.totalRows, 3);
      expect(r.valid.length, 2);
      expect(r.valid[0].correctAnswer, 'B');
      expect(r.valid[0].stem, {'ru': 'Клетка', 'ky': 'Клетка'});
      expect(r.valid[1].correctAnswer, 'A');
      expect(r.issues.single.row, 3);
      expect(r.issues.single.code, PracticeIssue.parseError);
    });

    test('broken JSON', () {
      expect(parsePracticeJson('{').issues.single.code, PracticeIssue.parseError);
      expect(parsePracticeJson('[]').issues.single.code, PracticeIssue.emptyFile);
    });
  });

  group('canonical writer (FB-13 / CMS-18)', () {
    test('type wire values are snake_case and read back the same', () {
      for (final raw in ['multipleChoice', 'QuestionType.trueFalse', 'text_based', 'fill_blank', 'mcq']) {
        final d = PracticeQuestionDraft.fromMap({
          'subject_id': 'm',
          'type': raw,
          'stem': {'ru': 's'},
          'options': [
            {'id': 'A', 'text': {'ru': '1'}},
            {'id': 'B', 'text': {'ru': '2'}},
          ],
          'correct_answer': 'A',
        });
        final written = d.toFirestoreFields();
        expect(kPracticeQuestionTypes, contains(written['type']), reason: raw);
        expect(PracticeQuestionDraft.fromMap(written).type, written['type']);
      }
    });

    test('writes both subject_id and the subjectId mirror the student app filters on', () {
      final f = PracticeQuestionDraft.fromMap({
        'subjectId': 'history',
        'stem': {'ru': 's'},
        'options': ['a', 'b'],
        'correct_answer': 'A',
      }).toFirestoreFields();
      expect(f['subject_id'], 'history');
      expect(f['subjectId'], 'history');
    });
  });

  test('chunked: a fresh batch per 400 documents (FB-16)', () {
    final items = List.generate(1001, (i) => i);
    final chunks = chunked(items, 400);
    expect(chunks.map((c) => c.length), [400, 400, 201]);
    expect(chunks.expand((c) => c).toList(), items);
    expect(chunked(<int>[], 400), isEmpty);
    expect(() => chunked(items, 0), throwsArgumentError);
  });
}
