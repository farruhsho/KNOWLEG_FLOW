# End-to-end backend tests (Firebase emulators)

Drives the real Cloud Functions (`functions/lib`) and the real `firestore.rules` /
`storage.rules` with the Firebase **client** SDK, the way the app does:
free first exam → draft autosave → forward-only sections (with per-question timings) → honest
result incl. `topic_time_avg` / `slow_topics` → review only after completion → server
XP/leaderboards/mistakes → NO_ENTITLEMENT → admin credit grant (logged) → paid attempt →
phase 3 (ARCHITECTURE §9): admin promo code + redeem once (`ALREADY_REDEEMED`) → referral code +
apply (`REFERRAL_NOT_ALLOWED` after an exam / own code) → `friendAdd` → group create/join/leave
with an owner assignment, a member submission, non-member denial, region/group league entries and
study seconds → `adminSendNotification` dry-run counts per audience → capped practice XP →
account deletion (incl. phase 3 data).

`e2e_phase4.test.mjs` covers phase 4 (ARCHITECTURE §10) on a seeded chemistry pool of 1.5
variants: `examStart` `mode: 'fresh'` assembles a NEW variant per attempt (free first, then 1
credit; `exam_variants/fresh_{attemptId}` with `status: 'generated'`, unreadable by students),
resume, exact topic × difficulty cells, easy → hard order, review; the second attempt uses every
unseen question and reports the repeats (`freshness`); `POOL_TOO_SMALL` (biology) charges nothing;
`adminUpdateExamPool` / `adminExamPoolHealth`; strict style (`SECTION_NOT_OVER` before the deadline,
flags ignored); web payments with the emulator-only **sandbox** provider: order → checkout page
(«Тестовая оплата — только эмулятор», «Оплатить (тест)» / «Отменить») → signed webhook → +1 credit,
ledger `web_{orderId}`, idempotent replay, bad signature 401, wrong amount → `failed` +
`admin_logs`, cancel, 10 orders/day, `adminRefundOrder` and provider `refunded` webhooks with
clawback (debt when spent), the referral reward of the first web payment and its clawback (same
code as Google Play), `ORDER_NOT_FOUND`, and account deletion (orders anonymized, generated
variants deleted). `PAYMENTS_DISABLED` cannot occur on the emulator (it runs the sandbox) and is
covered by `functions/test/payments.test.ts`.

The Google Play referral *reward* path (inside `billingVerifyPurchase`) needs a real Play purchase;
it shares its code with web payments (`functions/src/handlers/credit_grants.ts`), which the
phase 4 test exercises. Real FCM sends are not exercised on the emulators (dry runs only).

Requirements: Node 22+, Java 21 (`JAVA_HOME`), `firebase-tools` 15 on `PATH`.

```bash
cd functions && npm ci && npm run build && cd ../tests/e2e
npm install
FUNCTIONS_DISCOVERY_TIMEOUT=60 npm test
```

`FUNCTIONS_DISCOVERY_TIMEOUT` (seconds) avoids the emulator's 10 s code-load
limit on slow or busy machines. The project id `demo-ort-e2e` is emulator-only;
its function params live in `functions/.env.demo-ort-e2e` (App Check off).

## Running the app against the emulators (manual UI testing)

```bash
# 1. Emulators (Java 21) — keep running
FUNCTIONS_DISCOVERY_TIMEOUT=60 firebase emulators:start --project demo-ort-e2e --only auth,firestore,functions,storage
# 2. Seed: ORT 2026 blueprints, 4 published variants, pricing (+ web products), subjects, a lesson,
#    practice questions, promo code DEMO2026 (2 credits), config/exam_pool and the pilot bank
cd tests/e2e && node seed_dev.mjs
# 3. Optional local super_admin for the CMS (see seed_admin_dev.mjs for the emulator-only login)
node seed_admin_dev.mjs
# 4. The app in emulator mode (talks only to the demo-ort-e2e emulators; App Check off)
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=BILLING_MODE=external
#    Android emulator: add --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
# 5. Web payments with the sandbox provider (the return URL must be on PAYMENT_RETURN_ORIGINS,
#    functions/.env.demo-ort-e2e: http://localhost:8088 or http://127.0.0.1:8088)
flutter run -d chrome --web-port 8088 --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=BILLING_MODE=web
```

Phase 4 seed data (all emulator-only):

- `config/exam_pool = {fresh_enabled: true, min_review_status: 'ai_verified'}` — a **pilot
  setting for the emulator only**: the pilot bank is checked by an independent AI solver but not
  yet by a methodologist. Production keeps the default `methodologist_approved` until the owner
  changes it with `adminUpdateExamPool` (super_admin).
- Every committed ort_main_2026 ru bank (`content/bank/*/items.json` except `sample`: the pilot set
  `pilot_main_ru_v1_*` and set 2 `main_ru_v2_*`, 150 original `ai_verified` questions + 3 reading
  passages each) in `exam_questions` / `exam_question_keys` / `exam_passages` (§1.3 shape with
  `part_id`, plus `blueprint_id`, `passage_order`, `dedup_excluded`, `assembly_excluded` and the
  passage `layout`, as the pipeline importer writes them), so «Новый вариант» of the main test (ru)
  can be started in the app. The 300 questions make two disjoint variants: further attempts honestly
  report «N заданий вы уже встречали». The demo filler of the 4 library variants is
  `assembly_excluded` (never in a fresh variant).
- `config/pricing.web_products`: `exam_single` 1 credit = 100 som (on sale), packs disabled.
- `PAYMENT_PROVIDER=sandbox`: the «Оплатить» button opens the emulator's test checkout page
  («Тестовая оплата — только эмулятор»); its buttons send a signed webhook, no money moves. The
  sandbox refuses to load outside the Functions emulator or for a non-`demo-*` project.

Students sign up in the app itself (the Auth emulator accepts any address).
Nothing here can reach the production project: the app swaps its project id
for `demo-ort-e2e` and connects every Firebase service to the local emulators.
