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
