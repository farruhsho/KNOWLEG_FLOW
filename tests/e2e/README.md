# End-to-end backend tests (Firebase emulators)

Drives the real Cloud Functions (`functions/lib`) and the real `firestore.rules` /
`storage.rules` with the Firebase **client** SDK, the way the app does:
free first exam → draft autosave → forward-only sections → honest result →
review only after completion → server XP/leaderboards/mistakes → NO_ENTITLEMENT →
admin credit grant (logged) → paid attempt → capped practice XP → account deletion.

Requirements: Node 22+, Java 21 (`JAVA_HOME`), `firebase-tools` 15 on `PATH`.

```bash
cd functions && npm ci && npm run build && cd ../tests/e2e
npm install
FUNCTIONS_DISCOVERY_TIMEOUT=60 npm test
```

`FUNCTIONS_DISCOVERY_TIMEOUT` (seconds) avoids the emulator's 10 s code-load
limit on slow or busy machines. The project id `demo-ort-e2e` is emulator-only;
its function params live in `functions/.env.demo-ort-e2e` (App Check off).
