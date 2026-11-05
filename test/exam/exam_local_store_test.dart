import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:knowledge_flow/features/exam/data/exam_local_store.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';

import 'exam_test_fixtures.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('exam_store_test');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  ExamSession session() =>
      ExamSession.fromPayload(startPayload(skewMs: 4000), clientNow: t0, uid: 'u1');

  test('every change round-trips through the exam_sessions box', () async {
    final store = ExamLocalStore();
    var s = session();
    await store.save(s, includeContent: true, savedAtMs: 1);
    s = s.answer('q3', 'B', now: t0).toggleFlag('q1', now: t0).goTo(2);
    await store.save(s, savedAtMs: 2);

    final restored = (await store.load('att1'))!;
    expect(restored.answers, {'q3': 'B'});
    expect(restored.flags, {'q1'});
    expect(restored.currentIndex, 2);
    expect(restored.clockOffsetMs, 4000);
    expect(restored.uid, 'u1');
    expect(restored.questions, hasLength(3));
    expect(restored.optionsFor(0).first.text, 'А больше');
    expect(Hive.isBoxOpen(ExamLocalStore.boxName), isTrue);
  });

  test('survives closing and reopening the box (app kill)', () async {
    final s = session().answer('q1', 'D', now: t0);
    await ExamLocalStore().save(s, includeContent: true, savedAtMs: 10);
    await Hive.close();

    Hive.init(dir.path);
    final reopened = ExamLocalStore();
    final restored = (await reopened.load('att1'))!;
    expect(restored.answerOf('q1'), 'D');
    expect(restored.remaining(t0), s.remaining(t0));

    final unfinished = await reopened.listUnfinished(uid: 'u1');
    expect(unfinished, hasLength(1));
    expect(unfinished.single.attemptId, 'att1');
    expect(unfinished.single.sectionCount, 2);
    expect(unfinished.single.localDeadline, s.localDeadline());
    expect(await reopened.listUnfinished(uid: 'someone_else'), isEmpty);
  });

  test('section change rewrites content; completed attempts are not listed', () async {
    final store = ExamLocalStore();
    var s = session().answer('q1', 'A', now: t0).beginSubmit(now: t0);
    await store.save(s, includeContent: true, savedAtMs: 1);
    final at = t0.add(const Duration(minutes: 1));
    s = s.acceptNextSection(nextPayload(deviceNow: at), clientNow: at);
    await store.save(s, includeContent: true, savedAtMs: 2);

    var restored = (await store.load('att1'))!;
    expect(restored.section.sectionId, 'verbal');
    expect(restored.phase, ExamPhase.sectionIntro);
    expect(restored.section.passages['p1']!.title, 'Лес');

    s = s.startSection().beginSubmit(now: at).complete(ExamResult.fromJson(resultJson()));
    await store.save(s, includeContent: true, savedAtMs: 3);
    expect(await store.listUnfinished(), isEmpty);
    final records = await store.sectionRecords('att1');
    expect(records.keys, containsAll(['math', 'verbal']));
    restored = (await store.load('att1'))!;
    expect(restored.result!.xpAwarded, 103);

    // Pruning drops the question content but keeps result and records.
    await store.pruneContent('att1');
    expect(await store.load('att1'), isNull);
    expect((await store.loadResult('att1'))!.xpAwarded, 103);
    expect((await store.sectionRecords('att1')).keys, contains('math'));

    await store.remove('att1');
    expect(await store.loadResult('att1'), isNull);
    expect(await store.load('att1'), isNull);
  });

  test('corrupt entries are ignored, not thrown', () async {
    final box = await Hive.openBox<String>(ExamLocalStore.boxName);
    await box.put('state:bad', '{not json');
    await box.put('content:bad', '[]');
    final store = ExamLocalStore();
    expect(await store.load('bad'), isNull);
    expect(await store.listUnfinished(), isEmpty);
  });
}
