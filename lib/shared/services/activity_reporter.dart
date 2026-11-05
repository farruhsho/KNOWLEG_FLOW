import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
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

  /// Study time of this activity (ARCHITECTURE §9.5); the server accepts
  /// 0..[maxSeconds].
  final int? seconds;

  static const maxSeconds = 3600;

  /// Client id of this report (ARCHITECTURE §9.7): created once when the
  /// event is built and kept in the offline queue, so every retry carries
  /// the same id and the server credits [seconds] at most once per report,
  /// even when an earlier response was lost.
  final String reportId;

  /// A [reportId] the server accepts: 8..64 of `[A-Za-z0-9_-]`.
  static final RegExp reportIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,64}$');

  static const _reportIdAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
  static const _reportIdLength = 22; // 132 random bits.
  static Random? _random;

  /// A fresh random [reportId].
  @visibleForTesting
  static String newReportId([Random? random]) {
    final r = random ?? (_random ??= _secureRandom());
    return String.fromCharCodes([
      for (var i = 0; i < _reportIdLength; i++) _reportIdAlphabet.codeUnitAt(r.nextInt(_reportIdAlphabet.length)),
    ]);
  }

  static Random _secureRandom() {
    try {
      return Random.secure();
    } on UnsupportedError {
      return Random(DateTime.now().microsecondsSinceEpoch);
    }
  }

  /// [reportId] is passed only when an event is restored from the queue; a
  /// missing (queued by an older build) or malformed id gets a fresh one.
  ActivityEvent({
    required this.kind,
    required this.refId,
    this.correct,
    this.count,
    this.seconds,
    String? reportId,
  }) : reportId = reportId != null && reportIdPattern.hasMatch(reportId) ? reportId : newReportId();

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'refId': refId,
        if (correct != null) 'correct': correct,
        if (count != null) 'count': count,
        if (seconds != null) 'seconds': seconds!.clamp(0, maxSeconds),
        'reportId': reportId,
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
      seconds: JsonRead.integer(m, ['seconds']),
      reportId: JsonRead.string(m, ['reportId']),
    );
  }

  String get dedupeKey => '$kind:$refId';
}

/// Sends one `recordActivity` payload and returns the response data.
typedef ActivityCall = Future<Object?> Function(Map<String, dynamic> payload);

/// Callables cannot run on this platform (thrown before any network call).
class _CallablesUnsupported implements Exception {
  const _CallablesUnsupported();
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
/// retried on the next report/flush. A retry can reach the server twice when
/// only the response was lost. XP stays right because the server awards it
/// once per (kind, refId) (practice sessions use a unique session id, lessons
/// award XP once per lesson). Study time stays right because the queued event
/// keeps its [ActivityEvent.reportId], and the server credits `seconds` at
/// most once per reportId (ARCHITECTURE §9.7).
class ActivityReporter {
  ActivityReporter._([ActivityCall? call]) : _call = call ?? _callBackend;
  static final ActivityReporter instance = ActivityReporter._();

  /// A reporter that sends through [call] instead of the callable (tests).
  @visibleForTesting
  factory ActivityReporter.withCall(ActivityCall call) => ActivityReporter._(call);

  final ActivityCall _call;

  static Future<Object?> _callBackend(Map<String, dynamic> payload) async {
    if (!FirebaseService.supportsCallables) {
      // No App Check on this platform (Windows/Linux, web without a site
      // key): the server would reject the call, and retrying cannot help.
      throw const _CallablesUnsupported();
    }
    final res = await BackendFunctions.callable(
      BackendFunctions.recordActivity,
      timeout: const Duration(seconds: 20),
    ).call<Object?>(payload);
    return res.data;
  }

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
    try {
      final res = await _call(event.toJson());
      _lastFailureTransient = false;
      final data = JsonRead.asMap(res) ?? const <String, dynamic>{};
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
    } on _CallablesUnsupported {
      _lastFailureTransient = false;
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
