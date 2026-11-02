import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/backend/backend_contract.dart';
import '../domain/exam_failure.dart';
import '../domain/exam_payload.dart';
import '../domain/exam_session.dart';
import '../domain/json_utils.dart';

/// Exam callables (ARCHITECTURE §3). Every method throws [ExamFailure] on
/// error, never a raw platform exception.
abstract interface class ExamRemoteDataSource {
  Future<ExamSessionPayload> start({
    required String variantId,
    required String clientAppVersion,
  });

  Future<ExamSessionPayload> getState(String attemptId);

  Future<SubmitSectionResponse> submitSection(SectionSubmission submission);

  Future<List<ReviewItem>> getReview(String attemptId);
}

/// Version reported to `examStart` (`integrity.client_app_version`). Pass
/// `--dart-define=APP_VERSION=x.y.z+n` in release builds.
const String examClientAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');

class FirebaseExamRemoteDataSource implements ExamRemoteDataSource {
  const FirebaseExamRemoteDataSource();

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final result = await BackendFunctions.callable(name, timeout: timeout)
          .call<Object?>(data);
      return asJsonMap(deepJson(result.data));
    } on FirebaseFunctionsException catch (e) {
      final reason = BackendReasons.of(e);
      final kind = reason != null
          ? ExamFailureKind.fromReason(reason)
          : ExamFailureKind.fromCode(e.code);
      throw ExamFailure(kind, e.message);
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
  Future<ExamSessionPayload> start({
    required String variantId,
    required String clientAppVersion,
  }) async {
    final data = await _call(BackendFunctions.examStart, {
      'variantId': variantId,
      'clientAppVersion': clientAppVersion,
    });
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
