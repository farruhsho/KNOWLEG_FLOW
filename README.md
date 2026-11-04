# ORT Master KG

Приложение для подготовки к **Общереспубликанскому тестированию (ОРТ / ЖРТ)**
в Кыргызстане: пробные тесты в официальной структуре ОРТ, разбор ошибок,
практика по темам, уроки, AI-репетитор и геймификация. Интерфейс и контент —
на кыргызском и русском (английский интерфейс — для разработки).

> **Статус (2026-11-02):** проект в активной модернизации, в Google Play не
> опубликован. Технический аудит текущего кода и список того, что сломано и
> что исправляется, — в [`docs/modernization/AUDIT_REPORT.md`](docs/modernization/AUDIT_REPORT.md).
> Результат приложения — **учебный**, это не официальный балл ОРТ;
> приложение не связано с ЦООМО и не гарантирует поступление.

## Что делает продукт

- **Пробные экзамены по версионируемым blueprints** — основной тест (150
  заданий, 215 минут: математика, аналогии и дополнение предложений, чтение и
  понимание, практическая грамматика), 8 предметных тестов и тест по
  государственному языку; разделы только вперёд, время раздела задаёт сервер.
  Структура сверена с брошюрой ЦООМО 2026 — [`ORT_SPEC.md`](docs/modernization/ORT_SPEC.md).
- **Монетизация кредитами:** первый полный пробник бесплатно (один раз на
  аккаунт, проверяет сервер), каждый следующий — 1 кредит. Режим сборки
  `BILLING_MODE=play|external` — см. [`BUSINESS_MODEL.md`](docs/modernization/BUSINESS_MODEL.md).
- **Разбор и повторение:** результат по разделам и темам, очередь «Ошибки и
  повторение» (интервалы 1 → 3 → 7 → 14 → 30 дней).
- **AI-репетитор** через серверную функцию: объясняет ход решения, дневной
  лимит, недоступен по вопросам активной попытки.
- **Геймификация:** серверные XP, уровни, серии (по времени Бишкека),
  достижения, рейтинги.
- **Админка с ролями** (`super_admin`, `content_manager`, `methodologist`,
  `moderator`, `support`) и CMS вопросов и вариантов со статусами проверки.

Перечисленное — целевое состояние, которое **реализуется в ветке
модернизации**; что уже работает в коде, а что нет, — в аудите.

## Архитектура

```text
Flutter-клиент (Android)                 Cloud Functions (доверенный слой)        Firestore / Storage
 Riverpod, go_router, Material 3   ──►    examStart / examGetState /          ──►   exam_blueprints, exam_variants
 tokens.dart + app_theme.dart     callable examSubmitSection / examGetReview          exam_questions*, exam_question_keys*
 Hive: локальное сохранение       + App   billingVerifyPurchase, billingRtdn,         exam_attempts (+answers, drafts)
 ответов экзамена                  Check  billingSweepVoided                          entitlements (+ledger), purchases
 in_app_purchase (режим play)             aiTutor ──► Anthropic API (ключ-секрет)     user_stats, leaderboards, ai_usage
                                          recordActivity, accountDelete               user_mistakes, config, admin_logs
                                          admin*: роли, кредиты, публикация,          + существующие: users, subjects,
                                          цены, AI-черновики вопросов                 lessons, questions, user_progress…
                                                                                       (* — клиенту недоступны)
```

- **Сервер — источник истины** для результатов экзаменов, правильных ответов,
  прав доступа (кредиты), покупок, XP, рейтингов, лимитов AI и ролей.
  Клиент получает вопросы только текущего раздела и никогда — ответы до
  завершения попытки.
- **Структура экзамена — данные:** `assets/data/exam_blueprints.json`
  (офлайн-резерв) и коллекция `exam_blueprints`; новый год — новый документ.
- **Ничего не удаляется:** новые коллекции добавляются рядом со старыми,
  существующие поля и коллекции не переименовываются.
- **Проект Firebase** — `knowleg-33f36`; регион функций — `europe-west1`
  (должен совпадать с регионом Firestore).
- **Ключей и секретов в приложении нет** (ключ Anthropic — секрет функции).

Контракт (коллекции, роли, callable-функции, правила экзамена, оплата, AI):
[`docs/modernization/ARCHITECTURE.md`](docs/modernization/ARCHITECTURE.md).
Имена в клиенте: `lib/core/backend/backend_contract.dart`,
`lib/core/routes/route_paths.dart`.

### Структура репозитория

```text
lib/
  core/        backend (контракт), design (токены), theme, routes, network, constants
  features/    auth, onboarding, dashboard, subjects, lessons, quiz, handbook, progress,
               profile, settings, gamification, exam, billing, tutor, account, admin, mock_test
  shared/      модели, сервисы, общие виджеты
  l10n/        app_en.arb (шаблон), app_ru.arb, app_ky.arb + сгенерированные классы
assets/data/   exam_blueprints.json, kg_regions.json
functions/     Cloud Functions (TypeScript, Node.js 22) — см. functions/README.md
tools/content_pipeline/   генерация blueprints и пайплайн контента
docs/modernization/       архитектура, аудит, продукт, бизнес, релиз
docs/legal/               черновики политики конфиденциальности и условий
```

## Запуск для разработки

**Требования:** Flutter stable с Dart ≥ 3.9.2 (FlutterFire BoM 5.1 требует
Flutter ≥ 3.27), JDK 17 для сборки Android, Android SDK 36. Для функций —
Node.js 22; для эмуляторов Firebase — firebase-tools 15+ и JDK 21.

1. Получить `android/app/google-services.json` для проекта `knowleg-33f36`
   у владельца (файл в `.gitignore`, в git не коммитится).
2. Установить зависимости и сгенерировать локализацию:

   ```bash
   flutter pub get
   flutter gen-l10n
   ```

3. Запустить:

   ```bash
   # без покупок в приложении (кредиты покупаются вне приложения)
   flutter run --dart-define=BILLING_MODE=external

   # с Google Play Billing (нужен продавец в Play Console, лицензионный тестировщик)
   flutter run --dart-define=BILLING_MODE=play
   ```

4. **App Check в debug-сборке.** Функции требуют App Check
   (`enforceAppCheck`). В debug приложение использует debug-провайдер: при
   первом запуске в logcat появится строка `DebugAppCheckProvider` с
   debug-секретом — добавьте его в Firebase Console → App Check → Приложения →
   «Управление debug-токенами». Debug-токены и debug-сборки в магазин не
   попадают. Для web нужен ключ reCAPTCHA Enterprise:
   `--dart-define=APP_CHECK_WEB_SITE_KEY=<site key>` — без него студенческие
   функции на web показывают «недоступно на этой платформе»; на Windows/Linux
   App Check нет вообще (админ-функции App Check по умолчанию не требуют,
   параметр `APP_CHECK_ENFORCE_ADMIN`). Решения интеграции — в
   [`ARCHITECTURE.md` §8](docs/modernization/ARCHITECTURE.md).

Проверки:

```bash
dart analyze lib test
flutter test
```

## Бэкенд, контент, релиз

- **Cloud Functions и правила:** [`functions/README.md`](functions/README.md) —
  локальная разработка, эмуляторы, секреты (`ANTHROPIC_API_KEY`), деплой.
  Деплой выполняет только владелец проекта.
- **Контент-пайплайн:** [`docs/modernization/CONTENT_PIPELINE.md`](docs/modernization/CONTENT_PIPELINE.md)
  и `tools/content_pipeline/`. Вариант публикуется, только если все его
  вопросы одобрены методистом.
- **Выпуск в Google Play:** [`docs/modernization/PLAY_RELEASE_CHECKLIST.md`](docs/modernization/PLAY_RELEASE_CHECKLIST.md).
  Сборка AAB:

  ```bash
  flutter build appbundle --release --build-number=<N> \
    --dart-define=BILLING_MODE=external \
    --obfuscate --split-debug-info=build/symbols
  ```

  Без `android/key.properties` release подписывается debug-ключом — такую
  сборку загружать нельзя. `applicationId` пока шаблонный
  (`com.example.knowledge_flow`) и должен быть изменён до первой загрузки.

## Доступ администратора

Сейчас вход в админку проверяет `users/{uid}.role == 'admin'` (гейт роутера
`adminVerified`). По контракту модернизации (реализуется в ветке) права
определяются custom claim `role` в Firebase Auth, а старое `role == 'admin'`
считается `super_admin`; роли назначает `super_admin` через функцию
`adminSetRole`. В обоих случаях клиент никогда не пишет роль, и
самостоятельной регистрации администраторов нет.

## Документация

| Документ | О чём |
|---|---|
| [ARCHITECTURE.md](docs/modernization/ARCHITECTURE.md) | контракт: коллекции, роли, функции, экзамен, оплата, AI |
| [AUDIT_REPORT.md](docs/modernization/AUDIT_REPORT.md) | технический аудит: карта проекта, статус функций, 187 находок, что сохраняем, что исправляется |
| [ORT_SPEC.md](docs/modernization/ORT_SPEC.md) | официальная структура ОРТ 2026, баллы, пороги, календарь, модель в приложении |
| [CONTENT_PIPELINE.md](docs/modernization/CONTENT_PIPELINE.md) | производство и проверка контента |
| [COMPETITORS.md](docs/modernization/COMPETITORS.md) | конкуренты и наше отличие |
| [BUSINESS_MODEL.md](docs/modernization/BUSINESS_MODEL.md) | монетизация, блокер продавца Google Play, юнит-экономика |
| [GO_TO_MARKET.md](docs/modernization/GO_TO_MARKET.md) | каналы, сезонность, рефералы, метрики, честный маркетинг |
| [ASO_LISTING.md](docs/modernization/ASO_LISTING.md) | тексты листинга Google Play на ru и ky, скриншоты |
| [PLAY_RELEASE_CHECKLIST.md](docs/modernization/PLAY_RELEASE_CHECKLIST.md) | всё для выпуска в Google Play |
| [DATA_SAFETY.md](docs/modernization/DATA_SAFETY.md) | ответы для формы Data safety |
| [UX_DESIGN_SYSTEM.md](docs/modernization/UX_DESIGN_SYSTEM.md) | дизайн-система, карта 23 экранов, этика геймификации |
| [ROADMAP.md](docs/modernization/ROADMAP.md) | фазы после ветки, риски, решения владельца |
| [docs/legal/](docs/legal/) | черновики политики конфиденциальности (ru, ky), условий использования и страницы удаления аккаунта — требуют проверки юристом |
| [CTO_AUDIT_REPORT.md](CTO_AUDIT_REPORT.md) | предыдущий аудит (2026-06-17) |

Документы в корне `docs/` (`PRODUCT_VISION.md`, `TECHNICAL_SPEC.md`,
`PROJECT_SUMMARY.md`, `TESTING_REPORT.md`, `BUILD_OPTIMIZATION.md`,
`NEXT_STEPS.md`, `PHASE_9_LEGAL_GUIDE.md` и др.) — **устаревшие**: часть
утверждений в них не соответствует коду (DOC-01). Актуальная документация —
в `docs/modernization/`.

## Лицензия и контакты

Файла лицензии в репозитории нет; условия использования кода определяет
владелец проекта. Контакты поддержки будут указаны при публикации
(`[support@домен]`).
