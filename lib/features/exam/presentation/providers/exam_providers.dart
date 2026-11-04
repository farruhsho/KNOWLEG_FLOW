import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/locale_provider.dart';
import '../../data/exam_catalog_repository.dart';
import '../../data/exam_draft_sink.dart';
import '../../data/exam_local_store.dart';
import '../../data/exam_remote_datasource.dart';
import '../../domain/exam_attempt.dart';
import '../../domain/exam_blueprint.dart';
import '../../domain/exam_failure.dart';
import '../../domain/exam_payload.dart';
import '../../domain/exam_session.dart';
import '../../domain/exam_variant.dart';
import '../../domain/localized_text.dart';
import '../controllers/exam_runner_controller.dart';

// ------------------------------------------------------------ infrastructure

/// Device clock. Overridden with a fake in tests.
final examClockProvider = Provider<ExamClock>((ref) => DateTime.now);

final examAuthUidProvider = StreamProvider<String?>((ref) =>
    FirebaseAuth.instance.authStateChanges().map((u) => u?.uid));

/// Signed-in user's uid, or null.
final examUidProvider =
    Provider<String?>((ref) => ref.watch(examAuthUidProvider).valueOrNull);

final examRemoteProvider = Provider<ExamRemoteDataSource>(
    (ref) => const FirebaseExamRemoteDataSource());

final examCatalogRepositoryProvider = Provider<ExamCatalogRepository>(
    (ref) => FirestoreExamCatalogRepository(FirebaseFirestore.instance, rootBundle));

final examLocalStoreProvider = Provider<ExamLocalStore>((ref) => ExamLocalStore());

final examDraftSinkProvider = Provider<ExamDraftSink>(
    (ref) => FirestoreExamDraftSink(FirebaseFirestore.instance));

// ---------------------------------------------------------------- catalog

final examBlueprintsProvider = FutureProvider<List<ExamBlueprint>>(
    (ref) => ref.watch(examCatalogRepositoryProvider).loadBlueprints());

/// A blueprint by id: from the active list, else fetched directly (retired
/// blueprints of old attempts), else the bundled asset.
final examBlueprintProvider =
    FutureProvider.family<ExamBlueprint?, String>((ref, id) async {
  try {
    final all = await ref.watch(examBlueprintsProvider.future);
    for (final b in all) {
      if (b.id == id) return b;
    }
  } catch (_) {
    // fall through to the direct lookup
  }
  return ref.watch(examCatalogRepositoryProvider).loadBlueprint(id);
});

/// Language of exam content the user wants (ru / ky). Content of a variant
/// is always in the variant's own language; this only filters the catalog.
final examLanguageProvider = StateProvider<String>((ref) {
  final ui = ref.watch(localeProvider).languageCode;
  return ui == 'ky' ? 'ky' : 'ru';
});

typedef VariantQuery = ({String blueprintId, String language});

@immutable
class VariantListState {
  final List<ExamVariant> items;
  final bool loading;
  final bool hasMore;
  final ExamFailure? failure;

  const VariantListState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.failure,
  });

  bool get isInitialLoading => loading && items.isEmpty;
}

/// Published variants of one direction, paginated by `number`.
class VariantListNotifier extends StateNotifier<VariantListState> {
  final ExamCatalogRepository _repo;
  final VariantQuery query;
  static const pageSize = 10;

  VariantListNotifier(this._repo, this.query) : super(const VariantListState()) {
    loadMore();
  }

  Future<void> loadMore() async {
    if (state.loading || (!state.hasMore && state.failure == null)) return;
    state = VariantListState(items: state.items, loading: true, hasMore: state.hasMore);
    try {
      final page = await _repo.loadVariants(
        blueprintId: query.blueprintId,
        language: query.language,
        afterNumber: state.items.isEmpty ? null : state.items.last.number,
        limit: pageSize,
      );
      if (!mounted) return;
      state = VariantListState(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
      );
    } on ExamFailure catch (f) {
      if (!mounted) return;
      state = VariantListState(items: state.items, hasMore: state.hasMore, failure: f);
    } catch (e) {
      if (!mounted) return;
      state = VariantListState(
        items: state.items,
        hasMore: state.hasMore,
        failure: ExamFailure(ExamFailureKind.unknown, e.toString()),
      );
    }
  }

  Future<void> retry() => loadMore();
}

final variantListProvider = StateNotifierProvider.autoDispose
    .family<VariantListNotifier, VariantListState, VariantQuery>(
  (ref, q) => VariantListNotifier(ref.watch(examCatalogRepositoryProvider), q),
);

final examVariantProvider =
    FutureProvider.autoDispose.family<ExamVariant?, String>((ref, id) =>
        ref.watch(examCatalogRepositoryProvider).loadVariant(id));

// --------------------------------------------------------------- attempts

final myExamAttemptsProvider = StreamProvider<List<AttemptSummary>>((ref) {
  final uid = ref.watch(examUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(examCatalogRepositoryProvider).watchMyAttempts(uid);
});

/// Attempt status per variant id (empty while loading).
final variantStatusesProvider =
    Provider<Map<String, VariantAttemptStatus>>((ref) {
  final attempts = ref.watch(myExamAttemptsProvider).valueOrNull ?? const [];
  return VariantAttemptStatus.fromAttempts(attempts);
});

/// Unfinished attempts saved on this device for the current user. Nothing
/// while signed out, so a shared device never shows someone else's attempt.
final localUnfinishedAttemptsProvider =
    FutureProvider<List<LocalAttemptInfo>>((ref) async {
  final uid = ref.watch(examUidProvider);
  if (uid == null) return const [];
  return ref.watch(examLocalStoreProvider).listUnfinished(uid: uid);
});

@immutable
class ActiveAttemptInfo {
  final String attemptId;
  final String blueprintId;
  final LocalizedText blueprintTitle;
  final LocalizedText variantTitle;
  final int sectionIndex;
  final int sectionCount;

  /// Device-clock deadline of the open section, if known.
  final DateTime? deadline;
  final bool awaitingSubmit;

  const ActiveAttemptInfo({
    required this.attemptId,
    required this.blueprintId,
    this.blueprintTitle = LocalizedText.empty,
    this.variantTitle = LocalizedText.empty,
    required this.sectionIndex,
    required this.sectionCount,
    this.deadline,
    this.awaitingSubmit = false,
  });
}

/// The attempt the resume banner offers: local Hive copy first (it knows the
/// skew-corrected deadline), else an in-progress attempt from Firestore. A
/// local copy the server already reports as finished is ignored.
final activeAttemptProvider = Provider<ActiveAttemptInfo?>((ref) {
  final local = ref.watch(localUnfinishedAttemptsProvider).valueOrNull ?? const [];
  final remote = ref.watch(myExamAttemptsProvider).valueOrNull;
  final finishedRemotely = {
    for (final a in remote ?? const <AttemptSummary>[])
      if (!a.isInProgress) a.id,
  };
  for (final l in local) {
    if (finishedRemotely.contains(l.attemptId)) continue;
    return ActiveAttemptInfo(
      attemptId: l.attemptId,
      blueprintId: l.blueprintId,
      blueprintTitle: l.blueprintTitle,
      variantTitle: l.variantTitle,
      sectionIndex: l.sectionIndex,
      sectionCount: l.sectionCount,
      deadline: l.localDeadline,
      awaitingSubmit: l.phase == ExamPhase.submitPending ||
          l.phase == ExamPhase.submitting,
    );
  }
  final inProgress = (remote ?? const <AttemptSummary>[])
      .where((a) => a.isInProgress)
      .toList()
    ..sort((a, b) => (b.startedAtMs ?? 0).compareTo(a.startedAtMs ?? 0));
  if (inProgress.isEmpty) return null;
  final a = inProgress.first;
  return ActiveAttemptInfo(
    attemptId: a.id,
    blueprintId: a.blueprintId,
    sectionIndex: a.currentSectionIndex,
    sectionCount: a.sectionCount,
    deadline: a.currentDeadlineAtMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(a.currentDeadlineAtMs!),
  );
});

// ------------------------------------------------------------------ runner

final examRunnerControllerProvider = StateNotifierProvider.autoDispose
    .family<ExamRunnerController, ExamRunnerState, String>((ref, attemptId) {
  return ExamRunnerController(
    attemptId: attemptId,
    remote: ref.watch(examRemoteProvider),
    store: ref.watch(examLocalStoreProvider),
    drafts: ref.watch(examDraftSinkProvider),
    clock: ref.watch(examClockProvider),
    uid: ref.read(examUidProvider),
  );
});

// ------------------------------------------------------------------ result

@immutable
class ExamResultData {
  final String attemptId;
  final ExamResult result;
  final ExamBlueprint? blueprint;
  final AttemptSummary? attempt;

  /// Local per-section records (answered counts, flags) if this device ran
  /// the attempt.
  final Map<String, SectionRecord> localRecords;

  const ExamResultData({
    required this.attemptId,
    required this.result,
    required this.blueprint,
    required this.attempt,
    required this.localRecords,
  });

  /// Number of unanswered questions, when known.
  int? get skipped {
    if (result.skipped != null) return result.skipped;
    if (localRecords.isEmpty) return null;
    final answered = localRecords.values.fold<int>(0, (s, r) => s + r.answered);
    final total = localRecords.values.fold<int>(0, (s, r) => s + r.total);
    if (total != result.total) return null;
    return (total - answered).clamp(0, total);
  }

  int? get incorrect {
    if (result.incorrect != null) return result.incorrect;
    final s = skipped;
    if (s == null) return null;
    return (result.total - result.correct - s).clamp(0, result.total);
  }
}

/// Thrown by [examResultProvider] when the attempt exists but has no result
/// yet (still being scored, or not finished).
class ExamResultPendingException implements Exception {
  const ExamResultPendingException();
}

final examResultProvider =
    FutureProvider.autoDispose.family<ExamResultData, String>((ref, attemptId) async {
  final repo = ref.watch(examCatalogRepositoryProvider);
  final store = ref.watch(examLocalStoreProvider);
  Map<String, SectionRecord> records = const {};
  ExamResult? localResult;
  try {
    records = await store.sectionRecords(attemptId);
    localResult = await store.loadResult(attemptId);
  } catch (_) {}
  AttemptSummary? attempt;
  ExamFailure? failure;
  try {
    attempt = await repo.loadAttempt(attemptId);
  } on ExamFailure catch (f) {
    failure = f;
  }
  final result = attempt?.result ?? localResult;
  if (result == null) {
    if (failure != null) throw failure;
    if (attempt == null) {
      throw const ExamFailure(ExamFailureKind.attemptNotFound);
    }
    throw const ExamResultPendingException();
  }
  ExamBlueprint? blueprint;
  final bpId = attempt?.blueprintId;
  if (bpId != null && bpId.isNotEmpty) {
    try {
      blueprint = await ref.read(examBlueprintProvider(bpId).future);
    } catch (_) {}
  }
  return ExamResultData(
    attemptId: attemptId,
    result: result,
    blueprint: blueprint,
    attempt: attempt,
    localRecords: records,
  );
});

// ------------------------------------------------------------------ review

final examReviewProvider =
    FutureProvider.autoDispose.family<List<ReviewItem>, String>((ref, attemptId) =>
        ref.watch(examRemoteProvider).getReview(attemptId));

/// Locally known flagged question ids of an attempt (the review API does not
/// return flags).
final examLocalFlagsProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, attemptId) async {
  try {
    final records = await ref.watch(examLocalStoreProvider).sectionRecords(attemptId);
    return {for (final r in records.values) ...r.flags};
  } catch (_) {
    return const {};
  }
});

// ----------------------------------------------------------------- history

@immutable
class ExamHistoryState {
  final List<AttemptSummary> items;
  final bool loading;
  final bool hasMore;
  final Object? cursor;
  final ExamFailure? failure;

  const ExamHistoryState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.cursor,
    this.failure,
  });

  bool get isInitialLoading => loading && items.isEmpty;
}

class ExamHistoryNotifier extends StateNotifier<ExamHistoryState> {
  final ExamCatalogRepository _repo;
  final String? _uid;
  static const pageSize = 20;

  ExamHistoryNotifier(this._repo, this._uid) : super(const ExamHistoryState()) {
    loadMore();
  }

  Future<void> loadMore() async {
    final uid = _uid;
    if (uid == null) {
      state = const ExamHistoryState(hasMore: false);
      return;
    }
    if (state.loading || (!state.hasMore && state.failure == null)) return;
    state = ExamHistoryState(
        items: state.items, loading: true, hasMore: state.hasMore, cursor: state.cursor);
    try {
      final page = await _repo.loadHistory(uid, cursor: state.cursor, limit: pageSize);
      if (!mounted) return;
      state = ExamHistoryState(
        items: [...state.items, ...page.items],
        hasMore: page.hasMore,
        cursor: page.cursor,
      );
    } on ExamFailure catch (f) {
      if (!mounted) return;
      state = ExamHistoryState(
          items: state.items, hasMore: state.hasMore, cursor: state.cursor, failure: f);
    } catch (e) {
      if (!mounted) return;
      state = ExamHistoryState(
        items: state.items,
        hasMore: state.hasMore,
        cursor: state.cursor,
        failure: ExamFailure(ExamFailureKind.unknown, e.toString()),
      );
    }
  }
}

final examHistoryProvider =
    StateNotifierProvider.autoDispose<ExamHistoryNotifier, ExamHistoryState>(
  (ref) => ExamHistoryNotifier(
      ref.watch(examCatalogRepositoryProvider), ref.watch(examUidProvider)),
);
