# ORT Master KG — Cloud Functions (2nd gen)

Server side of the contract in [`docs/modernization/ARCHITECTURE.md`](../docs/modernization/ARCHITECTURE.md) §3.
TypeScript (strict), Node.js 22, `firebase-functions` 7.4, `firebase-admin` 14 (modular imports),
`@anthropic-ai/sdk` 1.3, `@googleapis/androidpublisher`. Region: `europe-west1`, `maxInstances: 20`
(`src/config.ts`).

| Function | Trigger | Who |
|---|---|---|
| `examStart`, `examGetState`, `examSubmitSection`, `examGetReview` | callable | signed-in (owner) |
| `billingVerifyPurchase` | callable | signed-in |
| `aiTutor` | callable | signed-in |
| `recordActivity` | callable | signed-in |
| `accountDelete` | callable | signed-in (self) |
| `adminSetRole`, `adminGrantCredits`, `adminUpdatePricing` | callable | `super_admin` |
| `adminPublishVariant` | callable | `super_admin`, `content_manager` |
| `adminAiDraftQuestions` | callable | `super_admin`, `content_manager`, `methodologist` |
| `examExpireStale` | schedule, every 30 min (Asia/Bishkek) | — |
| `billingRtdn` | Pub/Sub topic `play-billing` | — |
| `billingSweepVoided` | schedule, daily 04:00 (Asia/Bishkek) | — |

Errors are `HttpsError` with `details.reason` from `src/domain/reasons.ts`
(same codes as `BackendReasons` in `lib/core/backend/backend_contract.dart`).

## Layout

```
src/
  config.ts            setGlobalOptions + params + secrets (imported first everywhere)
  index.ts             exports every function
  domain/              pure, unit-tested business logic (no Firebase imports)
    scoring.ts         raw scoring, per-section/topic results, weak/strong topics
    entitlements.ts    free first exam / credits / resume / clawback with debt
    exam_session.ts    forward-only section state machine, 120 s grace, expiry
    payload.ts         ExamSessionPayload (current section only, never keys)
    purchase.ts        Play purchase decisions, sha256 token ids, RTDN parsing
    xp.ts              XP rules, level formula, Bishkek-day streaks, achievements
    roles.ts           permission matrix (ARCHITECTURE §2), legacy admin fallback
    tutor_quota.ts     AI tutor input validation, daily quota, cost estimate
    tutor_prompt.ts    frozen (cacheable) system prompt + per-request context
    blueprint_validation.ts  variant vs blueprint checks before publishing
    time.ts, types.ts, hash.ts, reasons.ts
  handlers/            thin Firebase adapters (Firestore transactions, Auth, Play, Anthropic)
test/                  node:test unit tests for every domain module
```

## Local development

```bash
cd functions
npm install
npm run build      # clean + tsc + copies ../assets/data/exam_blueprints.json to lib/data/
npm test           # tsc typecheck (src + test) and node:test via tsx
```

`lib/` is the deploy artifact. `gcp-build` is intentionally empty: Cloud Build must not
re-run `build`, because `copy-assets` reads `../assets`, which is not uploaded.
The predeploy hook in `firebase.json` builds locally before every deploy.

Security-rules tests live in [`tests/rules`](../tests/rules/README.md) (need the emulator + Java 21).

## Deploy checklist (project `knowleg-33f36`)

Nothing here has been deployed yet. Do these once, in order.

### 1. Region must match Firestore

Functions run in `europe-west1` (`FUNCTIONS_REGION` in `src/config.ts`, `BackendFunctions.region`
in the Flutter client). Open Firebase console → Firestore → the database location. If it is not
in Europe (for example `us-central1` / `nam5`), change **both** constants to the Firestore region
before the first deploy — cross-continent transactions are slow and every exam submit runs one.

### 2. Plan and APIs

The project must be on the Blaze plan. Enable (the CLI offers to do it on first deploy):
Cloud Functions, Cloud Build, Artifact Registry, Cloud Run, Eventarc, Pub/Sub, Cloud Scheduler,
Secret Manager, and **Google Play Android Developer API**.

### 3. Secret: Anthropic API key

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
```

Only `aiTutor` and `adminAiDraftQuestions` mount it. The key never reaches the app.

### 4. Params

Values are asked interactively on the first deploy, or put them in `functions/.env.knowleg-33f36`
(non-secret, may be committed):

| Param | Default | Meaning |
|---|---|---|
| `APP_CHECK_ENFORCE` | `true` | Reject callables without a valid App Check token. `false` only for the emulator. |
| `PLAY_PACKAGE_NAME` | `com.example.knowledge_flow` | Play `applicationId`. Change together with the Android app id before the first Play upload. |
| `ALLOW_TEST_PURCHASES` | `false` | Grant credits for license-tester purchases. Keep `false` in production. |
| `AI_TUTOR_MODEL` | `claude-opus-5-5` | Model for the tutor and the question drafter (owner can switch without an app release). |

```dotenv
# functions/.env.knowleg-33f36  (example values)
APP_CHECK_ENFORCE=true
PLAY_PACKAGE_NAME=kg.example.ortmaster
ALLOW_TEST_PURCHASES=false
AI_TUTOR_MODEL=claude-opus-5-5
```

### 5. Firestore config documents (optional, defaults shown)

- `config/pricing` — `{products: {exam_single: 1, exam_pack_5: 5, exam_pack_10: 10}, free_exams_per_user: 1}`.
  Written by `adminUpdatePricing`; prices shown to users always come from Google Play.
- `config/ai_tutor` — `{enabled: true, daily_limit: 15, max_tokens: 1200}` (Admin SDK / console only;
  clients cannot read it).
- `exam_blueprints/{id}` — import from `assets/data/exam_blueprints.json`; the functions fall back
  to the bundled copy when a document is missing.

### 6. Google Play: service account access

`billingVerifyPurchase`, `billingRtdn` and `billingSweepVoided` call the Android Publisher API with
Application Default Credentials, i.e. as the functions' runtime service account
(2nd gen default: `<PROJECT_NUMBER>-compute@developer.gserviceaccount.com`).

1. Play Console → **Users and permissions** → **Invite new users** → the service account e-mail.
2. App permissions for the ORT Master app: **View financial data, orders, and cancellation survey
   responses** and **Manage orders and subscriptions**. Nothing else.
3. Make sure the Google Play Android Developer API is enabled in the same Cloud project.
4. Create the in-app products `exam_single`, `exam_pack_5`, `exam_pack_10` as **consumables**.

Purchases must be made with `applicationUserName = sha256(uid)` (hex); the server rejects tokens
whose `obfuscatedExternalAccountId` belongs to another account.

### 7. Real-time developer notifications (refunds/cancellations)

1. Deploy once (the `play-billing` topic is created for the `billingRtdn` trigger), or create it:
   `gcloud pubsub topics create play-billing`.
2. Grant `google-play-developer-notifications@system.gserviceaccount.com` the **Pub/Sub Publisher**
   role on `projects/knowleg-33f36/topics/play-billing`.
3. Play Console → Monetize with Play → **Monetization setup** → Real-time developer notifications:
   topic `projects/knowleg-33f36/topics/play-billing`, notification content
   **"Subscriptions, voided purchases, and all one-time products"**. Click **Send test notification**
   and check the `billingRtdn` log for "RTDN test notification received".

`billingSweepVoided` polls the Voided Purchases API daily for the last 2 days (missed RTDNs,
quantity-based partial refunds) and retries `consume` for granted-but-unconsumed purchases.
Refunded credits never go below zero; spent credits are recorded as `debt_credits` on
`entitlements/{uid}` and settled from the next purchase.

### 8. App Check

Register the Android app with **Play Integrity** (and a debug provider for development builds) in
Firebase console → App Check. Callables enforce App Check whenever `APP_CHECK_ENFORCE=true`, so
the Flutter app must activate App Check before the first callable. Turn on Firestore/Storage
enforcement in the console separately, after the app release that ships App Check.

### 9. Deploy

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
firebase deploy --only functions
```

Indexes take a few minutes to build; `examExpireStale` and the exam/billing queries fail with
`FAILED_PRECONDITION` until they are ready.

During function discovery the CLI prints `params.APP_CHECK_ENFORCE.value() invoked during
function deployment` once per callable. That comes from `onCall` itself resolving the
`enforceAppCheck` expression at load time; it is expected and harmless (the value is read again
at runtime, where the param is set).

### 10. First super admin

Admin rights come from the custom claim `role` (`super_admin`, `content_manager`,
`methodologist`, `moderator`, `support`). A legacy `users/{uid}.role == 'admin'` counts as
`super_admin`, so an existing admin can call `adminSetRole({uid: <own uid>, role: 'super_admin'})`
to receive the claim, then assign other roles. Claims refresh on the next ID-token refresh
(sign out/in). Storage content uploads (`exam_media/`, `lesson_media/`) check the claim only.

## Behaviour notes

- **Exams.** `examStart` runs one transaction: resume an in-progress attempt of the same variant
  (free), else claim the free exam, else spend one credit, else `NO_ENTITLEMENT`. Only the current
  section's questions are returned, without keys; quantitative-comparison items carry the
  blueprint's fixed options. A section submitted later than deadline + 120 s is accepted but
  marked `late` (attempt becomes leaderboard-ineligible). The next section's clock starts when the
  server accepts the previous one. Re-submitting a closed section returns the current state
  (idempotent retry). The last section grades against `exam_question_keys`, writes `result`,
  `user_mistakes` (source `exam`), XP (`xp_events/{uid}/events/exam_{attemptId}`), `user_stats`,
  weekly/all-time (and subject-weekly) leaderboards and variant stats.
- **Expiry.** `examExpireStale` closes attempts whose current deadline passed more than 15 minutes
  ago, using `drafts/{sectionId}` for the open section; all closed sections are `late`.
- **XP.** Server-only, idempotent per event id. Practice XP is capped at 200/day (Bishkek day) and
  never reaches leaderboards; only exam XP from eligible attempts does.
- **AI tutor.** Opus with `output_config.effort: 'low'`, server-side refusal fallback
  (`fallbacks: 'default'`, beta `server-side-fallback-2026-07-01`), cached system prompt, no
  sampling parameters. Quota is reserved in a transaction before the model call and returned on
  API failure. Questions of an in-progress attempt are rejected (`AI_EXAM_IN_PROGRESS`).
  Token usage and an informational cost estimate go to `ai_usage/{uid}/days/{yyyy-mm-dd}`.
- **Account deletion.** Deletes all per-user documents (new and legacy collections, attempts with
  sub-collections, leaderboard entries, Storage avatars/temp uploads) and the Auth user;
  `purchases` and legacy `payments` are kept for finance/fraud review with
  `uid = 'deleted:' + sha256(uid)`.
