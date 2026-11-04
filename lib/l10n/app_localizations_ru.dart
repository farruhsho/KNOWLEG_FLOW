// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get aboutApp => 'О приложении';

  @override
  String get accountDeleteButton => 'Удалить аккаунт навсегда';

  @override
  String accountDeleteConfirmAlt(String word) {
    return 'Можно также ввести $word';
  }

  @override
  String accountDeleteConfirmLabel(String word) {
    return 'Для подтверждения введите $word';
  }

  @override
  String get accountDeleteConfirmWord => 'УДАЛИТЬ';

  @override
  String get accountDeleteDone => 'Аккаунт удалён.';

  @override
  String get accountDeleteGoToLogin => 'Войти';

  @override
  String get accountDeleteInProgress => 'Удаляем данные…';

  @override
  String get accountDeleteItemAi => 'История запросов к ИИ-репетитору';

  @override
  String get accountDeleteItemCredits =>
      'Неиспользованные кредиты и бесплатный экзамен — они аннулируются без возможности переноса';

  @override
  String get accountDeleteItemExams => 'Попытки и результаты пробных экзаменов';

  @override
  String get accountDeleteItemGamification =>
      'XP, уровень, серии, достижения и места в рейтингах';

  @override
  String get accountDeleteItemLogin =>
      'Данные для входа (email и пароль или привязка Google)';

  @override
  String get accountDeleteItemProfile =>
      'Профиль: имя, email, фото, класс, регион и настройки';

  @override
  String get accountDeleteItemProgress =>
      'Прогресс обучения, история уроков, ошибки и очередь повторения';

  @override
  String get accountDeleteKeptGoogle =>
      'История платежей Google Play хранится у Google в вашем Google-аккаунте.';

  @override
  String get accountDeleteKeptPurchases =>
      'Обезличенные записи о покупках (дата, товар, сумма, номер заказа) без имени и email. Они нужны для финансовой отчётности, возвратов и защиты от мошенничества.';

  @override
  String get accountDeleteSignedOut => 'Войдите в аккаунт, чтобы удалить его.';

  @override
  String get accountDeleteTitle => 'Удаление аккаунта';

  @override
  String get accountDeleteUnavailablePlatform =>
      'Удаление аккаунта недоступно на этой платформе. Откройте приложение на Android-устройстве, чтобы удалить аккаунт.';

  @override
  String get accountDeleteWarningBody =>
      'Аккаунт и данные об обучении будут удалены навсегда. Восстановить их будет невозможно.';

  @override
  String get accountDeleteWarningTitle => 'Это действие нельзя отменить';

  @override
  String get accountDeleteWhatDeletedTitle => 'Что будет удалено';

  @override
  String get accountDeleteWhatKeptTitle => 'Что сохранится';

  @override
  String get accountErrorGoogle =>
      'Не удалось войти через Google. Попробуйте ещё раз.';

  @override
  String get accountErrorNetwork =>
      'Нет соединения. Проверьте интернет и повторите.';

  @override
  String get accountErrorRecentLogin =>
      'Для безопасности войдите ещё раз и повторите.';

  @override
  String get accountErrorService =>
      'Удаление аккаунта временно недоступно. Попробуйте позже.';

  @override
  String get accountErrorTooManyRequests =>
      'Слишком много попыток. Подождите несколько минут и повторите.';

  @override
  String get accountErrorUnauthenticated =>
      'Сервер не смог проверить приложение или ваш сеанс. Обновите приложение, войдите заново и повторите.';

  @override
  String get accountErrorUnknown =>
      'Не удалось удалить аккаунт. Попробуйте ещё раз.';

  @override
  String get accountErrorUserMismatch =>
      'Это другой аккаунт. Войдите в тот, который хотите удалить.';

  @override
  String get accountErrorWrongPassword => 'Неверный пароль.';

  @override
  String get accountReauthBody =>
      'Для безопасности войдите ещё раз перед удалением аккаунта.';

  @override
  String get accountReauthCancel => 'Отмена';

  @override
  String get accountReauthConfirm => 'Подтвердить';

  @override
  String accountReauthEmail(String email) {
    return 'Аккаунт: $email';
  }

  @override
  String get accountReauthGoogle => 'Продолжить через Google';

  @override
  String get accountReauthPassword => 'Пароль';

  @override
  String get accountReauthSignInAgain => 'Войти заново';

  @override
  String get accountReauthTitle => 'Подтвердите, что это вы';

  @override
  String get adminAccountMenu => 'Аккаунт';

  @override
  String get adminActivate => 'Активировать';

  @override
  String get adminActive => 'Активен';

  @override
  String get adminAdd => 'Добавить';

  @override
  String get adminAddOption => 'Добавить вариант';

  @override
  String get adminAiCount => 'Количество';

  @override
  String adminAiDraftMeta(String topic, int difficulty) {
    return '$topic · сложность $difficulty';
  }

  @override
  String adminAiDrafts(int n) {
    return 'Черновики: $n';
  }

  @override
  String get adminAiEmpty => 'Заполните запрос и создайте черновики.';

  @override
  String get adminAiFillForm => 'Выберите структуру, раздел, часть и тему.';

  @override
  String get adminAiGenerate => 'Создать черновики';

  @override
  String get adminAiGenerating => 'Генерация…';

  @override
  String get adminAiNotice =>
      'Черновики создаются на сервере; ключ API в приложении не хранится. Каждый черновик сохраняется со статусом «Черновик» и должен быть одобрен методистом, прежде чем попадёт в вариант.';

  @override
  String get adminAiOpenBank => 'Открыть банк экзамена';

  @override
  String get adminAiRequest => 'Запрос';

  @override
  String adminAiSaveSelected(int n) {
    return 'Сохранить $n';
  }

  @override
  String adminAiSaved(int n) {
    return 'Сохранено черновиков на проверку: $n';
  }

  @override
  String get adminAll => 'Все';

  @override
  String get adminAppCheckPlatformNote =>
      'Сборка рассчитана на сервер, который требует App Check для админ-функций (APP_CHECK_ENFORCE_ADMIN), а на этой платформе App Check нет: роли, кредиты, публикация, тарифы и черновики ИИ будут отклонены. Используйте веб-версию с App Check или Android.';

  @override
  String get adminAppTitle => 'ORT Master · CMS';

  @override
  String get adminApply => 'Применить';

  @override
  String adminBanReasonTooLong(int max) {
    return 'Причина — не длиннее $max символов.';
  }

  @override
  String get adminCancel => 'Отмена';

  @override
  String get adminClose => 'Закрыть';

  @override
  String get adminCorrectMultiHelp => 'Отметьте все правильные варианты.';

  @override
  String get adminCorrectSingleHelp => 'Отметьте один правильный вариант.';

  @override
  String get adminDashboardReviewBody =>
      'Откройте банк экзамена с фильтром статуса «Черновик» или «Проверен ИИ», чтобы проверить вопросы. В опубликованный вариант попадают только одобренные вопросы с ключом ответа.';

  @override
  String get adminDashboardReviewTitle => 'Очередь проверки';

  @override
  String get adminDashboardShortcuts => 'Разделы';

  @override
  String adminDashboardWelcome(String role) {
    return 'Ваша роль: $role';
  }

  @override
  String get adminDeactivate => 'Деактивировать';

  @override
  String get adminDelete => 'Удалить';

  @override
  String get adminDeletePermanently => 'Удалить навсегда';

  @override
  String get adminDeleted => 'Удалено';

  @override
  String get adminDifficulty1 => '1 · лёгкий';

  @override
  String get adminDifficulty2 => '2 · средний';

  @override
  String get adminDifficulty3 => '3 · сложный';

  @override
  String adminDifficultyN(int n) {
    return 'сложность $n';
  }

  @override
  String get adminDiscard => 'Не сохранять';

  @override
  String get adminEdit => 'Редактировать';

  @override
  String get adminErrAppCheckPlatform =>
      'Сервер отклонил запрос: на этой платформе нет App Check (Windows/Linux или веб без ключа App Check). Откройте админку в веб-версии с App Check или на Android либо попросите владельца выставить APP_CHECK_ENFORCE_ADMIN=false.';

  @override
  String get adminErrAppCheckRejected =>
      'Сервер отклонил запрос (токен App Check отсутствует или недействителен). Войдите заново; если повторяется, проверьте регистрацию App Check для этого устройства.';

  @override
  String adminErrFileTooLarge(int mb) {
    return 'Файл слишком большой (максимум $mb МБ).';
  }

  @override
  String get adminErrForbidden => 'Недостаточно прав для этого действия.';

  @override
  String get adminErrFunctionMissing => 'Серверная функция ещё не развернута.';

  @override
  String adminErrGeneric(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get adminErrIndex =>
      'Для этого фильтра нужен индекс Firestore. Измените фильтр или создайте индекс.';

  @override
  String get adminErrNetwork =>
      'Нет связи с сервером. Проверьте сеть и повторите.';

  @override
  String get adminErrNotFound => 'Не найдено.';

  @override
  String get adminErrQuota => 'Достигнут лимит. Повторите позже.';

  @override
  String get adminErrSessionExpired =>
      'Сессия администратора истекла. Войдите снова.';

  @override
  String get adminErrTitle => 'Не удалось загрузить';

  @override
  String get adminErrUnknown => 'Что-то пошло не так. Повторите попытку.';

  @override
  String adminErrUnsupportedMedia(String ext) {
    return 'Неподдерживаемый формат файла ($ext). Разрешены: PNG, JPEG, WEBP, GIF, PDF.';
  }

  @override
  String get adminErrUserBanned =>
      'Этот аккаунт заблокирован. Действия на сервере недоступны.';

  @override
  String adminErrValidation(String message) {
    return 'Проверка не пройдена: $message';
  }

  @override
  String get adminExamAddTable => 'Добавить таблицу';

  @override
  String get adminExamApprove => 'Одобрить';

  @override
  String get adminExamBackToDraft => 'Вернуть в черновик';

  @override
  String get adminExamChoosePlacement =>
      'Сначала выберите структуру теста и раздел.';

  @override
  String get adminExamColumnA => 'Колонка А';

  @override
  String get adminExamColumnB => 'Колонка Б';

  @override
  String get adminExamColumns => 'Колонки А / Б';

  @override
  String get adminExamColumnsHelp =>
      'Сравнение величин: две сравниваемые величины. В тексте задания — только общее условие (может быть пустым).';

  @override
  String adminExamCorrectIs(String id) {
    return 'Правильный вариант: $id';
  }

  @override
  String adminExamCreateTranslation(String lang) {
    return 'Создать: $lang';
  }

  @override
  String get adminExamEdit => 'Редактирование вопроса экзамена';

  @override
  String get adminExamEmpty => 'Нет вопросов экзамена по этому фильтру.';

  @override
  String get adminExamErrApproveNoKey =>
      'Нельзя одобрить: у вопроса нет ключа ответа.';

  @override
  String get adminExamFixedOptions =>
      'В этой части варианты ответа фиксированы. Отметьте правильный.';

  @override
  String adminExamGroup(String id) {
    return 'Группа переводов: $id';
  }

  @override
  String get adminExamHasTranslation => 'Есть перевод';

  @override
  String get adminExamImage => 'Изображение';

  @override
  String get adminExamIssueColumns => 'Заполните обе колонки — А и Б.';

  @override
  String get adminExamIssueLanguage => 'Выберите язык (ru, ky или en).';

  @override
  String get adminExamIssueOptionDuplicate =>
      'Id вариантов не должны повторяться.';

  @override
  String adminExamIssueOptionsCount(int n) {
    return 'По структуре теста нужно $n вариантов.';
  }

  @override
  String get adminExamIssuePart => 'Выберите часть раздела.';

  @override
  String get adminExamIssuePassage => 'Для этой части нужен привязанный текст.';

  @override
  String get adminExamIssueSection => 'Выберите структуру теста и раздел.';

  @override
  String get adminExamIssueTopic => 'Укажите id темы.';

  @override
  String get adminExamKey => 'Ключ ответа (ученики не видят до завершения)';

  @override
  String get adminExamLink => 'Связать';

  @override
  String get adminExamLinkTitle => 'Связать с существующим переводом';

  @override
  String get adminExamLinked => 'Переводы связаны';

  @override
  String get adminExamMarkAiVerified => 'Отметить «Проверен ИИ»';

  @override
  String get adminExamNew => 'Новый вопрос экзамена';

  @override
  String get adminExamNewPassage => 'Новый текст';

  @override
  String adminExamNoBlueprint(String subject, String section) {
    return 'Ни один раздел структуры не совпадает с $subject/$section. Выберите структуру заново.';
  }

  @override
  String get adminExamNoGroup => 'Пока не связан с переводом.';

  @override
  String get adminExamNoImage => 'Изображения нет.';

  @override
  String get adminExamNoTable => 'Таблицы нет.';

  @override
  String get adminExamPartUnverified =>
      'Это деление на части — допущение (официально не опубликовано).';

  @override
  String get adminExamPassage => 'Привязанный текст';

  @override
  String get adminExamPassageEmpty => 'Текст пустой.';

  @override
  String get adminExamPassageText => 'Текст';

  @override
  String get adminExamPlacement => 'Место в тесте';

  @override
  String get adminExamQuestionId => 'Id вопроса';

  @override
  String get adminExamReject => 'Отклонить';

  @override
  String get adminExamRemoveTable => 'Удалить таблицу';

  @override
  String get adminExamReview => 'Проверка';

  @override
  String adminExamReviewDone(String status) {
    return 'Статус: $status';
  }

  @override
  String get adminExamReviewNoRights =>
      'Ваша роль не может менять статус проверки.';

  @override
  String get adminExamReviewNotes => 'Комментарий проверяющего';

  @override
  String adminExamReviewedBy(String uid, String date) {
    return '$uid · $date';
  }

  @override
  String get adminExamSaveBeforeReview =>
      'Сохраните изменения, прежде чем менять статус.';

  @override
  String get adminExamSavedBackToDraft =>
      'Сохранено. Содержание изменилось, поэтому вопрос возвращён в «Черновик» на проверку.';

  @override
  String get adminExamSolutionSteps => 'Шаги решения';

  @override
  String get adminExamSolutionStepsHelp => 'Один шаг на строку';

  @override
  String get adminExamSource => 'Источник';

  @override
  String get adminExamSourceAdapted => 'Адаптирован / переведён';

  @override
  String get adminExamSourceAi => 'ИИ';

  @override
  String get adminExamSourceAuthor => 'Автор';

  @override
  String get adminExamSourceBasis => 'Источник / основа';

  @override
  String get adminExamSourceKind => 'Происхождение';

  @override
  String get adminExamSourceOriginal => 'Оригинальный';

  @override
  String get adminExamStemLabel => 'Текст вопроса';

  @override
  String get adminExamTable => 'Таблица';

  @override
  String get adminExamTableAddColumn => 'Добавить столбец';

  @override
  String get adminExamTableAddRow => 'Добавить строку';

  @override
  String get adminExamTableCell => 'Ячейка';

  @override
  String get adminExamTableEmpty => 'Таблица пустая и не будет сохранена.';

  @override
  String get adminExamTableHeader => 'Заголовок';

  @override
  String get adminExamTableHeaderShort => 'Заг.';

  @override
  String get adminExamTableHelp =>
      'Строка заголовков и строки таблицы; в ячейках можно Markdown и LaTeX (\$...\$). В заданиях на сравнение первая строка содержит величины А и Б.';

  @override
  String get adminExamTablePreview => 'Предпросмотр';

  @override
  String get adminExamTableRemoveColumn => 'Удалить столбец';

  @override
  String get adminExamTableRemoveRow => 'Удалить строку';

  @override
  String get adminExamTranslations => 'Переводы';

  @override
  String adminExamWrongNote(String id) {
    return 'Почему $id неверно';
  }

  @override
  String get adminExport => 'Экспорт';

  @override
  String get adminExportCopied => 'Скопировано в буфер обмена';

  @override
  String get adminExportCopy => 'Копировать';

  @override
  String get adminExportHelp =>
      'Выгружаются вопросы текущего фильтра (до 5000). Даты записываются в формате ISO.';

  @override
  String get adminExportSave => 'Сохранить файл';

  @override
  String get adminExportSaved => 'Файл сохранён';

  @override
  String get adminExportTitle => 'Экспорт вопросов';

  @override
  String get adminFieldBlueprint => 'Структура теста';

  @override
  String get adminFieldDescription => 'Описание';

  @override
  String get adminFieldDifficulty => 'Сложность';

  @override
  String get adminFieldExplanation => 'Объяснение';

  @override
  String get adminFieldHint => 'Подсказка';

  @override
  String get adminFieldImageUrl => 'URL изображения';

  @override
  String get adminFieldLanguage => 'Язык';

  @override
  String get adminFieldOptions => 'Варианты ответа';

  @override
  String get adminFieldOrder => 'Порядок';

  @override
  String get adminFieldPart => 'Часть';

  @override
  String get adminFieldPoints => 'Баллы';

  @override
  String get adminFieldReview => 'Проверка';

  @override
  String get adminFieldSection => 'Раздел';

  @override
  String get adminFieldStatus => 'Статус';

  @override
  String get adminFieldStem => 'Текст вопроса';

  @override
  String get adminFieldSubject => 'Предмет';

  @override
  String get adminFieldSubtopicId => 'Id подтемы (необязательно)';

  @override
  String get adminFieldTags => 'Теги';

  @override
  String get adminFieldTagsHelp => 'Через запятую';

  @override
  String get adminFieldTitle => 'Название';

  @override
  String get adminFieldTopic => 'Тема';

  @override
  String get adminFieldTopicId => 'Id темы';

  @override
  String get adminFieldTopicIdHelp => 'Например, math.quadratic_equations';

  @override
  String get adminFieldType => 'Тип';

  @override
  String get adminForbiddenBody =>
      'Ваша роль не позволяет открыть этот раздел.';

  @override
  String get adminForbiddenTitle => 'Нет доступа';

  @override
  String get adminHidden => 'Скрыт';

  @override
  String get adminImport => 'Импорт';

  @override
  String get adminImportDuplicateId => 'Повторяющийся id в файле.';

  @override
  String get adminImportEmpty => 'В файле нет строк с данными.';

  @override
  String adminImportFailedAfter(int done, String error) {
    return 'Остановлено после $done строк: $error';
  }

  @override
  String adminImportHelp(int batch) {
    return 'Строки проверяются до записи; корректные записываются пакетами по $batch. Колонки CSV (разделитель , ; или табуляция):';
  }

  @override
  String get adminImportParseError => 'Не удалось прочитать файл.';

  @override
  String get adminImportPick => 'Выбрать файл';

  @override
  String adminImportProgress(int done, int total) {
    return 'Записано $done из $total';
  }

  @override
  String adminImportRowIssue(int row, String issue) {
    return 'Строка $row: $issue';
  }

  @override
  String adminImportRun(int count) {
    return 'Импортировать $count';
  }

  @override
  String adminImportSummary(int total, int valid, int invalid) {
    return 'Строк: $total · корректных: $valid · с ошибками: $invalid';
  }

  @override
  String get adminImportTitle => 'Импорт вопросов (CSV или JSON)';

  @override
  String get adminInactive => 'Неактивен';

  @override
  String get adminIssueCorrectNotInOptions =>
      'Правильного ответа нет среди вариантов.';

  @override
  String get adminIssueCorrectRequired => 'Отметьте правильный ответ.';

  @override
  String get adminIssueDifficulty => 'Сложность — от 1 до 3.';

  @override
  String get adminIssueOptionEmpty => 'У каждого варианта должен быть текст.';

  @override
  String get adminIssueStem => 'Введите текст вопроса.';

  @override
  String get adminLangEn => 'Английский';

  @override
  String get adminLangKy => 'Кыргызский';

  @override
  String get adminLangRu => 'Русский';

  @override
  String get adminLessonAddExample => 'Добавить пример';

  @override
  String get adminLessonAddFormula => 'Добавить формулу';

  @override
  String get adminLessonAddMistake => 'Добавить ошибку';

  @override
  String get adminLessonAddSection => 'Добавить раздел';

  @override
  String get adminLessonBasics => 'Основное';

  @override
  String get adminLessonCaption => 'Подпись';

  @override
  String get adminLessonExamples => 'Разобранные примеры';

  @override
  String get adminLessonFormulas => 'Формулы';

  @override
  String get adminLessonImages => 'Изображения';

  @override
  String get adminLessonIssueContent =>
      'Добавьте краткое содержание или хотя бы один раздел.';

  @override
  String get adminLessonIssueMinutes => 'Длительность — от 1 до 240 минут.';

  @override
  String get adminLessonIssueOrder => 'Порядок — от 0 до 10000.';

  @override
  String get adminLessonIssueSubject => 'Выберите предмет.';

  @override
  String get adminLessonIssueUrl =>
      'Видео/PDF — ссылка http(s) или загруженный файл.';

  @override
  String get adminLessonLatex => 'LaTeX';

  @override
  String get adminLessonMinutes => 'Минут';

  @override
  String get adminLessonMistake => 'Ошибка';

  @override
  String get adminLessonMistakes => 'Типичные ошибки';

  @override
  String get adminLessonNoImages => 'Изображений нет.';

  @override
  String get adminLessonPdf => 'PDF';

  @override
  String get adminLessonPdfHelp => 'Ссылка или загруженный файл (до 20 МБ)';

  @override
  String get adminLessonPracticeAndMedia => 'Практика и материалы';

  @override
  String get adminLessonPracticeIds => 'Id вопросов практики';

  @override
  String get adminLessonPracticeIdsHelp =>
      'Id из коллекции «questions» через запятую';

  @override
  String get adminLessonProblem => 'Условие';

  @override
  String get adminLessonPublishedHelp =>
      'Неопубликованные уроки скрыты от учеников.';

  @override
  String get adminLessonSectionBody => 'Текст (Markdown, LaTeX в \$…\$)';

  @override
  String get adminLessonSectionTitle => 'Заголовок раздела';

  @override
  String get adminLessonSections => 'Разделы урока';

  @override
  String get adminLessonSolution => 'Решение';

  @override
  String get adminLessonSummary => 'Кратко';

  @override
  String get adminLessonTitleSummary => 'Название и краткое содержание';

  @override
  String get adminLessonVideoUrl => 'URL видео';

  @override
  String get adminLessonsDeleteBody =>
      'Ученики больше не увидят урок. Чтобы скрыть его временно, лучше выключите «Опубликован».';

  @override
  String get adminLessonsDeleteTitle => 'Удалить урок?';

  @override
  String get adminLessonsEdit => 'Редактирование урока';

  @override
  String get adminLessonsEmpty => 'У этого предмета нет уроков.';

  @override
  String get adminLessonsLegacy => 'Старый формат';

  @override
  String adminLessonsMeta(int order, int minutes) {
    return '№$order · $minutes мин';
  }

  @override
  String get adminLessonsNew => 'Новый урок';

  @override
  String get adminLessonsNoSubjects => 'Сначала создайте предмет.';

  @override
  String adminListEnd(int count) {
    return 'Показано: $count';
  }

  @override
  String get adminListNoItems => 'Пока ничего не добавлено.';

  @override
  String get adminLoadMore => 'Загрузить ещё';

  @override
  String get adminLoginBackToApp => 'Вернуться в приложение';

  @override
  String get adminLoginContinue => 'Продолжить';

  @override
  String get adminLoginEmail => 'Email';

  @override
  String get adminLoginEmailInvalid => 'Введите корректный email';

  @override
  String get adminLoginErrCredentials => 'Неверный email или пароль.';

  @override
  String get adminLoginErrDisabled => 'Аккаунт отключён.';

  @override
  String get adminLoginErrNotAdmin =>
      'У этого аккаунта нет роли администратора.';

  @override
  String get adminLoginErrTooMany => 'Слишком много попыток. Повторите позже.';

  @override
  String get adminLoginForgot => 'Забыли пароль?';

  @override
  String get adminLoginHidePassword => 'Скрыть пароль';

  @override
  String get adminLoginOtherAccount => 'Войти в другой аккаунт';

  @override
  String get adminLoginPassword => 'Пароль';

  @override
  String get adminLoginPasswordRequired => 'Введите пароль';

  @override
  String get adminLoginResetSend => 'Отправить ссылку';

  @override
  String get adminLoginResetSent =>
      'Если аккаунт существует, ссылка для сброса отправлена.';

  @override
  String get adminLoginResetTitle => 'Сброс пароля';

  @override
  String get adminLoginShowPassword => 'Показать пароль';

  @override
  String adminLoginSignedInAs(String email) {
    return 'Вы вошли как $email';
  }

  @override
  String get adminLoginSubmit => 'Войти';

  @override
  String get adminLoginSubtitle => 'Только для сотрудников ORT Master.';

  @override
  String get adminLoginTitle => 'Админ-панель';

  @override
  String get adminLogout => 'Выйти';

  @override
  String adminLogsActor(String uid) {
    return 'кто: $uid';
  }

  @override
  String get adminLogsEmpty => 'Журнал пуст.';

  @override
  String adminLogsTarget(String uid) {
    return 'кому: $uid';
  }

  @override
  String get adminMarkCorrect => 'Отметить правильным';

  @override
  String get adminMathHelp => 'Markdown; формулы в \$…\$ или \$\$…\$\$';

  @override
  String adminMissingTranslation(String lang) {
    return 'Нет $lang';
  }

  @override
  String get adminMore => 'Ещё';

  @override
  String get adminMoveDown => 'Ниже';

  @override
  String get adminMoveUp => 'Выше';

  @override
  String get adminNavAiDrafts => 'Черновики ИИ';

  @override
  String get adminNavDashboard => 'Обзор';

  @override
  String get adminNavExamBank => 'Банк экзамена';

  @override
  String get adminNavLessons => 'Уроки';

  @override
  String get adminNavLogs => 'Журнал действий';

  @override
  String get adminNavPayments => 'Платежи';

  @override
  String get adminNavPractice => 'Вопросы практики';

  @override
  String get adminNavPricing => 'Тарифы';

  @override
  String get adminNavSubjects => 'Предметы и темы';

  @override
  String get adminNavUsers => 'Пользователи';

  @override
  String get adminNavVariants => 'Варианты экзамена';

  @override
  String get adminNo => 'нет';

  @override
  String get adminNone => 'Не задано';

  @override
  String adminOptionN(String id) {
    return 'Вариант $id';
  }

  @override
  String get adminOptionText => 'Текст';

  @override
  String adminPaymentsCredits(int n) {
    return 'кредитов: $n';
  }

  @override
  String get adminPaymentsEmpty => 'Покупок нет.';

  @override
  String get adminPaymentsReadOnly =>
      'Только просмотр. Кредиты начисляет сервер после проверки в Google Play.';

  @override
  String get adminPaymentsRefund => 'Возврат';

  @override
  String get adminPracticeDeleteBody =>
      'Вопрос будет удалён из практики. Чтобы скрыть его, лучше сделайте его неактивным.';

  @override
  String get adminPracticeDeleteTitle => 'Удалить вопрос?';

  @override
  String get adminPracticeEdit => 'Редактирование вопроса';

  @override
  String get adminPracticeEmpty => 'Нет вопросов по этому фильтру.';

  @override
  String get adminPracticeIssueOptionsMin => 'Нужно минимум два варианта.';

  @override
  String get adminPracticeIssueSubject => 'Укажите предмет.';

  @override
  String get adminPracticeIssueType => 'Неизвестный тип';

  @override
  String get adminPracticeNew => 'Новый вопрос';

  @override
  String get adminPricingConfirmBody =>
      'Изменения сразу применяются к новым покупкам.';

  @override
  String get adminPricingConfirmTitle => 'Сохранить тарифы?';

  @override
  String adminPricingCreditsFor(String id) {
    return '$id — кредитов';
  }

  @override
  String get adminPricingDefaults =>
      'config/pricing ещё не создан; показаны значения по умолчанию.';

  @override
  String get adminPricingFree => 'Бесплатные тесты';

  @override
  String get adminPricingFreeHelp =>
      'Правило продукта: 1 (первый полный тест бесплатен один раз на аккаунт)';

  @override
  String get adminPricingFreeLabel => 'Бесплатных полных тестов на аккаунт';

  @override
  String get adminPricingIssueCredits => 'Кредитов за продукт — от 1 до 100.';

  @override
  String adminPricingIssueFree(int min, int max) {
    return 'Бесплатных тестов на пользователя — от $min до $max.';
  }

  @override
  String get adminPricingIssueProduct => 'Неизвестный id продукта.';

  @override
  String get adminPricingIssueSingle =>
      'exam_single должен давать ровно 1 кредит.';

  @override
  String get adminPricingProducts => 'Кредиты за продукт';

  @override
  String get adminPricingSingleHelp => 'Фиксировано: 1 кредит = 1 тест';

  @override
  String get adminPricingWarning =>
      'Цены задаются в Google Play Console, а не здесь. На этой странице — только соответствие продуктов и кредитов. Базовую цену 100 сом (exam_single) нельзя менять без согласия владельца.';

  @override
  String get adminPublished => 'Опубликован';

  @override
  String get adminPurchaseGranted => 'Зачислена';

  @override
  String get adminPurchaseInvalid => 'Недействительна';

  @override
  String get adminPurchasePending => 'Ожидает';

  @override
  String get adminPurchaseRefunded => 'Возврат';

  @override
  String get adminPurchaseRevoked => 'Отозвана';

  @override
  String get adminQuestionExtra => 'Дополнительно';

  @override
  String get adminQuestionMeta => 'Классификация';

  @override
  String get adminReason => 'Причина';

  @override
  String get adminReasonRequired => 'Укажите причину (не менее 3 символов).';

  @override
  String get adminRemove => 'Удалить';

  @override
  String get adminRetry => 'Повторить';

  @override
  String get adminReviewAiVerified => 'Проверен ИИ';

  @override
  String get adminReviewApproved => 'Одобрен';

  @override
  String get adminReviewDraft => 'Черновик';

  @override
  String get adminReviewRejected => 'Отклонён';

  @override
  String get adminRoleContentManager => 'Контент-менеджер';

  @override
  String get adminRoleMethodologist => 'Методист';

  @override
  String get adminRoleModerator => 'Модератор';

  @override
  String get adminRoleSuperAdmin => 'Суперадмин';

  @override
  String get adminRoleSupport => 'Поддержка';

  @override
  String get adminSave => 'Сохранить';

  @override
  String get adminSaved => 'Сохранено';

  @override
  String get adminSessionExpiredBody => 'Войдите снова, чтобы продолжить.';

  @override
  String get adminSessionExpiredTitle => 'Сессия администратора завершена';

  @override
  String get adminSignInAgain => 'Войти';

  @override
  String get adminStatApproved => 'Одобрено';

  @override
  String get adminStatExam => 'Вопросы экзамена';

  @override
  String get adminStatLessons => 'Уроки';

  @override
  String get adminStatPendingReview => 'Ждут проверки';

  @override
  String get adminStatPractice => 'Вопросы практики';

  @override
  String get adminStatPurchases => 'Зачисленные покупки';

  @override
  String get adminStatSubjects => 'Предметы';

  @override
  String get adminStatUsers => 'Пользователи';

  @override
  String get adminStatVariants => 'Опубликованные варианты';

  @override
  String get adminSubjectsActiveHelp =>
      'Неактивный предмет остаётся в базе (мягкое удаление).';

  @override
  String get adminSubjectsAddTopic => 'Добавить тему';

  @override
  String get adminSubjectsColor => 'Цвет (#RRGGBB)';

  @override
  String get adminSubjectsColorInvalid => 'Формат #RRGGBB';

  @override
  String adminSubjectsDeleteBody(String id) {
    return 'Предмет $id будет удалён, только если его не используют уроки и вопросы. Иначе деактивируйте его.';
  }

  @override
  String get adminSubjectsDeleteTitle => 'Удалить предмет?';

  @override
  String get adminSubjectsEdit => 'Редактирование предмета';

  @override
  String get adminSubjectsEmpty => 'Предметов пока нет.';

  @override
  String get adminSubjectsErrExists => 'Предмет с таким id уже существует.';

  @override
  String adminSubjectsErrInUse(int lessons, int questions, int exam) {
    return 'Предмет ещё используется: уроков $lessons, вопросов практики $questions, экзаменационных вопросов $exam. Вместо удаления деактивируйте его.';
  }

  @override
  String get adminSubjectsIcon => 'Иконка';

  @override
  String get adminSubjectsId => 'Id предмета';

  @override
  String get adminSubjectsIdHelp =>
      'Латиница, цифры и _; потом изменить нельзя';

  @override
  String get adminSubjectsIdInvalid =>
      '2–41 символ: a–z, 0–9, _ (начинается с буквы)';

  @override
  String get adminSubjectsNew => 'Новый предмет';

  @override
  String adminSubjectsTopicDuplicate(String id) {
    return 'Повторяющийся id темы: $id';
  }

  @override
  String get adminSubjectsTopicId => 'Id темы';

  @override
  String adminSubjectsTopicIdInvalid(String id) {
    return 'Некорректный id темы: $id (a–z, 0–9, _ и точки)';
  }

  @override
  String adminSubjectsTopicN(int n) {
    return 'Тема $n';
  }

  @override
  String get adminSubjectsTopics => 'Темы';

  @override
  String adminSubjectsTopicsCount(int count) {
    return 'тем: $count';
  }

  @override
  String get adminSubjectsTopicsHelp =>
      'Id темы имеет вид предмет.тема (например, math.quadratic_equations) и используется в вопросах экзамена.';

  @override
  String get adminTitleRequired =>
      'Введите название на русском или кыргызском.';

  @override
  String get adminTypeAnalogy => 'Аналогия';

  @override
  String get adminTypeComparison => 'Сравнение величин';

  @override
  String get adminTypeCompletion => 'Дополнение предложения';

  @override
  String get adminTypeMatching => 'Соответствие';

  @override
  String get adminTypeMultiple => 'Несколько ответов';

  @override
  String get adminTypeOrdering => 'Порядок';

  @override
  String get adminTypeSingle => 'Один ответ';

  @override
  String get adminTypeTextBased => 'Работа с текстом';

  @override
  String get adminTypeTrueFalse => 'Верно / неверно';

  @override
  String get adminUnsavedBody => 'Есть несохранённые изменения.';

  @override
  String get adminUnsavedTitle => 'Отменить изменения?';

  @override
  String get adminUpdated => 'Обновлено';

  @override
  String get adminUploadImage => 'Загрузить изображение';

  @override
  String get adminUploadPdf => 'Загрузить PDF';

  @override
  String get adminUploaded => 'Загружено';

  @override
  String get adminUserActions => 'Действия';

  @override
  String adminUserBalance(int n) {
    return 'баланс $n';
  }

  @override
  String get adminUserBan => 'Заблокировать';

  @override
  String get adminUserBanTitle => 'Заблокировать пользователя?';

  @override
  String get adminUserCreated => 'Регистрация';

  @override
  String get adminUserCredits => 'Кредиты';

  @override
  String get adminUserEntitlements => 'Доступ к экзаменам';

  @override
  String get adminUserFreeUsed => 'Бесплатный тест использован';

  @override
  String get adminUserGrade => 'Класс';

  @override
  String get adminUserGrant => 'Начислить';

  @override
  String get adminUserGrantDelta => 'Кредиты';

  @override
  String get adminUserGrantDeltaHelp =>
      '1 кредит = 1 тест; отрицательное число — списание';

  @override
  String get adminUserGrantDeltaInvalid =>
      'Введите ненулевое число от -100 до 100.';

  @override
  String get adminUserGrantDone => 'Кредиты обновлены';

  @override
  String get adminUserGrantTitle => 'Начислить кредиты';

  @override
  String get adminUserLanguage => 'Язык';

  @override
  String get adminUserLastActive => 'Последняя активность';

  @override
  String get adminUserLedger => 'История кредитов';

  @override
  String get adminUserLifetime => 'Куплено кредитов';

  @override
  String get adminUserNoEntitlements =>
      'Записи о доступе пока нет (первый тест не использован).';

  @override
  String get adminUserPremiumOff => 'Снять премиум';

  @override
  String get adminUserPremiumOffBody => 'Подписка вернётся к бесплатной.';

  @override
  String get adminUserPremiumOffTitle => 'Снять премиум?';

  @override
  String get adminUserPremiumOn => 'Выдать премиум';

  @override
  String get adminUserPremiumOnBody =>
      'Подписка станет годовой на 365 дней. Кредиты на экзамены выдаются отдельно.';

  @override
  String get adminUserPremiumOnTitle => 'Выдать премиум?';

  @override
  String get adminUserRole => 'Роль';

  @override
  String get adminUserRoleBody =>
      'Роль задаётся на сервере. Чтобы она применилась, пользователь должен войти заново.';

  @override
  String get adminUserRoleDone => 'Роль обновлена';

  @override
  String get adminUserRoleNone => 'Без роли администратора';

  @override
  String get adminUserRoleTitle => 'Роль администратора';

  @override
  String get adminUserSchool => 'Школа';

  @override
  String get adminUserStats => 'Прогресс';

  @override
  String get adminUserSubscription => 'Подписка';

  @override
  String get adminUserTitle => 'Пользователь';

  @override
  String get adminUserUnban => 'Разблокировать';

  @override
  String get adminUserUnbanBody => 'Отметка о блокировке будет снята.';

  @override
  String get adminUserUnbanTitle => 'Разблокировать пользователя?';

  @override
  String get adminUsersBanned => 'Заблокирован';

  @override
  String get adminUsersEmpty => 'Пользователи не найдены.';

  @override
  String get adminUsersLegacyAdmin => 'admin (старое поле)';

  @override
  String get adminUsersPremium => 'Премиум';

  @override
  String get adminUsersSearch => 'Поиск по началу email';

  @override
  String get adminVariantAddIds => 'Добавить id вопросов';

  @override
  String get adminVariantAddIdsHelp =>
      'Id через пробел, запятую или с новой строки';

  @override
  String get adminVariantAdvanced => 'Повышенный';

  @override
  String get adminVariantArchived => 'В архиве';

  @override
  String get adminVariantAutoFill => 'Заполнить одобренными';

  @override
  String adminVariantAutoFilled(int n) {
    return 'Добавлено одобренных вопросов: $n';
  }

  @override
  String get adminVariantBasics => 'Вариант';

  @override
  String adminVariantBlocked(int n) {
    return 'Публикация заблокирована: замечаний $n.';
  }

  @override
  String get adminVariantBlueprintLocked =>
      'Чтобы сменить структуру, удалите все вопросы.';

  @override
  String get adminVariantCheck => 'Проверка по структуре';

  @override
  String get adminVariantChooseBlueprint => 'Выберите структуру теста.';

  @override
  String get adminVariantClear => 'Очистить';

  @override
  String get adminVariantDifficulty => 'Уровень';

  @override
  String get adminVariantDraft => 'Черновик';

  @override
  String get adminVariantInReview => 'На проверке';

  @override
  String adminVariantN(int n) {
    return 'Вариант $n';
  }

  @override
  String get adminVariantNoKey => 'нет ключа';

  @override
  String get adminVariantNoProblems => 'Замечаний нет.';

  @override
  String get adminVariantNumber => 'Номер';

  @override
  String get adminVariantNumberInvalid => 'Номер варианта — от 1 до 1000.';

  @override
  String get adminVariantPublish => 'Опубликовать';

  @override
  String get adminVariantPublishBody =>
      'Сервер ещё раз проверит вариант. Ученики смогут начать его сразу после публикации.';

  @override
  String get adminVariantPublishTitle => 'Опубликовать вариант?';

  @override
  String get adminVariantPublished => 'Опубликован';

  @override
  String get adminVariantReadOnly =>
      'Только просмотр: создавать и редактировать варианты могут только супер-админ и контент-менеджер.';

  @override
  String get adminVariantReady =>
      'Готов к публикации (сервер проверит ещё раз).';

  @override
  String get adminVariantRecheck => 'Проверить заново';

  @override
  String adminVariantResync(int version) {
    return 'Перевести на версию структуры $version';
  }

  @override
  String adminVariantResyncDone(int version) {
    return 'Вариант переведён на версию структуры $version. Сохраните, чтобы применить.';
  }

  @override
  String get adminVariantResyncHelp =>
      'Сервер публикует только варианты, собранные по текущей версии структуры. Перевод сохраняет все вопросы; затем сохраните вариант и проверьте отчёт.';

  @override
  String adminVariantServerResult(String status) {
    return 'Ответ сервера: $status';
  }

  @override
  String get adminVariantStandard => 'Стандартный';

  @override
  String get adminVariantUnknownQuestion => 'не найден';

  @override
  String get adminVariantUnpublish => 'Снять с публикации';

  @override
  String get adminVariantUnpublishBody =>
      'Новые попытки станут недоступны. Уже начатые попытки можно будет завершить.';

  @override
  String get adminVariantUnpublishTitle => 'Снять вариант с публикации?';

  @override
  String get adminVariantsEdit => 'Вариант';

  @override
  String get adminVariantsEmpty => 'Нет вариантов по этому фильтру.';

  @override
  String get adminVariantsErrPublished =>
      'Вариант опубликован. Снимите его с публикации перед редактированием.';

  @override
  String adminVariantsMeta(String blueprint, int count, int expected) {
    return '$blueprint · вопросов $count/$expected';
  }

  @override
  String get adminVariantsNew => 'Новый вариант';

  @override
  String adminVpBlueprintVersion(int expected, int actual) {
    return 'Собран по версии структуры $actual, текущая — $expected.';
  }

  @override
  String get adminVpLanguage => 'Этот язык не предусмотрен структурой теста.';

  @override
  String adminVpPartCount(String part, int expected, int actual) {
    return 'Часть $part: вопросов $actual, нужно $expected.';
  }

  @override
  String adminVpPartUnknown(String id) {
    return '$id: часть не определена (укажите часть в вопросе).';
  }

  @override
  String adminVpQuestionDuplicate(String id) {
    return '$id: используется повторно.';
  }

  @override
  String adminVpQuestionLanguage(String id) {
    return '$id: другой язык.';
  }

  @override
  String adminVpQuestionMissing(String id) {
    return '$id: вопрос не найден.';
  }

  @override
  String adminVpQuestionNoKey(String id) {
    return '$id: нет ключа ответа.';
  }

  @override
  String adminVpQuestionNotApproved(String id) {
    return '$id: не одобрен методистом.';
  }

  @override
  String adminVpQuestionOptions(String id, int expected, int actual) {
    return '$id: вариантов $actual, нужно $expected.';
  }

  @override
  String adminVpQuestionPart(String id) {
    return '$id: его части нет в этом разделе.';
  }

  @override
  String adminVpQuestionPassage(String id) {
    return '$id: нужен привязанный текст.';
  }

  @override
  String adminVpQuestionSection(String id, String section) {
    return '$id: относится не к разделу $section.';
  }

  @override
  String adminVpSectionCount(String section, int expected, int actual) {
    return '$section: вопросов $actual, нужно $expected.';
  }

  @override
  String adminVpSectionMissing(String section) {
    return 'Раздел $section пуст.';
  }

  @override
  String get adminVpSectionOrder => 'Разделы идут не в порядке структуры.';

  @override
  String adminVpSectionUnknown(String section) {
    return 'Раздела $section нет в структуре.';
  }

  @override
  String get adminYes => 'да';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get analytics => 'Аналитика';

  @override
  String get appName => 'ОРТ Мастер КГ';

  @override
  String get appVersion => 'Версия приложения';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get averageScore => 'Средний балл';

  @override
  String billingBalanceAfter(int balance) {
    return 'Баланс: $balance';
  }

  @override
  String get billingBalanceError => 'Не удалось загрузить баланс.';

  @override
  String get billingBalanceTitle => 'Ваш баланс';

  @override
  String billingBuySemantics(String title, String price) {
    return 'Купить: $title, $price';
  }

  @override
  String get billingCreditHistoryTitle => 'История кредитов';

  @override
  String get billingCreditRule => '1 кредит = 1 полный пробный экзамен';

  @override
  String billingCreditsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кредита',
      many: '$count кредитов',
      few: '$count кредита',
      one: '$count кредит',
    );
    return '$_temp0';
  }

  @override
  String get billingErrorAccountMismatch =>
      'Эта покупка привязана к другому аккаунту приложения. Войдите в него, чтобы её использовать.';

  @override
  String get billingErrorAlreadyOwned =>
      'Предыдущая покупка ещё обрабатывается. Мы проверяем её.';

  @override
  String get billingErrorInvalid =>
      'Покупку не удалось проверить. Если деньги списались, Google Play автоматически вернёт их в течение 3 дней.';

  @override
  String get billingErrorLaunch =>
      'Не удалось начать покупку. Попробуйте ещё раз.';

  @override
  String get billingErrorNotSignedIn =>
      'Войдите в аккаунт, чтобы купить тесты.';

  @override
  String get billingErrorProductUnavailable =>
      'Это предложение больше недоступно.';

  @override
  String get billingErrorStore =>
      'Google Play сообщил об ошибке. Попробуйте ещё раз.';

  @override
  String get billingErrorStoreUnavailable =>
      'Google Play сейчас недоступен. Попробуйте позже.';

  @override
  String get billingErrorVerifyDeferred =>
      'Пока не удалось подтвердить покупку. Мы повторим попытку автоматически — оплата не потеряется.';

  @override
  String get billingExternalInfo =>
      'Кредиты на вашем аккаунте отображаются здесь.';

  @override
  String get billingExternalNote => 'Баланс обновляется автоматически.';

  @override
  String get billingFreeExamAvailable =>
      'Первый полный пробный экзамен — бесплатно';

  @override
  String get billingFreeExamUsed =>
      'Бесплатный пробный экзамен уже использован';

  @override
  String billingFreeExamsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count бесплатного пробного экзамена',
      many: 'Осталось $count бесплатных пробных экзаменов',
      few: 'Осталось $count бесплатных пробных экзамена',
      one: 'Остался $count бесплатный пробный экзамен',
    );
    return '$_temp0';
  }

  @override
  String get billingHistoryError => 'Не удалось загрузить историю.';

  @override
  String get billingHistoryTooltip => 'История покупок';

  @override
  String get billingHonestNoGuarantee =>
      'Пробные экзамены помогают тренироваться, но не гарантируют результат на ОРТ.';

  @override
  String get billingHonestPayment => 'Оплата проходит через Google Play.';

  @override
  String get billingHonestServer =>
      'Кредиты зачисляются только после того, как наш сервер подтвердит покупку.';

  @override
  String get billingLedgerEmpty => 'Изменений баланса пока нет.';

  @override
  String get billingLoadMore => 'Загрузить ещё';

  @override
  String get billingLoadingProducts => 'Загружаем предложения…';

  @override
  String billingOrderId(String id) {
    return 'Заказ $id';
  }

  @override
  String billingProductSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count полного пробного экзамена',
      many: '$count полных пробных экзаменов',
      few: '$count полных пробных экзамена',
      one: '$count полный пробный экзамен',
    );
    return '$_temp0';
  }

  @override
  String billingProductTests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count теста',
      many: '$count тестов',
      few: '$count теста',
      one: '$count тест',
    );
    return '$_temp0';
  }

  @override
  String get billingProductsEmpty =>
      'Предложения временно недоступны. Попробуйте позже.';

  @override
  String get billingProductsError =>
      'Не удалось загрузить предложения из Google Play.';

  @override
  String get billingProductsTitle => 'Купить пробные экзамены';

  @override
  String get billingPurchasesEmpty => 'Покупок пока нет.';

  @override
  String get billingReasonAdminGrant => 'Начислено поддержкой';

  @override
  String get billingReasonCreditsAdded => 'Кредиты зачислены';

  @override
  String get billingReasonExamStart => 'Начат пробный экзамен';

  @override
  String get billingReasonFreeFirst => 'Бесплатный первый экзамен';

  @override
  String get billingReasonOther => 'Изменение баланса';

  @override
  String get billingReasonPurchase => 'Покупка';

  @override
  String get billingReasonRefund => 'Возврат';

  @override
  String get billingRestore => 'Восстановить покупки';

  @override
  String get billingRestoreDone =>
      'Проверка завершена. Баланс обновится автоматически.';

  @override
  String get billingRestoreStarted => 'Проверяем незавершённые покупки…';

  @override
  String get billingRetry => 'Повторить';

  @override
  String get billingSignInRequired =>
      'Войдите в аккаунт, чтобы увидеть баланс и историю.';

  @override
  String get billingStateGranted => 'Зачислено';

  @override
  String get billingStateInvalid => 'Не подтверждено';

  @override
  String get billingStatePending => 'Ожидает оплаты';

  @override
  String get billingStateRefunded => 'Возврат';

  @override
  String get billingStateRevoked => 'Отозвано';

  @override
  String get billingStatusCanceled => 'Покупка отменена.';

  @override
  String get billingStatusGranted => 'Покупка подтверждена, кредиты зачислены.';

  @override
  String get billingStatusLaunching => 'Открываем Google Play…';

  @override
  String get billingStatusPending =>
      'Ожидает оплаты. Кредиты будут зачислены, когда Google Play подтвердит оплату.';

  @override
  String get billingStatusVerifying => 'Подтверждаем покупку…';

  @override
  String get billingStoreTitle => 'Доступ к тестам';

  @override
  String get billingTabLedger => 'Движение кредитов';

  @override
  String get billingTabPurchases => 'Покупки';

  @override
  String get billingTransactionsTitle => 'История покупок';

  @override
  String get billingUnavailableBody =>
      'Оплата через Google Play недоступна на этом устройстве. Убедитесь, что Google Play установлен и вы вошли в аккаунт.';

  @override
  String get billingUnavailableTitle => 'Покупки недоступны';

  @override
  String get billingUnsupportedPlatformBody =>
      'Тесты можно купить в Android-приложении через Google Play. Баланс одинаковый на всех устройствах.';

  @override
  String get billingUnsupportedPlatformTitle => 'Покупки здесь недоступны';

  @override
  String get biology => 'Биология';

  @override
  String get buyTest => 'Купить тест';

  @override
  String get cancel => 'Отмена';

  @override
  String get cardPayment => 'Оплата картой';

  @override
  String get chemistry => 'Химия';

  @override
  String get clear => 'Очистить';

  @override
  String get clearCache => 'Очистить кэш';

  @override
  String get clearCacheConfirmation => 'Очистить кэш?';

  @override
  String get clearCacheDesc => 'Освободить место';

  @override
  String get clearCacheMessage =>
      'Это удалит все загруженные материалы. Вы сможете загрузить их снова при подключении к интернету.';

  @override
  String get community => 'Сообщество';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get continueTest => 'Продолжить тест';

  @override
  String get correct => 'Правильно';

  @override
  String get currentPlan => 'Текущий план';

  @override
  String get dailyGoal => 'Дневная цель';

  @override
  String get dark => 'Тёмная';

  @override
  String get darkMode => 'Темная тема';

  @override
  String get dashboard => 'Главная';

  @override
  String get dataAndStorage => 'Данные и хранилище';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get done => 'Готово';

  @override
  String get dontHaveAccount => 'Нет аккаунта?';

  @override
  String get downloadedContent => 'Загруженные материалы';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get email => 'Электронная почта';

  @override
  String get emailNotifications => 'Email-уведомления';

  @override
  String get emailNotificationsDesc => 'Новости и обновления';

  @override
  String get english => 'Английский';

  @override
  String get error => 'Ошибка';

  @override
  String examAnsweredOf(int answered, int total) {
    return 'Отвечено $answered из $total';
  }

  @override
  String get examAutoSubmitted => 'Время вышло. Раздел отправлен.';

  @override
  String get examBuy => 'Купить';

  @override
  String get examBuyToStart => 'Купить тест';

  @override
  String get examCatalogEmpty => 'Экзамены пока недоступны.';

  @override
  String get examCatalogIntro =>
      'Полные пробные экзамены в формате и по времени ОРТ.';

  @override
  String get examCatalogMainTitle => 'Основной тест';

  @override
  String get examCatalogStateLanguageTitle => 'Государственный язык';

  @override
  String get examCatalogSubjectsTitle => 'Предметные тесты';

  @override
  String get examClearAnswer => 'Сбросить ответ';

  @override
  String get examColumnA => 'Колонка А';

  @override
  String get examColumnB => 'Колонка Б';

  @override
  String get examContinue => 'Продолжить';

  @override
  String examCostCredit(int credits) {
    return '1 кредит (у вас $credits)';
  }

  @override
  String get examCostFree => 'Бесплатно — это ваш первый тест';

  @override
  String get examCostNeedCredit => 'Чтобы начать тест, нужен 1 кредит.';

  @override
  String get examCostResume => 'Бесплатно — вы продолжаете свою попытку';

  @override
  String get examDisclaimerFallback =>
      'Учебный результат. Не является официальным баллом ОРТ.';

  @override
  String examEntitlementCredits(int count) {
    return 'Кредитов: $count';
  }

  @override
  String get examEntitlementFree => 'Первый тест бесплатно';

  @override
  String examEntitlementFreeLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Осталось $count бесплатного теста',
      many: 'Осталось $count бесплатных тестов',
      few: 'Осталось $count бесплатных теста',
      one: 'Остался $count бесплатный тест',
    );
    return '$_temp0';
  }

  @override
  String get examEntitlementHint =>
      'Один кредит — один полный тест. Продолжение незавершённого теста бесплатно.';

  @override
  String get examEntitlementNone => 'Кредитов нет';

  @override
  String get examErrorAttemptNotFound => 'Попытка не найдена.';

  @override
  String get examErrorBanned =>
      'Ваш аккаунт заблокирован модератором, поэтому тесты недоступны. Если это ошибка, напишите в поддержку.';

  @override
  String get examErrorGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get examErrorNetwork =>
      'Нет соединения. Проверьте интернет и повторите.';

  @override
  String get examErrorPlatformUnsupported =>
      'На этом устройстве пробные экзамены недоступны. Откройте приложение на телефоне (Android или iPhone).';

  @override
  String get examErrorSignIn => 'Войдите в аккаунт, чтобы проходить экзамены.';

  @override
  String get examErrorVariantUnavailable => 'Этот вариант сейчас недоступен.';

  @override
  String get examExit => 'Выйти из теста';

  @override
  String get examExitBody =>
      'Пока вас нет, таймер раздела продолжает идти на сервере. Ответы сохранены — продолжить можно с главного экрана.';

  @override
  String get examExitLeave => 'Выйти';

  @override
  String get examExitStay => 'Остаться';

  @override
  String get examExitTitle => 'Выйти из теста?';

  @override
  String get examFinishSection => 'Завершить раздел';

  @override
  String get examFinishSectionConfirm => 'Завершить';

  @override
  String examFinishSectionFlagged(int count) {
    return 'Отмечено для проверки: $count';
  }

  @override
  String examFinishSectionTitle(String section) {
    return 'Завершить раздел «$section»?';
  }

  @override
  String examFinishSectionUnanswered(int count) {
    return 'Без ответа: $count';
  }

  @override
  String get examFinishSectionWarning =>
      'После завершения вернуться к этому разделу будет нельзя.';

  @override
  String get examFinishedLoading => 'Тест завершён. Загружаем результат…';

  @override
  String get examFlag => 'Отметить';

  @override
  String get examHistoryAction => 'История';

  @override
  String examHistoryAttempts(int count) {
    return 'Попыток: $count';
  }

  @override
  String get examHistoryEmpty =>
      'Завершённых тестов пока нет. Здесь появятся ваши результаты.';

  @override
  String examHistoryLast(String percent) {
    return 'Последний: $percent%';
  }

  @override
  String get examHistoryTitle => 'История экзаменов';

  @override
  String examHistoryTrendDown(String delta) {
    return '−$delta% к прошлому';
  }

  @override
  String get examHistoryTrendSame => 'Как в прошлый раз';

  @override
  String examHistoryTrendUp(String delta) {
    return '+$delta% к прошлому';
  }

  @override
  String get examImageError => 'Не удалось загрузить изображение';

  @override
  String get examIntroCost => 'Стоимость';

  @override
  String examIntroLanguage(String language) {
    return 'Язык теста: $language';
  }

  @override
  String get examIntroRules => 'Правила';

  @override
  String get examIntroStructure => 'Структура';

  @override
  String get examKeepWorking => 'Продолжить раздел';

  @override
  String get examLangEn => 'Английский';

  @override
  String get examLangKy => 'Кыргызский';

  @override
  String get examLangRu => 'Русский';

  @override
  String get examLanguageLabel => 'Язык теста';

  @override
  String get examLoading => 'Загрузка…';

  @override
  String examMinutesCount(int minutes) {
    return '$minutes мин';
  }

  @override
  String get examMockTitle => 'Пробный ОРТ';

  @override
  String get examNext => 'Далее';

  @override
  String get examNextSectionTimeRunning => 'Время этого раздела уже идёт:';

  @override
  String get examNextSectionTitle => 'Следующий раздел';

  @override
  String get examNoCreditsAvailable => 'Нет доступных кредитов';

  @override
  String get examNoQuestions =>
      'В этом разделе нет вопросов. Напишите в поддержку.';

  @override
  String get examOfflineAutoRetry => 'Мы также повторим попытку автоматически.';

  @override
  String get examOfflineBadge => 'Нет сети — ответы сохраняются на устройстве';

  @override
  String get examOfflineBody =>
      'Ответы сохранены на устройстве. Следующий раздел начнётся только после того, как сервер примет этот.';

  @override
  String get examOfflineTitle => 'Нет соединения';

  @override
  String examOnlyLanguage(String language) {
    return 'Только: $language';
  }

  @override
  String examOptionSemantics(String letter) {
    return 'Вариант ответа $letter';
  }

  @override
  String get examPalette => 'Вопросы';

  @override
  String get examPaletteAnswered => 'Отвечено';

  @override
  String get examPaletteCurrent => 'Текущий';

  @override
  String get examPaletteFlagged => 'Отмечено';

  @override
  String get examPaletteUnanswered => 'Без ответа';

  @override
  String get examPartAssumption =>
      'Официальное деление на эти части не опубликовано — это приближение.';

  @override
  String get examPassage => 'Текст';

  @override
  String get examPlatformUnsupportedShort => 'Недоступно на этом устройстве';

  @override
  String get examPassageHide => 'Скрыть текст';

  @override
  String get examPassageShow => 'Показать текст';

  @override
  String get examPrevious => 'Назад';

  @override
  String examQuestionOf(int current, int total) {
    return 'Вопрос $current из $total';
  }

  @override
  String examQuestionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вопроса',
      many: '$count вопросов',
      few: '$count вопроса',
      one: '$count вопрос',
    );
    return '$_temp0';
  }

  @override
  String get examResultBySection => 'По разделам';

  @override
  String get examResultCorrect => 'Верно';

  @override
  String get examResultIncorrect => 'Неверно';

  @override
  String get examResultLevelsBody =>
      'Официальный результат теста по государственному языку — уровень от 1 до 4. Границы уровней не опубликованы, поэтому приложение показывает только процент верных ответов и не угадывает уровень.';

  @override
  String get examResultLevelsTitle => 'Как выдаётся официальный результат';

  @override
  String get examResultNoWeak => 'Слабых тем не найдено — отличная работа!';

  @override
  String get examResultNotEligible =>
      'Часть разделов закрыта с опозданием, поэтому попытка не учитывается в рейтинге.';

  @override
  String get examResultPending =>
      'Результат ещё считается. Попробуйте через несколько секунд.';

  @override
  String examResultRecommendation(String topic) {
    return 'Повторите «$topic»: вернитесь к теории и решите 10–15 тренировочных заданий по этой теме.';
  }

  @override
  String get examResultReview => 'Разбор ответов';

  @override
  String examResultScore(int correct, int total) {
    return '$correct из $total верно';
  }

  @override
  String get examResultSkipped => 'Пропущено';

  @override
  String get examResultStrong => 'Сильные темы';

  @override
  String get examResultTitle => 'Результат';

  @override
  String get examResultToExams => 'К экзаменам';

  @override
  String examResultTopicScore(int correct, int total) {
    return '$correct из $total';
  }

  @override
  String get examResultWeak => 'Что повторить';

  @override
  String get examResultWrongOrSkipped => 'Неверно или пропущено';

  @override
  String examResultXp(int xp) {
    return 'Начислено XP: $xp';
  }

  @override
  String get examResumeAwaitingSubmit => 'Ожидает отправки';

  @override
  String get examResumeTimeUp => 'Время раздела вышло';

  @override
  String get examResumeTitle => 'Незавершённый тест';

  @override
  String get examRetry => 'Повторить';

  @override
  String get examReviewAskTutor => 'Спросить ИИ-репетитора';

  @override
  String examReviewCorrectAnswer(String answer) {
    return 'Правильный ответ: $answer';
  }

  @override
  String get examReviewEmpty => 'По этому фильтру ничего нет.';

  @override
  String get examReviewExplanation => 'Объяснение';

  @override
  String get examReviewFilterAll => 'Все';

  @override
  String get examReviewFilterFlagged => 'Отмеченные';

  @override
  String get examReviewFilterWrong => 'Ошибки';

  @override
  String get examReviewNoAnswer => 'нет ответа';

  @override
  String examReviewQuestionNumber(int number) {
    return 'Вопрос $number';
  }

  @override
  String get examReviewTitle => 'Разбор ответов';

  @override
  String examReviewYourAnswer(String answer) {
    return 'Ваш ответ: $answer';
  }

  @override
  String get examRuleForwardOnly =>
      'Разделы идут строго по порядку. Завершённый раздел закрывается — вернуться к нему нельзя.';

  @override
  String get examRuleFreeNavigation =>
      'Внутри раздела можно свободно переходить между вопросами и отмечать их, чтобы вернуться позже.';

  @override
  String get examRuleKeepsRunning =>
      'Если выйти из приложения, таймер продолжит идти. Ответы сохраняются на устройстве.';

  @override
  String get examRuleNoCalculator => 'Калькулятором пользоваться нельзя.';

  @override
  String examRuleScratchpad(String sections) {
    return 'Черновик можно использовать в разделах: $sections.';
  }

  @override
  String get examRuleTimer =>
      'У каждого раздела свой таймер. За 5 минут и за 1 минуту до конца будет предупреждение, а при нуле раздел отправится автоматически.';

  @override
  String get examSectionDone => 'Раздел принят';

  @override
  String examSectionLabel(int index, int count) {
    return 'Раздел $index из $count';
  }

  @override
  String examSectionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count раздела',
      many: '$count разделов',
      few: '$count раздела',
      one: '$count раздел',
    );
    return '$_temp0';
  }

  @override
  String get examShowMore => 'Показать ещё';

  @override
  String get examStart => 'Начать тест';

  @override
  String get examStartSection => 'Начать раздел';

  @override
  String get examStarting => 'Готовим тест…';

  @override
  String get examSubmitting => 'Отправляем раздел…';

  @override
  String get examTabTitle => 'Экзамены';

  @override
  String get examTimeLeftLabel => 'Осталось времени';

  @override
  String get examTotal => 'Итого';

  @override
  String get examUnflag => 'Снять отметку';

  @override
  String get examVariantAdvanced => 'Повышенный';

  @override
  String examVariantBest(String percent) {
    return 'Лучший: $percent%';
  }

  @override
  String get examVariantInProgress => 'В процессе';

  @override
  String get examVariantNotStarted => 'Не начат';

  @override
  String examVariantTitle(int number) {
    return 'Вариант $number';
  }

  @override
  String get examVariants => 'Варианты';

  @override
  String get examVariantsEmpty =>
      'Вариантов на этом языке пока нет. Новые добавляются регулярно.';

  @override
  String get examWarningFive => 'До конца раздела осталось 5 минут';

  @override
  String get examWarningOne =>
      'Осталась 1 минута — раздел отправится автоматически';

  @override
  String get explanation => 'Объяснение';

  @override
  String get finish => 'Завершить';

  @override
  String get flashcards => 'Карточки';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get free => 'Бесплатно';

  @override
  String get geography => 'География';

  @override
  String get getStarted => 'Начать';

  @override
  String get googleSignIn => 'Войти через Google';

  @override
  String get grade10 => '10 класс';

  @override
  String get grade11 => '11 класс';

  @override
  String get grade9 => '9 класс';

  @override
  String get graduate => 'Выпускник';

  @override
  String get history => 'История Кыргызстана';

  @override
  String get hours => 'часов';

  @override
  String get incorrect => 'Неправильно';

  @override
  String get kgs => 'сом';

  @override
  String get kyrgyz => 'Кыргызский';

  @override
  String get kyrgyzLanguage => 'Кыргызский язык';

  @override
  String get language => 'Язык';

  @override
  String get learnAchAccuracy90Desc => 'Наберите 90% в пробном экзамене';

  @override
  String get learnAchAccuracy90Title => 'Точность 90%';

  @override
  String get learnAchAnalogiesDesc => 'Высокий результат в разделе аналогий';

  @override
  String get learnAchAnalogiesTitle => 'Мастер аналогий';

  @override
  String get learnAchDays30Desc => 'Занимайтесь в 30 разных дней';

  @override
  String get learnAchDays30Title => '30 дней занятий';

  @override
  String get learnAchExamChampionDesc => 'Завершите 10 пробных экзаменов';

  @override
  String get learnAchExamChampionTitle => 'Чемпион пробных экзаменов';

  @override
  String get learnAchFirstLessonDesc => 'Пройдите первый урок';

  @override
  String get learnAchFirstLessonTitle => 'Первый урок';

  @override
  String get learnAchMathExpertDesc =>
      '90% по математике в трёх пробных экзаменах';

  @override
  String get learnAchMathExpertTitle => 'Эксперт по математике';

  @override
  String get learnAchReaderDesc => 'Высокий результат в разделе чтения';

  @override
  String get learnAchReaderTitle => 'Читатель';

  @override
  String get learnAchStreak7Desc => 'Занимайтесь 7 дней подряд';

  @override
  String get learnAchStreak7Title => 'Неделя подряд';

  @override
  String get learnAchXp100Desc => 'Наберите 100 XP';

  @override
  String get learnAchXp100Title => 'Первые 100 XP';

  @override
  String get learnAchievementLocked => 'Ещё не получено';

  @override
  String get learnAchievementUnlocked => 'Получено';

  @override
  String learnAchievementUnlockedOn(String date) {
    return 'Получено $date';
  }

  @override
  String get learnAchievementsServerNote =>
      'Достижения засчитываются автоматически по результатам на сервере.';

  @override
  String get learnAchievementsTitle => 'Достижения';

  @override
  String learnAchievementsUnlocked(int n, int total) {
    return 'Открыто $n из $total';
  }

  @override
  String learnAnswersCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n ответа',
      many: '$n ответов',
      few: '$n ответа',
      one: '$n ответ',
    );
    return '$_temp0';
  }

  @override
  String get learnAskTutor => 'Спросить ИИ-репетитора';

  @override
  String learnAvgPerQuestion(int seconds) {
    return 'В среднем $seconds с на вопрос';
  }

  @override
  String get learnBack => 'Назад';

  @override
  String get learnBackHome => 'На главную';

  @override
  String get learnBestResult => 'Лучший результат';

  @override
  String get learnCorrect => 'Верно!';

  @override
  String learnCorrectAnswerIs(String answer) {
    return 'Правильный ответ: $answer';
  }

  @override
  String get learnDailyLessonTitle => 'Урок дня';

  @override
  String get learnDifficultyEasy => 'Лёгкий';

  @override
  String get learnDifficultyHard => 'Сложный';

  @override
  String get learnDifficultyMedium => 'Средний';

  @override
  String learnDurationMinutes(int n) {
    return '$n мин';
  }

  @override
  String get learnElapsedTime => 'Прошло времени';

  @override
  String get learnErrorGeneric =>
      'Не удалось загрузить данные. Попробуйте ещё раз.';

  @override
  String get learnErrorNotFound => 'Материал не найден.';

  @override
  String get learnErrorOffline =>
      'Нет соединения. Проверьте интернет и попробуйте ещё раз.';

  @override
  String get learnErrorPermission =>
      'Нет доступа к данным. Войдите в аккаунт ещё раз.';

  @override
  String get learnExamHistoryAll => 'Вся история';

  @override
  String get learnExamHistoryEmpty =>
      'Вы ещё не завершили ни одного пробного экзамена.';

  @override
  String get learnExamHistoryTitle => 'Последние попытки';

  @override
  String get learnExamHistoryUnavailable =>
      'История экзаменов сейчас недоступна.';

  @override
  String get learnExamResultUnofficial =>
      'Учебный результат, не официальный балл ОРТ.';

  @override
  String get learnExamResultsTitle => 'Пробные экзамены';

  @override
  String get learnExamSectionsTitle => 'Средний результат по разделам';

  @override
  String learnExitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ответы на $count вопроса можно сохранить.',
      many: 'Ответы на $count вопросов можно сохранить.',
      few: 'Ответы на $count вопроса можно сохранить.',
      one: 'Ответ на $count вопрос можно сохранить.',
      zero: 'Вы ещё не ответили ни на один вопрос.',
    );
    return '$_temp0';
  }

  @override
  String get learnExitContinue => 'Продолжить';

  @override
  String get learnExitDiscard => 'Выйти без сохранения';

  @override
  String get learnExitFinish => 'Завершить и сохранить';

  @override
  String get learnExitTitle => 'Завершить тренировку?';

  @override
  String get learnExplanation => 'Объяснение';

  @override
  String get learnFinish => 'Завершить';

  @override
  String get learnHandbookFactsUnavailable =>
      'Не удалось загрузить структуру экзамена.';

  @override
  String get learnHandbookNotFound => 'Раздел справочника не найден';

  @override
  String get learnHandbookRussianOnly =>
      'Этот раздел доступен только на русском языке.';

  @override
  String get learnHandbookSearch => 'Поиск в справочнике';

  @override
  String learnHandbookSections(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n раздела',
      many: '$n разделов',
      few: '$n раздела',
      one: '$n раздел',
    );
    return '$_temp0';
  }

  @override
  String get learnHandbookTitle => 'Справочник';

  @override
  String get learnHbAssumption => '(деление условное)';

  @override
  String learnHbMainTest(String year) {
    return 'Основной тест ОРТ ($year)';
  }

  @override
  String learnHbMainTotal(int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions задания',
      many: '$questions заданий',
      few: '$questions задания',
      one: '$questions задание',
    );
    return 'Всего: $_temp0, $minutes мин.';
  }

  @override
  String learnHbMaxScore(int score) {
    return 'Официальный максимальный балл основного теста — $score.';
  }

  @override
  String learnHbPartLine(String title, int questions, int options) {
    String _temp0 = intl.Intl.pluralLogic(
      options,
      locale: localeName,
      other: '$options варианта ответа',
      many: '$options вариантов ответа',
      few: '$options варианта ответа',
      one: '$options вариант ответа',
    );
    return '$title: $questions зад., $_temp0';
  }

  @override
  String learnHbSectionLine(String title, int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions задания',
      many: '$questions заданий',
      few: '$questions задания',
      one: '$questions задание',
    );
    return '$title: $_temp0, $minutes мин';
  }

  @override
  String learnHbStateLanguage(int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions задания',
      many: '$questions заданий',
      few: '$questions задания',
      one: '$questions задание',
    );
    return '$_temp0, $minutes мин. Обязателен для сертификата, результат — уровень 1–4.';
  }

  @override
  String get learnHbSubjectTests => 'Предметные тесты (по выбору)';

  @override
  String learnHbThresholdCollege(int n) {
    return 'Для колледжей: $n по основному тесту.';
  }

  @override
  String learnHbThresholdsUniversity(int main, int subject) {
    return 'Пороговый балл для вузов: $main по основному тесту и $subject по предметным тестам (2026–2027).';
  }

  @override
  String get learnHbThresholdsYearly =>
      'Пороговые баллы ежегодно утверждаются заново — проверяйте testing.kg.';

  @override
  String get learnLeaderboardAllTime => 'Всё время';

  @override
  String get learnLeaderboardAnonymous => 'Ученик';

  @override
  String get learnLeaderboardBySubject => 'По предметам';

  @override
  String get learnLeaderboardEmpty => 'Рейтинг пока пуст';

  @override
  String get learnLeaderboardEmptyBody =>
      'Он появится, когда ученики начнут получать XP.';

  @override
  String get learnLeaderboardNotRanked =>
      'Вас пока нет в этом рейтинге. Сюда автоматически попадает XP за уроки, практику и пробные экзамены.';

  @override
  String get learnLeaderboardSubjectEmptyBody =>
      'Он заполнится, когда ученики пройдут пробные экзамены по этому тесту.';

  @override
  String get learnLeaderboardSubjectHint =>
      'Учитывается только XP за пробные экзамены по выбранному тесту за эту неделю.';

  @override
  String get learnLeaderboardSubjectNotRanked =>
      'Вас пока нет в этом рейтинге. Здесь учитывается только XP за пробные экзамены по этому тесту.';

  @override
  String get learnLeaderboardTitle => 'Рейтинг';

  @override
  String get learnLeaderboardWeekly => 'Неделя';

  @override
  String learnLeaderboardYou(String name) {
    return '$name (вы)';
  }

  @override
  String get learnLessonAllDone => 'Все уроки этого предмета пройдены.';

  @override
  String get learnLessonCommonMistakes => 'Частые ошибки';

  @override
  String get learnLessonCompletedToast => 'Урок отмечен как пройденный.';

  @override
  String get learnLessonDone => 'Урок пройден';

  @override
  String learnLessonExampleN(int n) {
    return 'Пример $n';
  }

  @override
  String get learnLessonExamples => 'Примеры';

  @override
  String get learnLessonFormulas => 'Формулы';

  @override
  String get learnLessonHideSolution => 'Скрыть решение';

  @override
  String get learnLessonMarkDone => 'Отметить урок пройденным';

  @override
  String get learnLessonMaterials => 'Материалы';

  @override
  String get learnLessonNoContent => 'Содержание урока пока не добавлено.';

  @override
  String get learnLessonNotFound => 'Урок не найден';

  @override
  String get learnLessonNotFoundBody =>
      'Возможно, урок ещё не опубликован или был удалён.';

  @override
  String learnLessonNumber(int n) {
    return 'Урок $n';
  }

  @override
  String get learnLessonOpenPdf => 'Открыть PDF';

  @override
  String learnLessonPracticeBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n вопроса по теме урока.',
      many: '$n вопросов по теме урока.',
      few: '$n вопроса по теме урока.',
      one: '$n вопрос по теме урока.',
    );
    return '$_temp0';
  }

  @override
  String get learnLessonPracticeSubjectBody =>
      'Закрепите материал вопросами по этому предмету.';

  @override
  String get learnLessonPracticeTitle => 'Практика по уроку';

  @override
  String get learnLessonShowSolution => 'Показать решение';

  @override
  String get learnLessonSummary => 'Кратко';

  @override
  String get learnLessonTitle => 'Урок';

  @override
  String get learnLessonWatchVideo => 'Смотреть видео';

  @override
  String learnLessonsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n урока',
      many: '$n уроков',
      few: '$n урока',
      one: '$n урок',
    );
    return '$_temp0';
  }

  @override
  String get learnLessonsHeading => 'Уроки';

  @override
  String learnLevelN(int n) {
    return 'Уровень $n';
  }

  @override
  String get learnLinkFailed => 'Не удалось открыть ссылку.';

  @override
  String get learnLoadingLesson => 'Загружаем урок…';

  @override
  String get learnLoadingQuestions => 'Подбираем вопросы…';

  @override
  String get learnLoadingSubject => 'Загружаем предмет…';

  @override
  String get learnLoadingSubjects => 'Загружаем предметы…';

  @override
  String learnMinutes(int n) {
    return '$n мин';
  }

  @override
  String get learnMistakeFromExam => 'Вопрос из пробного экзамена';

  @override
  String get learnMistakeMarkReviewed => 'Отметить как повторённое';

  @override
  String get learnMistakeOpenReview => 'Разбор';

  @override
  String get learnMistakePractice => 'Повторить';

  @override
  String get learnMistakeQuestion => 'Вопрос';

  @override
  String get learnMistakeResolve => 'Я разобрался';

  @override
  String learnMistakeReviewOn(String date) {
    return 'повтор $date';
  }

  @override
  String get learnMistakeReviewToday => 'повторить сегодня';

  @override
  String get learnMistakeReviewedPrompt =>
      'Разобрали этот вопрос? Отметьте — он вернётся позже.';

  @override
  String learnMistakeWrongCount(int n) {
    return 'ошибок: $n';
  }

  @override
  String get learnMistakesAllSubjects => 'Все предметы';

  @override
  String learnMistakesDueToday(int n) {
    return 'К повторению сегодня: $n';
  }

  @override
  String get learnMistakesEmptyBody =>
      'Неверные ответы из практики и экзаменов будут появляться здесь.';

  @override
  String get learnMistakesEmptyTitle => 'Ошибок для повторения нет';

  @override
  String get learnMistakesFilterAll => 'Все';

  @override
  String get learnMistakesFilterDue => 'Сегодня';

  @override
  String get learnMistakesNothingDue =>
      'На сегодня всё повторено. Загляните завтра.';

  @override
  String learnMistakesPracticeN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Повторить $n вопроса',
      many: 'Повторить $n вопросов',
      few: 'Повторить $n вопроса',
      one: 'Повторить $n вопрос',
    );
    return '$_temp0';
  }

  @override
  String get learnMistakesPracticeTitle => 'Повторение ошибок';

  @override
  String get learnMistakesSrsNote =>
      'Каждая ошибка возвращается через 1, 3, 7, 14 и 30 дней. Верный ответ переносит её дальше, неверный — возвращает к началу.';

  @override
  String get learnMistakesTitle => 'Ошибки и повторение';

  @override
  String get learnMore => 'Ещё';

  @override
  String get learnNext => 'Далее';

  @override
  String get learnNextLesson => 'Следующий урок';

  @override
  String get learnNoExplanation =>
      'Объяснение к этому вопросу пока не добавлено.';

  @override
  String get learnNoLessonsYet =>
      'Уроки пока не добавлены — начните с практики.';

  @override
  String get learnNoQuestionsBody =>
      'Здесь ещё нет проверенных вопросов. Загляните позже или попробуйте быструю практику.';

  @override
  String get learnNoQuestionsTitle => 'Вопросов пока нет';

  @override
  String get learnNoSearchResults => 'Ничего не найдено';

  @override
  String get learnNoSubjectsBody =>
      'Учебные материалы скоро появятся. А пока можно пройти быструю практику.';

  @override
  String get learnNoSubjectsTitle => 'Предметов пока нет';

  @override
  String get learnOpenMistakes => 'Работа над ошибками';

  @override
  String get learnPracticeAgain => 'Ещё одна тренировка';

  @override
  String get learnPracticeBySubjectEmpty =>
      'Решите несколько вопросов — здесь появится точность по предметам.';

  @override
  String get learnPracticeBySubjectTitle => 'Практика по предметам';

  @override
  String learnPracticeCorrectOfTotal(int correct, int total) {
    return '$correct из $total верно';
  }

  @override
  String get learnPracticeNotOrtNote =>
      'Это результат тренировки, а не балл ОРТ: по короткому набору вопросов нельзя оценить экзаменационный балл.';

  @override
  String learnPracticePercentLabel(int percent) {
    return 'Практика: $percent%';
  }

  @override
  String get learnPracticeSubject => 'Практика по предмету';

  @override
  String get learnPracticeTitle => 'Практика';

  @override
  String get learnPracticeVerdictExcellent => 'Отлично! Так держать.';

  @override
  String get learnPracticeVerdictFair =>
      'Неплохо. Разберите ошибки — это быстрее всего улучшает результат.';

  @override
  String get learnPracticeVerdictGood => 'Хорошо. Осталось немного.';

  @override
  String get learnPracticeVerdictLow =>
      'Нужно больше практики. Начните с разбора ошибок.';

  @override
  String get learnProgressEmptyBody =>
      'Пройдите урок или тренировку — здесь появится ваша реальная статистика.';

  @override
  String get learnProgressEmptyTitle => 'Пока нет данных';

  @override
  String get learnProgressTitle => 'Мой прогресс';

  @override
  String learnQuestAnswer(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Ответьте на $n вопроса',
      many: 'Ответьте на $n вопросов',
      few: 'Ответьте на $n вопроса',
      one: 'Ответьте на $n вопрос',
    );
    return '$_temp0';
  }

  @override
  String get learnQuestCompleteSet => 'Завершите одну тренировку';

  @override
  String learnQuestRun(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n верных ответа подряд',
      many: '$n верных ответов подряд',
      few: '$n верных ответа подряд',
      one: '$n верный ответ подряд',
    );
    return '$_temp0';
  }

  @override
  String learnQuestionNumber(int n) {
    return 'Вопрос $n';
  }

  @override
  String learnQuestionProgress(int current, int total) {
    return 'Вопрос $current из $total';
  }

  @override
  String learnQuestsDone(int done, int total) {
    return 'Выполнено $done из $total';
  }

  @override
  String learnQuestsReset(int h, int m) {
    return 'Обновятся через $h ч $m мин';
  }

  @override
  String get learnQuestsTitle => 'Задания дня';

  @override
  String get learnQuickPracticeTitle => 'Быстрая практика';

  @override
  String learnRecDueMistakesTitle(int n) {
    return 'Рекомендуем повторить ошибки ($n)';
  }

  @override
  String get learnRecDueMistakesWhy =>
      '…потому что сегодня подошёл срок их повторения: так материал запоминается надолго.';

  @override
  String learnRecMoreDataTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Рекомендуем решить ещё $n вопроса',
      many: 'Рекомендуем решить ещё $n вопросов',
      few: 'Рекомендуем решить ещё $n вопроса',
      one: 'Рекомендуем решить ещё $n вопрос',
    );
    return '$_temp0';
  }

  @override
  String get learnRecMoreDataWhy =>
      '…потому что выводы о точности становятся надёжными примерно после 20 ответов.';

  @override
  String get learnRecNoExamTitle => 'Рекомендуем пройти пробный экзамен';

  @override
  String get learnRecNoExamWhy =>
      '…потому что пока нет ни одного результата по всем разделам сразу — без него не видно, какой раздел проседает.';

  @override
  String get learnRecOpenExams => 'К экзаменам';

  @override
  String learnRecWeakSectionTitle(String section) {
    return 'Рекомендуем подтянуть раздел «$section»';
  }

  @override
  String learnRecWeakSectionWhy(int percent) {
    return '…потому что в пробных экзаменах там в среднем $percent% верных ответов — это самый слабый раздел.';
  }

  @override
  String learnRecWeakSubjectTitle(String subject) {
    return 'Рекомендуем потренировать «$subject»';
  }

  @override
  String learnRecWeakSubjectWhy(int percent, int count) {
    return '…потому что точность там $percent% — ниже, чем в других предметах (всего ответов: $count).';
  }

  @override
  String learnRecWeakTopicTitle(String topic) {
    return 'Рекомендуем повторить тему «$topic»';
  }

  @override
  String learnRecWeakTopicWhy(int percent) {
    return '…потому что верных ответов по этой теме только $percent%.';
  }

  @override
  String get learnRecommendationsNone =>
      'Пока всё идёт хорошо — продолжайте в том же темпе.';

  @override
  String get learnRecommendationsTitle => 'Рекомендации';

  @override
  String get learnResultsEmptyBody =>
      'Пройдите тренировку — здесь появится разбор ответов.';

  @override
  String get learnResultsEmptyTitle => 'Результатов пока нет';

  @override
  String get learnResultsTitle => 'Результат тренировки';

  @override
  String get learnReviewAnswers => 'Разбор ответов';

  @override
  String get learnRightAnswer => 'Правильный ответ';

  @override
  String get learnSearchSubjects => 'Поиск предметов';

  @override
  String get learnSignIn => 'Войти';

  @override
  String get learnSignInToPractice =>
      'Войдите, чтобы тренироваться и сохранять прогресс.';

  @override
  String get learnSignInToSave => 'Войдите, чтобы сохранять прогресс.';

  @override
  String get learnSkip => 'Пропустить';

  @override
  String get learnSkipAndFinish => 'Пропустить и завершить';

  @override
  String get learnStartPractice => 'Начать практику';

  @override
  String get learnStatAnswered => 'Ответов в практике';

  @override
  String learnStatBestStreak(int n) {
    return 'Лучшая: $n';
  }

  @override
  String get learnStatCorrect => 'Верно';

  @override
  String get learnStatExams => 'Пробных экзаменов';

  @override
  String learnStatLessonsCompleted(int n) {
    return 'уроков пройдено: $n';
  }

  @override
  String get learnStatLessonsDone => 'Уроков пройдено';

  @override
  String get learnStatLevel => 'Уровень';

  @override
  String get learnStatPracticeAccuracy => 'Точность в практике';

  @override
  String get learnStatPracticeOnly => 'только практика';

  @override
  String get learnStatPracticeTime => 'Время в практике';

  @override
  String get learnStatPracticeTimeHint => 'по завершённым тренировкам';

  @override
  String learnStatSessions(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n тренировки',
      many: '$n тренировок',
      few: '$n тренировки',
      one: '$n тренировка',
    );
    return '$_temp0';
  }

  @override
  String get learnStatSkipped => 'Пропущено';

  @override
  String get learnStatStreak => 'Серия, дней';

  @override
  String get learnStatTime => 'Время';

  @override
  String get learnStatWrong => 'Неверно';

  @override
  String learnStreakDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n дня',
      many: '$n дней',
      few: '$n дня',
      one: '$n день',
    );
    return '$_temp0';
  }

  @override
  String get learnSubjectNotFound => 'Предмет не найден';

  @override
  String get learnSubjectNotFoundBody => 'Возможно, ссылка устарела.';

  @override
  String get learnSubjectsTitle => 'Предметы';

  @override
  String get learnWeakTopicsEmpty =>
      'Недостаточно ответов, чтобы выделить слабые темы (нужно от 5 ответов по теме).';

  @override
  String get learnWeakTopicsTitle => 'Темы для повторения';

  @override
  String get learnWrong => 'Неверно';

  @override
  String learnXpAwarded(int xp) {
    return '+$xp XP';
  }

  @override
  String get learnXpNone => 'За эту тренировку XP не начислен.';

  @override
  String get learnXpPending => 'Начисляем XP…';

  @override
  String get learnXpQueued => 'XP начислится, когда появится связь.';

  @override
  String learnXpShort(int xp) {
    return '$xp XP';
  }

  @override
  String learnXpToNextLevel(int xp, int level) {
    return '$xp XP до уровня $level';
  }

  @override
  String learnXpTotal(int xp) {
    return 'Всего $xp XP';
  }

  @override
  String get learnYourAnswer => 'Ваш ответ';

  @override
  String get lessons => 'Уроки';

  @override
  String get light => 'Светлая';

  @override
  String get loading => 'Загрузка...';

  @override
  String get login => 'Войти';

  @override
  String get logout => 'Выйти';

  @override
  String get mathematics => 'Математика';

  @override
  String get mbankPayment => 'Оплата через MBank';

  @override
  String get mockTest => 'Пробный экзамен';

  @override
  String get mockTestDesc => 'Пройдите пробный экзамен в реальном формате';

  @override
  String get mockTestTitle => 'Полная симуляция ОРТ';

  @override
  String get monthly => 'Месячная';

  @override
  String get myProgress => 'Мой прогресс';

  @override
  String get next => 'Следующий';

  @override
  String get nextOrtDate => 'Следующая регистрация ОРТ';

  @override
  String get noConnection => 'Нет подключения к интернету';

  @override
  String get notifications => 'Уведомления';

  @override
  String get onboardingDesc1 =>
      'Проходите практические тесты и осваивайте все предметы для экзамена ОРТ';

  @override
  String get onboardingDesc2 =>
      'Следите за своими результатами и выявляйте слабые места для улучшения';

  @override
  String get onboardingDesc3 =>
      'Проходите полные симуляции с реальным форматом и временем ОРТ';

  @override
  String get onboardingTitle1 => 'Подготовка к ОРТ';

  @override
  String get onboardingTitle2 => 'Отслеживайте прогресс';

  @override
  String get onboardingTitle3 => 'Пробные экзамены';

  @override
  String get orContinueWith => 'Или продолжить с';

  @override
  String get password => 'Пароль';

  @override
  String get payNow => 'Оплатить';

  @override
  String get payment => 'Оплата';

  @override
  String get paymentMethod => 'Способ оплаты';

  @override
  String get phoneSignIn => 'Войти через телефон';

  @override
  String get physics => 'Физика';

  @override
  String get practiceQuiz => 'Практический тест';

  @override
  String get previous => 'Предыдущий';

  @override
  String get price => 'Цена';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get profile => 'Профиль';

  @override
  String get progress => 'Прогресс';

  @override
  String get pushNotifications => 'Push-уведомления';

  @override
  String get pushNotificationsDesc => 'Напоминания о занятиях';

  @override
  String get retry => 'Повторить';

  @override
  String get review => 'Просмотр';

  @override
  String get russian => 'Русский';

  @override
  String get russianLanguage => 'Русский язык';

  @override
  String get score => 'Результат';

  @override
  String get section1 => 'Основной тест';

  @override
  String get section2 => 'Предметный тест';

  @override
  String get section3 => 'Языковой тест';

  @override
  String get selectGrade => 'Выберите класс';

  @override
  String get selectLanguage => 'Выберите язык';

  @override
  String get selectSubjects => 'Выберите слабые предметы';

  @override
  String get settings => 'Настройки';

  @override
  String get shellAuthConfirmPasswordLabel => 'Повторите пароль';

  @override
  String get shellAuthContinueWithGoogle => 'Продолжить с Google';

  @override
  String get shellAuthEmailInvalid =>
      'Проверьте адрес, например name@example.com';

  @override
  String get shellAuthEmailLabel => 'Email';

  @override
  String get shellAuthEmailRequired => 'Введите email';

  @override
  String get shellAuthErrorDifferentCredential =>
      'Этот email уже привязан к другому способу входа.';

  @override
  String get shellAuthErrorEmailInUse =>
      'Этот email уже зарегистрирован. Войдите в аккаунт.';

  @override
  String get shellAuthErrorGoogleUnavailable =>
      'Вход через Google пока недоступен на этом устройстве. Войдите по email.';

  @override
  String get shellAuthErrorInvalidCredentials => 'Неверный email или пароль.';

  @override
  String get shellAuthErrorNetwork =>
      'Нет соединения. Проверьте интернет и попробуйте снова.';

  @override
  String get shellAuthErrorNotAllowed =>
      'Этот способ входа временно недоступен.';

  @override
  String get shellAuthErrorTooManyRequests =>
      'Слишком много попыток. Подождите несколько минут и попробуйте снова.';

  @override
  String get shellAuthErrorUnknown =>
      'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get shellAuthErrorUserDisabled =>
      'Этот аккаунт заблокирован. Обратитесь в поддержку.';

  @override
  String get shellAuthErrorUserNotFound =>
      'Аккаунт с таким email не найден. Сначала зарегистрируйтесь.';

  @override
  String get shellAuthForgotPassword => 'Забыли пароль?';

  @override
  String get shellAuthHidePassword => 'Скрыть пароль';

  @override
  String get shellAuthNameLabel => 'Имя';

  @override
  String get shellAuthNameRequired => 'Введите имя';

  @override
  String get shellAuthNameTooShort => 'Имя слишком короткое';

  @override
  String get shellAuthOr => 'или';

  @override
  String shellAuthPasswordHint(int min) {
    return 'Минимум $min символов, буквы и цифры';
  }

  @override
  String get shellAuthPasswordLabel => 'Пароль';

  @override
  String get shellAuthPasswordMismatch => 'Пароли не совпадают';

  @override
  String get shellAuthPasswordRequired => 'Введите пароль';

  @override
  String shellAuthPasswordTooShort(int min) {
    return 'Пароль должен быть не короче $min символов';
  }

  @override
  String get shellAuthPasswordTooWeak => 'Используйте и буквы, и цифры';

  @override
  String get shellAuthResetMessage =>
      'Введите email аккаунта — мы отправим ссылку для нового пароля.';

  @override
  String get shellAuthResetSend => 'Отправить';

  @override
  String get shellAuthResetSent =>
      'Если аккаунт с таким email существует, мы отправили письмо со ссылкой.';

  @override
  String get shellAuthResetTitle => 'Восстановление пароля';

  @override
  String get shellAuthShowPassword => 'Показать пароль';

  @override
  String get shellBootErrorMessage =>
      'Проверьте подключение к интернету и попробуйте ещё раз.';

  @override
  String get shellBootErrorTitle => 'Не удалось запустить приложение';

  @override
  String get shellCancel => 'Отмена';

  @override
  String get shellDaily10Desc => 'Лёгкий старт';

  @override
  String get shellDaily20Desc => 'Ровный темп';

  @override
  String get shellDaily30Desc => 'Интенсивная подготовка';

  @override
  String shellDailyMinutes(int minutes) {
    return '$minutes мин в день';
  }

  @override
  String get shellExitConfirm => 'Выйти';

  @override
  String get shellExitMessage => 'Ваш прогресс сохранён.';

  @override
  String get shellExitTitle => 'Выйти из приложения?';

  @override
  String get shellGoHome => 'На главную';

  @override
  String get shellGoalBand110Desc => 'Уверенная база';

  @override
  String get shellGoalBand150Desc => 'Сильный результат';

  @override
  String get shellGoalBand190Desc => 'Высший результат';

  @override
  String get shellGoalUnsure => 'Пока не знаю';

  @override
  String get shellGradeGraduate => 'Выпускник';

  @override
  String get shellGradeLabel => 'Класс';

  @override
  String shellGradeNumber(int grade) {
    return '$grade класс';
  }

  @override
  String get shellHide => 'Скрыть';

  @override
  String shellHomeBestStreak(int count) {
    return 'Рекорд: $count';
  }

  @override
  String get shellHomeBuyExam => 'Купить пробный экзамен';

  @override
  String shellHomeCredits(int count) {
    return 'Доступно пробных экзаменов: $count';
  }

  @override
  String get shellHomeDailyGoal => 'Дневная цель';

  @override
  String get shellHomeEmptyStatsMessage =>
      'Решите задание или пройдите урок — здесь появятся серия и прогресс за день.';

  @override
  String get shellHomeEmptyStatsTitle => 'Начните серию сегодня';

  @override
  String get shellHomeEntitlementError =>
      'Не удалось проверить доступ · Повторить';

  @override
  String get shellHomeFreeExam => 'Доступен бесплатный пробный экзамен';

  @override
  String shellHomeGoalMinutes(int minutes) {
    return 'Ваша цель: $minutes мин в день';
  }

  @override
  String get shellHomeGoalReached => 'Дневная цель выполнена!';

  @override
  String get shellHomeGreeting => 'Привет!';

  @override
  String shellHomeGreetingName(String name) {
    return 'Привет, $name!';
  }

  @override
  String shellHomeLevelXp(int level, int xp) {
    return 'Уровень $level · $xp XP';
  }

  @override
  String get shellHomeNextStepError => 'Не удалось загрузить рекомендацию.';

  @override
  String get shellHomeNoCredits => 'Нет доступных пробных экзаменов';

  @override
  String get shellHomeReminderEnable => 'Включить';

  @override
  String get shellHomeReminderMessage =>
      'Короткое напоминание раз в день помогает не терять серию.';

  @override
  String get shellHomeReminderTitle => 'Напоминать о занятиях?';

  @override
  String get shellHomeSetupAction => 'Настроить';

  @override
  String get shellHomeSetupMessage =>
      'Укажите класс, регион и желаемый балл — рекомендации станут точнее.';

  @override
  String get shellHomeSetupTitle => 'Настройте цель';

  @override
  String get shellHomeStatsError => 'Не удалось загрузить прогресс.';

  @override
  String shellHomeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня подряд',
      many: '$count дней подряд',
      few: '$count дня подряд',
      one: '$count день подряд',
    );
    return '$_temp0';
  }

  @override
  String get shellHomeStreakNone => 'Серии пока нет';

  @override
  String get shellHomeSubtitle => 'Продолжим подготовку к ОРТ';

  @override
  String shellHomeTodayXp(int today) {
    return 'Сегодня: $today XP';
  }

  @override
  String shellHomeTodayXpOfGoal(int today, int goal) {
    return 'Сегодня: $today из $goal XP';
  }

  @override
  String get shellLangEn => 'Английский';

  @override
  String get shellLangEnNative => 'English';

  @override
  String get shellLangKy => 'Кыргызский';

  @override
  String get shellLangKyNative => 'Кыргызча';

  @override
  String get shellLangRu => 'Русский';

  @override
  String get shellLangRuNative => 'Русский';

  @override
  String get shellLater => 'Позже';

  @override
  String get shellLinkOpenFailed => 'Не удалось открыть ссылку.';

  @override
  String get shellLoading => 'Загрузка';

  @override
  String get shellLoginButton => 'Войти';

  @override
  String get shellLoginCreateAccount => 'Создать';

  @override
  String get shellLoginNoAccount => 'Ещё нет аккаунта?';

  @override
  String get shellLoginSubtitle =>
      'Войдите, чтобы продолжить подготовку к ОРТ.';

  @override
  String get shellLoginTitle => 'С возвращением';

  @override
  String get shellNavExams => 'Экзамены';

  @override
  String get shellNavHome => 'Главная';

  @override
  String get shellNavLearn => 'Учёба';

  @override
  String get shellNavProfile => 'Профиль';

  @override
  String get shellNavProgress => 'Прогресс';

  @override
  String get shellNextFirstMock =>
      'Пройдите полный пробный экзамен, чтобы узнать свой уровень и слабые темы.';

  @override
  String get shellNextFirstMockFree =>
      'Пройдите первый полный пробный экзамен — он бесплатный. Узнаете свой уровень и слабые темы.';

  @override
  String get shellNextOpenExams => 'К экзаменам';

  @override
  String get shellNextOpenLearn => 'Перейти к учёбе';

  @override
  String get shellNextPractice =>
      'Хорошая работа! Закрепите результат быстрым тестом или пройдите ещё один пробный экзамен.';

  @override
  String get shellNextStepTitle => 'Следующий шаг';

  @override
  String shellNextWeakTopic(String area) {
    return 'В последнем экзамене слабее всего: $area. Повторите эту тему, чтобы поднять балл.';
  }

  @override
  String get shellNotFoundMessage =>
      'Возможно, ссылка устарела. Вернитесь на главный экран.';

  @override
  String get shellNotFoundTitle => 'Страница не найдена';

  @override
  String get shellNotNow => 'Не сейчас';

  @override
  String get shellNotSet => 'Не указано';

  @override
  String get shellOnbAboutSubtitle =>
      'Так мы подберём задания и покажем рейтинг вашего региона.';

  @override
  String get shellOnbAboutTitle => 'Расскажите о себе';

  @override
  String get shellOnbBack => 'Назад';

  @override
  String get shellOnbDailySubtitle =>
      'Короткие ежедневные занятия работают лучше редких марафонов.';

  @override
  String get shellOnbDailyTitle => 'Сколько времени в день готовы заниматься?';

  @override
  String get shellOnbGoalSubtitle =>
      'Цель поможет понять, сколько осталось. Её можно изменить в профиле.';

  @override
  String get shellOnbGoalTitle => 'Какой балл хотите набрать?';

  @override
  String get shellOnbLangKyHint => 'ОРТ на кыргызском языке';

  @override
  String get shellOnbLangRuHint => 'ОРТ на русском языке';

  @override
  String get shellOnbLanguageSubtitle =>
      'На этом языке будут приложение и пробные экзамены. Изменить можно в настройках.';

  @override
  String get shellOnbLanguageTitle => 'На каком языке будете готовиться?';

  @override
  String get shellOnbNext => 'Далее';

  @override
  String get shellOnbSavedLater =>
      'Ответы сохранены и синхронизируются, когда появится интернет.';

  @override
  String get shellOnbSkip => 'Пропустить';

  @override
  String get shellOnbStart => 'Начать';

  @override
  String shellOnbStepOf(int current, int total) {
    return 'Шаг $current из $total';
  }

  @override
  String get shellOnbUniversityHint => 'Например, КГМА или КНУ';

  @override
  String get shellOnbUniversityLabel => 'Вуз мечты';

  @override
  String get shellOptional => 'Необязательно';

  @override
  String get shellProfileAchievements => 'Достижения';

  @override
  String get shellProfileComplete => 'Заполнить профиль';

  @override
  String get shellProfileDailyGoal => 'Дневная цель';

  @override
  String get shellProfileDeleteAccount => 'Удалить аккаунт';

  @override
  String get shellProfileEdit => 'Редактировать профиль';

  @override
  String get shellProfileEditTitle => 'Редактирование профиля';

  @override
  String get shellProfileExamLanguage => 'Язык экзамена';

  @override
  String get shellProfileExams => 'Экзамены';

  @override
  String get shellProfileGoal => 'Цель по баллам';

  @override
  String get shellProfileLevel => 'Уровень';

  @override
  String get shellProfileLoadError => 'Не удалось загрузить профиль.';

  @override
  String get shellProfileNoName => 'Ученик';

  @override
  String get shellProfileRegionLocked => 'Регион можно менять раз в год.';

  @override
  String get shellProfileSaveError =>
      'Не удалось сохранить. Проверьте подключение и попробуйте снова.';

  @override
  String get shellProfileSaved => 'Профиль сохранён.';

  @override
  String get shellProfileSavedOffline =>
      'Сохранено. Изменения синхронизируются, когда появится интернет.';

  @override
  String get shellProfileSchool => 'Школа';

  @override
  String get shellProfileStreak => 'Серия';

  @override
  String get shellProfileTransactions => 'Покупки';

  @override
  String get shellQuickDailyLesson => 'Урок дня';

  @override
  String get shellQuickHandbook => 'Справочник';

  @override
  String get shellQuickLeaderboard => 'Рейтинг';

  @override
  String get shellQuickMockExam => 'Пробный экзамен';

  @override
  String get shellQuickTest => 'Быстрый тест';

  @override
  String get shellQuickTitle => 'Быстрые действия';

  @override
  String get shellQuickTutor => 'ИИ-репетитор';

  @override
  String get shellRegionDistrict => 'Район';

  @override
  String get shellRegionLabel => 'Регион';

  @override
  String get shellRegionLoadError => 'Не удалось загрузить список регионов.';

  @override
  String get shellRegionOblast => 'Область или город';

  @override
  String get shellReminderDenied =>
      'Уведомления для приложения отключены. Разрешите их в настройках телефона.';

  @override
  String get shellReminderEnabled => 'Напоминания включены.';

  @override
  String get shellReminderFailed =>
      'Не удалось включить напоминания. Попробуйте позже.';

  @override
  String get shellReminderUnsupported =>
      'Напоминания недоступны на этом устройстве.';

  @override
  String get shellRetry => 'Повторить';

  @override
  String get shellSave => 'Сохранить';

  @override
  String get shellSettingsAbout => 'О приложении';

  @override
  String get shellSettingsAppearance => 'Приложение';

  @override
  String get shellSettingsDisclaimer =>
      'Результаты пробных экзаменов — учебные и не являются официальными баллами ОРТ.';

  @override
  String get shellSettingsLanguage => 'Язык';

  @override
  String get shellSettingsNotifications => 'Уведомления';

  @override
  String get shellSettingsPrivacy => 'Политика конфиденциальности';

  @override
  String get shellSettingsReminder => 'Ежедневное напоминание';

  @override
  String get shellSettingsReminderHint =>
      'Короткое напоминание о занятиях раз в день';

  @override
  String get shellSettingsTerms => 'Условия использования';

  @override
  String get shellSettingsTheme => 'Тема';

  @override
  String get shellSettingsTitle => 'Настройки';

  @override
  String get shellSettingsVersion => 'Версия';

  @override
  String get shellSignOut => 'Выйти';

  @override
  String get shellSignOutMessage => 'Прогресс останется в вашем аккаунте.';

  @override
  String get shellSignOutTitle => 'Выйти из аккаунта?';

  @override
  String get shellSignupButton => 'Создать аккаунт';

  @override
  String get shellSignupHaveAccount => 'Уже есть аккаунт?';

  @override
  String get shellSignupLegalAnd => ' и ';

  @override
  String get shellSignupLegalPrefix =>
      'Регистрируясь, вы соглашаетесь с документами: ';

  @override
  String get shellSignupSubtitle =>
      'Это займёт минуту. Прогресс будет сохраняться в аккаунте.';

  @override
  String get shellSignupSuccess =>
      'Аккаунт создан. Мы отправили письмо для подтверждения email.';

  @override
  String get shellSignupTitle => 'Регистрация';

  @override
  String get shellTagline => 'Подготовка к ОРТ';

  @override
  String get shellThemeDark => 'Тёмная';

  @override
  String get shellThemeLight => 'Светлая';

  @override
  String get shellThemeSystem => 'Как в системе';

  @override
  String get shellVerifyCheck => 'Я подтвердил';

  @override
  String get shellVerifyDone => 'Email подтверждён. Спасибо!';

  @override
  String shellVerifyMessage(String email) {
    return 'Мы отправили ссылку на $email. Это поможет восстановить доступ к аккаунту.';
  }

  @override
  String get shellVerifyNotYet =>
      'Пока не подтверждено. Откройте ссылку из письма.';

  @override
  String get shellVerifyResend => 'Отправить снова';

  @override
  String get shellVerifySendFailed =>
      'Не удалось отправить письмо. Попробуйте позже.';

  @override
  String get shellVerifySent =>
      'Письмо отправлено. Проверьте «Входящие» и «Спам».';

  @override
  String get shellVerifyTitle => 'Подтвердите email';

  @override
  String get signup => 'Регистрация';

  @override
  String get skip => 'Пропустить';

  @override
  String get somethingWentWrong => 'Что-то пошло не так';

  @override
  String get startLearning => 'Начать обучение';

  @override
  String get startQuiz => 'Начать тест';

  @override
  String get startTest => 'Начать тест';

  @override
  String get streak => 'Дней подряд';

  @override
  String get strongTopics => 'Сильные темы';

  @override
  String get studyTime => 'Время обучения';

  @override
  String get subjects => 'Предметы';

  @override
  String get submit => 'Отправить';

  @override
  String get subscribe => 'Подписаться';

  @override
  String get subscription => 'Подписка';

  @override
  String get success => 'Успешно';

  @override
  String get system => 'Системная';

  @override
  String get takeQuiz => 'Пройти тест';

  @override
  String get terms => 'Условия использования';

  @override
  String get termsOfService => 'Условия использования';

  @override
  String get tests => 'Тесты';

  @override
  String get testsTaken => 'Пройдено тестов';

  @override
  String get theme => 'Тема';

  @override
  String get timeSpent => 'Затрачено времени';

  @override
  String get tutorAssistant => 'Репетитор';

  @override
  String get tutorClear => 'Очистить чат';

  @override
  String get tutorContextAttempt => 'Прикреплена попытка экзамена';

  @override
  String get tutorContextQuestion => 'Вопрос прикреплён';

  @override
  String get tutorContextRemove => 'Открепить';

  @override
  String get tutorDisclaimer =>
      'ИИ может ошибаться. Проверяйте важные шаги по учебнику или с учителем.';

  @override
  String get tutorEmptyBody =>
      'Выберите режим выше и задайте вопрос. Я объясняю ход решения, а не просто даю ответ.';

  @override
  String get tutorEmptyTitle => 'Чем помочь?';

  @override
  String get tutorErrorBanned =>
      'Ваш аккаунт ограничен, поэтому ИИ-репетитор недоступен. Если это ошибка, напишите в поддержку.';

  @override
  String get tutorErrorDisabled => 'ИИ-репетитор временно недоступен.';

  @override
  String get tutorErrorExamInProgress =>
      'Во время экзамена репетитор недоступен. Завершите попытку — потом разберём ошибки.';

  @override
  String get tutorErrorNetwork =>
      'Нет соединения. Проверьте интернет и повторите.';

  @override
  String get tutorErrorQuota =>
      'Лимит запросов к ИИ на сегодня исчерпан. Возвращайтесь завтра.';

  @override
  String get tutorErrorSignIn =>
      'Войдите в аккаунт, чтобы пользоваться ИИ-репетитором.';

  @override
  String get tutorErrorUnknown =>
      'Репетитор не смог ответить. Попробуйте ещё раз.';

  @override
  String get tutorErrorValidation =>
      'Сообщение пустое или слишком длинное. Сократите его и повторите.';

  @override
  String tutorExplainPrompt(
    String stem,
    String options,
    String userAnswer,
    String correctAnswer,
  ) {
    return 'Разбери мою ошибку.\nЗадание: $stem\nВарианты:\n$options\nМой ответ: $userAnswer\nПравильный ответ: $correctAnswer\nОбъясни, где я ошибся и как рассуждать правильно.';
  }

  @override
  String get tutorExplainerAiButton => 'Объяснить мою ошибку';

  @override
  String get tutorExplainerAiTitle =>
      'Почему неправильно? Спросите ИИ-репетитора';

  @override
  String get tutorExplainerClose => 'Закрыть';

  @override
  String get tutorExplainerCorrect => 'Правильно!';

  @override
  String tutorExplainerCorrectAnswer(String answer) {
    return 'Правильный ответ: $answer';
  }

  @override
  String get tutorExplainerExplanation => 'Объяснение';

  @override
  String get tutorExplainerIncorrect => 'Неправильно';

  @override
  String get tutorExplainerNext => 'Следующий';

  @override
  String get tutorExplainerNoAnswer => 'нет ответа';

  @override
  String get tutorExplainerOpenChat => 'Открыть чат с репетитором';

  @override
  String get tutorExplainerTryAgain => 'Попробовать снова';

  @override
  String tutorExplainerYourAnswer(String answer) {
    return 'Ваш ответ: $answer';
  }

  @override
  String get tutorHintChat => 'Задайте любой вопрос о подготовке к ОРТ.';

  @override
  String get tutorHintExplainMistake =>
      'Вставьте задание и свой ответ — объясню, где ошибка.';

  @override
  String get tutorHintGrammar =>
      'Спросите о правиле или вставьте предложение для проверки.';

  @override
  String get tutorHintPractice => 'Назовите тему — предложу похожие задания.';

  @override
  String get tutorHintStepByStep => 'Опишите задачу — решим её по шагам.';

  @override
  String get tutorHintStudyPlan => 'Напишите дату экзамена и слабые предметы.';

  @override
  String tutorMessageTooLong(int count, int max) {
    return 'Сообщение слишком длинное ($count/$max символов). Сократите его, чтобы отправить.';
  }

  @override
  String get tutorModeChat => 'Свободный вопрос';

  @override
  String get tutorModeExplainMistake => 'Разобрать ошибку';

  @override
  String get tutorModeGrammar => 'Грамматика';

  @override
  String get tutorModePractice => 'Похожие задания';

  @override
  String get tutorModeStepByStep => 'Пошагово';

  @override
  String get tutorModeStudyPlan => 'План подготовки';

  @override
  String tutorRemainingToday(int count) {
    return 'Осталось запросов сегодня: $count';
  }

  @override
  String get tutorRetry => 'Повторить';

  @override
  String get tutorSend => 'Отправить';

  @override
  String get tutorThinking => 'Репетитор думает…';

  @override
  String get tutorTitle => 'ИИ-репетитор';

  @override
  String get tutorUnavailablePlatform =>
      'ИИ-репетитор недоступен на этой платформе. Воспользуйтесь Android-приложением.';

  @override
  String get tutorYou => 'Вы';

  @override
  String get weakTopics => 'Слабые темы';

  @override
  String get welcome => 'Добро пожаловать';

  @override
  String get yearly => 'Годовая';
}
