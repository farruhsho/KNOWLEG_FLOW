# Security-rules tests

Emulator tests for [`firestore.rules`](../../firestore.rules) and [`storage.rules`](../../storage.rules)
using `@firebase/rules-unit-testing` and `node:test`.

**Status: written but not yet run.** They need the Firebase emulators, which need Java 21+;
Java is not installed on the machine where they were written. Run them before the first rules
deploy and fix any failure in the rules (not in the tests) unless the test contradicts
`docs/modernization/ARCHITECTURE.md`.

```bash
# prerequisites: Node 22+, Java 21+ (e.g. Temurin 21)
cd tests/rules
npm install
npm test               # firestore + storage
npm run test:firestore
npm run test:storage
```

`npm test` starts the emulators via `firebase emulators:exec` with the repo's `firebase.json`
(Firestore 8080, Storage 9199) under the demo project `demo-ort-rules`, so nothing touches the
real project.

What is covered:

- `users/{uid}`: create cannot claim privileges (`role`, `roles`, `is_premium`, paid
  `subscription`, …); owners cannot change privileged fields or delete the profile; staff access
  by role; a valid custom claim overrides the legacy `users.role == 'admin'`.
- Exam content: students never read `exam_questions`, `exam_question_keys`, `exam_passages`;
  only published variants are visible; variants cannot be published by a direct write; only
  reviewers approve questions.
- Attempts: owner read-only; drafts only for the current section, before deadline + 2 min, with
  the allowed keys and size limits.
- Server-owned collections (`entitlements`, `purchases` incl. the private token,
  `user_stats`, `xp_events`, `leaderboards`, `ai_usage`, `config`, `admin_logs`): no client writes.
- `user_mistakes`: owner writes practice items; exam items only allow schedule updates.
- Legacy collections (`user_gamification`, `user_achievements`, `daily_quests`, `gamification`,
  `daily_lessons`, content collections, `payments`, `forum_posts`, progress docs) and default deny.
- Storage: content media by role with type/size limits, avatars, `temp_uploads` images ≤ 5 MB,
  deletes where writes are allowed.

CI: add a job with `actions/setup-java` (21) + `actions/setup-node` (22) running `npm ci && npm test`
in this directory (the existing `.github/workflows/flutter-ci.yml` has a commented-out
`rules-test` placeholder).
