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

The referral *reward* (inside `billingVerifyPurchase`) needs a real Google Play purchase and is
covered by the unit tests in `functions/test/referral.test.ts` only. Real FCM sends are not
exercised on the emulators (dry runs only).

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
# 2. Seed: ORT 2026 blueprints, 4 published variants, pricing, subjects, a lesson, practice questions,
#    promo code DEMO2026 (2 credits)
cd tests/e2e && node seed_dev.mjs
# 3. Optional local super_admin for the CMS (see seed_admin_dev.mjs for the emulator-only login)
node seed_admin_dev.mjs
# 4. The app in emulator mode (talks only to the demo-ort-e2e emulators; App Check off)
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=BILLING_MODE=external
#    Android emulator: add --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Students sign up in the app itself (the Auth emulator accepts any address).
Nothing here can reach the production project: the app swaps its project id
for `demo-ort-e2e` and connects every Firebase service to the local emulators.
