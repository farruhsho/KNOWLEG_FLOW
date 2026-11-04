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
real project. The test files run one after another (`--test-concurrency=1`): both use the
Firestore emulator, and `storage.rules` reads `users/{uid}` through cross-service rules, so the
storage tests also need the Firestore emulator.

What is covered:

- `users/{uid}`: create cannot claim privileges (`role`, `roles`, `is_premium`, paid
  `subscription`, ban fields, …); owners cannot change privileged fields or delete the profile;
  staff access by role; a valid custom claim overrides the legacy `users.role == 'admin'`.
  Moderators ban/unban with the exact CMS map (`is_banned`, `ban_reason`, `banned_by` = self,
  `banned_at`) but cannot touch premium/roles or ban staff; reminder fields stay owner-writable.
- Exam content: students never read `exam_questions`, `exam_question_keys`, `exam_passages`;
  only published variants are visible; variants cannot be published by a direct write; only
  reviewers approve questions; content managers may edit metadata of approved questions but not
  reviewed fields; non-reviewers change a key's `correct` only together with a draft question.
- Attempts: owner read-only; drafts only for the current section, before deadline + 2 min, with
  the allowed keys and size limits, including the exact map the app's draft sink writes
  (`{answers, flags, client_updated_at: serverTimestamp()}`).
- Server-owned collections (`entitlements`, `purchases` incl. the private token,
  `user_stats`, `xp_events`, `leaderboards`, `ai_usage`, `config`, `admin_logs`): no client writes;
  super_admin, support and moderator read `entitlements`, its ledger and `user_stats`.
- `user_mistakes`: owner writes practice items; exam items only allow schedule updates (the exact
  maps of the app's exam-review path).
- `forum_posts`: banned users cannot post or edit.
- Legacy collections (`user_gamification`, `user_achievements`, `daily_quests`, `gamification`,
  `daily_lessons`, content collections, `payments`, `forum_posts`, progress docs) and default deny.
- Storage: content media by role (claim, or legacy `users.role == 'admin'` without a claim) with
  type/size limits (SVG rejected), avatars, `temp_uploads` images ≤ 5 MB, deletes where writes are
  allowed.
- Phase 3 (ARCHITECTURE §9): `referral_code`, `referred_by`, `group_ids` are privileged on
  `users`; `referral_codes`, `group_join_codes`, `promo_attempts`, `notification_quota` have no
  client access; `promo_codes` (+ `redemptions`) readable only by `super_admin`; `referrals`
  (counters + items) readable by the referrer; `friends/{uid}/list` owner read + delete only;
  `groups` and `members` readable by members only, never client-written; assignments created /
  edited / deleted by the group owner with the §9.3 map (kind, sizes, immutable `created_by` /
  `created_at`, banned owners rejected); submissions `{done_at, score_percent? 0..100}` written by
  the member for themself only, read by the owner (all) or the member (own); `notifications`
  readable by every admin role; `config/achievements` read by signed-in users, written by
  `super_admin` / `content_manager` with keys `titles`, `descriptions`, `disabled` only; region and
  group league boards read-only.

CI: add a job with `actions/setup-java` (21) + `actions/setup-node` (22) running `npm ci && npm test`
in this directory (the existing `.github/workflows/flutter-ci.yml` has a commented-out
`rules-test` placeholder).
