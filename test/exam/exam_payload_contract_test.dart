import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_question.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';

/// Shapes below are copied from what functions/src sends (payload.ts
/// toClientQuestion, exam.ts examGetReview, scoring.ts buildExamResult) and
/// what Firestore stores, so a field-name mismatch fails here instead of
/// silently hiding content in the app.
void main() {
  group('QuestionTable (EXAM-02, contract D2)', () {
    test('wire shape: rows as lists', () {
      final t = QuestionTable.fromJson({
        'headers': ['Колонка А', 'Колонка Б'],
        'rows': [
          ['2^{10}', '1000'],
        ],
      })!;
      expect(t.headers, ['Колонка А', 'Колонка Б']);
      expect(t.rows, [
        ['2^{10}', '1000'],
      ]);
    });

    test('Firestore storage shape: rows as {cells: [...]}', () {
      final t = QuestionTable.fromJson({
        'headers': ['A', 'B'],
        'rows': [
          {
            'cells': ['1', '2'],
          },
          {
            'cells': [3, 4.5],
          },
        ],
      })!;
      expect(t.rows, [
        ['1', '2'],
        ['3', '4.5'],
      ]);
    });

    test('mixed and index-keyed rows are tolerated', () {
      final t = QuestionTable.fromJson({
        'headers': <String>[],
        'rows': {
          '1': {'1': 'd', '0': 'c'},
          '0': ['a', 'b'],
        },
      })!;
      expect(t.rows, [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });

    test('empty or missing table is null; toJson writes the wire shape', () {
      expect(QuestionTable.fromJson(null), isNull);
      expect(QuestionTable.fromJson(const {'headers': [], 'rows': []}), isNull);
      final t = QuestionTable.fromJson({
        'headers': ['x'],
        'rows': [
          {
            'cells': ['1'],
          },
        ],
      })!;
      expect(t.toJson(), {
        'headers': ['x'],
        'rows': [
          ['1'],
        ],
      });
      // The Hive copy (wire shape) parses back to the same table.
      expect(QuestionTable.fromJson(t.toJson())!.rows, t.rows);
    });

    test('a question carries the stored table through ExamQuestion.fromJson', () {
      final q = ExamQuestion.fromJson({
        'id': 'q1',
        'stem': 'Сравните',
        'options': const [],
        'table': {
          'headers': ['А', 'Б'],
          'rows': [
            {
              'cells': ['x', 'y'],
            },
          ],
        },
      });
      expect(q.table!.rows.single, ['x', 'y']);
    });
  });

  group('question images (EXAM-03 / CP-02, contract D3)', () {
    test('runner: Storage path in imagePath (toClientQuestion output)', () {
      final q = ExamQuestion.fromJson({
        'id': 'q_x',
        'stem': '',
        'options': [
          {'id': 'A', 'text': '1'},
        ],
        'passageId': null,
        'imageUrl': null,
        'imagePath': 'exam_media/q_x/fig.png',
        'table': null,
        'topicId': 'math.plane_geometry',
      });
      expect(q.imageUrl, 'exam_media/q_x/fig.png');
    });

    test('an https imageUrl wins; snake_case and blank values handled', () {
      expect(
          ExamQuestion.fromJson({
            'id': 'q',
            'imageUrl': 'https://cdn.example/a.png',
            'imagePath': null,
          }).imageUrl,
          'https://cdn.example/a.png');
      expect(ExamQuestion.fromJson({'id': 'q', 'image_url': 'https://x/y.png'}).imageUrl,
          'https://x/y.png');
      expect(ExamQuestion.fromJson({'id': 'q', 'image_path': 'exam_media/q/a.png'}).imageUrl,
          'exam_media/q/a.png');
      expect(
          ExamQuestion.fromJson({'id': 'q', 'imageUrl': '  ', 'imagePath': 'exam_media/q/b.png'})
              .imageUrl,
          'exam_media/q/b.png');
      expect(ExamQuestion.fromJson({'id': 'q'}).imageUrl, isNull);
    });

    test('the Hive copy keeps the reference', () {
      final q = ExamQuestion.fromJson({'id': 'q', 'imagePath': 'exam_media/q/c.png'});
      expect(ExamQuestion.fromJson(q.toJson()).imageUrl, 'exam_media/q/c.png');
    });
  });

  group('review item (examGetReview output)', () {
    final serverItem = <String, dynamic>{
      'questionId': 'q_qc1',
      'sectionId': 'math',
      'partId': 'math_comparison',
      'type': 'quantitative_comparison',
      'stem': 'x > 0',
      'options': [
        {'id': 'A', 'text': 'А больше'},
      ],
      'columnA': r'$x^2$',
      'columnB': r'$2x$',
      'imagePath': 'exam_media/q_qc1/graph.png',
      'table': {
        'headers': ['x', 'y'],
        'rows': [
          ['1', '2'],
        ],
      },
      'passage': null,
      'userAnswer': 'A',
      'correct': 'D',
      'isCorrect': false,
      'explanation': 'Зависит от x.',
      'wrongOptionNotes': <String, dynamic>{},
      'solutionSteps': <String>[],
      'topicId': 'math.inequalities',
    };

    test('image (CP-02) and comparison columns (CP-08) are parsed', () {
      final item = ReviewItem.fromJson(serverItem);
      expect(item.imageUrl, 'exam_media/q_qc1/graph.png');
      expect(item.columnA, r'$x^2$');
      expect(item.columnB, r'$2x$');
      expect(item.hasComparisonColumns, isTrue);
      expect(item.partId, 'math_comparison');
      expect(item.table!.rows.single, ['1', '2']);
      expect(item.isWrong, isTrue);
    });

    test('snake_case and columns-map spellings', () {
      final item = ReviewItem.fromJson({
        'question_id': 'q',
        'section_id': 'math',
        'column_a': '1',
        'columns': {'b': '2'},
        'image_path': 'exam_media/q/a.png',
      });
      expect(item.columnA, '1');
      expect(item.columnB, '2');
      expect(item.imageUrl, 'exam_media/q/a.png');
      final plain = ReviewItem.fromJson({'questionId': 'q', 'stem': 's'});
      expect(plain.hasComparisonColumns, isFalse);
      expect(plain.imageUrl, isNull);
    });
  });

  group('ExamResult wrong / skipped counts (EXAM-05, contract D4)', () {
    test('server incorrect / skipped are used', () {
      final r = ExamResult.fromJson({
        'correct': 97,
        'total': 150,
        'percent': 64.7,
        'answered': 140,
        'incorrect': 43,
        'skipped': 10,
      });
      expect(r.incorrectCount, 43);
      expect(r.skippedCount, 10);
      expect(ExamResult.fromJson(r.toJson()).skippedCount, 10);
    });

    test('older results: derived from answered (total - correct - answeredWrong)', () {
      final r = ExamResult.fromJson({
        'correct': 97,
        'total': 150,
        'percent': 64.7,
        'answered': 140,
      });
      expect(r.incorrect, isNull);
      expect(r.incorrectCount, 43);
      expect(r.skippedCount, 10);
      // Survives the local Hive round trip.
      expect(ExamResult.fromJson(r.toJson()).skippedCount, 10);
    });

    test('derived counts stay within range', () {
      final r = ExamResult.fromJson({'correct': 5, 'total': 10, 'answered': 30});
      expect(r.incorrectCount, 5);
      expect(r.skippedCount, 0);
      final onlySkipped = ExamResult.fromJson({'correct': 5, 'total': 10, 'skipped': 3});
      expect(onlySkipped.incorrectCount, 2);
      expect(ExamResult.fromJson({'correct': 5, 'total': 10}).skippedCount, isNull);
    });

    test('ExamResultData prefers server counts over local records', () {
      final data = ExamResultData(
        attemptId: 'a',
        result: ExamResult.fromJson(
            {'correct': 3, 'total': 5, 'incorrect': 1, 'skipped': 1}),
        blueprint: null,
        attempt: null,
        localRecords: const {},
      );
      expect(data.incorrect, 1);
      expect(data.skipped, 1);

      // Opened on another device, older result: still shown.
      final older = ExamResultData(
        attemptId: 'a',
        result: ExamResult.fromJson({'correct': 3, 'total': 5, 'answered': 4}),
        blueprint: null,
        attempt: null,
        localRecords: const {},
      );
      expect(older.incorrect, 1);
      expect(older.skipped, 1);

      // Nothing known: hidden (the page shows "wrong or skipped").
      final unknown = ExamResultData(
        attemptId: 'a',
        result: ExamResult.fromJson({'correct': 3, 'total': 5}),
        blueprint: null,
        attempt: null,
        localRecords: const {},
      );
      expect(unknown.skipped, isNull);
      expect(unknown.incorrect, isNull);
    });
  });
}
