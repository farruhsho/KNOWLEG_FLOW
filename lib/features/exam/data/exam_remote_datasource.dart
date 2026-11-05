import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/backend/backend_contract.dart';
import '../domain/exam_failure.dart';
import '../domain/exam_payload.dart';
import '../domain/exam_session.dart';
import '../domain/exam_start.dart';
import '../domain/json_utils.dart';

/// Exam callables (ARCHITECTURE §3). Every method throws [ExamFailure] on
/// error, never a raw platform exception.
abstract interface class ExamRemoteDataSource {
  /// `examStart` in library mode (a published variant) or fresh mode (a new
  /// variant assembled for this attempt), standard or strict style (§10).
  Future<ExamSessionPayload> start(ExamStartRequest request);

  Future<ExamSessionPayload> getState(String attemptId);

  Future<SubmitSectionResponse> submitSection(SectionSubmission submission);

  Future<List<ReviewItem>> getReview(String attemptId);
}

/// Version reported to `examStart` (`integrity.client_app_version`). Pass
/// `--dart-define=APP_VERSION=x.y.z+n` in release builds.
const String examClientAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');

class FirebaseExamRemoteDataSource implements ExamRemoteDataSource {
  /// False where this build has no App Check provider (the shared gate
  /// `callablesSupportedOnThisPlatform`, decision D7): every call then fails
  /// with [ExamFailureKind.platformUnsupported] without touching the network.
  final bool platformSupported;

  const FirebaseExamRemoteDataSource({this.platformSupported = true});

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!platformSupported) {
      throw const ExamFailure(ExamFailureKind.platformUnsupported);
    }
    try {
      final result = await BackendFunctions.callable(name, timeout: timeout)
          .call<Object?>(data);
      return asJsonMap(deepJson(result.data));
    } on FirebaseFunctionsException catch (e) {
      final reason = BackendReasons.of(e);
      final kind = reason != null
          ? ExamFailureKind.fromReason(reason)
          : ExamFailureKind.fromCode(e.code);
      throw ExamFailure(kind, e.message, BackendReasons.detailsOf(e));
    } on TimeoutException {
      throw const ExamFailure(ExamFailureKind.network, 'timeout');
    } on ExamFailure {
      rethrow;
    } catch (e) {
      // Socket/platform errors: treat as connectivity problems (retryable).
      throw ExamFailure(ExamFailureKind.network, e.toString());
    }
  }

  @override
  Future<ExamSessionPayload> start(ExamStartRequest request) async {
    // A fresh variant is assembled server-side before the attempt is
    // created, so this call may take longer than the others.
    final data = await _call(
      BackendFunctions.examStart,
      request.toCallableData(),
      timeout: request.mode == ExamMode.fresh
          ? const Duration(seconds: 60)
          : const Duration(seconds: 30),
    );
    return _payload(data);
  }

  @override
  Future<ExamSessionPayload> getState(String attemptId) async {
    final data =
        await _call(BackendFunctions.examGetState, {'attemptId': attemptId});
    return _payload(data);
  }

  @override
  Future<SubmitSectionResponse> submitSection(
      SectionSubmission submission) async {
    final data = await _call(
      BackendFunctions.examSubmitSection,
      submission.toCallableData(),
      timeout: const Duration(seconds: 45),
    );
    return SubmitSectionResponse.fromJson(data);
  }

  @override
  Future<List<ReviewItem>> getReview(String attemptId) async {
    final data = await _call(
      BackendFunctions.examGetReview,
      {'attemptId': attemptId},
      timeout: const Duration(seconds: 45),
    );
    return asJsonList(data['items'])
        .map(ReviewItem.fromJson)
        .where((i) => i.questionId.isNotEmpty)
        .toList(growable: false);
  }

  ExamSessionPayload _payload(Map<String, dynamic> data) {
    final p = ExamSessionPayload.fromJson(data);
    if (p.attemptId.isEmpty) {
      throw const ExamFailure(
          ExamFailureKind.validationFailed, 'payload without attemptId');
    }
    return p;
  }
}
