import 'package:knowledge_flow/features/exam/data/exam_draft_sink.dart';
import 'package:knowledge_flow/features/exam/data/exam_local_store.dart';
import 'package:knowledge_flow/features/exam/data/exam_remote_datasource.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';
import 'package:knowledge_flow/features/exam/domain/exam_start.dart';
import 'package:knowledge_flow/features/exam/domain/question_timing.dart';

import 'exam_test_fixtures.dart';

/// Scriptable stand-in for the exam callables.
class FakeExamRemote implements ExamRemoteDataSource {
  ExamSessionPayload Function()? onGetState;
  SubmitSectionResponse Function(SectionSubmission s)? onSubmit;
  final submissions = <SectionSubmission>[];
  int getStateCalls = 0;

  FakeExamRemote({this.onGetState, this.onSubmit});

  @override
  Future<ExamSessionPayload> getState(String attemptId) async {
    getStateCalls++;
    final f = onGetState;
    if (f == null) throw const ExamFailure(ExamFailureKind.network);
    return f();
  }

  @override
  Future<SubmitSectionResponse> submitSection(SectionSubmission submission) async {
    submissions.add(submission);
    final f = onSubmit;
    if (f == null) throw const ExamFailure(ExamFailureKind.network);
    return f(submission);
  }

  /// Replaces the default [startPayload] answer of `examStart` (may throw).
  ExamSessionPayload Function()? onStart;
  int startCalls = 0;

  /// Every `examStart` request, in order.
  final startRequests = <ExamStartRequest>[];

  @override
  Future<ExamSessionPayload> start(ExamStartRequest request) async {
    startCalls++;
    startRequests.add(request);
    return (onStart ?? startPayload)();
  }

  @override
  Future<List<ReviewItem>> getReview(String attemptId) async => const [];
}

/// In-memory local store (same interface as the Hive one).
class MemoryExamStore implements ExamLocalStore {
  ExamSession? saved;
  int saves = 0;
  final ExamSession? initial;

  MemoryExamStore({this.initial}) : saved = initial;

  @override
  Future<ExamSession?> load(String attemptId) async => saved;

  @override
  Future<void> save(ExamSession session,
      {bool includeContent = false, int? savedAtMs}) async {
    saves++;
    saved = session;
  }

  @override
  Future<List<LocalAttemptInfo>> listUnfinished({String? uid}) async => const [];

  @override
  Future<Map<String, SectionRecord>> sectionRecords(String attemptId) async =>
      saved?.submitted ?? const {};

  @override
  Future<ExamResult?> loadResult(String attemptId) async => saved?.result;

  int prunes = 0;

  @override
  Future<void> pruneContent(String attemptId) async {
    prunes++;
    timings = null;
  }

  @override
  Future<void> remove(String attemptId) async {
    saved = null;
    timings = null;
  }

  /// Last saved per-question timings (`toJson` form).
  Map<String, dynamic>? timings;

  @override
  Future<void> saveTimings(String attemptId, QuestionTimer timer, DateTime now) async =>
      timings = timer.toJson(now);

  @override
  Future<QuestionTimer?> loadTimings(String attemptId) async =>
      timings == null ? null : QuestionTimer.fromJson(timings);
}

/// Draft sink whose first [failTimes] writes fail (e.g. PERMISSION_DENIED).
class FlakyDraftSink implements ExamDraftSink {
  int failTimes;
  int calls = 0;
  final written = <Map<String, String>>[];

  FlakyDraftSink({this.failTimes = 1});

  @override
  Future<void> writeDraft({
    required String attemptId,
    required String sectionId,
    required Map<String, String> answers,
    required List<String> flags,
  }) async {
    calls++;
    if (failTimes > 0) {
      failTimes--;
      throw StateError('permission-denied');
    }
    written.add(Map.of(answers));
  }
}

class RecordingDraftSink implements ExamDraftSink {
  final drafts = <({String sectionId, Map<String, String> answers, List<String> flags})>[];

  @override
  Future<void> writeDraft({
    required String attemptId,
    required String sectionId,
    required Map<String, String> answers,
    required List<String> flags,
  }) async {
    drafts.add((sectionId: sectionId, answers: Map.of(answers), flags: List.of(flags)));
  }
}
