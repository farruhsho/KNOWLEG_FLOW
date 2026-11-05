import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';

/// Device clock used by tests (UTC so DST never interferes).
final DateTime t0 = DateTime.utc(2026, 11, 2, 9);

const twoSectionBlueprint = <String, dynamic>{
  'id': 'bp_test',
  'kind': 'main',
  'exam_year': 2026,
  'version': 1,
  'status': 'active',
  'title': {'ru': 'Тест', 'ky': 'Тест', 'en': 'Test'},
  'languages': ['ru', 'ky'],
  'options_per_question': 4,
  'navigation': {'within_section': 'free', 'across_sections': 'forward_only'},
  'rules': {'calculators': false, 'scratchpad_sections': ['math']},
  'sections': [
    {
      'id': 'math',
      'order': 1,
      'title': {'ru': 'Математика', 'ky': 'Математика'},
      'question_count': 3,
      'duration_minutes': 10,
      'parts': [
        {
          'id': 'cmp',
          'title': {'ru': 'Сравнение'},
          'question_count': 2,
          'options_per_question': 4,
          'item_type': 'quantitative_comparison',
          'verified': true,
          'fixed_options': [
            {'id': 'A', 'text': {'ru': 'А больше', 'ky': 'А чоң'}},
            {'id': 'B', 'text': {'ru': 'Б больше', 'ky': 'Б чоң'}},
            {'id': 'C', 'text': {'ru': 'Равны', 'ky': 'Барабар'}},
            {'id': 'D', 'text': {'ru': 'Нельзя определить', 'ky': 'Аныктоого болбойт'}},
          ],
        },
        {
          'id': 'prob',
          'title': {'ru': 'Задачи'},
          'question_count': 1,
          'options_per_question': 5,
          'item_type': 'single_choice',
          'verified': true,
        },
      ],
    },
    {
      'id': 'verbal',
      'order': 2,
      'title': {'ru': 'Аналогии'},
      'question_count': 2,
      'duration_minutes': 5,
    },
  ],
  'scoring': {
    'method': 'raw',
    'official_scale_known': false,
    'disclaimer': {'ru': 'Учебный результат.'},
  },
};

Map<String, dynamic> mathSection({required int deadlineMs}) => {
      'sectionId': 'math',
      'deadlineAt': deadlineMs,
      'durationSec': 600,
      'questions': [
        {'id': 'q1', 'stem': r'Колонка А: $2^3$, колонка Б: $3^2$', 'options': [], 'topicId': 'math.powers'},
        {'id': 'q2', 'stem': 'Сравните', 'columnA': r'$\sqrt{16}$', 'columnB': '4', 'options': []},
        {
          'id': 'q3',
          'stem': r'Найдите $x$: $2x = 10$',
          'options': [
            {'id': 'A', 'text': '2'},
            {'id': 'B', 'text': '5'},
            {'id': 'C', 'text': '8'},
            {'id': 'D', 'text': '10'},
            {'id': 'E', 'text': '20'},
          ],
          'topicId': 'math.linear',
        },
      ],
      'passages': {},
    };

Map<String, dynamic> verbalSection({required int deadlineMs}) => {
      'sectionId': 'verbal',
      'deadlineAt': deadlineMs,
      'durationSec': 300,
      'questions': [
        {
          'id': 'v1',
          'stem': 'ДЕРЕВО : ЛЕС',
          'passageId': 'p1',
          'options': [
            {'id': 'A', 'text': 'книга : библиотека'},
            {'id': 'B', 'text': 'вода : река'},
            {'id': 'C', 'text': 'лист : ветка'},
            {'id': 'D', 'text': 'дом : окно'},
          ],
        },
        {
          'id': 'v2',
          'stem': 'Второй',
          'options': [
            {'id': 'A', 'text': 'a'},
            {'id': 'B', 'text': 'b'},
            {'id': 'C', 'text': 'c'},
            {'id': 'D', 'text': 'd'},
          ],
        },
      ],
      'passages': {
        'p1': {'title': 'Лес', 'text': 'line1\nline2\nline3\nline4\nline5\nline6'},
      },
    };

/// Payload as `examStart` would return it. The server clock is [skewMs]
/// ahead of the device clock [t0].
///
/// [examStyle] / [freshness] add the phase 4 fields (§10); without them the
/// payload is exactly what an older backend returns.
ExamSessionPayload startPayload({
  int skewMs = 0,
  Duration timeLeft = const Duration(minutes: 10),
  String? examStyle,
  Map<String, dynamic>? freshness,
  String variantId = 'var1',
}) {
  final serverNow = t0.millisecondsSinceEpoch + skewMs;
  return ExamSessionPayload.fromJson({
    'attemptId': 'att1',
    'variantId': variantId,
    'blueprint': twoSectionBlueprint,
    'status': 'in_progress',
    'currentSectionIndex': 0,
    'section': mathSection(deadlineMs: serverNow + timeLeft.inMilliseconds),
    'serverNow': serverNow,
    'entitlementSource': 'free_first',
    'language': 'ru',
    if (examStyle != null) 'examStyle': examStyle,
    if (freshness != null) 'freshness': freshness,
  });
}

ExamSessionPayload nextPayload({required DateTime deviceNow, int skewMs = 0, String? examStyle}) {
  final serverNow = deviceNow.millisecondsSinceEpoch + skewMs;
  return ExamSessionPayload.fromJson({
    'attemptId': 'att1',
    'variantId': 'var1',
    'blueprint': twoSectionBlueprint,
    'status': 'in_progress',
    'currentSectionIndex': 1,
    'section': verbalSection(deadlineMs: serverNow + 5 * 60 * 1000),
    'serverNow': serverNow,
    if (examStyle != null) 'examStyle': examStyle,
  });
}

Map<String, dynamic> resultJson() => {
      'correct': 3,
      'total': 5,
      'percent': 60.0,
      'sections': [
        {'section_id': 'math', 'correct': 2, 'total': 3, 'percent': 66.7},
        {'section_id': 'verbal', 'correct': 1, 'total': 2, 'percent': 50.0},
      ],
      'topics': [
        {'topic_id': 'math.linear', 'correct': 0, 'total': 1},
      ],
      'weak_topics': ['math.linear'],
      'strong_topics': ['math.powers'],
      'xp_awarded': 103,
      'leaderboard_eligible': true,
      'disclaimer_key': 'exam_result_unofficial',
    };
