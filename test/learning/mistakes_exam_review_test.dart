import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/shared/models/mistake_model.dart';
import 'package:knowledge_flow/shared/services/mistakes_service.dart';

/// GAM-X1: exam-sourced mistakes must be reviewable/resolvable by the owner
/// with exactly the fields firestore.rules allow on `source == 'exam'` items.
void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  final examItem = MistakeItem(
    questionId: 'eq_1',
    source: MistakeSource.exam,
    subjectId: 'verbal',
    intervalDays: 1,
    nextReviewAt: now.subtract(const Duration(hours: 1)),
    attemptId: 'a1',
  );

  /// The `hasOnly([...])` list of the exam branch of the user_mistakes
  /// update rule, read from the real rules file.
  Set<String> rulesExamFields() {
    final rules = File('firestore.rules').readAsStringSync();
    final block = rules.substring(rules.indexOf('match /user_mistakes/{uid}/items/{questionId}'));
    final m = RegExp(r"resource\.data\.source == 'exam'\s*&& changedKeys\(\)\.hasOnly\(\[([^\]]*)\]\)").firstMatch(block);
    expect(m, isNotNull, reason: 'exam update branch not found in firestore.rules');
    return RegExp(r"'([a-z_]+)'").allMatches(m!.group(1)!).map((x) => x.group(1)!).toSet();
  }

  test('client whitelist is allowed by the rules', () {
    final allowed = rulesExamFields();
    expect(allowed.containsAll(MistakesService.examWritableFields), isTrue,
        reason: 'rules allow $allowed, client writes ${MistakesService.examWritableFields}');
  });

  test('reviewing an exam item writes only allowed fields and moves 1 → 3 days', () {
    final patch = MistakesService.examReviewPatch(examItem, now);
    expect(MistakesService.examWritableFields.containsAll(patch.keys), isTrue, reason: '${patch.keys}');
    expect(patch['interval_days'], 3);
    expect(patch['resolved'], isFalse);
    expect(patch['next_review_at'], Timestamp.fromDate(now.add(const Duration(days: 3))));
    expect(patch['review_count'], FieldValue.increment(1));
    // Never the practice-shape fields the rules reject on exam items.
    for (final k in ['source', 'question_id', 'wrong_count', 'last_wrong_at', 'subject_id', 'topic_id']) {
      expect(patch.containsKey(k), isFalse, reason: k);
    }
  });

  test('the whole ladder resolves an exam item after the 30-day review', () {
    var item = examItem;
    final seen = <int>[];
    for (var i = 0; i < 10 && !item.resolved; i++) {
      final patch = MistakesService.examReviewPatch(item, now);
      item = item.copyWith(
        intervalDays: patch['interval_days'] as int,
        resolved: patch['resolved'] as bool,
        nextReviewAt: (patch['next_review_at'] as Timestamp).toDate(),
      );
      if (!item.resolved) seen.add(item.intervalDays);
    }
    expect(seen, [3, 7, 14, 30]);
    expect(item.resolved, isTrue);
  });

  test('resolving an exam item writes only allowed fields', () {
    final patch = MistakesService.examResolvePatch();
    expect(MistakesService.examWritableFields.containsAll(patch.keys), isTrue);
    expect(patch['resolved'], isTrue);
  });

  test('exam items stay out of the full practice writes', () {
    expect(examItem.clientWritable, isFalse);
    expect(examItem.isExam, isTrue);
    const practice = MistakeItem(questionId: 'q', source: MistakeSource.practice);
    expect(practice.clientWritable, isTrue);
    expect(practice.isExam, isFalse);
  });

  test('the open-queue query is backed by a (resolved, next_review_at) index', () {
    final indexes = jsonDecode(File('firestore.indexes.json').readAsStringSync()) as Map<String, dynamic>;
    final found = (indexes['indexes'] as List).cast<Map<String, dynamic>>().any((ix) {
      if (ix['collectionGroup'] != 'items') return false;
      final fields = [for (final f in (ix['fields'] as List).cast<Map<String, dynamic>>()) f['fieldPath']];
      return fields.length == 2 && fields[0] == 'resolved' && fields[1] == 'next_review_at';
    });
    expect(found, isTrue);
  });
}
