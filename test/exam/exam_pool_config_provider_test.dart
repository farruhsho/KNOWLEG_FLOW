import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:knowledge_flow/features/exam/domain/exam_start.dart';
import 'package:knowledge_flow/features/exam/presentation/providers/exam_providers.dart';

/// `config/exam_pool` on the student side (ARCHITECTURE §10.1): the
/// listener follows sign-in and comes back after an error.
void main() {
  late StateProvider<String?> uid;
  late List<StreamController<Map<String, dynamic>?>> listeners;
  late ProviderContainer container;

  setUp(() {
    uid = StateProvider<String?>((ref) => null);
    listeners = [];
    container = ProviderContainer(overrides: [
      examUidProvider.overrideWith((ref) => ref.watch(uid)),
      examPoolConfigSourceProvider.overrideWithValue(() {
        final c = StreamController<Map<String, dynamic>?>();
        listeners.add(c);
        return c.stream;
      }),
      examPoolConfigRetryDelayProvider.overrideWithValue(const Duration(milliseconds: 20)),
    ]);
  });

  tearDown(() => container.dispose());

  bool freshEnabled() => container.read(examFreshEnabledProvider);

  test('signed out: defaults, nothing is read', () async {
    container.listen(examPoolConfigProvider, (_, __) {});
    await pumpEventQueue();
    expect(listeners, isEmpty);
    expect(container.read(examPoolConfigProvider).valueOrNull?.freshEnabled, isTrue);
  });

  test('listens again after sign-in and follows the document', () async {
    container.listen(examFreshEnabledProvider, (_, __) {});
    await pumpEventQueue();
    expect(listeners, isEmpty);

    container.read(uid.notifier).state = 'u1';
    await pumpEventQueue();
    expect(listeners, hasLength(1), reason: 're-subscribed after sign-in');
    listeners.last.add({'fresh_enabled': false});
    await pumpEventQueue();
    expect(freshEnabled(), isFalse);

    // Another account: a new listener, the old one is closed.
    container.read(uid.notifier).state = 'u2';
    await pumpEventQueue();
    expect(listeners, hasLength(2));
    expect(listeners.first.hasListener, isFalse);
    listeners.last.add({'fresh_enabled': true});
    await pumpEventQueue();
    expect(freshEnabled(), isTrue);
  });

  test('an error keeps the last value and is retried after the delay', () async {
    container.read(uid.notifier).state = 'u1';
    container.listen(examFreshEnabledProvider, (_, __) {});
    await pumpEventQueue();
    listeners.single.add({'fresh_enabled': false});
    await pumpEventQueue();
    expect(freshEnabled(), isFalse);

    listeners.single.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
    await pumpEventQueue();
    expect(freshEnabled(), isFalse, reason: 'the error is not shown; last value kept');
    expect(listeners, hasLength(1), reason: 'not before the retry delay');

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(listeners, hasLength(2), reason: 'listening again');
    listeners.last.add(null); // document deleted → defaults
    await pumpEventQueue();
    expect(freshEnabled(), isTrue);
  });

  test('a cancelled listener is not retried', () async {
    final opened = <StreamController<Map<String, dynamic>?>>[];
    final stream = watchExamPoolConfig(() {
      final c = StreamController<Map<String, dynamic>?>();
      opened.add(c);
      return c.stream;
    }, retryDelay: const Duration(milliseconds: 10));
    final seen = <ExamPoolConfig>[];
    final sub = stream.listen(seen.add);
    await pumpEventQueue();
    expect(seen.single.freshEnabled, isTrue, reason: 'defaults first');
    opened.single.addError(StateError('offline'));
    await pumpEventQueue();
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(opened, hasLength(1));
  });
}
