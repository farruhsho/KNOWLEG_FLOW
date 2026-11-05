# ORT Master KG — Полный технический аудит (CTO-level)

> Дата: 2026-06-17 · Аудит выполнен мульти-агентной системой (карта проекта → аудит по 6 направлениям → продуктовая стратегия → состязательная верификация каждого findings по реальному коду).
> Объём: 134 Dart-файла (~25k LOC), Flutter 3.9+, Firebase, Riverpod, go_router.
> Метод: каждый дефект был перепроверен независимым «скептиком», который заново открывал указанный файл. Из 55 конкретных findings подтверждено 54, отклонён 1 (ложноположительный отфильтрован).

---

## 0. Важная поправка к исходным данным

В репозитории лежат `analysis_report.txt` / `analysis_report_utf8.txt` и `ERROR_ANALYSIS.md`, которые утверждают про «10 ошибок компиляции в profile_page.dart». **Это устарело.** Запуск `flutter analyze` на текущем дереве:

```
125 issues found. (ran in 21.3s)  — 0 errors, 0 warnings, 125 info-lints
```

Анализатор **зелёный**. Все импорты в `profile_page.dart` резолвятся, все классы существуют. НО: `flutter test` **красный** — единственный smoke-тест падает (`A Timer is still pending...`), а CI вообще не запускается (несовместимость версий). То есть «всё протестировано и чисто» из docs — фикция.

---

## 1. Executive Summary

**ORT Master KG — это сильный по продуктовой задумке, но преднамеренно недоделанный прототип, который выдаёт себя за платформу.** Доменная модель (ORT-структура, trilingual ru/ky/en, геймификация, региональные рейтинги, подписки в KGS, SM-2 spaced-repetition) проработана на уровне, который редко встретишь у стартапа на этой стадии. Но **бизнес-логика и монетизация почти целиком мертвы**: модель данных намного опережает то, что реально подключено к UI.

### Вердикт готовности

| Этап | Готов? | Главные блокеры |
|---|---|---|
| **Релиз (Play/App Store)** | ❌ НЕТ | Ключ Anthropic в клиенте; эскалация привилегий в Firestore; release подписан debug-ключом; CI не работает; `flutter test` красный |
| **1 000 пользователей** | ❌ НЕТ | + нет composite-индексов; нет анти-чита (счёт пишет клиент); нет наблюдаемости |
| **10 000** | ❌ НЕТ | + нет rate-limiting; стоимость Firestore-чтений рейтингов; нет контент-пайплайна |
| **100 000** | ❌ НЕТ | + Firebase-direct-from-client упирается в потолок; нет агрегации рейтингов; нет cost-governance |
| **1 000 000** | ❌ НЕТ | + нужен полноценный backend-tier, BigQuery, SRE/on-call, комплаенс по PII несовершеннолетних |

### Топ-5 проблем, которые надо закрыть немедленно (P0)

1. 🔴 **Секретный ключ Anthropic вводится в клиенте** (`ai_generator_page.dart:148` → `ai_service.dart:51` → `ai_models.dart:5`). Извлекается из бандла/трафика → кража ключа и неограниченные счёта.
2. 🔴 **Эскалация привилегий в Firestore** (`firestore.rules:29`): любой юзер пишет себе `role:'admin'`, а `isAdmin()` (`rules:14-17`) доверяет этому полю → полный admin-доступ + удаление чужих аккаунтов.
3. 🔴 **Хардкод плейнтекст-паролей админа** (`admin_service.dart:13-16`: `admin@ort.kg / admin123`) + публичная самo-регистрация в роли «Админ» (`signup_page.dart:172-195`).
4. 🔴 **Trust-tier отсутствует**: каталог `functions/` не существует, `cloud_functions` объявлен, но ни разу не вызван. Счёт, платежи, рейтинги нельзя валидировать на сервере.
5. 🔴 **Релиз нешипабелен**: Android подписан debug-ключом, `applicationId = com.example.knowledge_flow`, нет R8; iOS без `GoogleService-Info.plist`; CI падает на `pub get` (Flutter 3.16.0 vs Dart ^3.9.2).

### Сводка findings

- **54 подтверждённых дефекта**: 7 critical (код/безопасность) + 12 high + 21 medium + 14 low.
- **+5 critical** в DevOps/Testing/UX (CI сломан, релиз нешипабелен, тест красный, локализация-фасад, mock-тест — заглушка).
- **~6 200+ LOC мёртвого/дублированного кода** (legacy «Task»-фича 1 172 LOC, осиротевший admin-UI ~5 087 LOC, дубли моделей/сервисов, мёртвый nav-shell).

---

## 2. Architecture Analysis

### 2.1 Текущая архитектура — гибрид в середине миграции

Приложение застряло между легаси-структурой (`lib/models`, `lib/providers`, `lib/screens`) и feature-first (`lib/features/<feature>/{data,presentation}` + `lib/core` + `lib/shared`). Обе живут одновременно.

**Слоистость инвертирована везде, кроме admin.** Только admin-фича имеет настоящий data/repository-слой (`questions_repository.dart`, `subjects_repository.dart`, `users_repository.dart` — чистые Firestore-репозитории за Riverpod-провайдером). Все остальные фичи — presentation-only и тянут инфраструктуру прямо из `State`:

```dart
// quiz_page.dart:25 — инфраструктура «зашита» в виджет
final _firebaseDataService = FirebaseDataService();
// mission_provider.dart:7,15,34 — singleton НОВО создаётся внутри тела провайдера
```

**Домена нет вообще** — ни entities, ни use-cases, ни интерфейсов репозиториев. Бизнес-правила (подсчёт очков, сборка теста, прогресс миссий) живут внутри виджетов.

**DI несвязный — три конкурирующих паттерна без конвенции:**
1. Riverpod-провайдеры (`authServiceProvider`, `questionsRepositoryProvider`).
2. Статический синглтон `FirebaseService` со static-геттерами.
3. Inline-`new` `FirebaseDataService()` в 8+ `State` и в телах провайдеров.
4. `get_it ^8.0.3` объявлен в `pubspec.yaml:35`, но **не используется нигде** (мёртвая зависимость).

**Роутинг** — плоская таблица ~25 маршрутов (`app_router.dart`), **без `ShellRoute`/`StatefulShellRoute`** (5 вкладок — это один `/home` с `IndexedStack`), **без router-level redirect-guard**. Гейтинг авторизации делается императивно в `SplashPage` (`Future.delayed(2.5s)` → `context.go`), а админ-гейтинг — виджетом `AdminGuard`. Прямой deep-link на `/admin/dashboard` или `/home` обходит защиту.

**Boot-race**: `main.dart:34-37` запускает `FirebaseService.initialize()` БЕЗ `await` до `runApp`, поэтому первые кадры (и чтение auth в Splash) могут выполниться до готовности Firestore/RemoteConfig.

**Противоречие домена**: два источника правды о структуре ORT — `app_constants.dart` (`totalQuestions=130, maxScore=200`) vs `ort_constants.dart` (`totalMainQuestions=140, totalMaxScore=220`).

### 2.2 Целевая архитектура (feature-first Clean Architecture)

Принцип: `presentation → domain (entities/usecases/interfaces) → data (impl + datasources)`. Riverpod-only DI (удалить `get_it`). `StatefulShellRoute` + единый redirect-guard. Один канонический набор моделей/сервисов/констант. Cloud Function-прокси держит ключ AI.

```
lib/
├── main.dart                         # await bootstrap; ProviderScope
├── bootstrap.dart                    # НОВОЕ: awaited Firebase/Hive/prefs init
├── app/
│   ├── app.dart                      # OrtMasterApp (MaterialApp.router)
│   └── router/{app_router.dart (StatefulShellRoute + redirect guard), routes.dart}
├── core/
│   ├── constants/ort_structure.dart  # ЕДИНЫЙ источник (merge app_constants+ort_constants)
│   ├── error/failures.dart
│   ├── network/{firebase_providers.dart, firebase_bootstrap.dart}
│   ├── theme/  localization/  utils/
├── shared/
│   └── widgets/                      # только общие виджеты, БЕЗ сервисов
└── features/
    ├── auth/      {domain, data, presentation}
    ├── onboarding/ dashboard/ subjects/ quiz/ mock_test/ lessons/
    ├── handbook/ progress/ profile/ settings/ gamification/
    └── admin/     {domain, data (services/ai_proxy_service.dart → Cloud Function), presentation}
functions/                            # НОВОЕ: Cloud Functions — Anthropic-прокси держит ключ

УДАЛИТЬ: lib/models/, lib/providers/, lib/screens/, main_navigation.dart,
         admin/services/ (stub ai_service+admin_service), дубли моделей, get_it.
```

**Главный рычаг**: обобщить уже работающий паттерн репозиториев admin-фичи на все фичи — это единственный корректно-слоистый, тестируемый кусок в кодовой базе.

---

## 3. Code Quality Report (54 подтверждённых дефекта)

### 3.1 CRITICAL

#### CQ-01 — Хардкод плейнтекст-паролей админа + параллельная фейковая авторизация · `lib/shared/services/admin_service.dart:13-50`
```dart
final Map<String, String> _adminCredentials = {
  'admin@ort.kg': 'admin123',
  'superadmin@ort.kg': 'super123',
};
Future<bool> loginAdmin(String email, String password) async {
  await Future.delayed(const Duration(milliseconds: 300));
  if (_adminCredentials[email] == password) { _currentAdminEmail = email; return true; }
  return false;
}
```
`registerAdmin` (40-50) позволяет любому добавить себе админ-аккаунт в рантайме. Все write-операции гейтятся только на `isAdminLoggedIn` (nullable in-memory String). **Импортируется живыми экранами** (`signup_page.dart:49`, `admin_registration_page.dart:40`, `admin_generate_questions_page.dart:30`). Верификатор добавил: **второй** `AdminService` (`features/admin/services`) пишет в Firestore **вообще без проверки прав**.
→ Удалить класс. Роль — только из Firebase Auth custom claims, проверяемых на сервере.

#### CQ-02 — `AdminService` хранит всё в in-memory Map · `lib/shared/services/admin_service.dart:21-23`
Все `createSubject/createQuestion/createMockTest` мутируют `Map`, **ничего не пишется в Firestore**, плюс искусственные `Future.delayed`. Админ думает, что управляет контентом — а он исчезает при перезапуске и невидим студентам.

#### CQ-02 (dashboard) — Геймификация читается для литерала `'current_user'` · `dashboard_page.dart:34-36`
```dart
// TODO: Get actual user ID
final gamification = await _gamificationService.getUserGamification('current_user');
```
`achievements_page.dart:36` — то же. А квизы начисляют XP на **реальный** `FirebaseAuth...uid` (`quiz_page.dart:35`). Итог: студент проходит квиз, видит награду, но XP/уровень/стрик на дашборде и достижениях **никогда не обновляются** (читают пустой документ `user_gamification/current_user`). Плюс приватность: все делят один документ.

#### CQ-03 — `Navigator.pushNamed` в go_router-only приложении → гарантированный краш · `handbook_content_page.dart:262`
```dart
Navigator.of(context).pushNamed(route); // 'Could not find a generator for route ...'
```
Тап по любой quick-action кнопке хэндбука или по результату поиска (`handbook_search_delegate.dart:174,248`) роняет экран. → Использовать `context.push(...)`.

#### SEC-001 — Ключ Anthropic собирается и используется в клиенте · `ai_generator_page.dart:25,148-167,1034` · `ai_service.dart:47-171` · `ai_models.dart:5`
Долгоживущий `sk-ant-...` вводится в `TextFormField`, передаётся в `AiService(apiKey: ...)` и уходит `device → api.anthropic.com` с заголовком `x-api-key`. На Web виден в JS-heap и Network-вкладке. → Перенести в авторизованную Cloud Function (см. §11).

#### SEC-002 — Эскалация привилегий: любой юзер ставит себе `role:'admin'` · `firestore.rules:14-17,29`
`allow update: if isOwner(userId)` разрешает писать любое поле своего `/users/{uid}`, включая `role`. `isAdmin()` доверяет этому полю. Само приложение демонстрирует запись: `user_manager_page.dart:335` `.update({'role': selectedRole})`. → §11 (правила + custom claims).

#### SEC-003 — `/admin/dashboard` доступен любому залогиненному · `admin_login_page.dart:84-88` · `app_router.dart:276-284`
`AdminLoginPage` логинит и безусловно `context.go(adminDashboard)` с комментом `// TODO: Check if user has admin role`. Маршрут `/admin/dashboard` зарегистрирован **без** `AdminGuard` и без router-redirect. Источник правды раздвоен: `firestore.rules` смотрит `users.role`, а `AdminAccessControl` — отдельную коллекцию `/admins/{uid}`. → §11 (router-guard + проверка claim).

### 3.2 HIGH (12)

| ID | Файл:строка | Суть |
|---|---|---|
| CQ-06 | `quiz_page.dart:527` | Счёт = `correctAnswers/total*240`, при `maxScore=200`. Каждый результат завышен в 1.2×, портит `averageScore` и расчёт уровня |
| CQ-04 / TD-10 | `subject_detail_page.dart:18-19` | Единственный экран, читающий `MockDataService` (хардкод) в проде; ещё и навигация на mock-`lessonId` ломает `lesson_page` |
| CQ-09 | `daily_lesson_page.dart:53-64` | «Урок завершён! +50 XP» — но XP не начисляется и завершение не пишется (TODO). `lesson_page.dart:246` даже позволяет «развыполнить» |
| CQ-04 | `firebase_data_service.dart:18-39,286-336` | God-class на 6 доменов; глушит все ошибки `print()` + fallback-данные → сбой неотличим от «пусто», Crashlytics не получает ничего |
| CQ-11 | `error_boundary.dart:24-36` | `ErrorWidget.builder` перезаписывается глобально из `initState` и не восстанавливается в `dispose`; глушит все build-ошибки приложения (сейчас виджет ещё и не инстанцируется нигде — латентная мина) |
| TD-01 | admin pages | Осиротевший admin-UI: `AiGeneratorPage` + 9 manager-страниц + `AdminPanelPage` = **~5 087 LOC** мёртвого кода; `AdminSidebar.onNavigate` = `// TODO` |
| TD-02 | `task_*` + `/tasks` | Легаси шаблон «Task» (1 172 LOC) про «Что такое Widget в Flutter?» всё ещё подключён к роутеру |
| TD-05 | `admin/services/admin_service.dart` | Дубль `AdminService`: живой Firestore vs мёртвый mock с паролями |
| PERF-01 | `gamification_service.dart:93,132,147,247,253` | Искусственные `Future.delayed` на горячих путях, суммарно >1 сек на финише квиза |
| PERF-02 | `quiz_page.dart:516-567` | Серийный «write-storm»: ~12+ последовательных Firestore round-trip + N+1 по достижениям за блокирующим спиннером |
| SEC-004 | `admin_service.dart:13-16` + `signup_page.dart:172-195` | Публичный `SegmentedButton` «Админ» → `registerAdmin` → `adminDashboard` |
| CI-13/арх | `app_constants.dart:7-20` vs `ort_constants.dart:8,60` | Два противоречивых описания экзамена (130q/200 vs 140q/220) |

### 3.3 MEDIUM (21) — выжимка

- **CQ-07** `quiz_page.dart:51-68` — `setState` после `await` без `mounted`-guard (async).
- **CQ-03** `offline_database.dart:57-70…` — read-методы всегда возвращают пусто → весь офлайн молча сломан.
- **CQ-12** `subject_model.dart:28-40` — небезопасные non-null касты в `fromFirestore` → краш на пропущенном поле.
- **CQ-10** `mock_test_page.dart:411-421` — «Начать тест» — TODO, раннера нет (тупик основной конверсии).
- **CQ-11** `progress_page.dart:741-808` — фабрикует данные трендов по предметам в проде.
- **TD-03** — противоречие констант ORT (дубль арх-finding).
- **CQ-13** `profile_page.dart:92-491` / `quiz_page.dart` — god-виджеты (910/755 LOC), данные+домен+UI в одном `State`.
- **LINT-01** `analysis_options.yaml:21-23` — `avoid_print`/`use_build_context_synchronously` понижены до `info`, CI не падает на линтах.
- **CQ-09** `text_similarity_service.dart:103,172-185` — самописный `sqrt` вместо `dart:math`, медленный глобал.
- **CQ-14** `failures.dart:3-57` — вся иерархия `Failure` — мёртвый код (нигде не импортирована).
- **CQ-16** `firebase_service.dart:44-98` — `print()` и частичное проглатывание ошибок инициализации.
- **TD-08** `main_navigation.dart` — мёртвый второй nav-shell (0 импортёров).
- **TD-06** `admin/services/ai_service.dart` — 31-строчный TODO-stub дублирует реальный HTTP-клиент.
- **CQ-12** `profile_page.dart:565-597` — дублированные/расходящиеся правила уровней в виджете.
- **ADM-07** `admin/data/models/question_model.dart:116-216` — несовместимое второе определение `QuestionModel`/опций.
- **ADM-08** `admin_panel_page.dart:18` — обходимая клиентская проверка админа + push на несуществующие маршруты.
- **SEC-005** `validators.dart:20-30` — 6-символьные пароли, проверка email «есть `@`», некапнутые AI-промпты.
- **TD-11** `locale_provider.dart` vs `language_provider.dart` — два провайдера языка под разными ключами (`app_locale` vs `app_language`) → тихий рассинхрон.
- **CQ-05** `gamification_service.dart:7-24` — кэш на время жизни процесса без инвалидации → устаревшие XP/коины/стрик.
- **CQ-06/CQ-08** — `Future.delayed` + серийная цепочка на финише квиза (дубли PERF).

### 3.4 LOW (14) — выжимка

`updateTestStats` игнорирует параметры (`firebase_data_service.dart:215`) · тавтологическое условие стрика (`user_progress_model.dart:127`) · `awardXP` игнорирует `reason` · непоследовательное `Equatable` по моделям · **ground-truth: в `profile_page.dart` нет ошибок анализатора** (подтверждено) · фейковые метрики на дашборде/мёртвых страницах · мёртвый `mission_provider.dart` · `MockDataService` дублирует fallback из `FirebaseDataService` · домен-модели утроены по расположению · `get_it` не используется · O(n·m) Левенштейн на каждое сравнение · placeholder macOS Firebase + мёртвый `isRateLimited()` · auth-ошибки логируются `print()` и показываются сырыми в UI.

### 3.5 Отклонено верификацией (1)
- **CQ-05** «`QuizResultsPage` осиротела» — **ЛОЖНО**: есть живой вызов `quick_test_page.dart:82` через константу `AppRouter.quizResults`. Реальная (меньшая) проблема — две несогласованные ветки завершения квиза + таймер не реализован (`'10:00'` хардкод, `totalTimeSeconds = 0`).

---

## 4. Security Audit

| ID | Severity | Проблема |
|---|---|---|
| SEC-001 | 🔴 critical | Ключ Anthropic в клиенте (`ai_service.dart:51`, endpoint `ai_models.dart:5`, ввод `ai_generator_page.dart:148`) |
| SEC-002 | 🔴 critical | Self-escalation роли в `firestore.rules:29` |
| SEC-003 | 🔴 critical | `/admin/*` без guard; раздвоенный источник прав |
| CQ-01/SEC-004 | 🔴/high | Хардкод плейнтекст-паролей + публичная регистрация админа |
| SEC-005 | medium | Слабая валидация: 6-символьные пароли, email по `@`, AI-инпут без лимитов |
| ADM-08 | medium | Обходимая клиентская проверка админа на мёртвой странице |
| SEC-006 | low | Auth-ошибки через `print()` и сырыми в UI |
| SEC-007 | low | Placeholder Firebase-конфиг (macOS), мёртвый `isRateLimited()`, нужны ограничения API-ключей |

**Архитектурный корень всех проблем безопасности**: нет серверного tier. `cloud_functions` объявлен, но `functions/` не существует, а `firestore.rules:97` комментирует «Only Cloud Functions can update payment status» — то, что никто не обеспечивает. Платежи, счёт и рейтинги невозможно валидировать на сервере.

Готовые исправления (Cloud Function-прокси, харднинг `firestore.rules`, router-guard) — в **§11**.

---

## 5. Performance Audit

- **PERF-01 (high)** `gamification_service.dart` — 5 искусственных `Future.delayed` (200/100/200/200/300 мс) первым стейтментом методов; они **складываются** по цепочке `updateStatistic → _checkAchievements → awardXP` → >1 сек чистого сна на финише квиза. → Удалить все.
- **PERF-02 (high)** `quiz_page.dart:516-567` — все backend-вызовы строго последовательны (`awardXP`, `updateTestStats`, 2-3× `updateStatistic`, цикл по квестам), каждый — read-modify-write; `_checkAchievements` пересканирует 14 достижений на каждый вызов (N+1) с лишним `getUserGamification + _saveUserGamification`. → `Future.wait` для независимых записей + `WriteBatch` для квестов + один проход достижений.
- **TD-04/арх** — `FirebaseDataService()` создаётся inline в 8+ `State` → нет единого инстанса, лишние аллокации.
- **Boot** — `main.dart:34` fire-and-forget Firebase → гонка на старте.
- **~40× `prefer_const_constructors`** (из 125 info-линтов) — мелкие лишние ребилды; чинятся `dart fix --apply`.
- **`text_similarity_service`** — полная O(n·m) матрица Левенштейна на каждое сравнение (память+CPU).

---

## 6. UX/UI Audit

| ID | Severity | Экран | Проблема |
|---|---|---|---|
| ux-001 | 🔴 critical | весь app | **Локализация — фасад**: только `settings_page` использует `AppLocalizations`; остальные экраны хардкодят русский и передают литерал `ru`. Переключение языка не меняет ничего вне настроек → киргизская аудитория не может пользоваться |
| ux-002 | 🔴 critical | `mock_test_page` | «Начать тест» = `Navigator.pop` + TODO, раннера нет. Дашборд ведёт сюда → убита главная конверсия |
| ux-003 | high | `dashboard_page` | Приветствие «Студент» всем; фейковые `+12%`, `12` тестов, `145` средний, `7` стрик; хардкод-список предметов; геймификация для `'current_user'` |
| ux-004 | high | `progress_page` | Фабрикует историю по предметам и «AI-прогноз» из порога `testsCompleted`, показывает как реальное → студент неверно оценит готовность |
| CQ-14 | medium | `settings_page:72-119` | Тумблеры уведомлений с пустыми `onChanged` (откатываются назад), «245 МБ» хардкод, privacy/terms/clear-cache — TODO |

**Главные UX-выводы**: приложение демонстрирует фейковые данные как «прогресс пользователя» на ключевых экранах (дашборд, прогресс) — это разрушает доверие сильнее, чем отсутствие функции. Первый приоритет — связать дашборд/прогресс с реальным `uid` и честные empty-state.

---

## 7. Product Improvements

> **Главный продуктовый инсайт: модель данных намного опережает продуктовую поверхность.** Почти каждый механизм роста/монетизации наполовину построен и брошен мёртвым.

Что уже есть в коде, но **не подключено**:
- Подписка `UserModel.subscription` (free/monthly/yearly + `isActive`) — **0 использований гейтинга** в presentation; `/payments` — заглушка.
- Цены в KGS (`app_constants.dart:57-59`: мок 100, 5-пак 400, подписка 500 KGS) + `PaymentModel` (mbank/card/google_play).
- Полный движок **SM-2 spaced-repetition** (`flashcard_model.dart:119-163`) — но `/flashcards` заглушка.
- `UserModel.weakSubjects`, `targetUniversities`, `OrtConstants.universityThresholds` (medical=190…) — но онбординг ничего не собирает.
- `FirebaseMessaging` импортирован — но ни одного уведомления.
- `LinkedAccounts.parents/teachers`, регионально-школьные рейтинги, экономика коинов — мертвы.

### Приоритизированные улучшения

**Высокий impact:**
1. **Запустить paywall** (freemium-гейтинг + подписка в KGS) — вся обвязка уже есть, но ничего не залочено → выручки нет. *Главное действие по выручке.*
2. **Сделать AI-объяснения реальными** (server-proxied AI-репетитор «почему ты ошибся») вместо 3 хардкод-абзацев в `ai_explainer_modal.dart:206-221`. Лимит для free, безлимит для premium.
3. **Активировать SRS** — построить экран ревью, авто-генерить карточки из ошибок, «X карточек на сегодня» на дашборде. Сильнейший retention-механик.
4. **Диагностика → персональный план до целевого балла** как онбординг-стержень («тебе не хватает 40 баллов до медицины»).
5. **Адаптивные дриллы по слабым темам** на базе `weakSubjects` + статистики вопросов.
6. **Полные ORT-моки** по реальной структуре (220 баллов) + починить противоречие констант. Самый платёжеспособный SKU.
7. **Push-уведомления** (стрик под угрозой, карточки на ревью, дневная цель).

**Средний impact:** родительские отчёты/связанные аккаунты (платит родитель), сезоны/школьные рейтинги, рефералы + траты коинов, персонализация дашборда (дёшево, высокий рычаг), B2B-лицензии для ORT-курсов.

---

## 8. Competitor Analysis

**Категория**: mobile exam-prep для национального экзамена (ORT KG), trilingual ru/ky/en. **Доминирующего полированного ORT-приложения на рынке нет** — рынок фрагментирован.

| Конкурент | Сильные | Слабые / наш шанс |
|---|---|---|
| Офлайн «ORT курс»-центры (Bilim, Senim, Sebat…) | Доверие, живые учителя, проверенный контент, готовность родителей платить (10–40k+ KGS) | Дорого, гео-ограничены (Бишкек/Ош), не масштабируются, нет 24/7 и аналитики |
| Telegram-каналы/боты (PDF-банки) | Нулевой барьер, охват, бесплатно, дневной habit | Без структуры/аналитики/адаптивности, пиратский контент |
| testing.kg / CEATM | Авторитет, определяет реальную структуру | Не продукт обучения → партнёрство для credibility |
| Kundoluk / OkuduPro | Локальное проникновение, канал к школам/родителям | Не ORT-prep → может стать конкурентом или партнёром |
| Duolingo | Эталон retention (стрики/лиги/push) | Нет ORT/KG → копировать механики |
| Khan Academy | Бесплатный качественный контент, mastery | Нет ORT/KG, слабый ky/ru |
| Quizlet/Brilliant/Photomath | SRS / интерактив / пошаговое решение математики | Не ORT-specific → абсорбировать фичи |
| RU ЕГЭ-prep (Skysmart, Foxford, Яндекс) | Адаптивность, банки, аналитика, монетизация | Только русский, неверная структура → ky-medium ORT — наш незанятый сегмент |

### Сравнительная таблица (фрагмент; полная — 16 строк в данных аудита)

| Функция | Наш проект | Конкуренты | Что делать |
|---|---|---|---|
| ORT-структура и scoring | Сильно (`ort_constants`), но конфликт с `app_constants` | Курсы/testing.kg точны | **Moat.** Убрать конфликт, маркетинг «совпадает с официальным ORT» |
| Точный банк вопросов | Слабо/непроверено; `subject_detail` читает mock | Курсы/Telegram владеют этим | **Приоритет #1.** Большой экспертно-проверенный банк |
| Полный мок-симулятор (таймер/секции) | Сильно (`mock_test_page`) | Курсы — периодически | Углублять: percentile, «прогноз балла» |
| AI-репетитор | Слабо+рискованно (статика + клиентский ключ) | Photomath лучший | **Дифференциатор.** Перенести на сервер |
| Геймификация | Сильно (6 rarity, квесты, коины) | Duolingo — эталон | Лиги/лидерборды + streak-freeze |
| Региональный рейтинг | Сильно и уникально (область→район→село) | Локально никто | **Лить сюда.** Школа-vs-школа, shareable-карточки |
| Trilingual ky-first | Сильно (`l10n`) | RU-only у большинства | **Moat.** Перевести весь контент, не только UI |
| Адаптив/SRS | Отсутствует (движок есть, не подключён) | ЕГЭ/Quizlet/Khan | Высокий impact: подключить |
| Локальные платежи | Слабо (заглушка) | Курсы/ЕГЭ-apps | **Критично:** MBank/Elsom/O!Dengi + Google Play |
| Безопасность/целостность | **Критический риск** (ключ в клиенте, self-admin) | Зрелые: server-side | Блокер рынка, чинить до масштаба |

### ТОП-32 улучшения (отсортировано по impact)

1. Большой экспертно-проверенный банк вопросов по реальным прошлым ORT. 2. Server-side AI-прокси + студенческий AI-репетитор «почему ошибся». 3. Локальные платёжные рельсы (MBank/Elsom/O!Dengi/Optima) + Google Play IAP. 4. Офлайн-режим (кэш уроков/паков через Hive). 5. Адаптивная практика + SRS-карточки. 6. «Прогноз балла ORT» + разрыв до порога вуза. 7. Kyrgyz-first во всём контенте. 8. Duolingo-лиги поверх регионального рейтинга. 9. Push стрик+квесты. 10. Починить конфликт констант ORT (140/220). 11. Photomath-стиль пошаговая математика. 12. Харднинг `firestore.rules` + ограничение API-ключей. 13. Полные таймированные моки + percentile. 14. Сигналы доверия (авторы-эксперты, партнёрство CEATM). 15. Убрать `MockDataService` из прода. 16. Heatmap mastery по темам. 17. «Вопрос дня» с push (как в Telegram). 18. Родительский дашборд/отчёт. 19. Видео-объяснения (Khan-модель). 20. Shareable score-карточки для виральности. 21. Freemium-гейтинг. 22. Рефералы + траты коинов. 23. Peer Q&A/комьюнити (`forum_posts` зарезервирован). 24. План «обратный отсчёт до ORT». 25. Подсказки по грантам/стипендиям по прогнозу балла. 26. Банк ошибок «мои ошибки». 27. Верификация контента для ky/ru-потоков. 28. Router-level auth/admin guard. 29. Tutor-booking upsell. 30. Сезонные nationwide мок-олимпиады с призами. 31. Лёгкий онбординг (цель/вуз/класс). 32. Доступность + оптимизация для бюджетных Android (await Firebase init).

---

## 9. Roadmap (готовность к масштабу + фазы)

### Блокеры по уровням нагрузки
- **Релиз**: SEC-001/002/003, debug-подпись, CI сломан, mock-данные в проде, boot-race, нет тестов.
- **1k**: + нет `firestore.indexes.json` (composite where+orderBy в `firebase_data_service.dart:70-71` бросят `FAILED_PRECONDITION`); только `FlutterError` ловится Crashlytics (нет `runZonedGuarded`); анти-чит отсутствует (счёт пишет клиент); нет support/on-call.
- **10k**: + рейтинги читаются всеми авторизованными без пагинации/агрегации (взрыв стоимости чтений); `isRateLimited()` не применён; нет контент-пайплайна; фрагментация моделей.
- **100k**: + Firebase-direct-from-client — узкое место; нет регионального шардирования рейтингов; нет cost-governance; нет multi-env (dev/staging/prod).
- **1M**: + нужен реальный backend-tier (Functions/Run + аналитическое хранилище/BigQuery), SRE/on-call/SLO, multi-region/DR, комплаенс PII несовершеннолетних, App Check, ротация ключей.

### Фазы

| Фаза | Цель | Сложность | Срок | Impact |
|---|---|---|---|---|
| **P0 — Security & Release Blockers** | Сделать безопасным и шипабельным | high | 3-5 нед | high |
| **P1 — Stability, Tests, CI/CD, Observability** | Сетка безопасности от регрессий | high | 4-6 нед | high |
| **P2 — Architecture Refactor & Dedup** | Свести в одну связную архитектуру | high | 4-6 нед | medium |
| **P3 — Scale & Cost** | Дешёвые и быстрые Firestore/рейтинги | high | 5-8 нед | medium |
| **P4 — Growth & Monetization** | Платежи + контент-пайплайн + рост | medium | 4-6 нед | medium |

**P0**: Cloud Function `generateQuestions` (ключ на сервере) + удалить `_apiKeyController`; запретить self-write `role` (правила + custom claims); убрать `MockDataService` из `subject_detail_page`; реальный `applicationId` + release-keystore; `await` Firebase init; починить CI (SDK ≥3.9.2, реальный `projectId`, `upload-artifact@v4`); App Check + ограничение API-ключей.

**P1**: unit-тесты (scoring/XP/parsing) + firestore-rules-тесты на эмуляторе; `runZonedGuarded` + `PlatformDispatcher.onError` → Crashlytics; `firestore.indexes.json`; CI как реальный гейт + staging; server-validated scoring (анти-чит); квоты/лимиты на AI.

**P2**: один источник правды для моделей; примирить ORT-константы; удалить legacy «Task» + `/tasks`, мёртвый `main_navigation`, осиротевший admin-UI; единый DI (Riverpod, убрать `get_it`); data/repository-слой для не-admin фич + router-guard; вычистить 125 линтов и stale-доки.

**P3**: рейтинги → предрасчитанные агрегаты по расписанию + пагинация/шардинг по регионам; кэш/CDN контента + Remote Config kill-switches; применить rate-limiting; бюджеты/квоты + экспорт в BigQuery; офлайн-стратегия (Hive-очередь + конфликт-резолюция); load-тесты + SLO.

**P4**: платежи через Functions (+ webhook-верификация) + модель entitlement; контент-пайплайн author→review→versioned publish (ru/ky/en); рефералы/push-кампании/воронки; iOS-конфиг (`GoogleService-Info.plist` + URL scheme); комплаенс PII + брендинг (web-manifest сейчас дефолтный).

---

## 10. Refactoring Plan (по шагам, с риском)

| # | Шаг | Сложн./Риск | Почему именно сейчас |
|---|---|---|---|
| 1 | **Стабилизировать build/boot**: CI под SDK ^3.9.2; `await` Firebase init (или `initializationProvider`); починить `flutter test` | low / low | Нельзя рефакторить то, что не собирается и падает на старте |
| 2 | **Закрыть security-дыры, диктующие архитектуру**: Cloud Function-прокси для AI; не-самозаписываемая `role`; убрать мёртвый `isRateLimited()` | medium / **high** | Живой ключ и one-line escalation — production-critical; форсируют server-tier. Риск: правила могут залочить админов, если не выдать claims заранее |
| 3 | **Единый домен**: `core/constants/ort_structure.dart` (merge 130/200 ↔ 140/220), переподключить импорты | medium / medium | Два scoring-источника — латентный correctness-баг |
| 4 | **Централизовать DI на Riverpod**: `firebase_providers.dart`; `FirebaseDataService` → репозитории за провайдерами; убрать inline-`new` (`quiz_page.dart:25`, `mission_provider.dart`); удалить `get_it` | high / medium | Ядро тестируемости и предпосылка для domain-слоя |
| 5 | **Удалить мёртвый/дубль-код**: `main_navigation`, stub-сервисы admin, дубли моделей, осиротевшие manager-страницы, «Task»-фича + `/tasks`, stale-доки | medium / low | Уменьшает merge-конфликты и проясняет канон |
| 6 | **Domain-слой по фичам (старт admin+quiz)**: entities/usecases/interfaces; обобщить паттерн `questions_repository` | high / medium | Содержательный Clean-Arch шаг, даёт test-seam |
| 7 | **Перестроить роутинг**: `StatefulShellRoute` + redirect-guard на `authStateProvider+roleProvider`; убрать императивный гейтинг; заменить placeholder-Scaffold'ы | high / **high** | Закрывает deep-link-bypass; роутинг легко регрессит → после auth-провайдеров |
| 8 | **Перенести stray-провайдеры** в фичи/core, удалить `lib/providers,models,screens`; заменить `MockDataService` реальным репо | medium / low | Финальная подгонка дерева под целевое |
| 9 | **Guardrails**: import-lint (запрет `cloud_firestore` вне `*/data/`), `avoid_print`→Crashlytics, unit-тесты use-case'ов; CI под SDK | medium / low | Фиксирует архитектуру от регрессий |

---

## 11. Ready-to-Use Code

### 11.1 SEC-001 — Cloud Function-прокси (ключ не покидает сервер)
```typescript
// functions/src/generateQuestions.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import Anthropic from '@anthropic-ai/sdk';

const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');

export const generateQuestions = onCall(
  { secrets: [ANTHROPIC_API_KEY], enforceAppCheck: true },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Login required');
    if (req.auth.token.admin !== true) throw new HttpsError('permission-denied', 'Admin only');

    const { sectionId, subjectId, topic, difficulty, count } = req.data ?? {};
    if (typeof topic !== 'string' || topic.length > 500) throw new HttpsError('invalid-argument', 'topic');
    const n = Math.min(Math.max(Number(count) || 1, 1), 20);

    const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
    const msg = await client.messages.create({
      model: 'claude-sonnet-4-5',
      max_tokens: 8000,
      messages: [{ role: 'user', content: buildPrompt({ sectionId, subjectId, topic, difficulty, count: n }) }],
    });
    return { content: msg.content };
  }
);
```
```dart
// Dart-клиент: вместо AiService(apiKey: ...) — вызов callable; удалить _apiKeyController и поле ввода ключа
final res = await FirebaseFunctions.instance.httpsCallable('generateQuestions').call({
  'sectionId': sectionId, 'subjectId': subjectId, 'topic': topic,
  'difficulty': difficulty, 'count': count,
});
```

### 11.2 SEC-002 — Харднинг `firestore.rules` (роль не самозаписываема)
```javascript
function isAdmin() {
  // Доверяем ТОЛЬКО custom claim, никогда — самозаписываемому полю
  return request.auth != null && request.auth.token.admin == true;
}

match /users/{userId} {
  allow read:   if isOwner(userId) || isAdmin();
  allow create: if isOwner(userId)
                   && !('role' in request.resource.data)
                   && !('premium' in request.resource.data);
  allow update: if isOwner(userId)
                   && request.resource.data.diff(resource.data)
                        .affectedKeys()
                        .hasAny(['role','premium','subscription']) == false;
  allow delete: if isAdmin();
}
// Выдача админа — только через Cloud Function (Admin SDK):
// await admin.auth().setCustomUserClaims(uid, { admin: true });
```

### 11.3 SEC-003 — Router-level guard + проверка claim при логине
```dart
// app_router.dart
GoRouter(
  redirect: (context, state) async {
    final user = FirebaseAuth.instance.currentUser;
    final goingAdmin = state.uri.path.startsWith('/admin') && state.uri.path != AppRouter.adminLogin;
    if (!goingAdmin) return null;
    if (user == null) return AppRouter.adminLogin;
    final token = await user.getIdTokenResult();
    return token.claims?['admin'] == true ? null : AppRouter.adminLogin;
  },
  routes: [...],
);

// admin_login_page.dart — проверять claim ДО навигации
await authService.signInWithEmailAndPassword(email: ..., password: ...);
final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
if (token.claims?['admin'] != true) {
  await authService.signOut();
  _showError('Доступ запрещён: аккаунт не является администратором');
  return;
}
context.go(AppRouter.adminDashboard);
```

### 11.4 CQ-02 — реальный uid вместо `'current_user'`
```dart
// dashboard_page.dart / achievements_page.dart
Future<void> _loadGamificationData() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) { if (mounted) setState(() => _isLoading = false); return; }
  try {
    final gamification = await _gamificationService.getUserGamification(uid);
    final quests = await _gamificationService.getDailyQuests(uid);
    await _gamificationService.updateStreak(uid);
    if (!mounted) return;
    setState(() { _userGamification = gamification; _dailyQuests = quests; _isLoading = false; });
  } catch (_) { if (mounted) setState(() => _isLoading = false); }
}
```

### 11.5 CQ-03 — go_router вместо `Navigator.pushNamed`
```dart
import 'package:go_router/go_router.dart';
// handbook_content_page.dart _buildQuickActionButton:
onTap: () => context.push(route),
// handbook_search_delegate.dart (оба места):
context.push('/handbook/${result.categoryId}');
```

### 11.6 CQ-06 — счёт по канонической константе (не литерал 240)
```dart
// quiz_page.dart — после примирения констант (рекомендуется OrtConstants.totalMaxScore = 220)
final scorePercentage = (correctAnswers / _totalQuestions * OrtConstants.totalMaxScore).round();
// Решение продукта: зафиксировать ЕДИНЫЙ максимум (220 по ort_constants) и убрать app_constants.maxScore=200.
```

### 11.7 main.dart — детерминированный старт (без гонки)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    Hive.initFlutter(),
  ]);
  await FirebaseService.initialize(); // ← await, а не fire-and-forget
  runApp(ProviderScope(overrides: [...], child: const OrtMasterApp()));
}
```

### 11.8 CI-01 — исправленный GitHub Actions
```yaml
name: Flutter CI/CD
on:
  push: { branches: [main, develop] }
  pull_request: { branches: [main, develop] }
jobs:
  analyze-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }   # stable даёт Dart >= 3.9.2 (НЕ пинить 3.16.0)
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v4
        with: { files: coverage/lcov.info }
  rules-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm --prefix test/firestore ci
      - run: npx firebase emulators:exec --only firestore "npm --prefix test/firestore test"
  build-android:
    needs: [analyze-test, rules-test]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: flutter build appbundle --release
      - uses: actions/upload-artifact@v4   # v3 устарел/EOL
        with: { name: release-aab, path: build/app/outputs/bundle/release/app-release.aab }
```

### 11.9 PERF-01/02 — убрать искусственные задержки + параллелить запись
```dart
// gamification_service.dart: удалить ВСЕ строки `await Future.delayed(...)` (93,132,147,247,253)
// quiz_page.dart _finishQuiz: независимые записи — параллельно
await Future.wait([
  _gamificationService.awardXP(uid, xp, 'Quiz completed'),
  _firebaseDataService.updateTestStats(uid, score: scorePercentage, ...),
  _gamificationService.updateStatistic(uid, 'testsCompleted', 1),
  _gamificationService.updateStatistic(uid, 'questionsAnswered', _totalQuestions),
]);
// квесты — одним WriteBatch вместо цикла await.
```

### 11.10 REL-01 — release-подпись Android
```kotlin
// android/app/build.gradle.kts
android {
  namespace = "kg.ortmaster.app"
  defaultConfig { applicationId = "kg.ortmaster.app" }  // НЕ com.example.*
  signingConfigs {
    create("release") {
      val props = java.util.Properties().apply {
        load(java.io.FileInputStream(rootProject.file("key.properties"))) // key.properties — вне VCS
      }
      keyAlias = props.getProperty("keyAlias"); keyPassword = props.getProperty("keyPassword")
      storeFile = file(props.getProperty("storeFile")); storePassword = props.getProperty("storePassword")
    }
  }
  buildTypes {
    getByName("release") {
      signingConfig = signingConfigs.getByName("release")
      isMinifyEnabled = true; isShrinkResources = true   // R8/ProGuard
    }
  }
}
```

> Дополнительно `dart fix --apply` снимает большую часть из 125 info-линтов (≈40 `prefer_const_*`, `unnecessary_to_list_in_spreads`); миграция `Radio.groupValue/onChanged` → `RadioGroup` и `DropdownButtonFormField.value` → `initialValue`.

---

## 12. Final CTO Verdict

**УСЛОВНОЕ «ДА» для pre-seed / friends-and-family; ТВЁРДОЕ «НЕТ» для институциональных денег по текущей оценке.**

Это настоящий продукт с реальной доменной глубиной (ORT-структура, trilingual-контент, геймификация, продуманные AI-промпты) и фаундером, который **шипит**. Но это **прототип, выдающий себя за платформу**. Три находки по отдельности дисквалифицируют любой платный/публичный запуск:

1. Ключ Anthropic вводится в клиентское текстовое поле и уходит на `api.anthropic.com` (`ai_generator_page.dart:148` → `ai_service.dart:51`) — извлекаемый секрет в бандле → неограниченные счёта.
2. `firestore.rules:29` позволяет любому переписать свою роль на `admin` (`isAdmin()` доверяет этому полю) → захват контента и удаление чужих аккаунтов.
3. Вся модель доверия предполагает Cloud Functions, **которых не существует** — платежи, валидация счёта и целостность рейтингов опираются на серверный tier, который не построен.

Добавьте ~ноль автотестов (единственный тест красный), CI, который даже не запускает `pub get`, debug-подписанный релиз с `com.example` ID — и получите **6-10 инженеро-недель P0-ремедиации** прежде чем приложение можно безопасно показать реальным студентам.

**Самый большой риск — не отдельный баг, а отсутствие серверного tier.** Firebase-direct-from-client не способен обеспечить целостность, которую требует экзамен-преп с рейтингами и платежами.

**Сильнейший рычаг роста**: продуктовая поверхность отстаёт от данных. Подписка, SRS-движок, региональные рейтинги, экономика коинов и платёжная модель в KGS **уже написаны** — их нужно лишь подключить к UID и к paywall. Это превращает «прототип» в «бизнес» быстрее, чем кажется.

**Корректность к исходным данным**: анализатор сейчас ЗЕЛЁНЫЙ (0 ошибок, 125 info-линтов) — `profile_page.dart` компилируется; тезис «RED-анализатор / не собирается» из `ERROR_ANALYSIS.md` устарел. Но `flutter test` красный, а CI не запускается — что важнее для качества.

---

*Методология: 2 фазы мульти-агентного аудита (16 + 67 агентов, ~4.7M токенов), каждый конкретный дефект перепроверен независимым верификатором по реальному коду; 1 ложноположительный отфильтрован. Источники строк указаны в формате `файл:строка` и проверяемы.*
