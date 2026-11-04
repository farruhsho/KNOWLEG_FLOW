import '../../../core/backend/backend_contract.dart';
import '../domain/tutor_models.dart';

/// The AI tutor backend. The client never talks to an LLM directly and holds
/// no model API key: everything goes through the `aiTutor` callable, which
/// enforces quotas, App Check and the "no help during an active exam" rule.
abstract interface class TutorApi {
  /// Returns the reply or throws [TutorException].
  Future<TutorReply> ask(TutorRequest request);
}

class CallableTutorApi implements TutorApi {
  const CallableTutorApi();

  @override
  Future<TutorReply> ask(TutorRequest request) async {
    try {
      final result = await BackendFunctions.callable(
        BackendFunctions.aiTutor,
        timeout: const Duration(seconds: 90),
      ).call<Object?>(request.toPayload());
      return TutorReply.fromResponse(result.data);
    } on FormatException catch (e) {
      throw TutorException(TutorFailure.unknown, e);
    } catch (e) {
      throw TutorException(TutorFailure.from(e), e);
    }
  }
}
