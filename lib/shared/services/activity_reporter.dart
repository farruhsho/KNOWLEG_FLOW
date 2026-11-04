import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/backend/backend_contract.dart';
import '../../core/network/firebase_service.dart';
import '../../core/utils/app_log.dart';
import '../../core/utils/json_read.dart';

/// `recordActivity` kinds (ARCHITECTURE.md §3).
abstract final class ActivityKinds {
  static const lessonCompleted = 'lesson_completed';
  static const practiceAnswered = 'practice_answered';
}

class ActivityEvent {
  final String kind;
  final String refId;
  final int? correct;
  final int? count;

  const ActivityEvent({required this.kind, required this.refId, this.correct, this.count});

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'refId': refId,
        if (correct != null) 'correct': correct,
        if (count != null) 'count': count,
      };

  static ActivityEvent? fromJson(Object? raw) {
    final m = JsonRead.asMap(raw);
    if (m == null) return null;
    final kind = JsonRead.string(m, ['kind']);
    final ref = JsonRead.string(m, ['refId']);
    if (kind == null || ref == null) return null;
    return ActivityEvent(
      kind: kind,
      refId: ref,
      correct: JsonRead.integer(m, ['correct']),
      count: JsonRead.integer(m, ['count']),
    );
  }

  String get dedupeKey => '$kind:$refId';
}

/// What the server answered (null fields when it did not say).
class ActivityResult {
  final int xpAwarded;
  final Map<String, dynamic>? stats;
  const ActivityResult({required this.xpAwarded, this.stats});
}

/// Reports learning activity to the `recordActivity` callable so the
/// **server** awards XP (GAM-04). Never blocks the UI: callers fire and
/// forget, or show the result when it arrives.
///
/// Transient failures (offline, timeout) are queued in SharedPreferences and
/// retried on the next report/flush. That is safe because the backend is
/// idempotent per (kind, refId): practice sessions use a unique session id,
/// lessons award XP once per lesson.
class ActivityReporter {
  ActivityReporter._();
  static final ActivityReporter instance = ActivityReporter._();

  static const _prefsKey = 'learn_pending_activity_v1';
  static const _maxQueued = 50;
  bool _flushing = false;

  Future<ActivityResult?> report(ActivityEvent event) async {
    final result = await _send(event, queueOnFailure: true);
    if (result != null) unawaited(flushPending());
    return result;
  }

  /// Retries queued events. Safe to call often (e.g. when a learning page
  /// opens); does nothing while another flush runs.
  Future<void> flushPending() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final pending = await _load();
      if (pending.isEmpty) return;
      final remaining = <ActivityEvent>[];
      for (final e in pending) {
        final ok = await _send(e, queueOnFailure: false);
        if (ok == null && _lastFailureTransient) remaining.add(e);
      }
      await _save(remaining);
    } catch (e, st) {
      reportError(e, st, reason: 'learn.activity.flush');
    } finally {
      _flushing = false;
    }
  }

  bool _lastFailureTransient = false;

  Future<ActivityResult?> _send(ActivityEvent event, {required bool queueOnFailure}) async {
    if (!FirebaseService.supportsCallables) {
      // No App Check on this platform (Windows/Linux, web without a site
      // key): the server would reject the call, and retrying cannot help.
      _lastFailureTransient = false;
      return null;
    }
    try {
      final res = await BackendFunctions.callable(
        BackendFunctions.recordActivity,
        timeout: const Duration(seconds: 20),
      ).call<Object?>(event.toJson());
      _lastFailureTransient = false;
      final data = JsonRead.asMap(res.data) ?? const <String, dynamic>{};
      return ActivityResult(
        xpAwarded: JsonRead.intOr(data, ['xpAwarded', 'xp_awarded'], 0),
        stats: JsonRead.map(data, ['stats']),
      );
    } on FirebaseFunctionsException catch (e, st) {
      _lastFailureTransient = _isTransient(e.code);
      if (!_lastFailureTransient) {
        // Validation/permission problems will not fix themselves: drop.
        reportError(e, st, reason: 'learn.activity.${event.kind}');
      } else if (queueOnFailure) {
        await _enqueue(event);
      }
      return null;
    } catch (e) {
      // Offline, plugin missing, timeout…: keep for later.
      _lastFailureTransient = true;
      if (queueOnFailure) await _enqueue(event);
      return null;
    }
  }

  static bool _isTransient(String code) => const {
        'unavailable',
        'deadline-exceeded',
        'internal',
        'unknown',
        'resource-exhausted',
        'aborted',
        'cancelled',
      }.contains(code);

  Future<void> _enqueue(ActivityEvent e) async {
    try {
      final list = await _load();
      if (list.any((x) => x.dedupeKey == e.dedupeKey)) return;
      list.add(e);
      await _save(list.length > _maxQueued ? list.sublist(list.length - _maxQueued) : list);
    } catch (_) {
      // Best effort only.
    }
  }

  Future<List<ActivityEvent>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.map(ActivityEvent.fromJson).whereType<ActivityEvent>().toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<ActivityEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    if (events.isEmpty) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
    }
  }
}
