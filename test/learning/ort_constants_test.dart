import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/constants/app_constants.dart';
import 'package:knowledge_flow/core/constants/ort_constants.dart';

/// OrtConstants / AppConstants must mirror the canonical blueprint asset
/// (CMS-08): any drift fails here instead of reaching students.
void main() {
  final raw = jsonDecode(File('assets/data/exam_blueprints.json').readAsStringSync()) as Map<String, dynamic>;
  final blueprints = (raw['blueprints'] as List).cast<Map<String, dynamic>>();
  final main = blueprints.firstWhere((b) => b['id'] == 'ort_main_2026');
  final sections = (main['sections'] as List).cast<Map<String, dynamic>>();

  int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

  test('main test totals match the blueprint', () {
    expect(OrtConstants.totalMainQuestions, sum(sections.map((s) => s['question_count'] as int)));
    expect(OrtConstants.totalMainMinutes, sum(sections.map((s) => s['duration_minutes'] as int)));
    expect(AppConstants.mainTestQuestions, OrtConstants.totalMainQuestions);
    expect(AppConstants.mainTestTimeMinutes, OrtConstants.totalMainMinutes);
    expect(OrtConstants.officialMainMaxScore, (main['reference'] as Map)['official_max_score']);
  });

  test('parts map onto blueprint sections with the same counts and order', () {
    final parts = OrtConstants.mainSectionsList;
    expect(parts.map((p) => p.order).toList(), [1, 2, 3, 4, 5, 6]);
    expect(sum(parts.map((p) => p.questionCount)), OrtConstants.totalMainQuestions);
    expect(sum(parts.map((p) => p.timeMinutes)), OrtConstants.totalMainMinutes);

    final blueprintOrder = <String>[];
    for (final s in sections) {
      final id = s['id'] as String;
      final mine = parts.where((p) => p.blueprintSectionId == id).toList();
      expect(sum(mine.map((p) => p.questionCount)), s['question_count'], reason: id);
      expect(sum(mine.map((p) => p.timeMinutes)), s['duration_minutes'], reason: id);
      final bpParts = (s['parts'] as List).cast<Map<String, dynamic>>();
      if (bpParts.length == mine.length) {
        for (var i = 0; i < mine.length; i++) {
          expect(mine[i].questionCount, bpParts[i]['question_count'], reason: '$id part $i');
          expect(mine[i].optionsPerQuestion, bpParts[i]['options_per_question'], reason: '$id part $i');
        }
      }
      blueprintOrder.add(id);
    }
    final partOrder = <String>[];
    for (final p in parts) {
      if (partOrder.isEmpty || partOrder.last != p.blueprintSectionId) partOrder.add(p.blueprintSectionId!);
    }
    expect(partOrder, blueprintOrder);
    for (final p in parts) {
      expect(OrtConstants.getSectionConfig(p.id)?['questions'], p.questionCount, reason: p.id);
      expect(OrtConstants.getSectionConfig(p.id)?['minutes'], p.timeMinutes, reason: p.id);
    }
  });

  test('subject tests match their blueprints', () {
    final subjects = blueprints.where((b) => b['kind'] == 'subject').toList();
    expect(OrtConstants.subjectTestsList.map((s) => s.id).toSet(), subjects.map((b) => b['subject_id']).toSet());
    expect(OrtConstants.availableSubjects.toSet(), subjects.map((b) => b['subject_id']).toSet());
    for (final b in subjects) {
      final s = OrtConstants.subjectTestsList.firstWhere((x) => x.id == b['subject_id']);
      final sec = (b['sections'] as List).single as Map<String, dynamic>;
      expect(s.questionCount, sec['question_count'], reason: s.id);
      expect(s.timeMinutes, sec['duration_minutes'], reason: s.id);
    }
  });

  test('state language test and thresholds match the blueprint', () {
    final state = blueprints.firstWhere((b) => b['kind'] == 'state_language');
    final sec = (state['sections'] as List).single as Map<String, dynamic>;
    expect(OrtConstants.stateLanguageQuestions, sec['question_count']);
    expect(OrtConstants.stateLanguageMinutes, sec['duration_minutes']);
    expect(AppConstants.languageTestQuestions, sec['question_count']);
    expect(AppConstants.languageTestTimeMinutes, sec['duration_minutes']);

    final uni = ((main['reference'] as Map)['thresholds_2026_27'] as Map)['university'] as Map;
    expect(OrtConstants.universityThresholds, uni.map((k, v) => MapEntry(k as String, v as int)));
  });
}
