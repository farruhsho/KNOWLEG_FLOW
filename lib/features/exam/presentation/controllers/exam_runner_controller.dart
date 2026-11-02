import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/exam_draft_sink.dart';
import '../../data/exam_local_store.dart';
import '../../data/exam_remote_datasource.dart';
import '../../domain/exam_failure.dart';
import '../../domain/exam_session.dart';

/// One-shot messages for the runner UI (snackbars).
enum ExamRunnerNotice { fiveMinutesLeft, oneMinuteLeft, autoSubmitted }

@immutable
class ExamRunnerState {
  final bool loading;

  /// Fatal: nothing to show (no local copy and the server call failed).
  final ExamFailure? loadFailure;
  final ExamSession? session;

  /// The last server sync failed; running from the local copy.
  final bool offline;

  /// Why the last section submission failed (while in submitPending).
  final ExamFailure? submitFailure;
  final ExamRunnerNotice? notice;
  final int noticeSeq;

  const ExamRunnerState({
    this.loading = true,
    this.loadFailure,
    this.session,
    this.offline = false,
    this.submitFailure,
    this.notice,
    this.noticeSeq = 0,
  });

  ExamRunnerState copyWith({
    bool? loading,
    ExamFailure? loadFailure,
    bool clearLoadFailure = false,
    ExamSession? session,
    bool? offline,
    ExamFailure? submitFailure,
    bool clearSubmitFailure = false,
    ExamRunnerNotice? notice,
    int? noticeSeq,
  }) =>
      ExamRunnerState(
        loading: loading ?? this.loading,
        loadFailure: clearLoadFailure ? null : (loadFailure ?? this.loadFailure),
        session: session ?? this.session,
        offline: offline ?? this.offline,
        submitFailure:
            clearSubmitFailure ? null : (submitFailure ?? this.submitFailure),
        notice: notice ?? this.notice,
        noticeSeq: noticeSeq ?? this.noticeSeq,
      );

  ExamPhase? get phase => session?.phase;
}

/// Drives one attempt: restores it (local first, then the server), applies
/// edits to the pure [ExamSession], persists every change to Hive at once,
/// syncs drafts every [draftInterval] and when the app goes to background,
/// fires timer warnings and auto-submits at the deadline.
class ExamRunnerController extends StateNotifier<ExamRunnerState> {
  final String attemptId;
  final ExamRemoteDataSource _remote;
  final ExamLocalStore _store;
  final ExamDraftSink _drafts;
  final ExamClock _clock;
  final String? _uid;
  final Duration tickInterval;
  final Duration draftInterval;
  final Duration retryInterval;

  Timer? _ticker;
  Timer? _draftTimer;
  bool _draftDirty = false;
  bool _submitting = false;
  DateTime? _lastAutoRetry;
  Future<void> _saveChain = Future.value();

  ExamRunnerController({
    required this.attemptId,
    required ExamRemoteDataSource remote,
    required ExamLocalStore store,
    required ExamDraftSink drafts,
    required ExamClock clock,
    String? uid,
    this.tickInterval = const Duration(seconds: 1),
    this.draftInterval = const Duration(seconds: 20),
    this.retryInterval = const Duration(seconds: 15),
    bool autoLoad = true,
  })  : _remote = remote,
        _store = store,
        _drafts = drafts,
        _clock = clock,
        _uid = uid,
        super(const ExamRunnerState()) {
    if (autoLoad) load();
  }

  // ------------------------------------------------------------- loading

  Future<void> load() async {
    state = state.copyWith(loading: true, clearLoadFailure: true);
    ExamSession? local;
    try {
      local = await _store.load(attemptId);
    } catch (e) {
      debugPrint('exam: local load failed ($e)');
    }
    if (!mounted) return;
    if (local != null && (local.uid == null || _uid == null || local.uid == _uid)) {
      state = state.copyWith(loading: false, session: local);
      _startTimers();
    }
    await _syncWithServer(initial: true);
  }

  Future<void> _syncWithServer({bool initial = false}) async {
    try {
      final payload = await _remote.getState(attemptId);
      if (!mounted) return;
      final now = _clock();
      final current = state.session;
      final next = current == null
          ? ExamSession.fromPayload(payload, clientNow: now, uid: _uid)
          : current.reconcile(payload, clientNow: now);
      _commit(next, content: true);
      state = state.copyWith(loading: false, offline: false);
      _startTimers();
      if (next.phase == ExamPhase.submitPending) {
        unawaited(submitSection());
      } else if (next.phase == ExamPhase.submitting && !_submitting) {
        _commit(next.submitFailed());
      }
    } on ExamFailure catch (f) {
      if (!mounted) return;
      final current = state.session;
      if (f.kind == ExamFailureKind.attemptNotInProgress && current != null) {
        _commit(current.complete(null));
        state = state.copyWith(loading: false);
        return;
      }
      if (current == null) {
        state = state.copyWith(loading: false, loadFailure: f);
      } else {
        state = state.copyWith(loading: false, offline: true);
        if (current.phase == ExamPhase.submitting && !_submitting) {
          _commit(current.submitFailed());
        }
      }
    } catch (e) {
      if (!mounted) return;
      final f = ExamFailure(ExamFailureKind.unknown, e.toString());
      if (state.session == null) {
        state = state.copyWith(loading: false, loadFailure: f);
      } else {
        state = state.copyWith(loading: false, offline: true);
      }
    }
  }

  // --------------------------------------------------------------- edits

  void selectAnswer(String questionId, String optionId) =>
      _edit((s, now) => s.answer(questionId, optionId, now: now), dirty: true);

  void clearAnswer(String questionId) =>
      _edit((s, now) => s.clearAnswer(questionId, now: now), dirty: true);

  void toggleFlag(String questionId) =>
      _edit((s, now) => s.toggleFlag(questionId, now: now), dirty: true);

  void goTo(int index) => _edit((s, _) => s.goTo(index));
  void next() => _edit((s, _) => s.next());
  void previous() => _edit((s, _) => s.previous());

  /// Leaves the section interstitial.
  void startSection() => _edit((s, _) => s.startSection());

  void _edit(ExamSession Function(ExamSession s, DateTime now) f,
      {bool dirty = false}) {
    final s = state.session;
    if (s == null) return;
    final next = f(s, _clock());
    if (identical(next, s)) return;
    if (dirty) _draftDirty = true;
    _commit(next);
  }

  void _commit(ExamSession session, {bool content = false}) {
    if (!mounted) return;
    state = state.copyWith(session: session);
    // Serialise writes so an older snapshot can never land after a newer one.
    _saveChain = _saveChain.then((_) async {
      try {
        await _store.save(session,
            includeContent: content,
            savedAtMs: _clock().millisecondsSinceEpoch);
      } catch (e) {
        debugPrint('exam: local save failed ($e)');
      }
    });
  }

  /// Completes when every local write issued so far has finished.
  Future<void> get pendingWrites => _saveChain;

  // ------------------------------------------------------------ submission

  /// Closes the open section (after the user confirmed, or automatically at
  /// the deadline) and sends it. On failure the section stays locked in
  /// [ExamPhase.submitPending] until a retry succeeds.
  Future<void> submitSection({bool automatic = false}) async {
    final s = state.session;
    if (s == null || _submitting) return;
    if (s.phase != ExamPhase.inSection && s.phase != ExamPhase.submitPending) {
      return;
    }
    _submitting = true;
    try {
      final locked = s.beginSubmit(now: _clock(), automatic: automatic);
      _commit(locked);
      state = state.copyWith(clearSubmitFailure: true);
      final submission = locked.pendingSubmission!;
      _syncDraftNow(locked, force: true);
      final response = await _remote.submitSection(submission);
      if (!mounted) return;
      final current = state.session!;
      final now = _clock();
      final ExamSession next;
      if (response.completed || response.next == null) {
        next = current.complete(response.result);
      } else {
        next = current.acceptNextSection(response.next!, clientNow: now);
      }
      _draftDirty = false;
      _commit(next, content: true);
      state = state.copyWith(offline: false);
      if (submission.automatic) _notify(ExamRunnerNotice.autoSubmitted);
    } on ExamFailure catch (f) {
      if (!mounted) return;
      if (f.kind == ExamFailureKind.wrongSection ||
          f.kind == ExamFailureKind.attemptNotInProgress) {
        // The server already moved past this section: adopt its state.
        _submitting = false;
        await _syncWithServer();
        return;
      }
      _commit(state.session!.submitFailed());
      state = state.copyWith(
          submitFailure: f, offline: f.kind == ExamFailureKind.network);
    } on StateError catch (_) {
      _submitting = false;
      await _syncWithServer();
      return;
    } finally {
      _submitting = false;
    }
  }

  /// Manual "Повторить" on the offline screen.
  Future<void> retrySubmit() => submitSection();

  /// Manual retry when the first load failed.
  Future<void> retryLoad() => load();

  // ------------------------------------------------------------- drafts

  /// Sends the draft now (e.g. on AppLifecycleState.paused).
  void flushDraft() {
    final s = state.session;
    if (s != null) _syncDraftNow(s);
  }

  void _syncDraftNow(ExamSession s, {bool force = false}) {
    if (!force && !_draftDirty) return;
    if (s.phase != ExamPhase.inSection && !force) return;
    _draftDirty = false;
    final answers = <String, String>{
      for (final q in s.questions)
        if (s.answers[q.id] != null) q.id: s.answers[q.id]!,
    };
    final flags = [
      for (final q in s.questions)
        if (s.flags.contains(q.id)) q.id,
    ];
    // Firestore queues the write offline; never block the UI on it.
    unawaited(_drafts
        .writeDraft(
          attemptId: s.attemptId,
          sectionId: s.section.sectionId,
          answers: answers,
          flags: flags,
        )
        .catchError((Object e) => debugPrint('exam: draft write failed ($e)')));
  }

  // -------------------------------------------------------------- timers

  void _startTimers() {
    _ticker ??= Timer.periodic(tickInterval, (_) => tick());
    _draftTimer ??= Timer.periodic(draftInterval, (_) {
      final s = state.session;
      if (s != null) _syncDraftNow(s);
    });
  }

  /// One clock step: warnings, auto-submit, periodic retry. Public for tests.
  void tick() {
    final s = state.session;
    if (s == null || !mounted) return;
    final now = _clock();
    final warning = s.dueWarning(now);
    if (warning != null) {
      _commit(s.markWarned(warning));
      _notify(warning == TimerWarning.oneMinute
          ? ExamRunnerNotice.oneMinuteLeft
          : ExamRunnerNotice.fiveMinutesLeft);
    }
    final current = state.session!;
    if (current.shouldAutoSubmit(now)) {
      unawaited(submitSection(automatic: true));
    } else if (current.phase == ExamPhase.submitPending && !_submitting) {
      final last = _lastAutoRetry;
      if (last == null || now.difference(last) >= retryInterval) {
        _lastAutoRetry = now;
        unawaited(submitSection());
      }
    }
  }

  void _notify(ExamRunnerNotice n) {
    if (!mounted) return;
    state = state.copyWith(notice: n, noticeSeq: state.noticeSeq + 1);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _draftTimer?.cancel();
    final s = state.session;
    if (s != null && s.phase == ExamPhase.inSection) _syncDraftNow(s);
    super.dispose();
  }
}
