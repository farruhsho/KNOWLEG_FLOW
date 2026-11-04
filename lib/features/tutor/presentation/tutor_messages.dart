import '../../../l10n/app_localizations.dart';
import '../domain/tutor_models.dart';

extension TutorL10n on AppLocalizations {
  String tutorModeLabel(TutorMode m) => switch (m) {
        TutorMode.explainMistake => tutorModeExplainMistake,
        TutorMode.stepByStep => tutorModeStepByStep,
        TutorMode.grammar => tutorModeGrammar,
        TutorMode.practice => tutorModePractice,
        TutorMode.studyPlan => tutorModeStudyPlan,
        TutorMode.chat => tutorModeChat,
      };

  String tutorModeHint(TutorMode m) => switch (m) {
        TutorMode.explainMistake => tutorHintExplainMistake,
        TutorMode.stepByStep => tutorHintStepByStep,
        TutorMode.grammar => tutorHintGrammar,
        TutorMode.practice => tutorHintPractice,
        TutorMode.studyPlan => tutorHintStudyPlan,
        TutorMode.chat => tutorHintChat,
      };

  String tutorFailureMessage(TutorFailure f) => switch (f) {
        TutorFailure.quotaExceeded => tutorErrorQuota,
        TutorFailure.disabled => tutorErrorDisabled,
        TutorFailure.examInProgress => tutorErrorExamInProgress,
        TutorFailure.signInRequired => tutorErrorSignIn,
        TutorFailure.network => tutorErrorNetwork,
        TutorFailure.validation => tutorErrorValidation,
        TutorFailure.unknown => tutorErrorUnknown,
      };
}
