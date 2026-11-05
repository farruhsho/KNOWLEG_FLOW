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

/**
 * App Check enforcement on the admin* callables. Default false: they already
 * require a staff role (fresh custom claims), and the admin CMS also runs on
 * web/desktop builds where App Check may not be configured.
 */
export const APP_CHECK_ENFORCE_ADMIN = defineBoolean('APP_CHECK_ENFORCE_ADMIN', {
  default: false,
  description: 'Reject admin* callable requests without a valid App Check token.',
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

/**
 * Web payment provider (ARCHITECTURE §10.3): `none` (no sales; the default
 * until the owner signs a provider contract) | `sandbox` (Functions emulator
 * with a demo-* project ONLY — anywhere else it acts as `none`) | the name of
 * a provider adapter in src/payments/registry.ts.
 */
export const PAYMENT_PROVIDER = defineString('PAYMENT_PROVIDER', {
  default: 'none',
  description: 'Web payment provider adapter: none | sandbox (emulator only) | provider name.',
});

/** Comma-separated origins paymentCreateOrder accepts in returnUrl (the web app). */
export const PAYMENT_RETURN_ORIGINS = defineString('PAYMENT_RETURN_ORIGINS', {
  default: 'https://knowleg-33f36.web.app,https://knowleg-33f36.firebaseapp.com',
  description: 'Allowed origins of the web app pages the payment provider returns to.',
});

/**
 * Signing / API secret of the real payment provider, mounted by
 * paymentCreateOrder, paymentWebhook and adminRefundOrder for the provider
 * adapter. Deploy requires it to exist (`firebase functions:secrets:set
 * PAYMENT_PROVIDER_SECRET`; any placeholder while PAYMENT_PROVIDER=none).
 * The `none` and `sandbox` adapters never read it (the sandbox signs with a
 * fixed emulator-only key).
 */
export const PAYMENT_PROVIDER_SECRET = defineSecret('PAYMENT_PROVIDER_SECRET');
