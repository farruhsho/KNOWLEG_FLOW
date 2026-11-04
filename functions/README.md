# ORT Master KG — Cloud Functions (2nd gen)

Server side of the contract in [`docs/modernization/ARCHITECTURE.md`](../docs/modernization/ARCHITECTURE.md) §3
(phase 3 — referrals, promo codes, friends, groups, broadcasts, analytics — §9).
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
| `referralGetCode`, `referralApply`, `friendAdd` | callable | signed-in |
| `promoRedeem` | callable | signed-in |
| `groupCreate`, `groupJoin`, `groupLeave`, `groupRemoveMember` | callable | signed-in (owner for remove) |
| `adminUpsertPromoCode` | callable | `super_admin` (`grant_credits`) |
| `adminSendNotification` | callable | `super_admin`, `content_manager` (`send_notifications`) |
| `examExpireStale` | schedule, every 30 min (Asia/Bishkek) | — |
| `billingRtdn` | Pub/Sub topic `play-billing` | — |
| `billingSweepVoided` | schedule, daily 04:00 (Asia/Bishkek) | — |
| `sendStudyReminders` | schedule, daily 18:00 (Asia/Bishkek) | — |
| `onUserBanChanged` | Firestore `users/{uid}` updated | — |

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
    access.ts          deleted/banned accounts, recent sign-in, no tutor during an exam
    activity.ts        recordActivity event ids, lesson pointers, 0-award rule
    leaderboard.ts     board selection (weekly/all-time for all XP, subject boards for exams)
    reminders.ts       study-reminder targeting, quiet hours, ru/ky texts
    tutor_quota.ts     AI tutor input validation, daily quota, cost estimate
    tutor_prompt.ts    frozen (cacheable) system prompt + per-request context
    blueprint_validation.ts  variant vs blueprint checks before publishing
    codes.ts           referral / group join codes (6 chars, unambiguous alphabet), promo code format
    referral.ts        referralApply rules, first-paid-grant reward, monthly cap (Bishkek month)
    promo.ts           promoRedeem decision (10 attempts/day), adminUpsertPromoCode validation
    groups.ts          friend / group limits, join / leave / remove decisions
    notifications.ts   broadcast input, audience filter, language, FCM batches of 500, 3/day
    regions.ts         kg_regions.json index, users.region -> region id (leagues, audiences)
    timings.ts         exam timings sanitizing, topic_time_avg / slow_topics, activity seconds
    time.ts, types.ts, hash.ts, reasons.ts
  handlers/            thin Firebase adapters (Firestore transactions, Auth, Play, Anthropic)
test/                  node:test unit tests for every domain module
```

## Local development

```bash
cd functions
npm install
npm run build      # clean + tsc + copies ../assets/data/{exam_blueprints,kg_regions}.json to lib/data/
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
| `APP_CHECK_ENFORCE` | `true` | Reject student callables (exam*, billing, aiTutor, recordActivity, accountDelete) without a valid App Check token. `false` only for the emulator. |
| `APP_CHECK_ENFORCE_ADMIN` | `false` | Same for the `admin*` callables. They already require a staff role (fresh custom claims), and the CMS also runs on web/desktop builds; set `true` once every admin client ships App Check. |
| `PLAY_PACKAGE_NAME` | `com.example.knowledge_flow` | Play `applicationId`. Change together with the Android app id before the first Play upload. |
| `ALLOW_TEST_PURCHASES` | `false` | Grant credits for license-tester purchases. Keep `false` in production. |
| `AI_TUTOR_MODEL` | `claude-opus-5-5` | Model for the tutor and the question drafter (owner can switch without an app release). |

```dotenv
# functions/.env.knowleg-33f36  (example values)
APP_CHECK_ENFORCE=true
APP_CHECK_ENFORCE_ADMIN=false
PLAY_PACKAGE_NAME=kg.example.ortmaster
ALLOW_TEST_PURCHASES=false
AI_TUTOR_MODEL=claude-opus-5-5
```

### 5. Firestore config documents (optional, defaults shown)

- `config/pricing` — `{products: {exam_single: 1, exam_pack_5: 5, exam_pack_10: 10}, free_exams_per_user: 1}`.
  Written by `adminUpdatePricing`; prices shown to users always come from Google Play.
  `free_exams_per_user` is an integer in **0..5** (inclusive): `adminUpdatePricing` rejects anything else
  with `VALIDATION_FAILED`, and on read a missing or out-of-range value means 1
  (`FREE_EXAMS_PER_USER_*` in `src/domain/entitlements.ts`). The admin CMS and the student client use the same range.
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
Firebase console → App Check. Student callables enforce App Check whenever `APP_CHECK_ENFORCE=true`,
so the Flutter app must activate App Check before the first callable. The web build activates it
only when built with `--dart-define=APP_CHECK_WEB_SITE_KEY=<reCAPTCHA Enterprise site key>` (register
the web app with reCAPTCHA Enterprise in the console); Windows/Linux builds have no App Check
provider, so student callable features show "not available on this platform" there. The `admin*`
callables follow `APP_CHECK_ENFORCE_ADMIN` (default `false`), so the CMS works on web and desktop.
Turn on Firestore/Storage enforcement in the console separately, after the app release that ships
App Check.

### 9. Deploy

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
firebase deploy --only functions
```

Indexes take a few minutes to build; `examExpireStale` and the exam/billing queries fail with
`FAILED_PRECONDITION` until they are ready.

`storage.rules` reads `users/{uid}.role` through cross-service rules (legacy admin fallback). On the
first `firebase deploy --only storage` the CLI asks to grant the Storage service agent the
**Firebase Rules Firestore Service Agent** role; accept it, or legacy admins (no role claim) cannot
upload CMS media.

Phase 3 needs one more index override (in `firestore.indexes.json`): `members.uid` with
collection-group scope (accountDelete finds the user's group memberships). Broadcast audiences page
through `users` ordered by document id and filter in code, so they need no composite index.

`onUserBanChanged` is a Firestore trigger (Eventarc): it must be deployed in the Firestore
database's region (see step 1). `sendStudyReminders` needs the Firebase Cloud Messaging API
(enabled by default for Firebase projects).

During function discovery the CLI prints `params.APP_CHECK_ENFORCE.value() invoked during
function deployment` (and the same for `APP_CHECK_ENFORCE_ADMIN`) once per callable. That comes from `onCall` itself resolving the
`enforceAppCheck` expression at load time; it is expected and harmless (the value is read again
at runtime, where the param is set).

### 10. First super admin

Admin rights come from the custom claim `role` (`super_admin`, `content_manager`,
`methodologist`, `moderator`, `support`). A legacy `users/{uid}.role == 'admin'` counts as
`super_admin`, so an existing admin can call `adminSetRole({uid: <own uid>, role: 'super_admin'})`
to receive the claim, then assign other roles. Claims refresh on the next ID-token refresh
(sign out/in). Storage content uploads (`exam_media/`, `lesson_media/`) accept the claim or the
legacy field (cross-service rules, see step 9); migrating to the claim is still recommended.

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
- **ExamResult** carries `incorrect` (scored, answered wrongly) and `skipped` (scored, unanswered)
  besides `correct`/`total`/`answered`; `correct + incorrect + skipped == total`.
- **Publishing variants (parts).** `adminPublishVariant` assigns each question to a blueprint part
  (`partForValidation` in `src/domain/blueprint_validation.ts`): an explicit `part_id` must name a
  part of the section; a question with no `part_id` (missing, `null` or `''`) in a **single-part**
  section belongs to that part, so pipeline items (with `part_id`) and CMS items (`part_id: null`)
  can be mixed; in a **multi-part** section a missing `part_id` is `question_wrong_part` as soon as
  any question of the section has one (no inference by type). Only a section where no question
  has a `part_id` falls back to positional parts.
- **Question tables.** Firestore stores `table: {headers: [...], rows: [{cells: [...]}]}` (an array
  cannot directly contain an array). Every callable response (exam payload, `examGetReview`, tutor
  context) normalizes it to the wire shape `rows: [[...]]`; documents in the old shape are accepted.
- **XP and leaderboards.** Server-only, idempotent per event id (`lesson_{hash}` once per lesson,
  `practice_{day}_{hash}` once per ref per Bishkek day). Practice XP is capped at 200/day; once the
  cap is reached a call earns 0 and writes nothing. `weekly_{YYYY}-W{ww}` and `all_time` get all
  awarded XP (eligible exams + lessons + practice); `subject_{key}_weekly_{YYYY}-W{ww}` boards are
  exam-only, keyed `main`, the subject id, or `state_language`. `daily_lessons/{day}` ids are
  resolved to the lesson they point at.
- **Account state.** `examStart`, `billingVerifyPurchase`, `aiTutor` and `recordActivity` check that
  the Auth user still exists (an ID token outlives `accountDelete` by up to an hour) and reject
  deleted/disabled accounts with `unauthenticated`. Banned users (`users/{uid}.is_banned`, written
  by moderators) get `permission-denied` with reason `USER_BANNED` from `examStart`, `aiTutor`,
  `recordActivity` and `adminAiDraftQuestions`, never get leaderboard XP, and `onUserBanChanged`
  deletes their existing leaderboard entries when the ban is set.
- **Study reminders.** `sendStudyReminders` (18:00 Bishkek) messages users with
  `users/{uid}.daily_reminder_enabled == true` and `fcm_tokens` whose `user_stats.last_active_day`
  is not today, in `preferred_language` (ru/ky); dead tokens are removed from `fcm_tokens`; nothing
  is sent between 22:00 and 08:00.
- **AI tutor.** Opus with `output_config.effort: 'low'`, server-side refusal fallback
  (`fallbacks: 'default'`, beta `server-side-fallback-2026-07-01`), cached system prompt, no
  sampling parameters. Quota is reserved in a transaction before the model call and returned on
  API failure. While the user has any in-progress exam attempt every request is rejected
  (`AI_EXAM_IN_PROGRESS`), whatever ids the client sends. Message limit: 2000 characters.
  Token usage and an informational cost estimate go to `ai_usage/{uid}/days/{yyyy-mm-dd}`.
- **Account deletion.** Requires a recent sign-in: the ID token's `auth_time` must be at most
  5 minutes old, else `failed-precondition` with reason `REQUIRES_RECENT_LOGIN` (the client
  re-authenticates and retries). Deletes the Auth user first, then all per-user documents (new and
  legacy collections, attempts with sub-collections, leaderboard entries, Storage avatars/temp
  uploads); a retry after a partial failure finishes the data cleanup;
  `purchases` and legacy `payments` are kept for finance/fraud review with
  `uid = 'deleted:' + sha256(uid)`.
  Phase 3 adds: friend list, referral tree and code, promo attempt counters, the referrer's item
  about the user, group memberships (owned groups are deleted with their assignments; the other
  members' `group_ids` are cleaned).

## Phase 3 (ARCHITECTURE §9)

New `details.reason` codes: `CODE_INVALID` (not-found), `CODE_EXPIRED` (failed-precondition),
`CODE_EXHAUSTED` (resource-exhausted), `ALREADY_REDEEMED` (already-exists), `RATE_LIMITED`
(resource-exhausted), `REFERRAL_NOT_ALLOWED` (failed-precondition, `details.why`: `own_code`,
`already_referred`, `has_exams`, `has_purchases`), `LIMIT_REACHED` (resource-exhausted,
`details.what`), `NOT_GROUP_OWNER` (permission-denied).

- **Referrals.** `referralGetCode {}` → `{code}` creates the code once (6 characters from
  `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, reserved in `referral_codes/{code}`, mirrored to the
  privileged `users/{uid}.referral_code`). `referralApply {code}` → `{ok}` sets the privileged
  `users/{uid}.referred_by` and `referrals/{referrer}/items/{uid}` (`status: joined`); allowed only
  while the caller has no completed exam and no purchase, never with the caller's own code, and
  only one referrer per account (re-applying the same code is an idempotent `{ok: true}`).
  **Reward:** inside the `billingVerifyPurchase` grant transaction, the referred user's first
  non-test paid grant adds +1 credit to both (ledger `reason: 'referral'`, item → `rewarded`).
  The referrer gets at most 20 rewards per Bishkek calendar month (`referrals/{referrer}.month_key`
  / `month_rewarded`); past the cap only the referred user is rewarded (`referrer_capped: true`).
  A refund of that purchase does not take the referral credits back.
- **Promo codes.** `adminUpsertPromoCode {code, credits 1..10, maxRedemptions?, expiresAt? (ms),
  active, note}` → `{ok, code, created}` (code upper-cased, 4–20 `A-Z0-9`; `admin_logs`).
  `promoRedeem {code}` → `{credits, balance}` in one transaction: every call is counted in
  `promo_attempts/{uid}_{yyyy-mm-dd}` (Bishkek day; the 11th call of the day is `RATE_LIMITED`),
  checks are unknown/inactive → `CODE_INVALID`, already redeemed → `ALREADY_REDEEMED`, expired →
  `CODE_EXPIRED`, `redemptions >= max_redemptions` → `CODE_EXHAUSTED`; on success
  `promo_codes/{CODE}/redemptions/{uid}`, `redemptions + 1` and a ledger `reason: 'promo'` entry.
  Promo and referral credits are gifts: they do not count as purchases and do not settle refund debt.
- **Friends.** `friendAdd {code}` (the friend's referral code) → `{ok, friendUid, displayName}`
  writes `friends/{uid}/list/{friendUid} = {display_name, added_at}`; one-directional, idempotent,
  never yourself (`VALIDATION_FAILED`), at most 50 (`LIMIT_REACHED`). The owner deletes entries
  directly (rules).
- **Groups.** `groupCreate {name 2..60}` → `{groupId, joinCode}`; `groupJoin {code}` →
  `{groupId, name}`; `groupLeave {groupId}` → `{ok}`; `groupRemoveMember {groupId, uid}` → `{ok}`.
  The owner is a member (`members/{uid}.role == 'owner'`, listed in `group_ids`), so "≤ 5 own
  groups" and "≤ 5 memberships" are both enforced; a group holds at most 500 members.
  Members docs, `member_count` and `users.group_ids` change in one transaction. The owner can
  leave only as the last member, which deletes the group (assignments, submissions, join code);
  otherwise `VALIDATION_FAILED` (`why: owner_has_members`). Leaving / removal also deletes the
  current week's group-league entry. Join codes are reserved in `group_join_codes/{code}`.
  Assignments and submissions are written by clients under `firestore.rules`.
- **Leagues.** Wherever weekly XP is written (exam completion, `recordActivity`), the same XP also
  goes to `leaderboards/region_{regionId}_weekly_{YYYY}-W{ww}` (region id from
  `assets/data/kg_regions.json`, matched from `users.region.oblast`, a region id or legacy
  `region_id`) and `leaderboards/group_{gid}_weekly_{YYYY}-W{ww}` for each `users.group_ids` entry.
  Banned users get no entries, as before.
- **Broadcasts.** `adminSendNotification {title: {ru, ky}, body: {ru, ky}, audience: {kind:
  all|language|region|group, value?}, dryRun?}` → `{recipients, tokens, sent, failed, pruned,
  notificationId, dryRun}`. Recipients: not banned, with `fcm_tokens`; text by
  `preferred_language` (`ky*` → ky, else ru; an empty language falls back to the other). Audiences
  page through `users` by document id and filter in code (group: the group's members). Multicast
  batches of ≤ 500 tokens per language; invalid tokens are removed. At most 3 real sends per
  Bishkek day (`notification_quota/{day}`, `RATE_LIMITED`); `dryRun` only counts (no history,
  `notificationId: null`, not capped). History in `notifications/{id}` (`status: sending → sent |
  failed`), plus `admin_logs`.
- **Exam timings.** `examSubmitSection` accepts `timings: {questionId: seconds}`; only questions of
  the submitted section with values in `[0, section duration]` (rounded to whole seconds) are kept
  in `answers/{sectionId}.timings`, anything else is dropped (a non-object is `VALIDATION_FAILED`).
  `ExamResult.topic_time_avg` = mean seconds per topic (1 decimal) over timed questions;
  `slow_topics` = topics whose mean is above 1.5 × the attempt's median per-question time, slowest
  first. Both are always present (`{}` / `[]` without timings).
- **Study time.** `recordActivity` accepts `seconds` (integer 0..3600, else `VALIDATION_FAILED`):
  `user_stats.study_seconds_total`, `study_seconds_today` and `study_day` (Bishkek day; today is
  capped at 24 h). Study time is recorded even when the call earns no XP (duplicate, daily cap).
