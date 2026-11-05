import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/core/backend/backend_contract.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';
import 'package:knowledge_flow/features/exam/domain/exam_start.dart';

import 'exam_test_fixtures.dart';

/// Phase 4 (ARCHITECTURE §10): fresh-variant start request, strict style
/// rules in the pure session, and the new payload / config fields.
void main() {
  ExamSession strict({Map<String, dynamic>? freshness}) => ExamSession.fromPayload(
        startPayload(examStyle: 'strict', freshness: freshness),
        clientNow: t0,
        uid: 'u1',
      );

  ExamSession started(ExamSession s) => s.startSection();

  group('examStart request (§10.1)', () {
    test('fresh: mode, blueprint, language and style', () {
      const r = ExamStartRequest.fresh(
        blueprintId: 'ort_main_2026',
        language: 'ky',
        style: ExamStyle.strict,
        clientAppVersion: '2.0.0+5',
      );
      expect(r.toCallableData(), {
        'mode': 'fresh',
        'blueprintId': 'ort_main_2026',
        'language': 'ky',
        'examStyle': 'strict',
        'clientAppVersion': '2.0.0+5',
      });
    });

    test('library: variant id, standard by default, no blueprint', () {
      const r = ExamStartRequest.library(variantId: 'v7', clientAppVersion: '1');
      final data = r.toCallableData();
      expect(data['mode'], 'library');
      expect(data['variantId'], 'v7');
      expect(data['examStyle'], 'standard');
      expect(data.containsKey('blueprintId'), isFalse);
      expect(data.containsKey('language'), isFalse);
    });
  });

  group('payload and config parsing', () {
    test('examStyle and freshness are read from the payload', () {
      final p = startPayload(
          examStyle: 'strict', freshness: {'total': 150, 'repeated': 12});
      expect(p.examStyle, ExamStyle.strict);
      expect(p.freshness, const ExamFreshness(total: 150, repeated: 12));
      final old = startPayload();
      expect(old.examStyle, isNull, reason: 'older backend: caller decides');
      expect(old.freshness, isNull);
      expect(
        ExamSessionPayload.fromJson({'exam_style': 'standard'}).examStyle,
        ExamStyle.standard,
      );
    });

    test('freshness is clamped and malformed values are ignored', () {
      expect(ExamFreshness.fromJson({'total': 5, 'repeated': 9})!.repeated, 5);
      expect(ExamFreshness.fromJson({'total': 'x'}), isNull);
      expect(ExamFreshness.fromJson(null), isNull);
    });

    test('config/exam_pool: missing or malformed means fresh enabled', () {
      expect(ExamPoolConfig.fromMap(null).freshEnabled, isTrue);
      expect(ExamPoolConfig.fromMap({'fresh_enabled': 'no'}).freshEnabled, isTrue);
      expect(ExamPoolConfig.fromMap({'fresh_enabled': false}).freshEnabled, isFalse);
      expect(ExamPoolConfig.fromMap({'min_review_status': 'ai_verified'}).minReviewStatus,
          'ai_verified');
      expect(ExamPoolConfig.fromMap({'min_review_status': 'draft'}).minReviewStatus,
          'methodologist_approved');
    });

    test('new reasons map to failure kinds', () {
      expect(ExamFailureKind.fromReason(BackendReasons.poolTooSmall),
          ExamFailureKind.poolTooSmall);
      expect(ExamFailureKind.fromReason(BackendReasons.sectionNotOver),
          ExamFailureKind.sectionNotOver);
      expect(BackendFunctions.paymentCreateOrder, 'paymentCreateOrder');
      expect(BackendFunctions.adminExamPoolHealth, 'adminExamPoolHealth');
      expect(Collections.paymentOrders, 'payment_orders');
      expect(ConfigDocs.examPool, 'exam_pool');
      expect(PaymentOrderStatuses.terminal,
          {'paid', 'failed', 'expired', 'refunded'});
    });
  });

  group('strict style («Как на ОРТ», §10.2)', () {
    test('the first section opens with its instruction screen', () {
      final s = strict();
      expect(s.isStrict, isTrue);
      expect(s.phase, ExamPhase.sectionIntro);
      expect(started(s).phase, ExamPhase.inSection);
    });

    test('the requested style is used when the server does not report one', () {
      final s = ExamSession.fromPayload(startPayload(),
          clientNow: t0, style: ExamStyle.strict);
      expect(s.isStrict, isTrue);
      final server = ExamSession.fromPayload(startPayload(examStyle: 'standard'),
          clientNow: t0, style: ExamStyle.strict);
      expect(server.isStrict, isFalse, reason: 'the attempt\'s own style wins');
    });

    test('an answer can be corrected once; a third choice is refused', () {
      var s = started(strict());
      s = s.answer('q3', 'A', now: t0);
      expect(s.choicesMade('q3'), 1);
      expect(s.isAnswerLocked('q3'), isFalse);
      s = s.answer('q3', 'B', now: t0);
      expect(s.answerOf('q3'), 'B');
      expect(s.isAnswerLocked('q3'), isTrue);
      final third = s.answer('q3', 'C', now: t0);
      expect(identical(third, s), isTrue);
      expect(third.answerOf('q3'), 'B');
      // Tapping the same option again is not a change.
      expect(identical(s.answer('q3', 'B', now: t0), s), isTrue);
    });

    test('no clearing and no flags', () {
      final s = started(strict()).answer('q1', 'A', now: t0);
      expect(identical(s.clearAnswer('q1', now: t0), s), isTrue);
      expect(identical(s.toggleFlag('q1', now: t0), s), isTrue);
      expect(s.allowsFlags, isFalse);
      expect(s.canFinishEarly, isFalse);
    });

    test('no early finish: beginSubmit is refused until the deadline', () {
      final s = started(strict()).answer('q1', 'A', now: t0);
      final early = t0.add(const Duration(minutes: 9, seconds: 59));
      expect(s.canSubmit(early), isFalse);
      expect(identical(s.beginSubmit(now: early), s), isTrue);
      expect(s.shouldAutoSubmit(early), isFalse);
      final deadline = t0.add(const Duration(minutes: 10));
      expect(s.shouldAutoSubmit(deadline), isTrue);
      final locked = s.beginSubmit(now: deadline, automatic: true);
      expect(locked.phase, ExamPhase.submitting);
      expect(locked.pendingSubmission!.flags, isEmpty);
      expect(locked.pendingSubmission!.answers['q1'], 'A');
    });

    test('the section is sent at its deadline even from the instruction screen', () {
      final s = strict();
      final deadline = t0.add(const Duration(minutes: 10));
      expect(s.phase, ExamPhase.sectionIntro);
      expect(s.shouldAutoSubmit(deadline), isTrue);
      final locked = s.beginSubmit(now: deadline, automatic: true);
      expect(locked.pendingSubmission!.answers.values.every((a) => a == null), isTrue);
    });

    test('correction counts survive a restart (Hive JSON round trip)', () {
      final s = started(strict(freshness: {'total': 5, 'repeated': 2}))
          .answer('q3', 'A', now: t0)
          .answer('q3', 'B', now: t0)
          .answer('q1', 'C', now: t0);
      final state = jsonDecode(jsonEncode(s.toStateJson())) as Map<String, dynamic>;
      final content = jsonDecode(jsonEncode(s.toContentJson())) as Map<String, dynamic>;
      final restored = ExamSession.fromJson(state, content)!;
      expect(restored.isStrict, isTrue);
      expect(restored.isAnswerLocked('q3'), isTrue);
      expect(restored.choicesMade('q1'), 1);
      expect(restored.answer('q3', 'D', now: t0).answerOf('q3'), 'B');
      expect(restored.answer('q1', 'D', now: t0).answerOf('q1'), 'D',
          reason: 'q1 still has its one correction');
      expect(restored.freshness, const ExamFreshness(total: 5, repeated: 2));
    });

    test('counts reset with the next section', () {
      final s = started(strict())
          .answer('q3', 'A', now: t0)
          .answer('q3', 'B', now: t0);
      final deadline = t0.add(const Duration(minutes: 10));
      final next = s
          .beginSubmit(now: deadline, automatic: true)
          .acceptNextSection(nextPayload(deviceNow: deadline, examStyle: 'strict'),
              clientNow: deadline);
      expect(next.choiceCounts, isEmpty);
      expect(next.phase, ExamPhase.sectionIntro);
      expect(next.isStrict, isTrue);
    });
  });

  group('the attempt\'s style comes from the server', () {
    test('reconcile adopts a strict examStyle over a standard local copy', () {
      // A copy saved without the style (or before phase 4) restores as standard.
      final local = ExamSession.fromPayload(startPayload(), clientNow: t0, uid: 'u1')
          .answer('q1', 'A', now: t0)
          .toggleFlag('q3', now: t0);
      expect(local.isStrict, isFalse);
      final s = local.reconcile(startPayload(examStyle: 'strict'), clientNow: t0);
      expect(s.isStrict, isTrue);
      expect(s.phase, ExamPhase.inSection, reason: 'the open section stays open');
      expect(s.answerOf('q1'), 'A');
      expect(s.flags, isEmpty, reason: 'strict has no flags');
      expect(s.choicesMade('q1'), 1, reason: 'the given answer is the first choice');
      final corrected = s.answer('q1', 'B', now: t0);
      expect(corrected.answerOf('q1'), 'B');
      expect(corrected.answer('q1', 'C', now: t0).answerOf('q1'), 'B');
      expect(s.canSubmit(t0), isFalse, reason: 'no early finish any more');
      expect(s.toStateJson()['exam_style'], 'strict');
    });

    test('a payload without examStyle keeps the local style', () {
      final local = strict().startSection().answer('q3', 'A', now: t0);
      final s = local.reconcile(startPayload(), clientNow: t0);
      expect(s.isStrict, isTrue);
      expect(s.choicesMade('q3'), 1);
    });

    test('a standard examStyle replaces a strict local guess', () {
      final local = strict().startSection().answer('q3', 'A', now: t0).answer('q3', 'B', now: t0);
      final s = local.reconcile(startPayload(examStyle: 'standard'), clientNow: t0);
      expect(s.isStrict, isFalse);
      expect(s.choiceCounts, isEmpty);
      expect(s.answer('q3', 'C', now: t0).answerOf('q3'), 'C');
    });

    test('the next section payload carries the style too', () {
      final s = ExamSession.fromPayload(startPayload(), clientNow: t0);
      final next = s
          .beginSubmit(now: t0)
          .acceptNextSection(nextPayload(deviceNow: t0, examStyle: 'strict'), clientNow: t0);
      expect(next.isStrict, isTrue);
      final kept = s
          .beginSubmit(now: t0)
          .acceptNextSection(nextPayload(deviceNow: t0), clientNow: t0);
      expect(kept.isStrict, isFalse);
    });

    test('withStyle is a no-op for the same style', () {
      final s = strict();
      expect(identical(s.withStyle(ExamStyle.strict), s), isTrue);
    });
  });

  group('standard style is unchanged', () {
    test('free changes, clearing, flags, early finish', () {
      var s = ExamSession.fromPayload(startPayload(), clientNow: t0);
      expect(s.phase, ExamPhase.inSection);
      for (final o in ['A', 'B', 'C', 'D', 'E', 'A']) {
        s = s.answer('q3', o, now: t0);
      }
      expect(s.answerOf('q3'), 'A');
      expect(s.choiceCounts, isEmpty);
      expect(s.isAnswerLocked('q3'), isFalse);
      s = s.toggleFlag('q3', now: t0);
      expect(s.isFlagged('q3'), isTrue);
      expect(s.canSubmit(t0), isTrue);
      expect(s.beginSubmit(now: t0).pendingSubmission!.flags, ['q3']);
      expect(s.clearAnswer('q3', now: t0).answerOf('q3'), isNull);
    });

    test('a session saved before phase 4 restores as standard', () {
      final s = ExamSession.fromPayload(startPayload(), clientNow: t0)
          .answer('q1', 'A', now: t0);
      final state = Map<String, dynamic>.from(s.toStateJson())
        ..remove('exam_style')
        ..remove('choice_counts');
      final restored = ExamSession.fromJson(state, s.toContentJson())!;
      expect(restored.isStrict, isFalse);
      expect(restored.answerOf('q1'), 'A');
    });
  });
}
