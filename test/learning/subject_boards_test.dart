import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/content/topic_names.dart';
import 'package:knowledge_flow/features/gamification/domain/subject_boards.dart';

/// GAM-X2 / UX-03: the "By subject" leaderboard tab must use the blueprint
/// subject ids the server keys subject boards by (decision D10).
void main() {
  final names = TopicNames.fromJson(
      jsonDecode(File('assets/data/topic_names.json').readAsStringSync()) as Map<String, dynamic>);

  Set<String> blueprintSubjectIds() {
    final raw = jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync());
    final list = raw is List ? raw : (raw as Map<String, dynamic>)['blueprints'] as List;
    return {
      for (final b in list.cast<Map<String, dynamic>>())
        if (b['kind'] == 'main') 'main' else if (b['subject_id'] is String) b['subject_id'] as String,
    };
  }

  test('chips cover exactly the blueprint subject ids (main + subjects + state language)', () {
    expect(SubjectBoards.ids.toSet(), blueprintSubjectIds());
    expect(SubjectBoards.ids.toSet().length, SubjectBoards.ids.length, reason: 'no duplicates');
    expect(SubjectBoards.ids, containsAll(['main', 'chemistry', 'biology', 'physics', 'kyrgyz_lit', 'russian_lit']));
  });

  test('legacy learning-subject ids never become board ids', () {
    for (final legacy in ['russian', 'kyrgyz', 'history_kg', 'russian_lang', 'kyrgyz_lang']) {
      expect(SubjectBoards.ids, isNot(contains(legacy)));
    }
  });

  test('board ids use the server format', () {
    final now = DateTime.utc(2026, 11, 4, 12);
    expect(SubjectBoards.weeklyBoardId('kyrgyz_lit', now), 'subject_kyrgyz_lit_weekly_2026-W45');
    expect(SubjectBoards.weeklyBoardId('main', now), 'subject_main_weekly_2026-W45');
  });

  test('every chip has a real localized name, not a raw id', () {
    for (final id in SubjectBoards.ids) {
      for (final lang in ['ru', 'ky', 'en']) {
        final label = SubjectBoards.label(id, names: names, lang: lang, mainTestLabel: 'MAIN');
        if (id == SubjectBoards.main) {
          expect(label, 'MAIN');
        } else {
          expect(names.contains(id), isTrue, reason: id);
          expect(label, isNot(contains('_')), reason: '$id/$lang');
          expect(label, isNot(id), reason: '$id/$lang');
        }
      }
    }
    expect(SubjectBoards.label('kyrgyz_lit', names: names, lang: 'ky', mainTestLabel: ''), 'Кыргыз тили жана адабияты');
  });
}
