import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../core/backend/backend_contract.dart';

/// `aiTutor` modes (ARCHITECTURE §6). [wire] is what the callable expects.
enum TutorMode {
  explainMistake('explain_mistake'),
  stepByStep('step_by_step'),
  grammar('grammar'),
  practice('practice'),
  studyPlan('study_plan'),
  chat('chat');

  const TutorMode(this.wire);
  final String wire;

  static TutorMode? fromWire(Object? raw) {
    final s = raw?.toString().trim();
    for (final m in values) {
      if (m.wire == s || m.name == s) return m;
    }
    return null;
  }
}

enum TutorRole { user, assistant }

/// One chat bubble. Kept in memory for the app session.
@immutable
class TutorMessage {
  final String id;
  final TutorRole role;
  final String text;
  final DateTime at;

  /// Set on a user message that did not get an answer.
  final TutorFailure? failure;

  const TutorMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.at,
    this.failure,
  });

  TutorMessage copyWith({TutorFailure? failure, bool clearFailure = false}) => TutorMessage(
        id: id,
        role: role,
        text: text,
        at: at,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

/// The `aiTutor` request body.
@immutable
class TutorRequest {
  final TutorMode mode;
  final String message;

  /// `ru` or `ky` — the server answers in this language.
  final String language;
  final String? questionId;
  final String? attemptId;
  final List<TutorMessage> history;

  const TutorRequest({
    required this.mode,
    required this.message,
    required this.language,
    this.questionId,
    this.attemptId,
    this.history = const [],
  });

  /// Max previous messages sent as context ("last ~6 turns").
  static const maxHistory = 6;

  /// Per-message cap for history items, to keep requests small.
  static const maxHistoryChars = 1500;

  /// Cap for the new (trimmed) message, in UTF-16 code units. Mirrors
  /// `MAX_MESSAGE_CHARS` in functions/src/domain/tutor_quota.ts: the server
  /// rejects anything longer with VALIDATION_FAILED, so the composer blocks
  /// sending above it and every generated prompt is built to fit (D13).
  static const maxMessageChars = 2000;

  Map<String, dynamic> toPayload() {
    final usable = history.where((m) => m.failure == null && m.text.trim().isNotEmpty).toList();
    final recent = usable.length > maxHistory ? usable.sublist(usable.length - maxHistory) : usable;
    return {
      'mode': mode.wire,
      'message': clipTutorText(message.trim(), maxMessageChars),
      'language': language,
      if (questionId != null && questionId!.isNotEmpty) 'questionId': questionId,
      if (attemptId != null && attemptId!.isNotEmpty) 'attemptId': attemptId,
      'history': [
        for (final m in recent)
          {
            'role': m.role == TutorRole.user ? 'user' : 'assistant',
            'content': clipTutorText(m.text.trim(), maxHistoryChars),
          },
      ],
    };
  }
}

/// Cuts [s] to at most [max] UTF-16 code units (the unit both Dart and the
/// server's JS `length` count) without splitting a surrogate pair. With
/// [ellipsis], a cut string ends in "…" and still fits in [max].
String clipTutorText(String s, int max, {bool ellipsis = false}) {
  if (s.length <= max) return s;
  if (max <= 0) return '';
  final budget = ellipsis ? max - 1 : max;
  var end = budget < 0 ? 0 : budget;
  // Do not leave a lone high surrogate at the end.
  if (end > 0 && end < s.length) {
    final last = s.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
  }
  final cut = s.substring(0, end).trimRight();
  return ellipsis ? '$cut…' : cut;
}

/// `aiTutor` response: `{reply, remainingToday}`.
@immutable
class TutorReply {
  final String reply;
  final int? remainingToday;

  const TutorReply(this.reply, {this.remainingToday});

  factory TutorReply.fromResponse(Object? data) {
    if (data is! Map) throw const FormatException('aiTutor: not a map');
    final reply = data['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const FormatException('aiTutor: empty reply');
    }
    final r = data['remainingToday'];
    return TutorReply(reply, remainingToday: r is num ? r.toInt() : int.tryParse('$r'));
  }
}

enum TutorFailure {
  quotaExceeded,
  disabled,
  examInProgress,

  /// The account is banned by a moderator (`USER_BANNED`, decision D5).
  banned,
  signInRequired,
  network,
  validation,
  unknown;

  /// `details.reason` for a banned account (D5). Must equal the USER_BANNED
  /// entry of `BackendReasons` and functions/src/domain/reasons.ts.
  static const userBannedReason = 'USER_BANNED';

  /// Failures that make further requests pointless for now.
  bool get blocksInput => this == quotaExceeded || this == disabled || this == banned;

  /// Maps a callable error (HttpsError + `details.reason`) to a failure.
  static TutorFailure from(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (BackendReasons.of(error)) {
        case BackendReasons.aiQuotaExceeded:
          return quotaExceeded;
        case BackendReasons.aiDisabled:
          return disabled;
        case BackendReasons.aiExamInProgress:
          return examInProgress;
        case userBannedReason:
          return banned;
        case BackendReasons.validationFailed:
          return validation;
      }
      switch (error.code) {
        case 'resource-exhausted':
          return quotaExceeded;
        case 'unauthenticated':
          return signInRequired;
        case 'unavailable':
        case 'deadline-exceeded':
          return network;
        case 'invalid-argument':
          return validation;
      }
      return unknown;
    }
    if (error is TutorException) return error.failure;
    final s = error.toString().toLowerCase();
    if (s.contains('socketexception') || s.contains('network') || s.contains('timeout')) {
      return network;
    }
    return unknown;
  }
}

class TutorException implements Exception {
  final TutorFailure failure;
  final Object? cause;
  const TutorException(this.failure, [this.cause]);

  @override
  String toString() => 'TutorException($failure, $cause)';
}

/// Arguments accepted by the tutor route via `GoRouterState.extra`:
/// `{questionId?, attemptId?, mode?, prefill?}`.
@immutable
class TutorArgs {
  final String? questionId;
  final String? attemptId;
  final TutorMode? mode;
  final String? prefill;

  const TutorArgs({this.questionId, this.attemptId, this.mode, this.prefill});

  static const empty = TutorArgs();

  bool get isEmpty => questionId == null && attemptId == null && mode == null && prefill == null;

  factory TutorArgs.fromExtra(Object? extra) {
    if (extra is TutorArgs) return extra;
    if (extra is! Map) return empty;
    String? str(String k) {
      final v = extra[k];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final questionId = str('questionId');
    return TutorArgs(
      questionId: questionId,
      attemptId: str('attemptId'),
      mode: TutorMode.fromWire(extra['mode']) ??
          (questionId != null ? TutorMode.explainMistake : null),
      prefill: str('prefill'),
    );
  }

  Map<String, Object> toExtra() => {
        if (questionId != null) 'questionId': questionId!,
        if (attemptId != null) 'attemptId': attemptId!,
        if (mode != null) 'mode': mode!.wire,
        if (prefill != null) 'prefill': prefill!,
      };
}

/// The language code sent to `aiTutor`: Kyrgyz for `ky`, Russian otherwise.
String tutorLanguageFor(String? languageCode) => languageCode == 'ky' ? 'ky' : 'ru';
