import 'package:knowledge_flow/features/exam/data/exam_draft_sink.dart';
import 'package:knowledge_flow/features/exam/data/exam_local_store.dart';
import 'package:knowledge_flow/features/exam/data/exam_remote_datasource.dart';
import 'package:knowledge_flow/features/exam/domain/exam_failure.dart';
import 'package:knowledge_flow/features/exam/domain/exam_payload.dart';
import 'package:knowledge_flow/features/exam/domain/exam_session.dart';

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

  @override
  Future<ExamSessionPayload> start(
          {required String variantId, required String clientAppVersion}) async =>
      startPayload();

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
  Future<void> pruneContent(String attemptId) async {}

  @override
  Future<void> remove(String attemptId) async => saved = null;
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
