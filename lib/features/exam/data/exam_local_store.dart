import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../domain/exam_payload.dart';
import '../domain/exam_session.dart';
import '../domain/json_utils.dart';
import '../domain/localized_text.dart';
import '../domain/question_timing.dart';

/// Lightweight description of a locally saved, unfinished attempt (for the
/// resume banner) — read without restoring the whole session.
@immutable
class LocalAttemptInfo {
  final String attemptId;
  final String? uid;
  final String blueprintId;
  final LocalizedText blueprintTitle;
  final LocalizedText variantTitle;
  final int sectionIndex;
  final int sectionCount;
  final ExamPhase phase;

  /// Device-clock instant of the open section's deadline.
  final DateTime localDeadline;
  final int savedAtMs;

  const LocalAttemptInfo({
    required this.attemptId,
    required this.uid,
    required this.blueprintId,
    required this.blueprintTitle,
    required this.variantTitle,
    required this.sectionIndex,
    required this.sectionCount,
    required this.phase,
    required this.localDeadline,
    required this.savedAtMs,
  });
}

/// Hive box `exam_sessions`: every answer change of an attempt in progress is
/// written here immediately as JSON, so an app kill loses nothing.
///
/// Keys per attempt: `state:<id>` (small; answers, flags, position, phase —
/// rewritten on every change), `content:<id>` (blueprint and the open
/// section's questions — rewritten only when the section changes) and
/// `timing:<id>` (seconds per question of the open section, ARCHITECTURE
/// §9.5 — rewritten when the question changes and every ~20 s).
class ExamLocalStore {
  static const boxName = 'exam_sessions';
  static const _statePrefix = 'state:';
  static const _contentPrefix = 'content:';
  static const _timingPrefix = 'timing:';

  final Future<Box<String>> Function() _openBox;
  Future<Box<String>>? _box;

  ExamLocalStore({Future<Box<String>> Function()? openBox})
      : _openBox = openBox ?? _defaultOpen;

  static Future<Box<String>> _defaultOpen() async => Hive.isBoxOpen(boxName)
      ? Hive.box<String>(boxName)
      : Hive.openBox<String>(boxName);

  Future<Box<String>> get _boxFuture => _box ??= _openBox();

  Future<void> save(
    ExamSession session, {
    bool includeContent = false,
    int? savedAtMs,
  }) async {
    final box = await _boxFuture;
    final id = session.attemptId;
    final now = savedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final contentKey = '$_contentPrefix$id';
    if (includeContent || !box.containsKey(contentKey)) {
      await box.put(contentKey, jsonEncode(session.toContentJson()));
    }
    await box.put('$_statePrefix$id',
        jsonEncode(session.toStateJson(savedAtMs: now)));
  }

  Future<ExamSession?> load(String attemptId) async {
    final box = await _boxFuture;
    final state = _decode(box.get('$_statePrefix$attemptId'));
    final content = _decode(box.get('$_contentPrefix$attemptId'));
    if (state == null || content == null) return null;
    try {
      return ExamSession.fromJson(state, content);
    } catch (e) {
      debugPrint('exam: unreadable local session $attemptId ($e)');
      return null;
    }
  }

  /// Unfinished attempts saved on this device, newest first.
  Future<List<LocalAttemptInfo>> listUnfinished({String? uid}) async {
    final box = await _boxFuture;
    final out = <LocalAttemptInfo>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith(_statePrefix)) continue;
      final state = _decode(box.get(key));
      if (state == null) continue;
      final phase = ExamPhase.parse(state['phase']);
      if (phase == ExamPhase.completed) continue;
      final owner = asString(state['uid']);
      if (uid != null && owner != null && owner != uid) continue;
      final id = key.substring(_statePrefix.length);
      final content = _decode(box.get('$_contentPrefix$id')) ?? const {};
      final bp = asJsonMap(content['blueprint']);
      out.add(LocalAttemptInfo(
        attemptId: id,
        uid: owner,
        blueprintId: asString(state['blueprint_id']) ?? '',
        blueprintTitle: LocalizedText.fromJson(bp['title']),
        variantTitle: LocalizedText.fromJson(content['variant_title']),
        sectionIndex: asInt(state['section_index']) ?? 0,
        sectionCount: asJsonList(bp['sections']).length,
        phase: phase,
        localDeadline: DateTime.fromMillisecondsSinceEpoch(
            (asEpochMs(state['deadline_at']) ?? 0) -
                (asInt(state['clock_offset_ms']) ?? 0)),
        savedAtMs: asInt(state['saved_at']) ?? 0,
      ));
    }
    out.sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return out;
  }

  /// Local section records (answered counts, flags) of an attempt, kept
  /// after completion for the result and review screens.
  Future<Map<String, SectionRecord>> sectionRecords(String attemptId) async {
    final box = await _boxFuture;
    final state = _decode(box.get('$_statePrefix$attemptId'));
    if (state == null) return const {};
    final out = <String, SectionRecord>{};
    for (final r in asJsonList(state['submitted'])) {
      final rec = SectionRecord.fromJson(r);
      out[rec.sectionId] = rec;
    }
    return out;
  }

  /// Server result of a finished attempt as saved locally (needs only the
  /// small state record, so it survives [pruneContent]).
  Future<ExamResult?> loadResult(String attemptId) async {
    final box = await _boxFuture;
    final state = _decode(box.get('$_statePrefix$attemptId'));
    final result = state?['result'];
    return result is Map ? ExamResult.fromJson(result) : null;
  }

  /// Per-question timings of the open section (survive an app kill).
  Future<void> saveTimings(String attemptId, QuestionTimer timer, DateTime now) async {
    final box = await _boxFuture;
    await box.put('$_timingPrefix$attemptId', jsonEncode(timer.toJson(now)));
  }

  Future<QuestionTimer?> loadTimings(String attemptId) async {
    final box = await _boxFuture;
    final raw = _decode(box.get('$_timingPrefix$attemptId'));
    return raw == null ? null : QuestionTimer.fromJson(raw);
  }

  /// Drops the (large) question content and the timings of a finished
  /// attempt but keeps its small state record.
  Future<void> pruneContent(String attemptId) async {
    final box = await _boxFuture;
    await box.deleteAll(['$_contentPrefix$attemptId', '$_timingPrefix$attemptId']);
  }

  Future<void> remove(String attemptId) async {
    final box = await _boxFuture;
    await box.deleteAll([
      '$_statePrefix$attemptId',
      '$_contentPrefix$attemptId',
      '$_timingPrefix$attemptId',
    ]);
  }

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? asJsonMap(v) : null;
    } catch (_) {
      return null;
    }
  }
}
