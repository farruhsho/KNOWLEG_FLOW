import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/content/topic_names.dart';
import 'package:knowledge_flow/features/exam/domain/exam_blueprint.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/localized_text.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_result_page.dart';
import 'package:knowledge_flow/features/exam/presentation/pages/exam_review_page.dart';
import 'package:knowledge_flow/features/exam/presentation/widgets/exam_labels.dart';
import 'package:knowledge_flow/l10n/app_localizations_ru.dart';

/// The real bundled catalog (assets/data/topic_names.json).
TopicNames _assetNames() => TopicNames.fromJson(
    jsonDecode(File('assets/data/topic_names.json').readAsStringSync())
        as Map<String, dynamic>);

ExamBlueprint _blueprint(String id) => ExamBlueprint.listFromJson(
        jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()))
    .firstWhere((b) => b.id == id);

void main() {
  final names = _assetNames();
  final main = _blueprint('ort_main_2026');

  group('topic names instead of raw ids (UX-02)', () {
    test('known topic ids resolve to the catalog name in ru / ky', () {
      expect(examTopicName('math.arithmetic', names: names, lang: 'ru'), 'Арифметика');
      expect(
          examTopicName('math.arithmetic.gcd_lcm', names: names, lang: 'ky'),
          'Эң чоң жалпы бөлүүчү жана эң кичине жалпы эселүү');
    });

    test('unknown leaf falls back to the nearest known parent, then the blueprint',
        () {
      expect(examTopicName('math.arithmetic.unknown_leaf', names: names, lang: 'ru'),
          'Арифметика');
      // 'analogies' is not in the catalog, but it is a part of the main test.
      final label = examTopicName('analogies.brand_new', names: names, lang: 'ru', blueprint: main);
      expect(label, isNot(contains('brand')));
      expect(label, isNot(contains('analogies')));
    });

    test('a server title wins', () {
      expect(
          examTopicName('math.arithmetic',
              names: names,
              lang: 'ru',
              serverTitle: const LocalizedText({'ru': 'Счёт'})),
          'Счёт');
    });

    test('result labels never show the slug remainder', () {
      final result = ExamResult.fromJson({
        'correct': 1,
        'total': 2,
        'topics': [
          {'topic_id': 'math.arithmetic', 'correct': 0, 'total': 2},
        ],
        'weak_topics': ['math.arithmetic'],
      });
      final label = examTopicLabel('math.arithmetic', result, main, 'ru', names: names);
      expect(label, 'Арифметика');
      expect(label, isNot(contains('arithmetic')));
    });

    test('sections and blueprints without a loaded blueprint', () {
      final l = AppLocalizationsRu();
      expect(examSectionName('verbal', names: names, lang: 'ru'),
          'Аналогии и дополнение предложений');
      expect(examSectionName('math', names: names, lang: 'ru', blueprint: main), 'Математика');
      expect(examBlueprintName('ort_main_2027', l: l, names: names, lang: 'ru'),
          l.examCatalogMainTitle);
      expect(examBlueprintName('ort_state_language_2026', l: l, names: names, lang: 'ru'),
          l.examCatalogStateLanguageTitle);
      expect(examBlueprintName('ort_subject_chemistry_2026', l: l, names: names, lang: 'ru'),
          'Химия');
      expect(examBlueprintName('ort_subject_kyrgyz_lit_2026', l: l, names: names, lang: 'ru'),
          isNot(contains('_')));
      expect(examBlueprintName('ort_main_2026', l: l, names: names, lang: 'ru', blueprint: main),
          main.title.resolve('ru'));
    });

    test('review card line: section · topic, deduplicated', () {
      ReviewItem item(String section, String? topic) => ReviewItem.fromJson(
          {'questionId': 'q', 'sectionId': section, 'topicId': topic});
      expect(
          reviewItemContext(item('math', 'math.arithmetic'),
              names: names, lang: 'ru', blueprint: main),
          'Математика · Арифметика');
      expect(
          reviewItemContext(item('math', 'math'), names: names, lang: 'ru', blueprint: main),
          'Математика');
      expect(reviewItemContext(item('math', null), names: names, lang: 'ru'), '');
    });
  });
}
