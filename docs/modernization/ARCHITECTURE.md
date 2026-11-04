# ORT Master KG — целевая архитектура и контракты (v1, 2026-11-02)

Этот документ — **контракт** между клиентом (Flutter), бэкендом (Cloud Functions),
правилами Firestore, контент-пайплайном и админкой. Любое изменение формата
коллекции или callable-функции сначала вносится сюда.

Принципы:

1. **Ничего не удаляем.** Новые коллекции добавляются рядом со старыми
   (`questions`, `mock_tests`, `ort_attempts`, `payments`, … остаются как есть).
   Миграция старых данных — отдельный шаг с бэкапом и подтверждением владельца.
2. **Сервер — источник истины** для: результатов экзаменов, правильных ответов
   платных вариантов, прав доступа (entitlements), покупок, XP/уровней/серий,
   рейтингов, лимитов AI, ролей админов.
3. **Структура экзамена — данные, а не код.** Формат ОРТ хранится как
   версионируемый *blueprint* (`exam_blueprints`), а не константы в Dart.
4. **Имена полей в Firestore — snake_case** (как в существующих моделях).
5. Регион функций: константа `FUNCTIONS_REGION` (по умолчанию `europe-west1`;
   должен совпадать с регионом Firestore проекта `knowleg-33f36` — проверить в
   консоли перед деплоем).

---

## 1. Коллекции (новые)

| Коллекция | Чтение клиентом | Запись клиентом | Кто пишет |
|---|---|---|---|
| `exam_blueprints/{blueprintId}` | любой вошедший | нет | content_manager+, пайплайн |
| `exam_variants/{variantId}` | вошедший, только `status=='published'` (админы — все) | нет | content_manager+, пайплайн |
| `exam_questions/{questionId}` | **нет** | нет | Admin SDK / админ-роли |
| `exam_question_keys/{questionId}` | **нет** | нет | Admin SDK / админ-роли |
| `exam_passages/{passageId}` | **нет** | нет | Admin SDK / админ-роли |
| `exam_attempts/{attemptId}` | владелец | нет | функции |
| `exam_attempts/{attemptId}/answers/{sectionId}` | владелец | нет | функции |
| `exam_attempts/{attemptId}/drafts/{sectionId}` | владелец | владелец, только текущий раздел, до дедлайна+2 мин | клиент (черновик) |
| `entitlements/{uid}` | владелец | нет | функции |
| `entitlements/{uid}/ledger/{entryId}` | владелец | нет | функции |
| `purchases/{sha256(purchaseToken)}` | владелец (`uid == auth.uid`), super_admin, support | нет | функции |
| `user_stats/{uid}` | владелец | нет | функции |
| `xp_events/{uid}/events/{eventId}` | владелец | нет | функции |
| `leaderboards/{boardId}/entries/{uid}` | любой вошедший | нет | функции |
| `ai_usage/{uid}/days/{yyyy-mm-dd}` | владелец | нет | функции |
| `config/pricing` | любой вошедший | нет | super_admin (через функцию) |
| `config/ai_tutor` | нет | нет | super_admin (через функцию) |
| `admin_logs/{logId}` | super_admin, support | нет | функции |
| `user_mistakes/{uid}/items/{questionId}` | владелец | владелец (только practice-записи) | клиент (практика), функции (экзамен) |

`user_mistakes/{uid}/items/{questionId}` — очередь «Ошибки и повторение»:
`{question_id, source: practice|exam, subject_id, section_id, topic_id,
wrong_count, last_wrong_at, next_review_at, interval_days, resolved: bool,
attempt_id?}`. Клиент может писать только документы с `source == 'practice'`
(id вопроса из коллекции `questions`); записи `source == 'exam'` пишет
`examSubmitSection` при завершении попытки (без правильного ответа — его клиент
получает через `examGetReview`). Повторение по интервалам 1 → 3 → 7 → 14 → 30
дней (`AppConstants.srsIntervals`).

Storage: `exam_media/{questionId}/{file}` и `lesson_media/{lessonId}/{file}` —
запись только для контент-ролей (custom claim `role` ∈ super_admin,
content_manager, methodologist), изображения ≤ 5 МБ, PDF ≤ 20 МБ, видео ≤ 200 МБ;
чтение — вошедшим пользователям.

### 1.1 `exam_blueprints/{blueprintId}`

**Каноничные данные — [`assets/data/exam_blueprints.json`](../../assets/data/exam_blueprints.json)**
(генератор: `tools/content_pipeline/gen_blueprints_2026.js`). Пайплайн импортирует
их в Firestore, клиент использует как офлайн-fallback. Структура сверена с
официальной брошюрой ЦООМО 2026 (см. `ORT_SPEC.md`):

| Blueprint | Разделы (заданий / минут) |
|---|---|
| `ort_main_2026` | `math` 60/90 (часть I «сравнение величин» 30 × 4 фикс. варианта, часть II «задачи» 30 × 5 вариантов) → `verbal` 30/30 (аналогии + дополнение) → `reading` 30/60 (тексты) → `grammar` 30/35 (язык выбранного теста). Итого 150/215 |
| `ort_subject_{chemistry,biology,physics,math,history,english,kyrgyz_lit,russian_lit}_2026` | один раздел: 40/80, 40/60, 40/80, 40/80, 40/60, 50/60, 40/60, 40/60; 4 варианта |
| `ort_state_language_2026` | 50/60, только кыргызский; официальный результат — уровень 1–4 |

У раздела есть `parts[]` (подблоки без отдельного таймера): у каждой части свой
`options_per_question`, `item_type` (`single_choice`, `quantitative_comparison`
с `fixed_options`, `analogy`, `completion`, `text_based`) и флаг `verified`
(`false` = деление не опубликовано официально, это допущение).

Пример id: `ort_main_2026`, `ort_subject_chemistry_2026`, `ort_state_language_2026`.
Новый экзаменационный год = **новый документ** (`ort_main_2027`), старые попытки
продолжают ссылаться на свою версию.

```jsonc
{
  "id": "ort_main_2026",
  "kind": "main",                 // main | subject | state_language
  "subject_id": null,             // для kind=subject: "chemistry" | "biology" | ...
  "exam_year": 2026,
  "version": 1,                   // инкремент при любой правке документа
  "status": "active",             // draft | active | retired
  "title": {"ru": "Основной тест ОРТ", "ky": "ЖРТнын негизги тести", "en": "ORT Main test"},
  "languages": ["ru", "ky"],
  "options_per_question": 4,      // число вариантов ответа (сверить с testing.kg)
  "navigation": {
    "within_section": "free",     // free: можно ходить по вопросам внутри раздела
    "across_sections": "forward_only" // нельзя вернуться в завершённый раздел
  },
  "sections": [
    {
      "id": "math", "order": 1,
      "title": {"ru": "Математика", "ky": "Математика"},
      "question_count": 60, "duration_minutes": 90, "points_per_question": 1,
      "subject_area": "math",
      "topic_matrix": [ {"topic_id": "math.arithmetic", "min": 6, "max": 12} ],
      "difficulty_mix": {"1": 0.3, "2": 0.5, "3": 0.2},
      "uses_passages": false
    }
  ],
  "scoring": {
    "method": "raw",              // raw = число верных; official_scale_known=false
    "official_scale_known": false,
    "disclaimer": {"ru": "Учебный результат. Не является официальным баллом ОРТ.", "ky": "..."}
  },
  "source": {"url": "https://testing.kg/...", "verified_at": "2026-11-02", "note": "..."},
  "effective_from": "2026-01-01",
  "effective_to": null
}
```

Клиент берёт активный blueprint из Firestore и падает обратно на
`assets/data/exam_blueprints.json` (тот же формат, массив), если сети нет.

### 1.2 `exam_variants/{variantId}`

```jsonc
{
  "blueprint_id": "ort_main_2026", "blueprint_version": 1,
  "number": 1,                    // порядковый номер варианта в направлении (1..100)
  "title": {"ru": "Вариант 1", "ky": "1-вариант"},
  "language": "ru",               // ru | ky — один вариант = один язык
  "status": "published",          // draft | in_review | published | archived
  "sections": [ {"section_id": "math", "question_ids": ["q_..."]} ],
  "content_version": 3,
  "difficulty_label": "standard", // standard | advanced
  "created_by": "pipeline", "published_at": <Timestamp>, "published_by": "<uid>",
  "stats": {"attempts": 0, "avg_percent": 0}
}
```

### 1.3 `exam_questions/{questionId}` (+ ключи и тексты)

Один документ = один язык. Переводы связаны `translation_group_id`.

```jsonc
{
  "subject_id": "math", "section_id": "math",
  "topic_id": "math.quadratic_equations", "subtopic_id": "math.quadratic_equations.vieta",
  "difficulty": 2,                // 1 лёгкий, 2 средний, 3 сложный
  "language": "ru", "translation_group_id": "tg_...",
  "type": "single_choice",
  "stem": "Найдите сумму корней уравнения $x^2-5x+6=0$.",   // Markdown + LaTeX в $...$
  "options": [ {"id": "A", "text": "5"}, {"id": "B", "text": "6"}, ... ],
  "passage_id": null,             // для заданий к тексту
  "image_path": null,             // путь в Storage: exam_media/{questionId}/...
  "table": null,                  // хранение: {"headers": [...], "rows": [{"cells": [...]}]} — Firestore не хранит массив в массиве;
                                  // в ответах функций отдаётся как {"headers": [...], "rows": [[...]]} (решение D2)
  "source": {"kind": "original", "basis": "Программа 9 кл., тема ...", "author": "pipeline:v1"},
  "review": {"status": "methodologist_approved", "reviewed_by": "<uid>", "reviewed_at": <Timestamp>, "notes": ""},
  "content_version": 1, "content_hash": "sha256:...",
  "created_at": <Timestamp>, "updated_at": <Timestamp>
}
```

`exam_question_keys/{questionId}`:

```jsonc
{ "correct": "A", "explanation": "По теореме Виета ...",
  "wrong_option_notes": {"B": "Это произведение корней, а не сумма"},
  "solution_steps": ["...", "..."] }
```

`exam_passages/{passageId}`: `{language, subject_id, section_id, title, text, source}`.

`review.status`: `draft` → `ai_verified` → `methodologist_approved` (или `rejected`).
**Опубликовать вариант можно только если все его вопросы `methodologist_approved`**
и у каждого есть ключ (проверяет `adminPublishVariant`).

### 1.4 `exam_attempts/{attemptId}`

```jsonc
{
  "uid": "...", "variant_id": "...", "blueprint_id": "ort_main_2026", "blueprint_version": 1,
  "language": "ru",
  "status": "in_progress",        // in_progress | completed | expired
  "entitlement_source": "free_first", // free_first | credit | admin_grant | resume
  "current_section_index": 0,
  "current_section_id": "math",
  "current_deadline_at": <Timestamp>,
  "sections": [
    {"section_id": "math", "started_at": <Timestamp>, "deadline_at": <Timestamp>,
     "submitted_at": null, "late": false, "question_ids": ["..."]}
  ],
  "started_at": <Timestamp>, "completed_at": null,
  "integrity": {"late_sections": 0, "client_app_version": "1.0.0+1"},
  "result": null                  // заполняется при завершении, см. ExamResult
}
```

`ExamResult`:

```jsonc
{
  "correct": 97, "incorrect": 41, "skipped": 12, "answered": 138,   // incorrect/skipped — решение D4
  "total": 150, "percent": 64.7,
  "sections": [ {"section_id": "math", "correct": 38, "total": 60, "percent": 63.3} ],
  "topics": [ {"topic_id": "math.quadratic_equations", "correct": 2, "total": 5} ],
  "weak_topics": ["math.quadratic_equations"], "strong_topics": ["analogies.part_whole"],
  "xp_awarded": 197,
  "leaderboard_eligible": true,   // false, если были «поздние» разделы
  "disclaimer_key": "exam_result_unofficial"
}
```

### 1.5 `entitlements/{uid}`

```jsonc
{ "free_exam_used": false, "free_exam_used_at": null, "free_exam_attempt_id": null,
  "credits": 0, "lifetime_credits_purchased": 0, "updated_at": <Timestamp> }
```

Ledger (`entitlements/{uid}/ledger/{id}`): `{delta, balance_after, reason: purchase|exam_start|refund|admin_grant|free_first, ref, actor_uid, at}`.

**Правило бесплатного теста:** первый полноценный пробный тест (любого
направления) бесплатен **один раз на аккаунт**. Флаг хранится на сервере и
переживает переустановку. Каждая следующая попытка списывает 1 кредит
(1 кредит = 1 тест = 100 сом). Продолжение незавершённой попытки кредит не
списывает.

### 1.6 `purchases/{sha256(purchaseToken)}`

```jsonc
{ "uid": "...", "platform": "google_play", "product_id": "exam_single",
  "order_id": "GPA.1234-...", "purchase_token_hash": "...", "purchase_time": <Timestamp>,
  "state": "granted",             // pending | granted | refunded | revoked | invalid
  "credits_granted": 1, "acknowledged": true, "consumed": true,
  "price_display": "100 сом",     // информативно, со слов клиента
  "created_at": <Timestamp>, "updated_at": <Timestamp>,
  "refund": null }                // {at, source: rtdn|voided_api|admin, credits_clawed_back}
```

Продукты Google Play (consumable, управляемые в Play Console):

| product_id | Кредиты | Цена (Play Console) |
|---|---|---|
| `exam_single` | 1 | 100 KGS (базовая цена, менять только с согласия владельца) |
| `exam_pack_5` | 5 | предложение: 450 KGS |
| `exam_pack_10` | 10 | предложение: 800 KGS |

Карта product_id → кредиты хранится в `config/pricing.products` (сервер), а
цена, которую видит пользователь, всегда берётся из Google Play
(`ProductDetails.price`), а не из кода.

### 1.7 `user_stats/{uid}` и геймификация

```jsonc
{ "xp": 1240, "level": 5, "current_streak": 4, "best_streak": 11,
  "last_active_day": "2026-11-02",   // по Asia/Bishkek (UTC+6)
  "active_days_total": 23, "today_xp": 40, "daily_goal_xp": 50,
  "exams_completed": 3, "best_exam_percent": {"ort_main": 71.3},
  "achievements": {"first_lesson": <Timestamp>, "streak_7": <Timestamp>},
  "updated_at": <Timestamp> }
```

Правила начисления XP (только сервер, идемпотентно по `eventId`):

| Событие | XP | Ограничение |
|---|---|---|
| Завершён пробный экзамен | 100 + 1 за каждый верный ответ (≤ 250 всего) | 1 раз на попытку |
| Улучшен лучший результат по направлению | +50 | 1 раз на попытку |
| Завершён урок | 20 | 1 раз на урок |
| Верный ответ в практике | 2 | ≤ 200 XP/день из практики |
| Выполнена дневная цель | 10 | 1 раз в день |

Уровень: `level = floor(sqrt(xp / 50)) + 1`. Серия засчитывается за любой день
с начислением XP (граница дня — полночь по Бишкеку).

Достижения (проверяются сервером): `first_lesson`, `xp_100`, `streak_7`,
`days_30`, `accuracy_90` (экзамен ≥ 90%), `math_expert` (раздел математики
≥ 90% в 3 экзаменах), `analogies_master`, `reader`, `exam_champion`
(10 завершённых экзаменов).

Рейтинги: `leaderboards/weekly_{YYYY}-W{ww}`, `leaderboards/all_time`,
`leaderboards/subject_{subject}_weekly_{YYYY}-W{ww}`. Запись: `{display_name,
avatar_url, region_id, xp, updated_at}`. Только серверные XP, только
`leaderboard_eligible` попытки.

---

## 2. Роли администраторов

Custom claim `role` в Firebase Auth. Обратная совместимость: `users.role == 'admin'`
(старое поле) = `super_admin`.

| Право | super_admin | content_manager | methodologist | moderator | support |
|---|:-:|:-:|:-:|:-:|:-:|
| `manage_roles` | ✓ | | | | |
| `manage_pricing` | ✓ | | | | |
| `grant_credits` / `refund` | ✓ | | | | |
| `view_payments` | ✓ | | | | ✓ |
| `edit_content` (предметы, темы, уроки, медиа) | ✓ | ✓ | ✓ | | |
| `edit_questions` (вопросы, ключи, объяснения, переводы) | ✓ | ✓ | ✓ | | |
| `review_questions` (approve/reject) | ✓ | | ✓ | | |
| `publish_variants` | ✓ | ✓ | | | |
| `manage_free_tests` | ✓ | ✓ | | | |
| `view_users` | ✓ | | | ✓ | ✓ |
| `moderate_users` (бан, рейтинги) | ✓ | | | ✓ | |
| `send_notifications` | ✓ | ✓ | | | |
| `manage_achievements` | ✓ | ✓ | | | |
| `view_stats` | ✓ | ✓ | ✓ | ✓ | ✓ |

Все действия админов через функции пишут `admin_logs`.

---

## 3. Callable-функции (Cloud Functions v2, `onCall`, App Check enforced)

Ошибки — `HttpsError` с `details.reason` из списка ниже.

| Функция | Вход | Выход | Кто |
|---|---|---|---|
| `examStart` | `{variantId, clientAppVersion}` | `ExamSessionPayload` | вошедший |
| `examGetState` | `{attemptId}` | `ExamSessionPayload` | владелец |
| `examSubmitSection` | `{attemptId, sectionId, answers: {qid: "A"\|null}, flags: [qid], clientElapsedSec}` | `{completed: bool, next?: ExamSessionPayload, result?: ExamResult}` | владелец |
| `examGetReview` | `{attemptId}` | `{items: [{questionId, sectionId, stem, options, passage?, userAnswer, correct, explanation, topicId}]}` | владелец, только `completed` |
| `billingVerifyPurchase` | `{productId, purchaseToken, orderId?, priceDisplay?}` | `{status: granted\|already_processed\|pending\|invalid, credits}` | вошедший |
| `aiTutor` | `{mode, message, language, questionId?, attemptId?, history?}` | `{reply, remainingToday}` | вошедший |
| `recordActivity` | `{kind: lesson_completed\|practice_answered, refId, correct?, count?}` | `{xpAwarded, stats}` | вошедший |
| `accountDelete` | `{}` | `{ok: true}` | вошедший |
| `adminSetRole` | `{uid, role\|null}` | `{ok}` | super_admin |
| `adminGrantCredits` | `{uid, delta, reason}` | `{credits}` | super_admin |
| `adminPublishVariant` | `{variantId, publish: bool}` | `{status, problems: []}` | super_admin, content_manager |
| `adminUpdatePricing` | `{products, freeExamsPerUser}` | `{ok}` | super_admin |
| `adminAiDraftQuestions` | `{subjectId, sectionId, partId, topicId, difficulty, language, count ≤ 10}` | `{drafts: [question без id + key]}` | super_admin, content_manager, methodologist |

Рантайм: Node.js 22 (`"runtime": "nodejs22"` в `firebase.json`; Node 20 выведен
из эксплуатации 2026-10-30), `firebase-functions` ^7.4, `firebase-admin` ^14
(модульные импорты), `@anthropic-ai/sdk` ^1.3 (без `temperature/top_p/top_k`),
`@googleapis/androidpublisher`. Все onCall: `enforceAppCheck: true` (отключается
параметром `APP_CHECK_ENFORCE=false` только для эмулятора). Секреты —
`defineSecret` (`ANTHROPIC_API_KEY`); сервисный аккаунт Play — через
Application Default Credentials функции, приглашённый в Play Console.

Правила для **существующих** коллекций, которые использует текущий клиент и для
которых сейчас нет правил (запись молча отклоняется): `user_gamification`,
`user_achievements`, `daily_quests` — владелец читает и пишет (это
«косметическая» геймификация, на рейтинги не влияет; рейтинги и уровни
считаются только из серверного `user_stats`); `daily_lessons` — чтение
вошедшим, запись админ-ролям. Запись `gamification/{uid}` при регистрации
удаляется из клиента.

`ExamSessionPayload`:

```jsonc
{ "attemptId": "...", "variantId": "...", "blueprint": { /* blueprint целиком */ },
  "status": "in_progress", "currentSectionIndex": 1,
  "section": { "sectionId": "verbal", "deadlineAt": 1762080000000, "durationSec": 1800,
               "questions": [ {"id": "...", "stem": "...", "options": [{"id":"A","text":"..."}],
                               "passageId": null, "imageUrl": null, "imagePath": "exam_media/q1/fig.png", "table": null, "topicId": "..."} ],
               // imageUrl — только для https-ссылок; imagePath — путь в Storage, клиент сам получает download URL (D3)
               "passages": { "p1": {"title": "...", "text": "..."} } },
  "serverNow": 1762078200000,
  "entitlementSource": "credit" }
```

Клиент получает **только вопросы текущего раздела** и никогда — правильные ответы
до завершения попытки. Таймер раздела якорится на `deadlineAt` сервера
(клиент корректирует часы по `serverNow`).

`details.reason` (коды ошибок): `NO_ENTITLEMENT`, `VARIANT_NOT_AVAILABLE`,
`ATTEMPT_NOT_FOUND`, `ATTEMPT_NOT_IN_PROGRESS`, `WRONG_SECTION`,
`PURCHASE_INVALID`, `PURCHASE_ACCOUNT_MISMATCH`, `PURCHASE_PENDING`,
`AI_QUOTA_EXCEEDED`, `AI_DISABLED`, `AI_EXAM_IN_PROGRESS`, `FORBIDDEN_ROLE`,
`VALIDATION_FAILED`.

Фоновые функции:

| Функция | Триггер | Что делает |
|---|---|---|
| `examExpireStale` | каждые 30 мин | `in_progress` попытки, у которых дедлайн текущего раздела прошёл > 15 мин назад: разделы закрываются по черновикам (`drafts`), попытка завершается со статусом `completed` и `late` разделами |
| `billingRtdn` | Pub/Sub `play-billing` | RTDN: `oneTimeProductNotification` (отмена) и `voidedPurchaseNotification` (возврат) → отзыв кредитов |
| `billingSweepVoided` | ежедневно | Voided Purchases API за последние 2 дня (страховка от пропущенных RTDN) |

---

## 4. Режим экзамена на клиенте

* Внутри раздела — свободная навигация по вопросам, отметка «вернуться позже»,
  палитра вопросов, прогресс.
* Между разделами — **только вперёд** (`navigation.across_sections == forward_only`):
  завершённый раздел закрыт навсегда. Перед закрытием раздела — подтверждение с
  количеством неотвеченных и отмеченных вопросов.
* Таймер раздела: предупреждения за 5 мин и за 1 мин, автоматическое закрытие
  раздела по истечении.
* Каждое изменение ответа сразу сохраняется локально (Hive, бокс `exam_sessions`),
  а также раз в ~20 с и при уходе приложения в фон — в `drafts/{sectionId}`.
* Защита от случайного выхода (`PopScope` + диалог), восстановление
  незавершённой попытки при следующем запуске (баннер на главной).
* Нет сети на границе раздела → ответы сохранены, экран «Нет соединения —
  повторить»; время следующего раздела стартует только когда сервер принял
  предыдущий.
* Результат: верные/неверные/пропущенные, процент, по разделам, слабые и
  сильные темы, рекомендации, история попыток. **Всегда с пометкой
  «Учебный результат, не официальный балл ОРТ»** — официальной формулы
  пересчёта в открытом доступе нет.

---

## 5. Оплата (Google Play Billing)

> ⚠️ **Блокер владельца (проверено 2026-11-02):** Google Play **не поддерживает
> регистрацию продавца (merchant) в Кыргызстане**. Аккаунт разработчика с
> платёжным профилем в КР не может продавать внутриигровые товары. Варианты:
> (а) продавец — юрлицо/ИП в поддерживаемой стране (Казахстан, Узбекистан,
> Армения, ОАЭ…); (б) Play-сборка «consumption-only» (покупок в приложении нет,
> доступ покупается на сайте через ELQR/Finik, в приложении нельзя ссылаться на
> оплату). Поэтому клиент поддерживает режим сборки
> `--dart-define=BILLING_MODE=play|external`: `play` — Google Play Billing,
> `external` — экран магазина показывает только баланс и нейтральный текст без
> ссылок и цен. Серверная модель кредитов одинакова для обоих режимов.
>
> Покупатели в КР платят в **USD** (местная валюта Play не поддерживается):
> цену в UI всегда берём из `ProductDetails.price`, «100 сом» в коде не пишем.
> Библиотека: `in_app_purchase 3.3.1` + `in_app_purchase_android 0.5.x`
> (Play Billing Library 8, принимается до 31.08.2027).

1. Клиент запрашивает `ProductDetails` для `exam_single`, `exam_pack_5`,
   `exam_pack_10` и показывает **цену из Google Play** до покупки.
2. Покупка: `buyConsumable(autoConsume: false)` c
   `applicationUserName = sha256(uid)` (→ `obfuscatedAccountId`).
3. Клиент передаёт `purchaseToken` в `billingVerifyPurchase`. Сервер через
   Android Publisher API (`purchases.productsv2.getproductpurchasev2`, fallback
   `purchases.products.get`) проверяет `PURCHASED`, тестовую покупку
   (`testPurchaseContext` — в проде не начислять, если не включено
   `ALLOW_TEST_PURCHASES`), совпадение `obfuscatedExternalAccountId`, отсутствие
   повторной обработки (документ `purchases/{sha256(token)}` создаётся в
   транзакции), начисляет кредиты, затем делает `consume`.
4. Доступ открывается **только** после ответа сервера. Клиентский ответ Play
   сам по себе ничего не открывает.
5. Восстановление: при старте приложения клиент перебирает незавершённые
   покупки (`purchaseStream` / `restorePurchases`) и повторно отправляет их на
   сервер — сервер идемпотентен.
6. Возвраты/отмены — RTDN + ежедневный опрос Voided Purchases API.

---

## 6. AI-репетитор

* Только через `aiTutor` (ключ Anthropic — секрет функции `ANTHROPIC_API_KEY`,
  в приложении ключа нет).
* Режимы: `explain_mistake`, `step_by_step`, `grammar`, `practice`,
  `study_plan`, `chat`. Системная инструкция: объяснять ход мысли, не выдавать
  голый ответ, отвечать на языке пользователя (ru/ky).
* Нельзя спрашивать о вопросах активной (незавершённой) попытки
  (`AI_EXAM_IN_PROGRESS`).
* Дневной лимит запросов на пользователя (`config/ai_tutor.daily_limit`), лимит
  длины ответа, учёт токенов и стоимости в `ai_usage`.
* Модель задаётся параметром `AI_TUTOR_MODEL` (по умолчанию `claude-opus-5-5`
  с `effort: low`; владелец может сменить модель без релиза приложения).

---

## 7. Контент-пайплайн (`tools/content_pipeline`)

Матрица тем → распределение сложности → генерация → независимая проверка →
проверка переводов → дедупликация → сборка вариантов по blueprint → контроль
тайминга → импорт в Firebase → финальная валидация. Реестр готовности —
`content/registry.json`; вариант считается готовым только при статусе
`methodologist_approved` у всех вопросов. Подробно: `CONTENT_PIPELINE.md`.

---

## 8. Решения интеграции (D1–D14, 2026-11-04)

Приняты после перекрёстного ревью пакетов; обязательны для клиента, функций,
правил и пайплайна.

| # | Решение |
|---|---|
| D1 | Черновик раздела: клиент пишет ровно `{answers, flags, client_updated_at: serverTimestamp}` в `exam_attempts/{id}/drafts/{sectionId}`; правило — `hasOnly` этих трёх ключей. |
| D2 | Таблица вопроса хранится как `rows: [{cells: [...]}]`; функции отдают `rows: [[...]]`; клиенты читают обе формы. |
| D3 | Изображения: функции отдают `imagePath` (путь в Storage), клиент получает download URL сам; `imageUrl` — только для внешних https-ссылок. |
| D4 | `ExamResult` содержит `incorrect` и `skipped` (+ `answered`); `correct + incorrect + skipped == total`. |
| D5 | Модератор пишет в `users/{uid}` только `is_banned, ban_reason (≤ 500), banned_at, banned_by, updated_at`; подписка/премиум — только super_admin. Бан проверяется сервером (`USER_BANNED` в examStart, aiTutor, recordActivity, adminAiDraftQuestions), забаненные исключаются из рейтингов. |
| D6 | super_admin, support и moderator читают `entitlements/{uid}` (+ledger) и `user_stats/{uid}` любого пользователя. |
| D7 | App Check: студенческие callable — `APP_CHECK_ENFORCE` (по умолчанию вкл.), admin* — `APP_CHECK_ENFORCE_ADMIN` (по умолчанию выкл., защищены ролями). Клиент включает App Check на web только с `--dart-define=APP_CHECK_WEB_SITE_KEY`; единственная проверка платформы — `lib/core/backend/callable_platform.dart`. Windows/Linux показывают «недоступно на этой платформе». |
| D8 | Пока у пользователя есть любая незавершённая попытка, `aiTutor` отвечает `AI_EXAM_IN_PROGRESS`. |
| D9 | `accountDelete` требует свежий вход (≤ 5 мин, `REQUIRES_RECENT_LOGIN`), сначала удаляет Auth-пользователя, затем данные; студенческие callable отклоняют удалённых/отключённых пользователей. |
| D10 | Недельный и общий рейтинг — весь серверный XP (экзамены + практика/уроки с дневным лимитом); предметные — только экзамены, ключи: main, math, chemistry, biology, physics, history, english, kyrgyz_lit, russian_lit, state_language. При нулевой награде recordActivity ничего не пишет. |
| D11 | Повторный импорт пайплайна не перезаписывает документы, отредактированные в CMS (`edited_in_cms_at` / расхождение `pipeline_hash`) без `--overwrite`, не меняет `status` существующих вариантов и пишет `part_id` всегда. CMS при сохранении ставит `edited_in_cms_at` и не пересчитывает `content_hash`. |
| D12 | Напоминания: `sendStudyReminders` ежедневно в 18:00 по Бишкеку для `daily_reminder_enabled == true` и `fcm_tokens`, если сегодня не было активности; тихие часы 22:00–08:00. Выход из аккаунта удаляет только токен устройства. |
| D13 | Длина сообщения AI-репетитору ≤ 2000 символов (клиент и сервер). |
| D14 | Число бесплатных экзаменов — `config/pricing.free_exams_per_user` (по умолчанию 1); клиент показывает остаток по `entitlements.free_exams_used_count`. |

---

## 9. Фаза 3: рост, социальные функции, аналитика (контракт, 2026-11-05)

Все записи ниже делает только сервер (callable), если не сказано иное. Новые
причины ошибок: `CODE_INVALID`, `CODE_EXPIRED`, `CODE_EXHAUSTED`,
`ALREADY_REDEEMED`, `RATE_LIMITED`, `REFERRAL_NOT_ALLOWED`, `LIMIT_REACHED`,
`NOT_GROUP_OWNER`.

### 9.1 Рефералы

| Объект | Поля |
|---|---|
| `users/{uid}.referral_code` (привилегированное поле) | 6 символов из `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |
| `referral_codes/{code}` | `{uid, created_at}` — клиентам чтение запрещено |
| `users/{uid}.referred_by` (привилегированное) | uid пригласившего |
| `referrals/{referrerUid}/items/{uid}` | `{status: joined/rewarded, joined_at, rewarded_at?, display_name}` — читает пригласивший |

* `referralGetCode {}` → `{code}`: идемпотентно создаёт код.
* `referralApply {code}` → `{ok}`: один раз на аккаунт; свой код нельзя; только
  пока у пользователя нет завершённых экзаменов и покупок (`REFERRAL_NOT_ALLOWED`).
* Награда: при **первом начислении кредитов за оплаченную покупку** приглашённого
  (`billingVerifyPurchase` grant) оба получают +1 кредит (ledger `reason: 'referral'`),
  статус `rewarded`. Не больше 20 наград пригласившему за календарный месяц
  (Бишкек). Идемпотентно по uid приглашённого.

### 9.2 Промокоды

`promo_codes/{CODE}` (id в верхнем регистре, 4–20 символов `A-Z0-9`):
`{credits: 1..10, max_redemptions: int|null, redemptions: int, expires_at: Timestamp|null, active: bool, note, created_by, created_at}`;
`promo_codes/{CODE}/redemptions/{uid}` = `{at}`. Клиентам чтение запрещено
(админ-роли с `grant_credits` читают).

* `promoRedeem {code}` → `{credits, balance}`: транзакция, один раз на
  пользователя, ledger `reason: 'promo'`; не более 10 попыток в сутки
  (`RATE_LIMITED`), счётчик `promo_attempts/{uid}_{yyyy-mm-dd}`.
* `adminUpsertPromoCode {code, credits, maxRedemptions?, expiresAt? (ms), active, note}` —
  только super_admin (`grant_credits`), пишет `admin_logs`.
* Промокод — не способ оплаты, доступен в обоих режимах `BILLING_MODE`.

### 9.3 Лиги: регион, друзья, группы, домашние задания

* Регион: тот же XP, что и в недельном рейтинге (D10), дополнительно пишется в
  `leaderboards/region_{regionId}_weekly_{YYYY}-W{ww}/entries/{uid}`, если у
  пользователя задан `users/{uid}.region` (id из `assets/data/kg_regions.json`).
* Друзья: `friends/{uid}/list/{friendUid}` = `{display_name, added_at}`;
  владелец читает и удаляет; создаёт только `friendAdd {code}` (по
  `referral_code` друга), максимум 50. Рейтинг друзей клиент собирает из
  недельных записей друзей и своей.
* Группы (класс, учебный центр): `groups/{gid}` = `{name, owner_uid, join_code, member_count, created_at}`;
  `groups/{gid}/members/{uid}` = `{display_name, role: owner/member, joined_at}`;
  `users/{uid}.group_ids` (привилегированное, ≤ 5). Читают участники группы.
  `groupCreate {name}` → `{groupId, joinCode}` (≤ 5 своих групп),
  `groupJoin {code}` → `{groupId}`, `groupLeave {groupId}` (владелец не может
  выйти, пока есть участники), `groupRemoveMember {groupId, uid}` (владелец).
  XP пишется и в `leaderboards/group_{gid}_weekly_{YYYY}-W{ww}/entries/{uid}`.
* Домашние задания (FR-LRN-6): `groups/{gid}/assignments/{aid}` =
  `{title, kind: lesson/practice/exam_variant, ref_id, due_at, created_by, created_at}` —
  создаёт и удаляет владелец группы (правила), читают участники;
  `groups/{gid}/assignments/{aid}/submissions/{uid}` = `{done_at, score_percent?}` —
  участник пишет только свою запись, владелец читает все.

### 9.4 Рассылки и достижения (админ)

* `adminSendNotification {title:{ru,ky}, body:{ru,ky}, audience:{kind: all/language/region/group, value?}, dryRun?}` →
  `{recipients, sent, failed, notificationId}`; право `send_notifications`;
  получатели — пользователи с `fcm_tokens` (язык по `preferred_language`),
  пачки ≤ 500, невалидные токены удаляются; не больше 3 рассылок в сутки;
  история в `notifications/{id}` (читают админ-роли).
* `config/achievements` = `{titles: {id: {ru, ky}}, descriptions: {id: {ru, ky}}, disabled: [id]}` —
  пишут роли с `manage_achievements` напрямую (правила), читают все вошедшие.
  Пороги и логика начисления остаются в коде сервера.

### 9.5 Расширенная аналитика

* `examSubmitSection` принимает `timings: {questionId: seconds}` (целые от 0 до
  длительности раздела); хранятся в `answers/{sectionId}.timings`; `ExamResult`
  получает `topic_time_avg: {topicId: seconds}` и `slow_topics: [topicId]`
  (среднее время по теме > 1,5 × медианы по попытке).
* `recordActivity` принимает `seconds` (0..3600) для практики и уроков;
  `user_stats.study_seconds_total` и `study_seconds_today` (день по Бишкеку).
* Клиент: «Частые ошибки» (топ тем по `wrong_count` из `user_mistakes`), время
  по темам, предупреждение о риске потери мотивации (нет активности ≥ 3 дней или
  падение результата за два последних экзамена) с объяснением причины.

