import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tutor_api.dart';
import '../domain/tutor_models.dart';

@immutable
class TutorChatState {
  final List<TutorMessage> messages;
  final TutorMode mode;
  final String? questionId;
  final String? attemptId;
  final bool sending;
  final int? remainingToday;

  /// Quota exhausted / tutor disabled: input stays disabled until cleared.
  final TutorFailure? blockingFailure;

  const TutorChatState({
    this.messages = const [],
    this.mode = TutorMode.chat,
    this.questionId,
    this.attemptId,
    this.sending = false,
    this.remainingToday,
    this.blockingFailure,
  });

  bool get hasContext => questionId != null || attemptId != null;

  TutorChatState copyWith({
    List<TutorMessage>? messages,
    TutorMode? mode,
    String? questionId,
    String? attemptId,
    bool clearContext = false,
    bool? sending,
    int? remainingToday,
    TutorFailure? blockingFailure,
    bool clearBlocking = false,
  }) =>
      TutorChatState(
        messages: messages ?? this.messages,
        mode: mode ?? this.mode,
        questionId: clearContext ? null : (questionId ?? this.questionId),
        attemptId: clearContext ? null : (attemptId ?? this.attemptId),
        sending: sending ?? this.sending,
        remainingToday: remainingToday ?? this.remainingToday,
        blockingFailure: clearBlocking ? null : (blockingFailure ?? this.blockingFailure),
      );
}

/// In-memory chat for the current app session (cleared on sign-out).
class TutorChatController extends StateNotifier<TutorChatState> {
  TutorChatController(this._api, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const TutorChatState());

  final TutorApi _api;
  final DateTime Function() _clock;
  int _seq = 0;

  String _nextId() => '${_clock().microsecondsSinceEpoch}_${_seq++}';

  void setMode(TutorMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode);
  }

  /// Applies route arguments (question / attempt context and mode).
  void applyArgs(TutorArgs args) {
    if (args.isEmpty) return;
    state = state.copyWith(
      mode: args.mode ?? state.mode,
      questionId: args.questionId,
      attemptId: args.attemptId,
    );
  }

  void clearContext() => state = state.copyWith(clearContext: true);

  void clear() {
    state = TutorChatState(
      mode: state.mode,
      remainingToday: state.remainingToday,
      blockingFailure: state.blockingFailure,
    );
  }

  /// Sends [text] in [language] (`ru`/`ky`). Returns false if nothing was sent.
  Future<bool> send(String text, {required String language}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending || state.blockingFailure != null) return false;
    final userMsg = TutorMessage(id: _nextId(), role: TutorRole.user, text: trimmed, at: _clock());
    final history = state.messages;
    state = state.copyWith(messages: [...history, userMsg], sending: true);
    await _ask(userMsg, history, language);
    return true;
  }

  /// Re-sends a failed user message.
  Future<void> retry(String messageId, {required String language}) async {
    if (state.sending || state.blockingFailure != null) return;
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;
    final msg = state.messages[index].copyWith(clearFailure: true);
    final history = state.messages.sublist(0, index);
    final rest = state.messages.sublist(index + 1);
    state = state.copyWith(messages: [...history, msg, ...rest], sending: true);
    await _ask(msg, history, language);
  }

  Future<void> _ask(TutorMessage userMsg, List<TutorMessage> history, String language) async {
    final request = TutorRequest(
      mode: state.mode,
      message: userMsg.text,
      language: language,
      questionId: state.questionId,
      attemptId: state.attemptId,
      history: history,
    );
    try {
      final reply = await _api.ask(request);
      if (!mounted) return;
      state = state.copyWith(
        sending: false,
        remainingToday: reply.remainingToday,
        messages: [
          ...state.messages,
          TutorMessage(id: _nextId(), role: TutorRole.assistant, text: reply.reply, at: _clock()),
        ],
      );
    } catch (e) {
      if (!mounted) return;
      final failure = TutorFailure.from(e);
      state = state.copyWith(
        sending: false,
        remainingToday: failure == TutorFailure.quotaExceeded ? 0 : null,
        blockingFailure: failure.blocksInput ? failure : null,
        messages: [
          for (final m in state.messages) m.id == userMsg.id ? m.copyWith(failure: failure) : m,
        ],
      );
    }
  }
}

final tutorApiProvider = Provider<TutorApi>((ref) => const CallableTutorApi());

/// Signed-in uid; the chat is rebuilt (cleared) whenever it changes.
final tutorUidProvider = StreamProvider<String?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges().map((u) => u?.uid);
  } catch (_) {
    return Stream<String?>.value(null);
  }
});

final tutorChatProvider = StateNotifierProvider<TutorChatController, TutorChatState>((ref) {
  ref.watch(tutorUidProvider.select((u) => u.valueOrNull));
  return TutorChatController(ref.watch(tutorApiProvider));
});
