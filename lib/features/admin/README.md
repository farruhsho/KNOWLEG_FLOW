# Admin CMS (`lib/features/admin`)

Role-based content and operations console for ORT Master KG. Contract:
`docs/modernization/ARCHITECTURE.md` (§1 collections, §2 roles, §3 callables).

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
| `/admin/variants`, `/admin/variants/:id` | Variant builder, publish via `adminPublishVariant` | edit_questions / publish_variants |
| `/admin/ai-drafts` | `adminAiDraftQuestions` → drafts | super_admin, content_manager, methodologist |
| `/admin/users`, `/admin/users/:uid` | Users, entitlements, ledger; ban/premium; `adminSetRole`; `adminGrantCredits` | view_users / moderate_users / super_admin |
| `/admin/payments` | Read-only `purchases` | view_payments |
| `/admin/pricing` | `config/pricing` via `adminUpdatePricing` | manage_pricing |
| `/admin/logs` | `admin_logs` | super_admin, support |

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
  / rejected; content edits by non-reviewers send a question back to draft.
* No secrets in the client: AI generation, role changes, credits, pricing and
  publishing go through callables.

Tests: `flutter test test/admin`.
