/// Shared fixtures of the phase 4 admin tests (ARCHITECTURE §10).
library;

/// Shape of `adminExamPoolHealth` as functions/src/handlers/fresh.ts returns it.
Map<String, dynamic> healthResponse() => {
      'blueprintId': 'ort_main_2026',
      'language': 'ru',
      'freshEnabled': true,
      'minReviewStatus': 'ai_verified',
      'sections': [
        {
          'section_id': 'math',
          'parts': [
            {
              'part_id': 'p1',
              'needed': 30,
              'available_by_status': {'methodologist_approved': 40, 'ai_verified': 12, 'draft': 7},
              'eligible': 50,
              'passages': {'standalone': 0, 'paired': 0, 'unknown': 0},
              'disjoint_variants': 1,
            },
            {
              'part_id': 'p2',
              'needed': 30,
              'available_by_status': {'methodologist_approved': 20, 'ai_verified': 0, 'draft': 3},
              'eligible': 18,
              'passages': {'standalone': 0, 'paired': 0, 'unknown': 0},
              'disjoint_variants': 0,
            },
          ],
        },
        {
          'section_id': 'reading',
          'parts': [
            {
              'part_id': 'p1',
              'needed': 30,
              'available_by_status': {'methodologist_approved': 30, 'ai_verified': 0, 'draft': 0},
              'eligible': 30,
              'passages': {'standalone': 2, 'paired': 0, 'unknown': 1},
              'disjoint_variants': 0,
            },
          ],
        },
      ],
      'disjoint_variants': 0,
      'disjoint_variants_capped': false,
      'shortfalls': [
        {'kind': 'cell', 'section_id': 'math', 'part_id': 'p2', 'topic_id': 'math.geometry', 'difficulty': 3, 'needed': 4, 'available': 1},
        {'kind': 'cell', 'section_id': 'math', 'part_id': 'p2', 'topic_id': 'math.geometry', 'difficulty': 1, 'needed': 2, 'available': 1},
        {'kind': 'cell', 'section_id': 'math', 'part_id': 'p2', 'topic_id': 'math.algebra', 'difficulty': 2, 'needed': 6, 'available': 0},
        {'kind': 'cell', 'section_id': 'math', 'part_id': 'p2', 'topic_id': 'math.arithmetic', 'difficulty': 2, 'needed': 2, 'available': 2},
        {'kind': 'passages', 'section_id': 'reading', 'part_id': 'p1', 'layout': 'paired', 'needed': 1, 'available': 0},
        {'kind': 'unknown_future_kind', 'section_id': 'x'},
      ],
    };
