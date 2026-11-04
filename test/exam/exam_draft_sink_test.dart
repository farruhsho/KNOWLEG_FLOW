import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/data/exam_draft_sink.dart';

/// The string list inside `d.keys().hasOnly([...])` of `canWriteDraft` in
/// firestore.rules, or null when the rule no longer has that shape.
List<String>? _ruleDraftKeys() {
  final rules = File('firestore.rules').readAsStringSync();
  final start = rules.indexOf('function canWriteDraft');
  if (start < 0) return null;
  final end = rules.indexOf('function ', start + 1);
  final body = rules.substring(start, end < 0 ? rules.length : end);
  final m = RegExp(r'hasOnly\(\s*\[([^\]]*)\]\s*\)').firstMatch(body);
  if (m == null) return null;
  return RegExp(r"""['"]([^'"]+)['"]""")
      .allMatches(m.group(1)!)
      .map((x) => x.group(1)!)
      .toList();
}

void main() {
  group('exam draft document (EXAM-01 / SEC-DRAFT-01, contract D1)', () {
    test('has exactly answers, flags and client_updated_at', () {
      final data = examDraftData(
        answers: const {'q1': 'A', 'q3': 'C'},
        flags: const ['q2'],
        clientUpdatedAt: 1762078200000,
      );
      expect(data.keys.toSet(), examDraftKeys.toSet());
      expect(data.keys, hasLength(3));
      expect(data['answers'], {'q1': 'A', 'q3': 'C'});
      expect(data['flags'], ['q2']);
      // No keys the rule rejects (the old client also sent these).
      for (final k in const ['section_id', 'client_saved_at', 'updated_at']) {
        expect(data.containsKey(k), isFalse, reason: k);
      }
    });

    test('client_updated_at defaults to the server timestamp', () {
      final data = examDraftData(answers: const {}, flags: const []);
      expect(data['client_updated_at'], isA<FieldValue>());
      expect(data['client_updated_at'], FieldValue.serverTimestamp());
    });

    test('copies the inputs (later edits do not leak into a queued write)', () {
      final answers = {'q1': 'A'};
      final flags = ['q1'];
      final data = examDraftData(answers: answers, flags: flags);
      answers['q2'] = 'B';
      flags.add('q2');
      expect(data['answers'], {'q1': 'A'});
      expect(data['flags'], ['q1']);
    });

    test('every key is allowed by canWriteDraft in firestore.rules', () {
      final ruleKeys = _ruleDraftKeys();
      expect(ruleKeys, isNotNull,
          reason: 'canWriteDraft must restrict draft keys with hasOnly([...])');
      expect(ruleKeys!.toSet().containsAll(examDraftKeys), isTrue,
          reason: 'client draft keys $examDraftKeys are not all in the '
              'rule\'s hasOnly $ruleKeys: every autosave would be '
              'PERMISSION_DENIED');
    });
  });
}
