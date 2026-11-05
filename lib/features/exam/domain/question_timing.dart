import 'dart:math' as math;

import 'json_utils.dart';

/// Time spent on each question of the open section (ARCHITECTURE §9.5).
///
/// Counts only while a question is actually on screen: [focus] switches the
/// running clock to another question (or stops it with `null`), [pause] /
/// [resume] follow the app lifecycle. It is a plain object owned by the
/// runner controller, deliberately outside the widget state, so ticking time
/// never rebuilds anything.
///
/// Every value is capped at the section duration, which is also what the
/// server accepts (`timings: {questionId: 0..durationSec}`). Clock jumps
/// backwards are ignored.
class QuestionTimer {
  QuestionTimer({
    required this.sectionId,
    required this.capSeconds,
    Map<String, int>? initialMs,
  }) : _ms = {...?initialMs};

  /// Section the timings belong to; a new section starts a new timer.
  final String sectionId;

  /// Section duration in seconds (upper bound per question).
  final int capSeconds;

  final Map<String, int> _ms;
  String? _active;
  DateTime? _since;
  bool _paused = false;

  int get _capMs => math.max(0, capSeconds) * 1000;

  String? get activeQuestionId => _active;
  bool get isPaused => _paused;
  bool get isRunning => _since != null;

  /// [questionId] is now on screen (null: no question is visible, e.g. the
  /// section interstitial or the "submitting" screen).
  void focus(String? questionId, DateTime now) {
    if (questionId == _active && (_paused || _since != null || questionId == null)) return;
    _flush(now);
    _active = questionId;
    _since = (questionId != null && !_paused) ? now : null;
  }

  /// The app went to the background (or the screen is covered).
  void pause(DateTime now) {
    if (_paused) return;
    _flush(now);
    _paused = true;
    _since = null;
  }

  void resume(DateTime now) {
    if (!_paused) return;
    _paused = false;
    _since = _active == null ? null : now;
  }

  void _flush(DateTime now) {
    final id = _active;
    final since = _since;
    if (id == null || since == null) return;
    final delta = now.difference(since).inMilliseconds;
    if (delta > 0) _ms[id] = math.min((_ms[id] ?? 0) + delta, _capMs);
    _since = now;
  }

  /// Accumulated milliseconds per question as of [now] (running time
  /// included), capped at the section duration.
  Map<String, int> millisAt(DateTime now) {
    _flush(now);
    return Map.unmodifiable(_ms);
  }

  /// Whole seconds per question for `examSubmitSection`, restricted to
  /// [questionIds] when given and clamped to `0..capSeconds`.
  Map<String, int> secondsAt(DateTime now, {Iterable<String>? questionIds}) {
    final ms = millisAt(now);
    final allowed = questionIds?.toSet();
    return {
      for (final e in ms.entries)
        if (allowed == null || allowed.contains(e.key))
          e.key: (e.value / 1000).round().clamp(0, math.max(0, capSeconds)),
    };
  }

  /// Persisted form (Hive): only finished intervals; a restored timer starts
  /// paused-free with no running question until the runner focuses one.
  Map<String, dynamic> toJson(DateTime now) => {
        'v': 1,
        'section_id': sectionId,
        'cap_sec': capSeconds,
        'ms': millisAt(now),
      };

  /// Restores a timer saved with [toJson], or null when it is unreadable.
  static QuestionTimer? fromJson(Object? json) {
    final m = asJsonMap(json);
    final section = asString(m['section_id']);
    if (section == null || section.isEmpty) return null;
    final cap = asInt(m['cap_sec']) ?? 0;
    final ms = <String, int>{};
    asJsonMap(m['ms']).forEach((k, v) {
      final n = asInt(v);
      if (n != null && n > 0) ms[k] = math.min(n, math.max(0, cap) * 1000);
    });
    return QuestionTimer(sectionId: section, capSeconds: cap, initialMs: ms);
  }
}
