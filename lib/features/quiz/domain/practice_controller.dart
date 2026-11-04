import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../shared/models/practice_session_model.dart';
import '../../../shared/models/question_model.dart';
import 'practice_launch.dart';

enum PracticeStatus { loading, error, empty, running, finished }

typedef QuestionLoader = Future<List<QuestionModel>> Function(PracticeLaunch launch);

/// State of one practice session: instant feedback after each answer,
/// skipping, honest elapsed time. Free of Flutter widgets and Firebase so it
/// can be unit tested; the loader is injected.
class PracticeController extends ChangeNotifier {
  final PracticeLaunch launch;
  final QuestionLoader _loader;
  final DateTime Function() _now;

  PracticeController({
    required this.launch,
    required QuestionLoader loader,
    DateTime Function()? clock,
  })  : _loader = loader,
        _now = clock ?? DateTime.now;

  PracticeStatus _status = PracticeStatus.loading;
  Object? _error;
  List<QuestionModel> _questions = const [];
  final Map<String, PracticeAnswer> _answers = {};
  int _index = 0;
  DateTime? _startedAt;
  DateTime? _questionShownAt;
  PracticeSessionResult? _result;
  final String sessionId = _newSessionId();

  PracticeStatus get status => _status;
  Object? get error => _error;
  List<QuestionModel> get questions => _questions;
  int get index => _index;
  int get total => _questions.length;
  DateTime get startedAt => _startedAt ?? _now();
  QuestionModel? get current =>
      _status == PracticeStatus.running && _index < _questions.length ? _questions[_index] : null;
  PracticeAnswer? get currentAnswer => current == null ? null : _answers[current!.id];
  bool get isAnswered => currentAnswer != null;
  bool get isLast => _index >= _questions.length - 1;
  int get answeredCount => _answers.values.where((a) => !a.isSkipped).length;
  int get correctCount => _answers.values.where((a) => a.isCorrect).length;
  bool get hasProgress => _answers.isNotEmpty;
  PracticeSessionResult? get result => _result;

  Future<void> load() async {
    _status = PracticeStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final loaded = (await _loader(launch)).where((q) => q.isGradable).toList();
      _questions = loaded;
      _answers.clear();
      _index = 0;
      _result = null;
      if (loaded.isEmpty) {
        _status = PracticeStatus.empty;
      } else {
        _status = PracticeStatus.running;
        _startedAt = _now();
        _questionShownAt = _startedAt;
      }
    } catch (e) {
      _error = e;
      _status = PracticeStatus.error;
    }
    notifyListeners();
  }

  /// Locks in [optionId] for the current question and reveals feedback.
  void select(String optionId) {
    final q = current;
    if (q == null || isAnswered) return;
    _answers[q.id] = PracticeAnswer(
      question: q,
      selectedOptionId: optionId,
      outcome: optionId == q.correctAnswer ? PracticeOutcome.correct : PracticeOutcome.wrong,
      elapsedSeconds: _secondsOnQuestion(),
    );
    notifyListeners();
  }

  /// Skips the current question (counts as skipped, not wrong).
  void skip() {
    final q = current;
    if (q == null || isAnswered) return;
    _answers[q.id] = PracticeAnswer(
      question: q,
      selectedOptionId: null,
      outcome: PracticeOutcome.skipped,
      elapsedSeconds: _secondsOnQuestion(),
    );
    next();
  }

  /// Moves on; finishes after the last question.
  void next() {
    if (_status != PracticeStatus.running) return;
    if (isLast) {
      finish();
      return;
    }
    _index++;
    _questionShownAt = _now();
    notifyListeners();
  }

  /// Ends the session now. Unseen questions are not counted at all.
  PracticeSessionResult finish() {
    final existing = _result;
    if (existing != null) return existing;
    final answers = [
      for (final q in _questions)
        if (_answers[q.id] != null) _answers[q.id]!,
    ];
    final r = PracticeSessionResult(
      sessionId: sessionId,
      kind: launch.kind,
      subjectId: launch.subjectId,
      refId: launch.refId,
      answers: answers,
      startedAt: startedAt,
      finishedAt: _now(),
    );
    _result = r;
    _status = PracticeStatus.finished;
    notifyListeners();
    return r;
  }

  int _secondsOnQuestion() {
    final shown = _questionShownAt ?? startedAt;
    final s = _now().difference(shown).inSeconds;
    return s < 0 ? 0 : s;
  }

  static String _newSessionId() {
    final r = Random();
    final rand = List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join();
    return 'p_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_$rand';
  }
}
