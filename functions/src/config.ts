/**
 * Global options and deploy-time parameters. Every handler module imports
 * this file FIRST so setGlobalOptions runs before any function is defined
 * (firebase-functions reads the global options at definition time).
 */
import { setGlobalOptions } from 'firebase-functions/v2';
import { defineBoolean, defineSecret, defineString } from 'firebase-functions/params';

/** Must equal BackendFunctions.region in lib/core/backend/backend_contract.dart and the Firestore location. */
export const FUNCTIONS_REGION = 'europe-west1';

setGlobalOptions({ region: FUNCTIONS_REGION, maxInstances: 20 });

/** App Check enforcement on every onCall. Set to false ONLY for the emulator. */
export const APP_CHECK_ENFORCE = defineBoolean('APP_CHECK_ENFORCE', {
  default: true,
  description: 'Reject callable requests without a valid App Check token (false only for the emulator).',
});

/** Android package name of the Play listing (purchases are verified against it). */
export const PLAY_PACKAGE_NAME = defineString('PLAY_PACKAGE_NAME', {
  default: 'com.example.knowledge_flow',
  description: 'Google Play applicationId used for Android Publisher API calls.',
});

/** Grant credits for Play license-tester (test) purchases. Keep false in production. */
export const ALLOW_TEST_PURCHASES = defineBoolean('ALLOW_TEST_PURCHASES', {
  default: false,
  description: 'Grant credits for Google Play test purchases (license testers).',
});

/** Claude model for the AI tutor and the admin question drafter. */
export const AI_TUTOR_MODEL = defineString('AI_TUTOR_MODEL', {
  default: 'claude-opus-5-5',
  description: 'Anthropic model id used by aiTutor and adminAiDraftQuestions.',
});

/** Anthropic API key (Secret Manager). Never shipped to the client. */
export const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');
