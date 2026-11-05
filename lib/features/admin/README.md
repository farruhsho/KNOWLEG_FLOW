# Admin CMS (`lib/features/admin`)

Role-based content and operations console for ORT Master KG. Contract:
`docs/modernization/ARCHITECTURE.md` (§1 collections, §2 roles, §3 callables,
§9 phase 3: promo codes, broadcasts, achievements, referrals and groups;
§10 phase 4: fresh-variant pool, website orders and prices).

## Access

* Sign-in: `/admin/login` → Firebase Auth email/password → role from the custom
  claim `getIdTokenResult(true).claims['role']`; fallback `users/{uid}.role ==
  'admin'` (= `super_admin`). Only a valid admin role sets
  `adminVerified` (`lib/core/routes/admin_session.dart`) and starts
  `adminSessionProvider` / `adminRoleProvider`
  (`lib/providers/admin_access_provider.dart`).
* Roles and the permission matrix: `domain/admin_role.dart` (exactly §2).
  Section visibility: `domain/admin_nav.dart`. Screens hide actions the role
  cannot perform; Firestore rules and the callables enforce the same matrix.
* Every `/admin/*` route re-checks the verified session (`admin_routes.dart`).

## Routes (`adminRoutes`)

| Path | Screen | Who |
|---|---|---|
| `/admin/login` | Sign-in, password reset | everyone |
| `/admin/dashboard` | `count()` counters, shortcuts | view_stats |
| `/admin/subjects` | Subjects & inline topics | edit_content |
| `/admin/lessons`, `/admin/lessons/:id` | Structured lessons (`lessons`) | edit_content |
| `/admin/questions`, `/admin/questions/:id` | Practice bank (`questions`), CSV/JSON import & export | edit_questions |
| `/admin/exam-bank`, `/admin/exam-bank/:id` | `exam_questions` + keys + passages, review | edit_questions (approve/reject: review_questions) |
| `/admin/variants`, `/admin/variants/:id` | Variant builder, publish via `adminPublishVariant` | view: edit_questions; create/edit/publish: publish_variants |
| `/admin/ai-drafts` | `adminAiDraftQuestions` → drafts | super_admin, content_manager, methodologist |
| `/admin/users`, `/admin/users/:uid` | Users, entitlements, ledger; ban (moderate_users: only `is_banned`, `ban_reason`, `banned_at`, `banned_by`, `updated_at`); premium, `adminSetRole`, `adminGrantCredits` (super_admin); read-only referral code, `referred_by`, invited count (`count()` of `referrals/{uid}/items`) and groups (`group_ids` → `groups/{gid}.name`) | view_users / moderate_users / super_admin |
| `/admin/exam-pool` | Fresh-variant pool (§10.1): `config/exam_pool` settings (`adminUpdateExamPool`, super_admin) and `adminExamPoolHealth` per blueprint × language | super_admin, content_manager, methodologist (settings: super_admin) |
| `/admin/payments` | Tabs: website orders (`payment_orders`, refund via `adminRefundOrder` — super_admin), revenue per Bishkek day (30 days), read-only Google Play `purchases` | view_payments (refund: super_admin) |
| `/admin/pricing` | Tabs: website products (`web_products` via `adminUpdatePricing({webProducts})`) and Google Play credits + free exams (`adminUpdatePricing`) | manage_pricing |
| `/admin/logs` | `admin_logs` | super_admin, support |
| `/admin/notifications` | Push broadcasts via `adminSendNotification`: ru + ky title/body, audience (all / language / region / group), reach check (dry run) required before a confirmed send; paginated `notifications` history | send_notifications |
| `/admin/promo-codes` | `promo_codes` list (paginated) and create / edit / deactivate via `adminUpsertPromoCode` | grant_credits (super_admin) |
| `/admin/achievements` | `config/achievements` editor: ru/ky title and description overrides, enabled switch, preview | manage_achievements |

`/admin/generate-questions` (old template generator) redirects to AI drafts.

## Layout

```
domain/        pure Dart: roles, nav, blueprints, variant validation, codecs
data/          Firebase handles, callables, repositories (paginated, count())
application/   Riverpod providers, cursor-paginated list notifier
presentation/  shell (sidebar ↔ drawer), pages, widgets (Markdown+LaTeX, l10n fields)
```

## Data rules kept for compatibility

* Subjects: doc id == subject id; writes the fields the student
  `SubjectModel` requires; delete = deactivate unless nothing references it.
* Lessons: structured snake_case fields plus legacy mirrors (`id`,
  `subjectId`, `content`, `order`, `createdAt` ISO string).
* Practice questions: one codec, snake_case `type`, `subject_id` + `subjectId`
  mirror; `update()` keeps unknown fields; import commits a new batch per 400.
* Exam questions: `review.status` draft → ai_verified → methodologist_approved
  / rejected. Edits of review-relevant fields (`ExamQuestionDoc.reviewRelevantFields`:
  stem, options, passage, image, language, table, type, columns A/B) by
  non-reviewers send a question back to draft; metadata, explanation and
  translation links keep the status. Updates write only the changed fields.
* Tables (`table`) are stored as `{headers, rows: [{cells}]}` (Firestore has no
  nested arrays); the CMS also reads the wire shape `rows: [[...]]`.
  Comparison items may carry `column_a` / `column_b`.
* The CMS never writes `content_hash` (the content pipeline's scheme); every
  CMS save of a question, key or passage sets `edited_in_cms_at`, which the
  pipeline treats as "edited outside the pipeline" and does not overwrite.
* Uploads: PNG, JPEG, WEBP, GIF (≤ 5 MB) and PDF (≤ 20 MB) only — SVG is
  refused before uploading (storage.rules does not accept it).
* App Check: where it is not available (Windows/Linux, web built without
  `APP_CHECK_WEB_SITE_KEY`) the shell shows a notice, and callables rejected for
  App Check get a dedicated message instead of "no permission".
* Language: the CMS is Russian-first by design; Kyrgyz ARB values of older
  `admin*` keys equal the Russian text.
* No secrets in the client: AI generation, role changes, credits, pricing and
  publishing go through callables.

## Phase 3 (ARCHITECTURE §9)

* Broadcasts (`domain/notification_draft.dart`): both languages required,
  title ≤ 65 and body ≤ 240 code points (what a phone shows untruncated; the
  callable validates again). The audience `region` value is the canonical
  oblast stored in `users/{uid}.region.oblast` (`oblast` in
  `assets/data/kg_regions.json`, the server's `region_id`), `group` is the
  group document id, `language` is `ru` / `ky`. "Send" is enabled only for
  the exact text and audience of the last reach check; any edit, a finished
  send or a failed send (a timeout may still have delivered) requires a new
  check. `LIMIT_REACHED` / `RATE_LIMITED` show the 3-per-day limit; the
  "sent today" hint is counted from the history by Bishkek day, the server
  enforces the real limit. History is ordered by `created_at`.
* Promo codes (`domain/promo_code.dart`): code `A-Z0-9`, 4–20, upper-cased;
  1–10 credits; optional max redemptions (≥ current redemptions while active)
  and expiry (end of the chosen day, 23:59 Bishkek; must be in the future
  while active). Unset optional fields are omitted from the callable payload.
  The CMS never writes `promo_codes` directly; deactivation re-sends the code
  with `active: false` and every other field unchanged.
* Achievements (`domain/achievements_config.dart`): the CMS writes
  `config/achievements` with `set()` (no merge) and exactly `titles`,
  `descriptions`, `disabled`; only the nine server ids, only ru/ky, trimmed,
  empty values dropped (empty = the app's built-in text); a text is
  overridden in both languages or neither.

## Phase 4 (ARCHITECTURE §10)

* Pool (`domain/exam_pool.dart`, `presentation/pages/exam_pool_page.dart`):
  `config/exam_pool` is read directly (signed-in users may read it) and
  changed only through `adminUpdateExamPool` with just the changed field.
  Switching `min_review_status` to `ai_verified` shows that such questions
  were checked by an independent AI solver, **not** by a methodologist, and
  needs an explicit acknowledgement. The health report is requested with
  «Проверить пул» (the callable may run up to 120 s; client timeout 150 s):
  needed vs eligible per part, counts by review status, passages, disjoint
  variants (with «не меньше» when the server capped the count) and the
  shortfalls of the next variant grouped by topic, largest gap first.
* Website orders (`domain/payment_order.dart`,
  `presentation/pages/web_payments_page.dart`): newest first, status filter
  (`(status, created_at DESC)` index), order card with every field, refund
  for super_admin only on paid + granted orders (the server rule), reason
  3–200 characters after trimming, `refunded` vs `pending` (provider confirms
  later) reported separately. Revenue: one `paid_at >=` range query (single
  field, ≤ 3000 orders) summed per Bishkek day; refunded orders are listed
  apart, not as revenue; Google Play is not included.
* Website prices (`domain/pricing_config.dart`,
  `presentation/pages/web_pricing_form.dart`): the whole `web_products` map
  is sent (the server replaces it); defaults from §10.3 are shown when it is
  missing. `exam_single` always grants 1 credit; a price other than 100 som
  shows «Базовая цена согласуется с владельцем», needs the new price typed
  again and sends `confirmBasePriceChange: true`.
* Permission-denied reads (rules not deployed yet, wrong role) show a
  no-access state instead of a raw error (`isAdminAccessDenied`).

Tests: `flutter test test/admin`.
