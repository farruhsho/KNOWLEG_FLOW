import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/content/topic_names.dart';
import 'package:knowledge_flow/features/gamification/presentation/pages/mistakes_page.dart';
import 'package:knowledge_flow/features/progress/presentation/pages/progress_page.dart';

/// UX-02: progress and mistakes pages show curriculum names, never raw
/// English slugs, to ru/ky students.
void main() {
  final names = TopicNames.fromJson(
      jsonDecode(File('assets/data/topic_names.json').readAsStringSync()) as Map<String, dynamic>);

  group('ProgressLabels', () {
    test('topics resolve to curriculum names in the UI language', () {
      final ru = ProgressLabels(lang: 'ru', names: names);
      final ky = ProgressLabels(lang: 'ky', names: names);
      expect(ru.topic('math.arithmetic'), 'Арифметика');
      expect(ky.topic('math.arithmetic.order_of_operations'), 'Амалдардын аткарылуу тартиби');
      // Unknown child → nearest known parent, not "Not in catalog".
      expect(ru.topic('math.arithmetic.not_in_catalog'), 'Арифметика');
      expect(ru.topic(null), '');
    });

    test('learning subject titles win; exam ids fall back to curriculum names', () {
      final l = ProgressLabels(
        lang: 'ru',
        names: names,
        subjectTitles: const {'russian': 'Русский язык'},
        sectionTitles: const {
          'math': {'ru': 'Математика', 'ky': 'Математика'},
        },
      );
      expect(l.subject('russian'), 'Русский язык');
      expect(l.subject('kyrgyz_lit'), 'Кыргызский язык и литература');
      expect(l.section('math'), 'Математика');
      expect(l.section('verbal'), 'Аналогии и дополнение предложений');
    });

    test('no label is ever a raw dotted or snake_case id', () {
      final l = ProgressLabels(lang: 'ky', names: names);
      for (final id in ['verbal', 'reading', 'grammar', 'state_language', 'math.fractions_percents']) {
        expect(l.topic(id), isNot(contains('_')), reason: id);
        expect(l.topic(id), isNot(contains('.')), reason: id);
        expect(l.section(id), isNot(contains('_')), reason: id);
      }
    });
  });

  group('mistakeSubjectLabel', () {
    test('exam section ids get curriculum names', () {
      expect(mistakeSubjectLabel('verbal', const {}, names, 'ky'), 'Аналогиялар жана сүйлөмдөрдү толуктоо');
      expect(mistakeSubjectLabel('reading', const {}, names, 'ru'), 'Чтение и понимание');
      expect(mistakeSubjectLabel('russian_lit', const {}, names, 'en'), 'Russian language and literature');
    });

    test('practice subjects keep their learning-subject title', () {
      expect(mistakeSubjectLabel('kyrgyz', const {'kyrgyz': 'Кыргыз тили'}, names, 'ky'), 'Кыргыз тили');
      expect(mistakeSubjectLabel('', const {}, names, 'ru'), '');
    });
  });
}
