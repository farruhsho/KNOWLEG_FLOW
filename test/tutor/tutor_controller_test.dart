import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/tutor/application/tutor_controller.dart';
import 'package:knowledge_flow/features/tutor/data/tutor_api.dart';
import 'package:knowledge_flow/features/tutor/domain/tutor_models.dart';

class FakeTutorApi implements TutorApi {
  final List<TutorRequest> requests = [];
  final List<Object> script;
  FakeTutorApi(this.script);

  @override
  Future<TutorReply> ask(TutorRequest request) async {
    requests.add(request);
    final next = script.length > 1 ? script.removeAt(0) : script.first;
    if (next is TutorReply) return next;
    throw next;
  }
}

void main() {
  test('send appends user and assistant messages and tracks the quota', () async {
    final api = FakeTutorApi([const TutorReply('Шаг 1: ...', remainingToday: 9)]);
    final c = TutorChatController(api);
    c.applyArgs(const TutorArgs(questionId: 'q1', mode: TutorMode.explainMistake));

    expect(await c.send('  Почему?  ', language: 'ru'), isTrue);

    expect(c.state.messages.map((m) => m.role), [TutorRole.user, TutorRole.assistant]);
    expect(c.state.messages.first.text, 'Почему?');
    expect(c.state.remainingToday, 9);
    expect(c.state.sending, isFalse);
    final r = api.requests.single;
    expect(r.mode, TutorMode.explainMistake);
    expect(r.questionId, 'q1');
    expect(r.language, 'ru');
    expect(r.history, isEmpty);
  });

  test('history passed to the next request excludes the new message', () async {
    final api = FakeTutorApi([const TutorReply('a1'), const TutorReply('a2')]);
    final c = TutorChatController(api);
    await c.send('q1', language: 'ky');
    await c.send('q2', language: 'ky');
    final second = api.requests[1];
    expect(second.message, 'q2');
    expect(second.history.map((m) => m.text), ['q1', 'a1']);
    expect(second.toPayload()['language'], 'ky');
  });

  test('a network error marks the message as failed and retry resends it', () async {
    final api = FakeTutorApi([
      FirebaseFunctionsException(code: 'unavailable', message: 'offline'),
      const TutorReply('ok'),
    ]);
    final c = TutorChatController(api);
    await c.send('hello', language: 'ru');
    final failed = c.state.messages.single;
    expect(failed.failure, TutorFailure.network);
    expect(c.state.blockingFailure, isNull);

    await c.retry(failed.id, language: 'ru');
    expect(c.state.messages.map((m) => m.text), ['hello', 'ok']);
    expect(c.state.messages.first.failure, isNull);
    expect(api.requests, hasLength(2));
  });

  test('quota exceeded blocks further input', () async {
    final api = FakeTutorApi([
      FirebaseFunctionsException(
          code: 'resource-exhausted', message: 'q', details: {'reason': 'AI_QUOTA_EXCEEDED'}),
    ]);
    final c = TutorChatController(api);
    await c.send('one', language: 'ru');
    expect(c.state.blockingFailure, TutorFailure.quotaExceeded);
    expect(c.state.remainingToday, 0);
    expect(await c.send('two', language: 'ru'), isFalse);
    expect(api.requests, hasLength(1));
  });

  test('exam in progress is reported but does not block chat', () async {
    final api = FakeTutorApi([
      FirebaseFunctionsException(
          code: 'failed-precondition', message: 'x', details: {'reason': 'AI_EXAM_IN_PROGRESS'}),
    ]);
    final c = TutorChatController(api);
    await c.send('help', language: 'ru');
    expect(c.state.messages.single.failure, TutorFailure.examInProgress);
    expect(c.state.blockingFailure, isNull);
  });

  group('route context (TUTOR-CTX-01)', () {
    test('a practice question after an exam review drops the stale attemptId', () async {
      final api = FakeTutorApi([const TutorReply('ok')]);
      final c = TutorChatController(api);
      // "Ask tutor" from an exam review.
      c.applyArgs(const TutorArgs(questionId: 'exam_q1', attemptId: 'att_1', mode: TutorMode.explainMistake));
      expect(c.state.attemptId, 'att_1');

      // Later: "Ask tutor" on a practice mistake (no attempt).
      c.applyArgs(const TutorArgs(questionId: 'practice_q9', mode: TutorMode.explainMistake));
      expect(c.state.questionId, 'practice_q9');
      expect(c.state.attemptId, isNull);

      await c.send('Почему?', language: 'ru');
      final payload = api.requests.single.toPayload();
      expect(payload['questionId'], 'practice_q9');
      expect(payload.containsKey('attemptId'), isFalse);
    });

    test('an attempt-only context drops the old question', () {
      final c = TutorChatController(FakeTutorApi([const TutorReply('ok')]));
      c.applyArgs(const TutorArgs(questionId: 'q1'));
      c.applyArgs(const TutorArgs(attemptId: 'att_2'));
      expect(c.state.questionId, isNull);
      expect(c.state.attemptId, 'att_2');
    });

    test('arguments without context (mode / prefill only) keep the current context', () {
      final c = TutorChatController(FakeTutorApi([const TutorReply('ok')]));
      c.applyArgs(const TutorArgs(questionId: 'q1', attemptId: 'a1'));
      c.applyArgs(const TutorArgs(mode: TutorMode.studyPlan));
      expect(c.state.mode, TutorMode.studyPlan);
      expect(c.state.questionId, 'q1');
      expect(c.state.attemptId, 'a1');
    });
  });

  test('a message over the server limit is not sent (D13)', () async {
    final api = FakeTutorApi([const TutorReply('ok')]);
    final c = TutorChatController(api);
    expect(await c.send('x' * (TutorRequest.maxMessageChars + 1), language: 'ru'), isFalse);
    expect(api.requests, isEmpty);
    expect(c.state.messages, isEmpty);
    expect(await c.send('x' * TutorRequest.maxMessageChars, language: 'ru'), isTrue);
    expect(api.requests, hasLength(1));
  });

  test('a banned account blocks further input', () async {
    final api = FakeTutorApi([
      FirebaseFunctionsException(
          code: 'permission-denied', message: 'banned', details: {'reason': 'USER_BANNED'}),
    ]);
    final c = TutorChatController(api);
    await c.send('help', language: 'ru');
    expect(c.state.blockingFailure, TutorFailure.banned);
    expect(await c.send('again', language: 'ru'), isFalse);
  });

  test('empty input is not sent; clear keeps mode', () async {
    final api = FakeTutorApi([const TutorReply('x')]);
    final c = TutorChatController(api);
    c.setMode(TutorMode.grammar);
    expect(await c.send('   ', language: 'ru'), isFalse);
    await c.send('a', language: 'ru');
    c.clear();
    expect(c.state.messages, isEmpty);
    expect(c.state.mode, TutorMode.grammar);
    c.clearContext();
    expect(c.state.hasContext, isFalse);
  });
}
