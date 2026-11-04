import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

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

/// Developer escape hatch: `--dart-define=EXAM_CALLABLES_ON_DESKTOP=true`
/// lets a Windows/Linux debug build call the exam functions, e.g. against a
/// backend deployed with `APP_CHECK_ENFORCE=false`. Never set it in releases.
const bool _examCallablesOnDesktop =
    bool.fromEnvironment('EXAM_CALLABLES_ON_DESKTOP');

/// Whether the exam callables can be used on this platform (contract D7).
/// They enforce App Check, which has providers on Android, iOS, macOS and
/// web (reCAPTCHA Enterprise) but none on Windows or Linux, so desktop
/// builds show a "not available on this platform" state instead of failing.
bool examCallablesSupported({
  bool? isWeb,
  TargetPlatform? platform,
  bool desktopOverride = _examCallablesOnDesktop,
}) {
  if (isWeb ?? kIsWeb) return true;
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => desktopOverride,
  };
}

class FirebaseExamRemoteDataSource implements ExamRemoteDataSource {
  /// False on platforms without App Check: every call then fails with
  /// [ExamFailureKind.platformUnsupported] without touching the network.
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
