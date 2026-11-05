import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/tutor/domain/tutor_models.dart';

TutorMessage msg(int i, TutorRole role, {TutorFailure? failure, String? text}) => TutorMessage(
      id: 'm$i',
      role: role,
      text: text ?? 'message $i',
      at: DateTime(2026, 11, 2, 10, i),
      failure: failure,
    );

void main() {
  group('TutorRequest.toPayload', () {
    test('carries mode wire name, language and optional ids', () {
      final p = const TutorRequest(
        mode: TutorMode.explainMistake,
        message: '  Почему B?  ',
        language: 'ky',
        questionId: 'q_1',
        attemptId: 'att_1',
      ).toPayload();
      expect(p['mode'], 'explain_mistake');
      expect(p['message'], 'Почему B?');
      expect(p['language'], 'ky');
      expect(p['questionId'], 'q_1');
      expect(p['attemptId'], 'att_1');
      expect(p['history'], isEmpty);
    });

    test('omits absent ids', () {
      final p = const TutorRequest(mode: TutorMode.chat, message: 'hi', language: 'ru').toPayload();
      expect(p.containsKey('questionId'), isFalse);
      expect(p.containsKey('attemptId'), isFalse);
    });

    test('sends only the last 6 successful turns, oldest first, as role/content', () {
      final history = [
        for (var i = 0; i < 10; i++) msg(i, i.isEven ? TutorRole.user : TutorRole.assistant),
        msg(10, TutorRole.user, failure: TutorFailure.network),
      ];
      final p = TutorRequest(mode: TutorMode.chat, message: 'next', language: 'ru', history: history).toPayload();
      final h = (p['history'] as List).cast<Map<String, dynamic>>();
      expect(h, hasLength(TutorRequest.maxHistory));
      expect(h.first['content'], 'message 4');
      expect(h.last['content'], 'message 9');
      expect(h.first['role'], 'user');
      expect(h[1]['role'], 'assistant');
      expect(h.any((m) => m['content'] == 'message 10'), isFalse);
    });

    test('clips long history items and messages', () {
      final long = 'x' * 10000;
      final p = TutorRequest(
        mode: TutorMode.chat,
        message: long,
        language: 'ru',
        history: [msg(0, TutorRole.assistant, text: long)],
      ).toPayload();
      expect((p['message'] as String).length, TutorRequest.maxMessageChars);
      expect(((p['history'] as List).single as Map)['content'].length, TutorRequest.maxHistoryChars);
    });

    test('message limit is the server limit (2000, D13)', () {
      expect(TutorRequest.maxMessageChars, 2000);
      final ok = TutorRequest(mode: TutorMode.chat, message: 'a' * 2000, language: 'ru').toPayload();
      expect((ok['message'] as String).length, 2000);
      final cut = TutorRequest(mode: TutorMode.chat, message: 'b' * 2500, language: 'ru').toPayload();
      expect((cut['message'] as String).length, lessThanOrEqualTo(2000));
    });

    test('every mode has the contract wire name', () {
      expect(TutorMode.values.map((m) => m.wire).toList(),
          ['explain_mistake', 'step_by_step', 'grammar', 'practice', 'study_plan', 'chat']);
      expect(TutorMode.fromWire('study_plan'), TutorMode.studyPlan);
      expect(TutorMode.fromWire('nope'), isNull);
    });
  });

  group('TutorReply.fromResponse', () {
    test('parses reply and remainingToday', () {
      final r = TutorReply.fromResponse({'reply': 'Ответ', 'remainingToday': 7});
      expect(r.reply, 'Ответ');
      expect(r.remainingToday, 7);
      expect(TutorReply.fromResponse({'reply': 'ok'}).remainingToday, isNull);
    });

    test('rejects empty or malformed replies', () {
      expect(() => TutorReply.fromResponse({'reply': ''}), throwsFormatException);
      expect(() => TutorReply.fromResponse('text'), throwsFormatException);
    });
  });

  group('TutorFailure.from', () {
    FirebaseFunctionsException err(String code, [String? reason]) => FirebaseFunctionsException(
        code: code, message: 'm', details: reason == null ? null : {'reason': reason});

    test('maps backend reasons', () {
      expect(TutorFailure.from(err('resource-exhausted', 'AI_QUOTA_EXCEEDED')), TutorFailure.quotaExceeded);
      expect(TutorFailure.from(err('failed-precondition', 'AI_DISABLED')), TutorFailure.disabled);
      expect(TutorFailure.from(err('failed-precondition', 'AI_EXAM_IN_PROGRESS')), TutorFailure.examInProgress);
      expect(TutorFailure.from(err('invalid-argument', 'VALIDATION_FAILED')), TutorFailure.validation);
      expect(TutorFailure.from(err('permission-denied', 'USER_BANNED')), TutorFailure.banned);
    });

    test('maps plain codes', () {
      expect(TutorFailure.from(err('resource-exhausted')), TutorFailure.quotaExceeded);
      expect(TutorFailure.from(err('unauthenticated')), TutorFailure.signInRequired);
      expect(TutorFailure.from(err('unavailable')), TutorFailure.network);
      expect(TutorFailure.from(err('deadline-exceeded')), TutorFailure.network);
      expect(TutorFailure.from(err('internal')), TutorFailure.unknown);
      expect(TutorFailure.from(const TutorException(TutorFailure.disabled)), TutorFailure.disabled);
      expect(TutorFailure.from(Exception('SocketException: failed host lookup')), TutorFailure.network);
    });

    test('only quota/disabled/banned block further input', () {
      expect(TutorFailure.quotaExceeded.blocksInput, isTrue);
      expect(TutorFailure.disabled.blocksInput, isTrue);
      expect(TutorFailure.banned.blocksInput, isTrue);
      expect(TutorFailure.examInProgress.blocksInput, isFalse);
      expect(TutorFailure.network.blocksInput, isFalse);
    });
  });

  group('TutorArgs', () {
    test('parses route extra', () {
      final a = TutorArgs.fromExtra({'questionId': 'q1', 'attemptId': 'a1', 'mode': 'grammar', 'prefill': 'Hi'});
      expect(a.questionId, 'q1');
      expect(a.attemptId, 'a1');
      expect(a.mode, TutorMode.grammar);
      expect(a.prefill, 'Hi');
    });

    test('a question without a mode defaults to explain_mistake', () {
      expect(TutorArgs.fromExtra({'questionId': 'q1'}).mode, TutorMode.explainMistake);
    });

    test('tolerates null / wrong types and round-trips', () {
      expect(TutorArgs.fromExtra(null).isEmpty, isTrue);
      expect(TutorArgs.fromExtra('x').isEmpty, isTrue);
      expect(TutorArgs.fromExtra({'questionId': 5, 'prefill': '  '}).isEmpty, isTrue);
      const a = TutorArgs(questionId: 'q', mode: TutorMode.practice);
      final b = TutorArgs.fromExtra(a.toExtra());
      expect(b.questionId, 'q');
      expect(b.mode, TutorMode.practice);
    });
  });

  group('clipTutorText', () {
    test('keeps short text and cuts long text to the limit', () {
      expect(clipTutorText('abc', 5), 'abc');
      expect(clipTutorText('abcdef', 3), 'abc');
      expect(clipTutorText('abcdef', 4, ellipsis: true), 'abc…');
      expect(clipTutorText('abcdef', 4, ellipsis: true).length, 4);
      expect(clipTutorText('abc', 0), '');
    });

    test('never splits a surrogate pair', () {
      const s = 'ab😀cd'; // 😀 is two UTF-16 code units at index 2..3
      final cut = clipTutorText(s, 3);
      expect(cut, 'ab');
      expect(cut.codeUnits.any((u) => u >= 0xD800 && u <= 0xDFFF), isFalse);
      expect(clipTutorText(s, 4), 'ab😀');
    });
  });

  test('tutorLanguageFor', () {
    expect(tutorLanguageFor('ky'), 'ky');
    expect(tutorLanguageFor('ru'), 'ru');
    expect(tutorLanguageFor('en'), 'ru');
    expect(tutorLanguageFor(null), 'ru');
  });
}
