import 'package:flutter/foundation.dart';

import 'exam_blueprint.dart';
import 'exam_payload.dart';
import 'exam_question.dart';
import 'exam_start.dart';
import 'json_utils.dart';
import 'localized_text.dart';

/// Injectable wall clock (device time). Tests pass a fake.
typedef ExamClock = DateTime Function();

enum ExamPhase {
  /// The student is answering the current section.
  inSection,

  /// The section was closed and is being sent to the server.
  submitting,

  /// Sending failed (usually no connection). Answers are kept locally and the
  /// next section does not start until the server accepts this one.
  submitPending,

  /// The server accepted the previous section and opened the next one;
  /// showing the interstitial with the next section's rules.
  sectionIntro,

  /// The attempt is finished (result may still be loading).
  completed;

  static ExamPhase parse(Object? v) => ExamPhase.values.firstWhere(
        (p) => p.name == v,
        orElse: () => ExamPhase.inSection,
      );
}

enum TimerWarning { fiveMinutes, oneMinute }

/// What the client sends to `examSubmitSection`.
@immutable
class SectionSubmission {
  final String attemptId;
  final String sectionId;

  /// Every question of the section, `null` when unanswered.
  final Map<String, String?> answers;
  final List<String> flags;
  final int clientElapsedSec;
  final bool automatic;

  /// Seconds each question was on screen (ARCHITECTURE §9.5), capped at the
  /// section duration. Empty when nothing was measured (older sessions).
  final Map<String, int> timings;

  const SectionSubmission({
    required this.attemptId,
    required this.sectionId,
    required this.answers,
    required this.flags,
    required this.clientElapsedSec,
    this.automatic = false,
    this.timings = const {},
  });

  Map<String, dynamic> toCallableData() => {
        'attemptId': attemptId,
        'sectionId': sectionId,
        'answers': answers,
        'flags': flags,
        'clientElapsedSec': clientElapsedSec,
        if (timings.isNotEmpty) 'timings': timings,
      };

  Map<String, dynamic> toJson() => {
        ...toCallableData(),
        'automatic': automatic,
      };

  factory SectionSubmission.fromJson(Object? json) {
    final m = asJsonMap(json);
    return SectionSubmission(
      attemptId: asString(m['attemptId']) ?? '',
      sectionId: asString(m['sectionId']) ?? '',
      answers: asJsonMap(m['answers']).map((k, v) => MapEntry(k, asString(v))),
      flags: asStringList(m['flags']),
      clientElapsedSec: asInt(m['clientElapsedSec']) ?? 0,
      automatic: asBool(m['automatic']),
      timings: {
        for (final e in asJsonMap(m['timings']).entries)
          if (asInt(e.value) case final v? when v >= 0) e.key: v,
      },
    );
  }
}

/// Local record of a section the server has accepted (used for the
/// "skipped" count and the "flagged" review filter — the server's result
/// does not carry them).
@immutable
class SectionRecord {
  final String sectionId;
  final int answered;
  final int total;
  final List<String> flags;

  const SectionRecord({
    required this.sectionId,
    required this.answered,
    required this.total,
    this.flags = const [],
  });

  Map<String, dynamic> toJson() => {
        'section_id': sectionId,
        'answered': answered,
        'total': total,
        'flags': flags,
      };

  factory SectionRecord.fromJson(Object? json) {
    final m = asJsonMap(json);
    return SectionRecord(
      sectionId: asString(m['section_id']) ?? '',
      answered: asInt(m['answered']) ?? 0,
      total: asInt(m['total']) ?? 0,
      flags: asStringList(m['flags']),
    );
  }
}

/// Status of one question cell in the palette.
@immutable
class QuestionCellState {
  final bool answered;
  final bool flagged;
  final bool current;

  const QuestionCellState({
    required this.answered,
    required this.flagged,
    required this.current,
  });

  @override
  bool operator ==(Object other) =>
      other is QuestionCellState &&
      other.answered == answered &&
      other.flagged == flagged &&
      other.current == current;

  @override
  int get hashCode => Object.hash(answered, flagged, current);
}

/// Pure, immutable state machine of one exam attempt on the client.
///
/// Rules (ARCHITECTURE §4):
/// * free navigation between questions of the current section;
/// * forward-only across sections — a submitted section never reopens;
/// * the section deadline is the server's `deadlineAt`, compared against
///   device time corrected by `serverNow` (clock skew);
/// * warnings at 5 and 1 minute, automatic submission at 0.
///
/// Strict style («Как на ОРТ», §10.2) adds: an instruction screen before
/// every section (the first one included), an answer can be chosen and then
/// corrected once (a third choice is refused), no flags, no clearing, and no
/// early finish — the section is sent only at its deadline.
///
/// Every transition returns a new instance; a transition that is not allowed
/// in the current state returns `this` unchanged.
@immutable
class ExamSession {
  final String attemptId;
  final String variantId;
  final String? uid;
  final String language;
  final ExamBlueprint blueprint;
  final LocalizedText variantTitle;
  final int sectionIndex;
  final SectionPayload section;

  /// `serverNow - deviceNow` at the moment the payload was received.
  final int clockOffsetMs;
  final Map<String, String> answers;
  final Set<String> flags;
  final int currentIndex;
  final ExamPhase phase;
  final Set<TimerWarning> warned;
  final Map<String, SectionRecord> submitted;
  final SectionSubmission? pendingSubmission;
  final ExamResult? result;

  /// Standard («Тренировка») or strict («Как на ОРТ», §10.2).
  final ExamStyle style;

  /// Strict style: how many times an option was chosen per question of the
  /// open section (1 = first choice, 2 = corrected once — the limit). Saved
  /// with the session so the limit survives an app restart. Empty in
  /// standard style.
  final Map<String, int> choiceCounts;

  /// Repeated questions of a fresh variant (§10.1), shown once at the start.
  final ExamFreshness? freshness;

  const ExamSession._({
    required this.attemptId,
    required this.variantId,
    required this.uid,
    required this.language,
    required this.blueprint,
    required this.variantTitle,
    required this.sectionIndex,
    required this.section,
    required this.clockOffsetMs,
    required this.answers,
    required this.flags,
    required this.currentIndex,
    required this.phase,
    required this.warned,
    required this.submitted,
    required this.pendingSubmission,
    required this.result,
    this.style = ExamStyle.standard,
    this.choiceCounts = const {},
    this.freshness,
  });

  /// Builds a session from a server payload received at [clientNow].
  ///
  /// [style] is what the client asked `examStart` for; the payload's own
  /// `examStyle` wins when the server reports it.
  factory ExamSession.fromPayload(
    ExamSessionPayload payload, {
    required DateTime clientNow,
    ExamBlueprint? blueprint,
    String? uid,
    String? fallbackLanguage,
    LocalizedText? variantTitle,
    ExamStyle? style,
  }) {
    final bp = payload.blueprint ?? blueprint;
    final section = payload.section;
    if (bp == null || bp.sections.isEmpty) {
      throw ArgumentError('Exam payload has no blueprint');
    }
    if (section == null && !payload.isCompleted) {
      throw ArgumentError('Exam payload has no open section');
    }
    final lang = payload.language ??
        (fallbackLanguage != null ? bp.languageFor(fallbackLanguage) : null) ??
        bp.languages.first;
    final effectiveStyle = payload.examStyle ?? style ?? ExamStyle.standard;
    return ExamSession._(
      attemptId: payload.attemptId,
      variantId: payload.variantId,
      uid: uid,
      language: lang,
      blueprint: bp,
      variantTitle: payload.variantTitle.isEmpty
          ? (variantTitle ?? LocalizedText.empty)
          : payload.variantTitle,
      sectionIndex: payload.currentSectionIndex,
      section: section ??
          SectionPayload(
            sectionId: bp.sections.last.id,
            deadlineAtMs: payload.serverNowMs,
            durationSec: 0,
            questions: const [],
          ),
      clockOffsetMs: payload.serverNowMs - clientNow.millisecondsSinceEpoch,
      answers: const {},
      flags: const {},
      currentIndex: 0,
      // Strict: the first section also opens with its instruction screen.
      phase: payload.isCompleted
          ? ExamPhase.completed
          : effectiveStyle.isStrict
              ? ExamPhase.sectionIntro
              : ExamPhase.inSection,
      warned: const {},
      submitted: const {},
      pendingSubmission: null,
      result: payload.result,
      style: effectiveStyle,
      freshness: payload.freshness,
    );
  }

  ExamSession _copy({
    String? language,
    LocalizedText? variantTitle,
    int? sectionIndex,
    SectionPayload? section,
    int? clockOffsetMs,
    Map<String, String>? answers,
    Set<String>? flags,
    int? currentIndex,
    ExamPhase? phase,
    Set<TimerWarning>? warned,
    Map<String, SectionRecord>? submitted,
    SectionSubmission? pendingSubmission,
    bool clearPending = false,
    ExamResult? result,
    Map<String, int>? choiceCounts,
  }) =>
      ExamSession._(
        attemptId: attemptId,
        variantId: variantId,
        uid: uid,
        language: language ?? this.language,
        blueprint: blueprint,
        variantTitle: variantTitle ?? this.variantTitle,
        sectionIndex: sectionIndex ?? this.sectionIndex,
        section: section ?? this.section,
        clockOffsetMs: clockOffsetMs ?? this.clockOffsetMs,
        answers: answers ?? this.answers,
        flags: flags ?? this.flags,
        currentIndex: currentIndex ?? this.currentIndex,
        phase: phase ?? this.phase,
        warned: warned ?? this.warned,
        submitted: submitted ?? this.submitted,
        pendingSubmission:
            clearPending ? null : (pendingSubmission ?? this.pendingSubmission),
        result: result ?? this.result,
        style: style,
        choiceCounts: choiceCounts ?? this.choiceCounts,
        freshness: freshness,
      );

  // ---------------------------------------------------------------- queries

  List<ExamQuestion> get questions => section.questions;
  int get questionCount => questions.length;
  bool get hasQuestions => questions.isNotEmpty;

  ExamQuestion? get currentQuestion =>
      hasQuestions ? questions[currentIndex.clamp(0, questionCount - 1)] : null;

  /// Blueprint description of the open section.
  ExamSection get sectionSpec =>
      blueprint.sectionById(section.sectionId) ??
      blueprint.sections[sectionIndex.clamp(0, blueprint.sections.length - 1)];

  int get sectionCount => blueprint.sections.length;
  bool get isLastSection => sectionIndex >= sectionCount - 1;

  /// Next section in the blueprint, if any.
  ExamSection? get nextSectionSpec =>
      isLastSection ? null : blueprint.sections[sectionIndex + 1];

  int get answeredCount =>
      questions.where((q) => answers.containsKey(q.id)).length;
  int get unansweredCount => questionCount - answeredCount;
  int get flaggedCount => questions.where((q) => flags.contains(q.id)).length;

  int serverNowMs(DateTime clientNow) =>
      clientNow.millisecondsSinceEpoch + clockOffsetMs;

  /// Time left in the open section according to the (skew-corrected) server
  /// clock. Never negative.
  Duration remaining(DateTime clientNow) {
    final ms = section.deadlineAtMs - serverNowMs(clientNow);
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  /// Device-clock instant at which the section deadline is reached.
  DateTime localDeadline() => DateTime.fromMillisecondsSinceEpoch(
      section.deadlineAtMs - clockOffsetMs);

  bool isExpired(DateTime clientNow) => remaining(clientNow) == Duration.zero;

  bool canEdit(DateTime clientNow) =>
      phase == ExamPhase.inSection && !isExpired(clientNow);

  String? answerOf(String questionId) => answers[questionId];
  bool isFlagged(String questionId) => flags.contains(questionId);

  bool get isStrict => style.isStrict;

  /// Strict style has no "come back later" flags (§10.2).
  bool get allowsFlags => !isStrict;

  /// Strict style: the section is sent only at its deadline.
  bool get canFinishEarly => !isStrict;

  /// Strict style: an answer cannot be removed, only corrected once.
  bool get allowsClearing => !isStrict;

  /// Strict: the most choices per question (the first one + one correction).
  static const int strictMaxChoices = 2;

  /// Times an option was chosen for [questionId] in the open section. An
  /// answer restored without a count (older local copy) counts as one.
  int choicesMade(String questionId) {
    final n = choiceCounts[questionId] ?? 0;
    return answers.containsKey(questionId) && n < 1 ? 1 : n;
  }

  /// Strict: the answer was already corrected; another option is refused.
  bool isAnswerLocked(String questionId) =>
      isStrict &&
      answers.containsKey(questionId) &&
      choicesMade(questionId) >= strictMaxChoices;

  QuestionCellState cell(int index) {
    final q = questions[index];
    return QuestionCellState(
      answered: answers.containsKey(q.id),
      flagged: flags.contains(q.id),
      current: index == currentIndex,
    );
  }

  /// Part of the section the question at [index] belongs to.
  ExamPart partAt(int index) {
    final spec = sectionSpec;
    if (index >= 0 && index < questionCount) {
      final byId = spec.partById(questions[index].partId);
      if (byId != null) return byId;
    }
    return spec.partForIndex(index);
  }

  /// Options to show for [question]: the blueprint's fixed options (e.g. the
  /// four quantitative-comparison answers, in the exam language) when the
  /// part defines them, otherwise the question's own options.
  List<QuestionOption> optionsFor(int index) {
    final q = questions[index];
    final part = partAt(index);
    if (part.fixedOptions.isNotEmpty &&
        (q.options.isEmpty ||
            part.itemType == ExamItemType.quantitativeComparison)) {
      return part.fixedOptions
          .map((o) => QuestionOption(id: o.id, text: o.text.resolve(language)))
          .toList(growable: false);
    }
    return q.options;
  }

  ExamPassage? passageFor(ExamQuestion q) =>
      q.passageId == null ? null : section.passages[q.passageId];

  /// Warning that should be shown now, if any (each fires once per section).
  TimerWarning? dueWarning(DateTime clientNow) {
    if (phase != ExamPhase.inSection) return null;
    final left = remaining(clientNow);
    if (left == Duration.zero) return null;
    if (left <= const Duration(minutes: 1) &&
        !warned.contains(TimerWarning.oneMinute)) {
      return TimerWarning.oneMinute;
    }
    if (left <= const Duration(minutes: 5) &&
        !warned.contains(TimerWarning.fiveMinutes) &&
        !warned.contains(TimerWarning.oneMinute)) {
      return TimerWarning.fiveMinutes;
    }
    return null;
  }

  /// The open section must be sent now: its time is up. In strict style
  /// this also applies while the instruction screen is still shown (the
  /// section's time runs there too, and it is sent only at the deadline).
  bool shouldAutoSubmit(DateTime clientNow) =>
      _canClose && isExpired(clientNow);

  bool get _canClose =>
      phase == ExamPhase.inSection ||
      (isStrict && phase == ExamPhase.sectionIntro);

  /// Whether [beginSubmit] may close the section now: in strict style only
  /// once its time is up (the server answers SECTION_NOT_OVER otherwise).
  bool canSubmit(DateTime clientNow) {
    if (phase == ExamPhase.submitPending) return pendingSubmission != null;
    if (!_canClose) return false;
    return !isStrict || isExpired(clientNow);
  }

  // ------------------------------------------------------------ transitions

  ExamSession answer(String questionId, String optionId,
      {required DateTime now}) {
    if (!canEdit(now)) return this;
    final index = questions.indexWhere((q) => q.id == questionId);
    if (index < 0) return this;
    if (!optionsFor(index).any((o) => o.id == optionId)) return this;
    if (answers[questionId] == optionId) return this;
    final nextAnswers = Map<String, String>.unmodifiable(
        {...answers, questionId: optionId});
    if (!isStrict) return _copy(answers: nextAnswers);
    // Strict: first choice, then one correction — a third choice is refused.
    if (isAnswerLocked(questionId)) return this;
    return _copy(
      answers: nextAnswers,
      choiceCounts: Map.unmodifiable(
          {...choiceCounts, questionId: choicesMade(questionId) + 1}),
    );
  }

  ExamSession clearAnswer(String questionId, {required DateTime now}) {
    if (!allowsClearing) return this;
    if (!canEdit(now) || !answers.containsKey(questionId)) return this;
    final next = Map<String, String>.of(answers)..remove(questionId);
    return _copy(answers: Map.unmodifiable(next));
  }

  ExamSession toggleFlag(String questionId, {required DateTime now}) {
    if (!allowsFlags) return this;
    if (!canEdit(now)) return this;
    if (!questions.any((q) => q.id == questionId)) return this;
    final next = Set<String>.of(flags);
    if (!next.remove(questionId)) next.add(questionId);
    return _copy(flags: Set.unmodifiable(next));
  }

  ExamSession goTo(int index) {
    if (phase != ExamPhase.inSection) return this;
    if (index < 0 || index >= questionCount || index == currentIndex) {
      return this;
    }
    if (!blueprint.freeNavigationWithinSection && index < currentIndex) {
      return this;
    }
    return _copy(currentIndex: index);
  }

  ExamSession next() => goTo(currentIndex + 1);
  ExamSession previous() => goTo(currentIndex - 1);

  ExamSession markWarned(TimerWarning w) {
    final next = {...warned, w};
    if (w == TimerWarning.oneMinute) next.add(TimerWarning.fiveMinutes);
    return _copy(warned: Set.unmodifiable(next));
  }

  /// Closes the section and prepares the payload for `examSubmitSection`.
  /// From [ExamPhase.submitPending] the original submission is reused, so a
  /// retry sends exactly what was locked in.
  ///
  /// [timings] (seconds per question, see `QuestionTimer`) are sent as they
  /// are, restricted to this section's questions and clamped to
  /// `0..duration`.
  ExamSession beginSubmit({
    required DateTime now,
    bool automatic = false,
    Map<String, int>? timings,
  }) {
    if (phase == ExamPhase.submitPending && pendingSubmission != null) {
      return _copy(phase: ExamPhase.submitting);
    }
    if (!_canClose) return this;
    // Strict: no early finish — the section closes only at its deadline.
    if (isStrict && !isExpired(now)) return this;
    final total = section.durationSec > 0
        ? section.durationSec
        : sectionSpec.durationMinutes * 60;
    final elapsed = (total - remaining(now).inSeconds).clamp(0, total);
    final ids = {for (final q in questions) q.id};
    final submission = SectionSubmission(
      attemptId: attemptId,
      sectionId: section.sectionId,
      answers: {for (final q in questions) q.id: answers[q.id]},
      // Strict attempts have no flags (the server ignores them anyway).
      flags: [
        if (allowsFlags)
          for (final q in questions)
            if (flags.contains(q.id)) q.id,
      ],
      clientElapsedSec: elapsed,
      automatic: automatic,
      timings: {
        for (final e in (timings ?? const <String, int>{}).entries)
          if (ids.contains(e.key)) e.key: e.value.clamp(0, total),
      },
    );
    return _copy(phase: ExamPhase.submitting, pendingSubmission: submission);
  }

  /// Sending failed — keep everything and wait for a retry.
  ExamSession submitFailed() {
    if (phase != ExamPhase.submitting) return this;
    return _copy(phase: ExamPhase.submitPending);
  }

  SectionRecord _recordCurrent() => SectionRecord(
        sectionId: section.sectionId,
        answered: answeredCount,
        total: questionCount,
        flags: [
          for (final q in questions)
            if (flags.contains(q.id)) q.id,
        ],
      );

  /// The server accepted the open section and returned the next one.
  /// Throws [StateError] if [next] would reopen this or an earlier section.
  ExamSession acceptNextSection(ExamSessionPayload next,
      {required DateTime clientNow}) {
    final nextSection = next.section;
    if (nextSection == null) {
      throw ArgumentError('Next payload has no section');
    }
    if (next.currentSectionIndex <= sectionIndex ||
        submitted.containsKey(nextSection.sectionId) ||
        nextSection.sectionId == section.sectionId) {
      throw StateError('Cannot reopen a submitted section');
    }
    return _copy(
      submitted: Map.unmodifiable({
        ...submitted,
        section.sectionId: _recordCurrent(),
      }),
      sectionIndex: next.currentSectionIndex,
      section: nextSection,
      clockOffsetMs: next.serverNowMs - clientNow.millisecondsSinceEpoch,
      answers: const {},
      flags: const {},
      choiceCounts: const {},
      currentIndex: 0,
      warned: const {},
      phase: ExamPhase.sectionIntro,
      clearPending: true,
    );
  }

  /// Leaves the interstitial and shows the next section's questions.
  ExamSession startSection() =>
      phase == ExamPhase.sectionIntro ? _copy(phase: ExamPhase.inSection) : this;

  /// The attempt is finished. [result] may be null when the server finished
  /// it (e.g. it expired) and the result has to be read from the attempt.
  ExamSession complete(ExamResult? result) {
    if (phase == ExamPhase.completed) {
      return result == null ? this : _copy(result: result);
    }
    return _copy(
      submitted: Map.unmodifiable({
        ...submitted,
        section.sectionId: _recordCurrent(),
      }),
      phase: ExamPhase.completed,
      result: result,
      clearPending: true,
    );
  }

  /// Strict style, after SECTION_NOT_OVER: the server reports that the open
  /// section still runs (the device clock was ahead of the estimate). The
  /// section is reopened with the server's clock and deadline; answers and
  /// corrections are kept. Anything else returns `this`.
  ExamSession reopenNotOver(ExamSessionPayload server,
      {required DateTime clientNow}) {
    final sec = server.section;
    if (!isStrict || server.isCompleted || sec == null) return this;
    if (phase != ExamPhase.submitPending && phase != ExamPhase.submitting) {
      return this;
    }
    if (server.currentSectionIndex != sectionIndex ||
        sec.sectionId != section.sectionId) {
      return this;
    }
    final reopened = _copy(
      phase: ExamPhase.inSection,
      clearPending: true,
      clockOffsetMs: server.serverNowMs - clientNow.millisecondsSinceEpoch,
      section: SectionPayload(
        sectionId: section.sectionId,
        deadlineAtMs: sec.deadlineAtMs > 0 ? sec.deadlineAtMs : section.deadlineAtMs,
        durationSec: section.durationSec,
        questions: section.questions,
        passages: section.passages,
      ),
    );
    // A few seconds short is not worth reopening: wait and send again.
    return reopened.remaining(clientNow) > strictReopenThreshold ? reopened : this;
  }

  /// SECTION_NOT_OVER with less time left than this keeps the "sending
  /// shortly" screen instead of reopening the section.
  static const Duration strictReopenThreshold = Duration(seconds: 10);

  /// Merges authoritative server state (from `examGetState`) into the local
  /// session after a restart or reconnect. Local answers of the same open
  /// section win (they are newer than the last draft); a section the server
  /// has already moved past is closed locally and never reopened.
  ExamSession reconcile(ExamSessionPayload server,
      {required DateTime clientNow}) {
    if (server.isCompleted) return complete(server.result);
    final serverSection = server.section;
    final offset = server.serverNowMs - clientNow.millisecondsSinceEpoch;
    if (serverSection == null) return _copy(clockOffsetMs: offset);
    if (server.currentSectionIndex < sectionIndex ||
        submitted.containsKey(serverSection.sectionId)) {
      // Server cannot be behind a section it already accepted; keep local.
      return _copy(clockOffsetMs: offset);
    }
    if (server.currentSectionIndex == sectionIndex &&
        serverSection.sectionId == section.sectionId) {
      return _copy(
        clockOffsetMs: offset,
        section: SectionPayload(
          sectionId: section.sectionId,
          deadlineAtMs: serverSection.deadlineAtMs,
          durationSec: serverSection.durationSec > 0
              ? serverSection.durationSec
              : section.durationSec,
          questions: serverSection.questions.isNotEmpty
              ? serverSection.questions
              : section.questions,
          passages: serverSection.passages.isNotEmpty
              ? serverSection.passages
              : section.passages,
        ),
      );
    }
    // The server moved on (our submission landed but the reply was lost, or
    // the section was closed server-side at its deadline).
    return _copy(
      submitted: Map.unmodifiable({
        ...submitted,
        section.sectionId: _recordCurrent(),
      }),
      sectionIndex: server.currentSectionIndex,
      section: serverSection,
      clockOffsetMs: offset,
      answers: const {},
      flags: const {},
      choiceCounts: const {},
      currentIndex: 0,
      warned: const {},
      phase: ExamPhase.sectionIntro,
      clearPending: true,
    );
  }

  // ---------------------------------------------------------- persistence

  /// Small, frequently written part (answers, flags, position, phase).
  Map<String, dynamic> toStateJson({int? savedAtMs}) => {
        'v': 1,
        'attempt_id': attemptId,
        'variant_id': variantId,
        if (uid != null) 'uid': uid,
        'language': language,
        'blueprint_id': blueprint.id,
        'section_index': sectionIndex,
        'section_id': section.sectionId,
        'deadline_at': section.deadlineAtMs,
        'clock_offset_ms': clockOffsetMs,
        'answers': answers,
        'flags': flags.toList(),
        'current_index': currentIndex,
        'phase': phase.name,
        'warned': warned.map((w) => w.name).toList(),
        'submitted': submitted.values.map((r) => r.toJson()).toList(),
        if (pendingSubmission != null)
          'pending_submission': pendingSubmission!.toJson(),
        if (result != null) 'result': result!.toJson(),
        if (savedAtMs != null) 'saved_at': savedAtMs,
        'exam_style': style.wire,
        if (choiceCounts.isNotEmpty) 'choice_counts': choiceCounts,
        if (freshness != null) 'freshness': freshness!.toJson(),
      };

  /// Large, rarely changing part (blueprint and open section content).
  Map<String, dynamic> toContentJson() => {
        'v': 1,
        'section_id': section.sectionId,
        'blueprint': blueprint.raw,
        'variant_title': variantTitle.toJson(),
        'section': section.toJson(),
      };

  /// Restores a session saved with [toStateJson] + [toContentJson]. Returns
  /// null if the two parts do not belong together or are unreadable.
  static ExamSession? fromJson(
      Map<String, dynamic> state, Map<String, dynamic> content) {
    final bp = ExamBlueprint.fromJson(content['blueprint']);
    final section = SectionPayload.fromJson(content['section']);
    final attemptId = asString(state['attempt_id']);
    if (attemptId == null || bp.sections.isEmpty) return null;
    if (section.sectionId != asString(state['section_id'])) return null;
    final submitted = <String, SectionRecord>{};
    for (final r in asJsonList(state['submitted'])) {
      final rec = SectionRecord.fromJson(r);
      submitted[rec.sectionId] = rec;
    }
    final pending = state['pending_submission'];
    final result = state['result'];
    final count = section.questions.length;
    final phase = ExamPhase.parse(state['phase']);
    return ExamSession._(
      attemptId: attemptId,
      variantId: asString(state['variant_id']) ?? '',
      uid: asString(state['uid']),
      language: asString(state['language']) ?? bp.languages.first,
      blueprint: bp,
      variantTitle: LocalizedText.fromJson(content['variant_title']),
      sectionIndex: asInt(state['section_index']) ?? 0,
      section: SectionPayload(
        sectionId: section.sectionId,
        deadlineAtMs: asEpochMs(state['deadline_at']) ?? section.deadlineAtMs,
        durationSec: section.durationSec,
        questions: section.questions,
        passages: section.passages,
      ),
      clockOffsetMs: asInt(state['clock_offset_ms']) ?? 0,
      answers: Map.unmodifiable(<String, String>{
        for (final e in asJsonMap(state['answers']).entries)
          if (asString(e.value) != null) e.key: asString(e.value)!,
      }),
      flags: Set.unmodifiable(asStringList(state['flags'])),
      currentIndex: count == 0
          ? 0
          : (asInt(state['current_index']) ?? 0).clamp(0, count - 1),
      // A submission that was in flight when the app died must be retried.
      phase: phase == ExamPhase.submitting ? ExamPhase.submitPending : phase,
      warned: Set.unmodifiable(asStringList(state['warned'])
          .map((n) => TimerWarning.values.where((w) => w.name == n))
          .expand((e) => e)),
      submitted: Map.unmodifiable(submitted),
      pendingSubmission:
          pending is Map ? SectionSubmission.fromJson(pending) : null,
      result: result is Map ? ExamResult.fromJson(result) : null,
      style: ExamStyle.parse(state['exam_style']),
      choiceCounts: Map.unmodifiable(<String, int>{
        for (final e in asJsonMap(state['choice_counts']).entries)
          if (asInt(e.value) case final n? when n > 0) e.key: n,
      }),
      freshness: ExamFreshness.fromJson(state['freshness']),
    );
  }
}
