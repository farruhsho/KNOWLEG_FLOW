// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kirghiz Kyrgyz (`ky`).
class AppLocalizationsKy extends AppLocalizations {
  AppLocalizationsKy([String locale = 'ky']) : super(locale);

  @override
  String get aboutApp => 'Тиркеме жөнүндө';

  @override
  String get accountDeleteButton => 'Аккаунтту биротоло өчүрүү';

  @override
  String accountDeleteConfirmLabel(String word) {
    return 'Ырастоо үчүн $word деп жазыңыз';
  }

  @override
  String get accountDeleteConfirmWord => 'ӨЧҮРҮҮ';

  @override
  String get accountDeleteDone => 'Аккаунт өчүрүлдү.';

  @override
  String get accountDeleteGoToLogin => 'Кирүү';

  @override
  String get accountDeleteInProgress => 'Маалыматтар өчүрүлүүдө…';

  @override
  String get accountDeleteItemAi =>
      'ЖИ-репетиторго берилген суроолордун тарыхы';

  @override
  String get accountDeleteItemCredits =>
      'Колдонулбаган кредиттер жана акысыз экзамен — алар жокко чыгарылат жана башка аккаунтка өткөрүлбөйт';

  @override
  String get accountDeleteItemExams =>
      'Сынамык экзамендердин аракеттери жана жыйынтыктары';

  @override
  String get accountDeleteItemGamification =>
      'XP, деңгээл, катар күндөр, жетишкендиктер жана рейтингдеги орундар';

  @override
  String get accountDeleteItemLogin =>
      'Кирүү маалыматтары (email жана сырсөз же Google байланышы)';

  @override
  String get accountDeleteItemProfile =>
      'Профиль: аты-жөнү, email, сүрөт, класс, аймак жана жөндөөлөр';

  @override
  String get accountDeleteItemProgress =>
      'Окуудагы прогресс, сабактардын тарыхы, каталар жана кайталоо тизмеси';

  @override
  String get accountDeleteKeptGoogle =>
      'Google Play төлөмдөрүнүн тарыхы Google\'да, сиздин Google аккаунтуңузда сакталат.';

  @override
  String get accountDeleteKeptPurchases =>
      'Сатып алуулар тууралуу анонимдүү жазуулар (күнү, товар, сумма, буйрутма номери) аты-жөнүңүз жана email жок. Алар каржылык отчеттуулук, акчаны кайтаруу жана алдамчылыктан коргоо үчүн керек.';

  @override
  String get accountDeleteSignedOut => 'Аккаунтту өчүрүү үчүн ага кириңиз.';

  @override
  String get accountDeleteTitle => 'Аккаунтту өчүрүү';

  @override
  String get accountDeleteWarningBody =>
      'Аккаунтуңуз жана окуу маалыматтарыңыз биротоло өчүрүлөт. Аларды калыбына келтирүү мүмкүн болбойт.';

  @override
  String get accountDeleteWarningTitle =>
      'Бул аракетти артка кайтаруу мүмкүн эмес';

  @override
  String get accountDeleteWhatDeletedTitle => 'Эмнелер өчүрүлөт';

  @override
  String get accountDeleteWhatKeptTitle => 'Эмнелер сакталат';

  @override
  String get accountErrorGoogle =>
      'Google аркылуу кирүү мүмкүн болбоду. Дагы бир жолу аракет кылыңыз.';

  @override
  String get accountErrorNetwork =>
      'Байланыш жок. Интернетти текшерип, кайталаңыз.';

  @override
  String get accountErrorRecentLogin =>
      'Коопсуздук үчүн кайра кирип, кайталаңыз.';

  @override
  String get accountErrorService =>
      'Аккаунтту өчүрүү убактылуу жеткиликсиз. Кийинчерээк аракет кылыңыз.';

  @override
  String get accountErrorTooManyRequests =>
      'Аракеттер өтө көп. Бир нече мүнөт күтүп, кайталаңыз.';

  @override
  String get accountErrorUnknown =>
      'Аккаунтту өчүрүү мүмкүн болбоду. Дагы бир жолу аракет кылыңыз.';

  @override
  String get accountErrorUserMismatch =>
      'Бул башка аккаунт. Өчүргүңүз келген аккаунтка кириңиз.';

  @override
  String get accountErrorWrongPassword => 'Сырсөз туура эмес.';

  @override
  String get accountReauthBody =>
      'Коопсуздук үчүн аккаунтту өчүрүүдөн мурун кайра кириңиз.';

  @override
  String get accountReauthCancel => 'Жокко чыгаруу';

  @override
  String get accountReauthConfirm => 'Ырастоо';

  @override
  String accountReauthEmail(String email) {
    return 'Аккаунт: $email';
  }

  @override
  String get accountReauthGoogle => 'Google аркылуу улантуу';

  @override
  String get accountReauthPassword => 'Сырсөз';

  @override
  String get accountReauthTitle => 'Бул сиз экениңизди ырастаңыз';

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
  String get adminAppTitle => 'ORT Master · CMS';

  @override
  String get adminApply => 'Применить';

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
  String get adminErrTitle => 'Не удалось загрузить';

  @override
  String get adminErrUnknown => 'Что-то пошло не так. Повторите попытку.';

  @override
  String adminErrValidation(String message) {
    return 'Проверка не пройдена: $message';
  }

  @override
  String get adminExamApprove => 'Одобрить';

  @override
  String get adminExamBackToDraft => 'Вернуть в черновик';

  @override
  String get adminExamChoosePlacement =>
      'Сначала выберите структуру теста и раздел.';

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
  String get adminPricingIssueFree =>
      'Бесплатных тестов на пользователя — от 0 до 10.';

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
  String get adminVariantReady =>
      'Готов к публикации (сервер проверит ещё раз).';

  @override
  String get adminVariantRecheck => 'Проверить заново';

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
  String get alreadyHaveAccount => 'Аккаунтуңуз барбы?';

  @override
  String get analytics => 'Аналитика';

  @override
  String get appName => 'ОРТ Мастер КГ';

  @override
  String get appVersion => 'Тиркеменин версиясы';

  @override
  String get appearance => 'Тышкы көрүнүш';

  @override
  String get averageScore => 'Орточо упай';

  @override
  String billingBalanceAfter(int balance) {
    return 'Баланс: $balance';
  }

  @override
  String get billingBalanceError => 'Балансты жүктөө мүмкүн болбоду.';

  @override
  String get billingBalanceTitle => 'Сиздин балансыңыз';

  @override
  String billingBuySemantics(String title, String price) {
    return 'Сатып алуу: $title, $price';
  }

  @override
  String get billingCreditRule => '1 кредит = 1 толук сынамык экзамен';

  @override
  String billingCreditsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кредит',
    );
    return '$_temp0';
  }

  @override
  String get billingErrorAccountMismatch =>
      'Бул сатып алуу тиркемедеги башка аккаунтка байланган. Аны колдонуу үчүн ошол аккаунтка кириңиз.';

  @override
  String get billingErrorAlreadyOwned =>
      'Мурунку сатып алуу дагы эле иштетилүүдө. Биз аны текшерип жатабыз.';

  @override
  String get billingErrorInvalid =>
      'Сатып алууну текшерүү мүмкүн болбоду. Эгер акча чегерилсе, Google Play аны 3 күндүн ичинде автоматтык түрдө кайтарат.';

  @override
  String get billingErrorLaunch =>
      'Сатып алууну баштоо мүмкүн болбоду. Дагы бир жолу аракет кылыңыз.';

  @override
  String get billingErrorNotSignedIn =>
      'Тест сатып алуу үчүн аккаунтка кириңиз.';

  @override
  String get billingErrorProductUnavailable =>
      'Бул сунуш мындан ары жеткиликсиз.';

  @override
  String get billingErrorStore =>
      'Google Play ката кабарлады. Дагы бир жолу аракет кылыңыз.';

  @override
  String get billingErrorStoreUnavailable =>
      'Google Play азыр жеткиликсиз. Кийинчерээк аракет кылыңыз.';

  @override
  String get billingErrorVerifyDeferred =>
      'Сатып алууну азырынча ырастоо мүмкүн болбоду. Биз автоматтык түрдө кайра аракет кылабыз — төлөм жоголбойт.';

  @override
  String get billingExternalInfo =>
      'Кошумча тесттерге жеткиликтүүлүктү биздин сайттан сатып алса болот.';

  @override
  String get billingExternalNote =>
      'Сатып алынган кредиттер бул жерде автоматтык түрдө пайда болот.';

  @override
  String get billingFreeExamAvailable =>
      'Биринчи толук сынамык экзамен — акысыз';

  @override
  String get billingFreeExamUsed => 'Акысыз сынамык экзамен колдонулуп бүткөн';

  @override
  String get billingHistoryError => 'Тарыхты жүктөө мүмкүн болбоду.';

  @override
  String get billingHistoryTooltip => 'Сатып алуулардын тарыхы';

  @override
  String get billingHonestNoGuarantee =>
      'Сынамык экзамендер машыгууга жардам берет, бирок ЖРТдагы жыйынтыкка кепилдик бербейт.';

  @override
  String get billingHonestPayment => 'Төлөм Google Play аркылуу жүргүзүлөт.';

  @override
  String get billingHonestServer =>
      'Кредиттер биздин сервер сатып алууну ырастагандан кийин гана кошулат.';

  @override
  String get billingLedgerEmpty => 'Баланстын өзгөрүүлөрү азырынча жок.';

  @override
  String get billingLoadMore => 'Дагы жүктөө';

  @override
  String get billingLoadingProducts => 'Сунуштар жүктөлүүдө…';

  @override
  String billingOrderId(String id) {
    return 'Буйрутма $id';
  }

  @override
  String billingProductSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count толук сынамык экзамен',
    );
    return '$_temp0';
  }

  @override
  String billingProductTests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тест',
    );
    return '$_temp0';
  }

  @override
  String get billingProductsEmpty =>
      'Сунуштар убактылуу жеткиликсиз. Кийинчерээк аракет кылыңыз.';

  @override
  String get billingProductsError =>
      'Google Play\'ден сунуштарды жүктөө мүмкүн болбоду.';

  @override
  String get billingProductsTitle => 'Сынамык экзамендерди сатып алуу';

  @override
  String get billingPurchasesEmpty => 'Азырынча сатып алуулар жок.';

  @override
  String get billingReasonAdminGrant => 'Колдоо кызматы кошту';

  @override
  String get billingReasonExamStart => 'Сынамык экзамен башталды';

  @override
  String get billingReasonFreeFirst => 'Акысыз биринчи экзамен';

  @override
  String get billingReasonOther => 'Баланстын өзгөрүшү';

  @override
  String get billingReasonPurchase => 'Сатып алуу';

  @override
  String get billingReasonRefund => 'Кайтаруу';

  @override
  String get billingRestore => 'Сатып алууларды калыбына келтирүү';

  @override
  String get billingRestoreDone =>
      'Текшерүү аяктады. Баланс автоматтык түрдө жаңыланат.';

  @override
  String get billingRestoreStarted =>
      'Аягына чыкпаган сатып алууларды текшерип жатабыз…';

  @override
  String get billingRetry => 'Кайталоо';

  @override
  String get billingSignInRequired =>
      'Балансты жана тарыхты көрүү үчүн аккаунтка кириңиз.';

  @override
  String get billingStateGranted => 'Кошулду';

  @override
  String get billingStateInvalid => 'Ырасталган жок';

  @override
  String get billingStatePending => 'Төлөм күтүлүүдө';

  @override
  String get billingStateRefunded => 'Кайтарылды';

  @override
  String get billingStateRevoked => 'Жокко чыгарылды';

  @override
  String get billingStatusCanceled => 'Сатып алуу жокко чыгарылды.';

  @override
  String get billingStatusGranted => 'Сатып алуу ырасталды, кредиттер кошулду.';

  @override
  String get billingStatusLaunching => 'Google Play ачылууда…';

  @override
  String get billingStatusPending =>
      'Төлөм күтүлүүдө. Google Play төлөмдү ырастаганда кредиттер кошулат.';

  @override
  String get billingStatusVerifying => 'Сатып алууну ырастап жатабыз…';

  @override
  String get billingStoreTitle => 'Тесттерге жеткиликтүүлүк';

  @override
  String get billingTabLedger => 'Кредиттердин кыймылы';

  @override
  String get billingTabPurchases => 'Сатып алуулар';

  @override
  String get billingTransactionsTitle => 'Сатып алуулардын тарыхы';

  @override
  String get billingUnavailableBody =>
      'Бул түзмөктө Google Play аркылуу төлөө жеткиликсиз. Google Play орнотулганын жана аккаунтка киргениңизди текшериңиз.';

  @override
  String get billingUnavailableTitle => 'Сатып алуу жеткиликсиз';

  @override
  String get biology => 'Биология';

  @override
  String get buyTest => 'Тестти сатып алуу';

  @override
  String get cancel => 'Жокко чыгаруу';

  @override
  String get cardPayment => 'Карта менен төлөө';

  @override
  String get chemistry => 'Химия';

  @override
  String get clear => 'Тазалоо';

  @override
  String get clearCache => 'Кэшти тазалоо';

  @override
  String get clearCacheConfirmation => 'Кэшти тазалоо?';

  @override
  String get clearCacheDesc => 'Орун бошотуу';

  @override
  String get clearCacheMessage =>
      'Бул бардык жүктөлгөн материалдарды өчүрөт. Интернетке туташканда аларды кайра жүктөй аласыз.';

  @override
  String get community => 'Коом';

  @override
  String get confirmPassword => 'Сыр сөздү ырастаңыз';

  @override
  String get continueTest => 'Тестти улантуу';

  @override
  String get correct => 'Туура';

  @override
  String get currentPlan => 'Учурдагы план';

  @override
  String get dailyGoal => 'Күндүк максат';

  @override
  String get dark => 'Караңгы';

  @override
  String get darkMode => 'Караңгы тема';

  @override
  String get dashboard => 'Башкы бет';

  @override
  String get dataAndStorage => 'Маалыматтар жана сактоо';

  @override
  String get deleteAccount => 'Аккаунтту жок кылуу';

  @override
  String get done => 'Бүттү';

  @override
  String get dontHaveAccount => 'Аккаунтуңуз жокпу?';

  @override
  String get downloadedContent => 'Жүктөлгөн материалдар';

  @override
  String get editProfile => 'Профилди өзгөртүү';

  @override
  String get email => 'Электрондук почта';

  @override
  String get emailNotifications => 'Email-билдирмелер';

  @override
  String get emailNotificationsDesc => 'Жаңылыктар жана жаңыртуулар';

  @override
  String get english => 'Англисче';

  @override
  String get error => 'Ката';

  @override
  String examAnsweredOf(int answered, int total) {
    return '$total суроодон $answered жооп берилди';
  }

  @override
  String get examAutoSubmitted => 'Убакыт бүттү. Бөлүм жөнөтүлдү.';

  @override
  String get examBuy => 'Сатып алуу';

  @override
  String get examBuyToStart => 'Тест сатып алуу';

  @override
  String get examCatalogEmpty => 'Азырынча экзамендер жок.';

  @override
  String get examCatalogIntro =>
      'ЖРТнын форматы жана убактысы боюнча толук сынамык экзамендер.';

  @override
  String get examCatalogMainTitle => 'Негизги тест';

  @override
  String get examCatalogStateLanguageTitle => 'Мамлекеттик тил';

  @override
  String get examCatalogSubjectsTitle => 'Предметтик тесттер';

  @override
  String get examClearAnswer => 'Жоопту өчүрүү';

  @override
  String get examColumnA => 'А мамычасы';

  @override
  String get examColumnB => 'Б мамычасы';

  @override
  String get examContinue => 'Улантуу';

  @override
  String examCostCredit(int credits) {
    return '1 кредит (сизде $credits)';
  }

  @override
  String get examCostFree => 'Акысыз — бул сиздин биринчи тестиңиз';

  @override
  String get examCostNeedCredit => 'Тестти баштоо үчүн 1 кредит керек.';

  @override
  String get examCostResume => 'Акысыз — сиз аракетиңизди улантып жатасыз';

  @override
  String get examDisclaimerFallback =>
      'Окуу жыйынтыгы. ЖРТнын расмий баллы эмес.';

  @override
  String examEntitlementCredits(int count) {
    return 'Кредиттер: $count';
  }

  @override
  String get examEntitlementFree => 'Биринчи тест акысыз';

  @override
  String get examEntitlementHint =>
      'Бир кредит — бир толук тест. Аяктабаган тестти улантуу акысыз.';

  @override
  String get examEntitlementNone => 'Кредит калган жок';

  @override
  String get examErrorAttemptNotFound => 'Бул аракет табылган жок.';

  @override
  String get examErrorGeneric =>
      'Бир нерсе туура эмес болду. Кайра аракет кылып көрүңүз.';

  @override
  String get examErrorNetwork =>
      'Байланыш жок. Интернетти текшерип, кайра аракет кылыңыз.';

  @override
  String get examErrorSignIn => 'Экзамен тапшыруу үчүн аккаунтуңузга кириңиз.';

  @override
  String get examErrorVariantUnavailable => 'Бул вариант азыр жеткиликсиз.';

  @override
  String get examExit => 'Тесттен чыгуу';

  @override
  String get examExitBody =>
      'Сиз жокто бөлүмдүн таймери серверде токтобойт. Жоопторуңуз сакталды — башкы экрандан уланта аласыз.';

  @override
  String get examExitLeave => 'Чыгуу';

  @override
  String get examExitStay => 'Калуу';

  @override
  String get examExitTitle => 'Тесттен чыгасызбы?';

  @override
  String get examFinishSection => 'Бөлүмдү аяктоо';

  @override
  String get examFinishSectionConfirm => 'Аяктоо';

  @override
  String examFinishSectionFlagged(int count) {
    return 'Кайра кароо үчүн белгиленгени: $count';
  }

  @override
  String examFinishSectionTitle(String section) {
    return '«$section» бөлүмүн аяктайсызбы?';
  }

  @override
  String examFinishSectionUnanswered(int count) {
    return 'Жооп берилбегени: $count';
  }

  @override
  String get examFinishSectionWarning =>
      'Аяктагандан кийин бул бөлүмгө кайра кайтууга болбойт.';

  @override
  String get examFinishedLoading => 'Тест аяктады. Жыйынтык жүктөлүүдө…';

  @override
  String get examFlag => 'Белгилөө';

  @override
  String get examHistoryAction => 'Тарых';

  @override
  String examHistoryAttempts(int count) {
    return 'Аракеттер: $count';
  }

  @override
  String get examHistoryEmpty =>
      'Аяктаган тесттер азырынча жок. Жыйынтыктарыңыз ушул жерде чыгат.';

  @override
  String examHistoryLast(String percent) {
    return 'Акыркы: $percent%';
  }

  @override
  String get examHistoryTitle => 'Экзамендердин тарыхы';

  @override
  String examHistoryTrendDown(String delta) {
    return 'мурункудан −$delta%';
  }

  @override
  String get examHistoryTrendSame => 'Мурункудай эле';

  @override
  String examHistoryTrendUp(String delta) {
    return 'мурункудан +$delta%';
  }

  @override
  String get examImageError => 'Сүрөт жүктөлгөн жок';

  @override
  String get examIntroCost => 'Баасы';

  @override
  String examIntroLanguage(String language) {
    return 'Тесттин тили: $language';
  }

  @override
  String get examIntroRules => 'Эрежелер';

  @override
  String get examIntroStructure => 'Түзүлүшү';

  @override
  String get examKeepWorking => 'Бөлүмдү улантуу';

  @override
  String get examLangEn => 'Англис тили';

  @override
  String get examLangKy => 'Кыргыз тили';

  @override
  String get examLangRu => 'Орус тили';

  @override
  String get examLanguageLabel => 'Тесттин тили';

  @override
  String get examLoading => 'Жүктөлүүдө…';

  @override
  String examMinutesCount(int minutes) {
    return '$minutes мүн.';
  }

  @override
  String get examMockTitle => 'Сынамык ЖРТ';

  @override
  String get examNext => 'Кийинки';

  @override
  String get examNextSectionTimeRunning => 'Бул бөлүмдүн убактысы башталды:';

  @override
  String get examNextSectionTitle => 'Кийинки бөлүм';

  @override
  String get examNoQuestions =>
      'Бул бөлүмдө суроолор жок. Колдоо кызматына жазыңыз.';

  @override
  String get examOfflineAutoRetry =>
      'Биз ошондой эле автоматтык түрдө кайра аракет кылабыз.';

  @override
  String get examOfflineBadge => 'Тармак жок — жооптор түзмөктө сакталууда';

  @override
  String get examOfflineBody =>
      'Жоопторуңуз түзмөктө сакталды. Кийинки бөлүм сервер ушул бөлүмдү кабыл алгандан кийин гана башталат.';

  @override
  String get examOfflineTitle => 'Байланыш жок';

  @override
  String examOnlyLanguage(String language) {
    return 'Бир гана: $language';
  }

  @override
  String examOptionSemantics(String letter) {
    return '$letter жооп варианты';
  }

  @override
  String get examPalette => 'Суроолор';

  @override
  String get examPaletteAnswered => 'Жооп берилген';

  @override
  String get examPaletteCurrent => 'Учурдагы';

  @override
  String get examPaletteFlagged => 'Белгиленген';

  @override
  String get examPaletteUnanswered => 'Жооп берилген эмес';

  @override
  String get examPartAssumption =>
      'Бул бөлүктөргө расмий бөлүнүшү жарыяланган эмес — бул болжолдуу бөлүштүрүү.';

  @override
  String get examPassage => 'Текст';

  @override
  String get examPassageHide => 'Текстти жашыруу';

  @override
  String get examPassageShow => 'Текстти көрсөтүү';

  @override
  String get examPrevious => 'Артка';

  @override
  String examQuestionOf(int current, int total) {
    return '$current-суроо ($total суроодон)';
  }

  @override
  String examQuestionsCount(int count) {
    return '$count суроо';
  }

  @override
  String get examResultBySection => 'Бөлүмдөр боюнча';

  @override
  String get examResultCorrect => 'Туура';

  @override
  String get examResultIncorrect => 'Туура эмес';

  @override
  String get examResultLevelsBody =>
      'Мамлекеттик тил боюнча тесттин расмий жыйынтыгы — 1ден 4кө чейинки деңгээл. Деңгээлдердин чектери жарыяланган эмес, ошондуктан тиркеме туура жооптордун пайызын гана көрсөтөт жана деңгээлди болжолдобойт.';

  @override
  String get examResultLevelsTitle => 'Расмий жыйынтык кантип берилет';

  @override
  String get examResultNoWeak => 'Алсыз темалар табылган жок — азаматсыз!';

  @override
  String get examResultNotEligible =>
      'Айрым бөлүмдөр кечигип жабылгандыктан, бул аракет рейтингде эсепке алынбайт.';

  @override
  String get examResultPending =>
      'Жыйынтык али эсептелип жатат. Бир нече секунддан кийин кайра аракет кылыңыз.';

  @override
  String examResultRecommendation(String topic) {
    return '«$topic» темасын кайталаңыз: теорияны кайра карап, ушул тема боюнча 10–15 машыгуу тапшырмасын иштеңиз.';
  }

  @override
  String get examResultReview => 'Жоопторду талдоо';

  @override
  String examResultScore(int correct, int total) {
    return '$total суроодон $correct туура';
  }

  @override
  String get examResultSkipped => 'Өткөрүлгөн';

  @override
  String get examResultStrong => 'Күчтүү темалар';

  @override
  String get examResultTitle => 'Жыйынтык';

  @override
  String get examResultToExams => 'Экзамендерге';

  @override
  String examResultTopicScore(int correct, int total) {
    return '$total ичинен $correct';
  }

  @override
  String get examResultWeak => 'Эмнени кайталоо керек';

  @override
  String get examResultWrongOrSkipped => 'Туура эмес же өткөрүлгөн';

  @override
  String examResultXp(int xp) {
    return 'Алынган XP: $xp';
  }

  @override
  String get examResumeAwaitingSubmit => 'Жөнөтүүнү күтүүдө';

  @override
  String get examResumeTimeUp => 'Бөлүмдүн убактысы бүттү';

  @override
  String get examResumeTitle => 'Аяктабаган тест';

  @override
  String get examRetry => 'Кайра аракет кылуу';

  @override
  String get examReviewAskTutor => 'ЖИ-репетитордон суроо';

  @override
  String examReviewCorrectAnswer(String answer) {
    return 'Туура жооп: $answer';
  }

  @override
  String get examReviewEmpty => 'Бул чыпка боюнча эч нерсе жок.';

  @override
  String get examReviewExplanation => 'Түшүндүрмө';

  @override
  String get examReviewFilterAll => 'Баары';

  @override
  String get examReviewFilterFlagged => 'Белгиленгендер';

  @override
  String get examReviewFilterWrong => 'Каталар';

  @override
  String get examReviewNoAnswer => 'жооп жок';

  @override
  String examReviewQuestionNumber(int number) {
    return '$number-суроо';
  }

  @override
  String get examReviewTitle => 'Жоопторду талдоо';

  @override
  String examReviewYourAnswer(String answer) {
    return 'Сиздин жооп: $answer';
  }

  @override
  String get examRuleForwardOnly =>
      'Бөлүмдөр так ирети менен жүрөт. Аяктаган бөлүм жабылат — ага кайра кайтууга болбойт.';

  @override
  String get examRuleFreeNavigation =>
      'Бөлүмдүн ичинде суроолордун ортосунда эркин өтүп, кийин кайтуу үчүн белгилеп койсоңуз болот.';

  @override
  String get examRuleKeepsRunning =>
      'Тиркемеден чыксаңыз да, таймер токтобойт. Жоопторуңуз түзмөктө сакталат.';

  @override
  String get examRuleNoCalculator => 'Калькулятор колдонууга болбойт.';

  @override
  String examRuleScratchpad(String sections) {
    return 'Черновикти бул бөлүмдөрдө колдонууга болот: $sections.';
  }

  @override
  String get examRuleTimer =>
      'Ар бир бөлүмдүн өз таймери бар. Аягына 5 мүнөт жана 1 мүнөт калганда эскертүү чыгат, убакыт бүткөндө бөлүм автоматтык түрдө жөнөтүлөт.';

  @override
  String get examSectionDone => 'Бөлүм кабыл алынды';

  @override
  String examSectionLabel(int index, int count) {
    return '$index-бөлүм ($count бөлүмдөн)';
  }

  @override
  String examSectionsCount(int count) {
    return '$count бөлүм';
  }

  @override
  String get examShowMore => 'Дагы көрсөтүү';

  @override
  String get examStart => 'Тестти баштоо';

  @override
  String get examStartSection => 'Бөлүмдү баштоо';

  @override
  String get examStarting => 'Тест даярдалууда…';

  @override
  String get examSubmitting => 'Бөлүм жөнөтүлүүдө…';

  @override
  String get examTabTitle => 'Экзамендер';

  @override
  String get examTimeLeftLabel => 'Калган убакыт';

  @override
  String get examTotal => 'Жалпы';

  @override
  String get examUnflag => 'Белгини алып салуу';

  @override
  String get examVariantAdvanced => 'Татаалдатылган';

  @override
  String examVariantBest(String percent) {
    return 'Эң жакшы: $percent%';
  }

  @override
  String get examVariantInProgress => 'Аткарылууда';

  @override
  String get examVariantNotStarted => 'Башталган эмес';

  @override
  String examVariantTitle(int number) {
    return '$number-вариант';
  }

  @override
  String get examVariants => 'Варианттар';

  @override
  String get examVariantsEmpty =>
      'Бул тилде азырынча варианттар жок. Жаңылары үзгүлтүксүз кошулуп турат.';

  @override
  String get examWarningFive => 'Бөлүмдүн аягына 5 мүнөт калды';

  @override
  String get examWarningOne =>
      '1 мүнөт калды — бөлүм автоматтык түрдө жөнөтүлөт';

  @override
  String get explanation => 'Түшүндүрмө';

  @override
  String get finish => 'Бүтүрүү';

  @override
  String get flashcards => 'Карталар';

  @override
  String get forgotPassword => 'Сыр сөздү унуттуңузбу?';

  @override
  String get free => 'Акысыз';

  @override
  String get geography => 'География';

  @override
  String get getStarted => 'Баштоо';

  @override
  String get googleSignIn => 'Google аркылуу кирүү';

  @override
  String get grade10 => '10-класс';

  @override
  String get grade11 => '11-класс';

  @override
  String get grade9 => '9-класс';

  @override
  String get graduate => 'Бүтүрүүчү';

  @override
  String get history => 'Кыргызстандын тарыхы';

  @override
  String get hours => 'саат';

  @override
  String get incorrect => 'Туура эмес';

  @override
  String get kgs => 'сом';

  @override
  String get kyrgyz => 'Кыргызча';

  @override
  String get kyrgyzLanguage => 'Кыргыз тили';

  @override
  String get language => 'Тил';

  @override
  String get learnAchAccuracy90Desc => 'Сынамык экзаменде 90% чогултуңуз';

  @override
  String get learnAchAccuracy90Title => '90% тактык';

  @override
  String get learnAchAnalogiesDesc => 'Аналогиялар бөлүмүндө жогорку жыйынтык';

  @override
  String get learnAchAnalogiesTitle => 'Аналогиялардын чебери';

  @override
  String get learnAchDays30Desc => '30 башка-башка күнү машыгыңыз';

  @override
  String get learnAchDays30Title => '30 күн машыгуу';

  @override
  String get learnAchExamChampionDesc => '10 сынамык экзаменди аяктаңыз';

  @override
  String get learnAchExamChampionTitle => 'Сынамык экзамендердин чемпиону';

  @override
  String get learnAchFirstLessonDesc => 'Биринчи сабакты өтүңүз';

  @override
  String get learnAchFirstLessonTitle => 'Биринчи сабак';

  @override
  String get learnAchMathExpertDesc => 'Үч сынамык экзаменде математикадан 90%';

  @override
  String get learnAchMathExpertTitle => 'Математика боюнча эксперт';

  @override
  String get learnAchReaderDesc => 'Окуу бөлүмүндө жогорку жыйынтык';

  @override
  String get learnAchReaderTitle => 'Окурман';

  @override
  String get learnAchStreak7Desc => '7 күн катары менен машыгыңыз';

  @override
  String get learnAchStreak7Title => 'Катары менен бир жума';

  @override
  String get learnAchXp100Desc => '100 XP топтоңуз';

  @override
  String get learnAchXp100Title => 'Алгачкы 100 XP';

  @override
  String get learnAchievementLocked => 'Азырынча алына элек';

  @override
  String get learnAchievementUnlocked => 'Алынды';

  @override
  String learnAchievementUnlockedOn(String date) {
    return '$date алынды';
  }

  @override
  String get learnAchievementsServerNote =>
      'Жетишкендиктер сервердеги жыйынтыктар боюнча автоматтык түрдө эсептелет.';

  @override
  String get learnAchievementsTitle => 'Жетишкендиктер';

  @override
  String learnAchievementsUnlocked(int n, int total) {
    return '$total ичинен $n ачылды';
  }

  @override
  String learnAnswersCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n жооп',
    );
    return '$_temp0';
  }

  @override
  String get learnAskTutor => 'ЖИ-репетитордон суроо';

  @override
  String learnAvgPerQuestion(int seconds) {
    return 'Бир суроого орточо $seconds сек';
  }

  @override
  String get learnBack => 'Артка';

  @override
  String get learnBackHome => 'Башкы бетке';

  @override
  String get learnBestResult => 'Эң жакшы жыйынтык';

  @override
  String get learnCorrect => 'Туура!';

  @override
  String learnCorrectAnswerIs(String answer) {
    return 'Туура жооп: $answer';
  }

  @override
  String get learnDailyLessonTitle => 'Күндүн сабагы';

  @override
  String get learnDifficultyEasy => 'Жеңил';

  @override
  String get learnDifficultyHard => 'Татаал';

  @override
  String get learnDifficultyMedium => 'Орточо';

  @override
  String learnDurationMinutes(int n) {
    return '$n мүн.';
  }

  @override
  String get learnElapsedTime => 'Өткөн убакыт';

  @override
  String get learnErrorGeneric =>
      'Маалыматты жүктөө мүмкүн болбоду. Кайра аракет кылыңыз.';

  @override
  String get learnErrorNotFound => 'Материал табылган жок.';

  @override
  String get learnErrorOffline =>
      'Байланыш жок. Интернетти текшерип, кайра аракет кылыңыз.';

  @override
  String get learnErrorPermission =>
      'Маалыматка кирүү мүмкүн эмес. Аккаунтка кайра кириңиз.';

  @override
  String get learnExamHistoryAll => 'Бардык тарых';

  @override
  String get learnExamHistoryEmpty =>
      'Сиз азырынча бир да сынамык экзаменди аяктай элексиз.';

  @override
  String get learnExamHistoryTitle => 'Акыркы аракеттер';

  @override
  String get learnExamHistoryUnavailable =>
      'Экзамендердин тарыхы азыр жеткиликсиз.';

  @override
  String get learnExamResultUnofficial =>
      'Окуу жыйынтыгы, ЖРТнын расмий баллы эмес.';

  @override
  String get learnExamResultsTitle => 'Сынамык экзамендер';

  @override
  String get learnExamSectionsTitle => 'Бөлүмдөр боюнча орточо жыйынтык';

  @override
  String learnExitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count суроого берилген жоопторду сактоого болот.',
      zero: 'Сиз азырынча бир да суроого жооп бере элексиз.',
    );
    return '$_temp0';
  }

  @override
  String get learnExitContinue => 'Улантуу';

  @override
  String get learnExitDiscard => 'Сактабай чыгуу';

  @override
  String get learnExitFinish => 'Аяктап, сактоо';

  @override
  String get learnExitTitle => 'Машыгууну аяктайсызбы?';

  @override
  String get learnExplanation => 'Түшүндүрмө';

  @override
  String get learnFinish => 'Аяктоо';

  @override
  String get learnHandbookFactsUnavailable =>
      'Экзамендин түзүлүшүн жүктөө мүмкүн болбоду.';

  @override
  String get learnHandbookNotFound => 'Маалымдаманын бөлүмү табылган жок';

  @override
  String get learnHandbookRussianOnly =>
      'Бул бөлүм орус тилинде гана жеткиликтүү.';

  @override
  String get learnHandbookSearch => 'Маалымдамадан издөө';

  @override
  String learnHandbookSections(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n бөлүм',
    );
    return '$_temp0';
  }

  @override
  String get learnHandbookTitle => 'Маалымдама';

  @override
  String get learnHbAssumption => '(бөлүнүшү шарттуу)';

  @override
  String learnHbMainTest(String year) {
    return 'ЖРТнын негизги тести ($year)';
  }

  @override
  String learnHbMainTotal(int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions тапшырма',
    );
    return 'Бардыгы: $_temp0, $minutes мүн.';
  }

  @override
  String learnHbMaxScore(int score) {
    return 'Негизги тесттин расмий максималдуу баллы — $score.';
  }

  @override
  String learnHbPartLine(String title, int questions, int options) {
    String _temp0 = intl.Intl.pluralLogic(
      options,
      locale: localeName,
      other: '$options жооп варианты',
    );
    return '$title: $questions тапшырма, $_temp0';
  }

  @override
  String learnHbSectionLine(String title, int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions тапшырма',
    );
    return '$title: $_temp0, $minutes мүн.';
  }

  @override
  String learnHbStateLanguage(int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions тапшырма',
    );
    return '$_temp0, $minutes мүн. Сертификат үчүн милдеттүү, жыйынтыгы 1–4-деңгээл менен берилет.';
  }

  @override
  String get learnHbSubjectTests => 'Предметтик тесттер (тандоо боюнча)';

  @override
  String learnHbThresholdCollege(int n) {
    return 'Колледждер үчүн: негизги тест боюнча $n.';
  }

  @override
  String learnHbThresholdsUniversity(int main, int subject) {
    return 'ЖОЖдор үчүн босого балл: негизги тест боюнча $main, предметтик тесттер боюнча $subject (2026–2027).';
  }

  @override
  String get learnHbThresholdsYearly =>
      'Босого баллдар жыл сайын жаңыдан бекитилет — testing.kg сайтынан текшериңиз.';

  @override
  String get learnLeaderboardAllTime => 'Бардык убакыт';

  @override
  String get learnLeaderboardAnonymous => 'Окуучу';

  @override
  String get learnLeaderboardBySubject => 'Предметтер боюнча';

  @override
  String get learnLeaderboardEmpty => 'Рейтинг азырынча бош';

  @override
  String get learnLeaderboardEmptyBody =>
      'Окуучулар XP ала баштаганда пайда болот.';

  @override
  String get learnLeaderboardNotRanked =>
      'Сиз азырынча бул рейтингде жоксуз. Сабактар, машыгуу жана сынамык экзамендер үчүн алынган XP бул жерге автоматтык түрдө кошулат.';

  @override
  String get learnLeaderboardSubjectEmptyBody =>
      'Окуучулар ушул тест боюнча сынамык экзамендерди тапшырганда толо баштайт.';

  @override
  String get learnLeaderboardSubjectHint =>
      'Бул жерде тандалган тест боюнча ушул аптадагы сынамык экзамендерден алынган XP гана эсептелет.';

  @override
  String get learnLeaderboardSubjectNotRanked =>
      'Сиз азырынча бул рейтингде жоксуз. Бул жерде ушул тест боюнча сынамык экзамендерден алынган XP гана эсептелет.';

  @override
  String get learnLeaderboardTitle => 'Рейтинг';

  @override
  String get learnLeaderboardWeekly => 'Апта';

  @override
  String learnLeaderboardYou(String name) {
    return '$name (сиз)';
  }

  @override
  String get learnLessonAllDone => 'Бул предмет боюнча бардык сабактар өтүлдү.';

  @override
  String get learnLessonCommonMistakes => 'Көп кетирилген каталар';

  @override
  String get learnLessonCompletedToast => 'Сабак өтүлдү деп белгиленди.';

  @override
  String get learnLessonDone => 'Сабак өтүлдү';

  @override
  String learnLessonExampleN(int n) {
    return '$n-мисал';
  }

  @override
  String get learnLessonExamples => 'Мисалдар';

  @override
  String get learnLessonFormulas => 'Формулалар';

  @override
  String get learnLessonHideSolution => 'Чыгарылышты жашыруу';

  @override
  String get learnLessonMarkDone => 'Сабакты өтүлдү деп белгилөө';

  @override
  String get learnLessonMaterials => 'Материалдар';

  @override
  String get learnLessonNoContent => 'Сабактын мазмуну азырынча кошула элек.';

  @override
  String get learnLessonNotFound => 'Сабак табылган жок';

  @override
  String get learnLessonNotFoundBody =>
      'Сабак азырынча жарыялана элек же өчүрүлгөн болушу мүмкүн.';

  @override
  String learnLessonNumber(int n) {
    return '$n-сабак';
  }

  @override
  String get learnLessonOpenPdf => 'PDF ачуу';

  @override
  String learnLessonPracticeBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Сабактын темасы боюнча $n суроо.',
    );
    return '$_temp0';
  }

  @override
  String get learnLessonPracticeSubjectBody =>
      'Материалды ушул предмет боюнча суроолор менен бекемдеңиз.';

  @override
  String get learnLessonPracticeTitle => 'Сабак боюнча машыгуу';

  @override
  String get learnLessonShowSolution => 'Чыгарылышты көрсөтүү';

  @override
  String get learnLessonSummary => 'Кыскача';

  @override
  String get learnLessonTitle => 'Сабак';

  @override
  String get learnLessonWatchVideo => 'Видеону көрүү';

  @override
  String learnLessonsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n сабак',
    );
    return '$_temp0';
  }

  @override
  String get learnLessonsHeading => 'Сабактар';

  @override
  String learnLevelN(int n) {
    return '$n-деңгээл';
  }

  @override
  String get learnLinkFailed => 'Шилтемени ачуу мүмкүн болбоду.';

  @override
  String get learnLoadingLesson => 'Сабак жүктөлүүдө…';

  @override
  String get learnLoadingQuestions => 'Суроолор тандалууда…';

  @override
  String get learnLoadingSubject => 'Предмет жүктөлүүдө…';

  @override
  String get learnLoadingSubjects => 'Предметтер жүктөлүүдө…';

  @override
  String learnMinutes(int n) {
    return '$n мүн.';
  }

  @override
  String get learnMistakeFromExam => 'Сынамык экзамендеги суроо';

  @override
  String get learnMistakeMarkReviewed => 'Кайталанды деп белгилөө';

  @override
  String get learnMistakeOpenReview => 'Талдоо';

  @override
  String get learnMistakePractice => 'Кайталоо';

  @override
  String get learnMistakeQuestion => 'Суроо';

  @override
  String get learnMistakeResolve => 'Түшүндүм';

  @override
  String learnMistakeReviewOn(String date) {
    return '$date кайталоо';
  }

  @override
  String get learnMistakeReviewToday => 'бүгүн кайталоо';

  @override
  String get learnMistakeReviewedPrompt =>
      'Бул суроону талдадыңызбы? Белгилеңиз — ал кийинчерээк кайра чыгат.';

  @override
  String learnMistakeWrongCount(int n) {
    return 'ката: $n';
  }

  @override
  String get learnMistakesAllSubjects => 'Бардык предметтер';

  @override
  String learnMistakesDueToday(int n) {
    return 'Бүгүн кайталоо керек: $n';
  }

  @override
  String get learnMistakesEmptyBody =>
      'Машыгуудагы жана экзамендердеги туура эмес жооптор бул жерде пайда болот.';

  @override
  String get learnMistakesEmptyTitle => 'Кайталай турган каталар жок';

  @override
  String get learnMistakesFilterAll => 'Баары';

  @override
  String get learnMistakesFilterDue => 'Бүгүн';

  @override
  String get learnMistakesNothingDue =>
      'Бүгүнкүсү баары кайталанды. Эртең кириңиз.';

  @override
  String learnMistakesPracticeN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n суроону кайталоо',
    );
    return '$_temp0';
  }

  @override
  String get learnMistakesPracticeTitle => 'Каталарды кайталоо';

  @override
  String get learnMistakesSrsNote =>
      'Ар бир ката 1, 3, 7, 14 жана 30 күндөн кийин кайра чыгат. Туура жооп аны кийинки мөөнөткө жылдырат, туура эмес жооп — башына кайтарат.';

  @override
  String get learnMistakesTitle => 'Каталар жана кайталоо';

  @override
  String get learnMore => 'Дагы';

  @override
  String get learnNext => 'Кийинки';

  @override
  String get learnNextLesson => 'Кийинки сабак';

  @override
  String get learnNoExplanation =>
      'Бул суроого түшүндүрмө азырынча кошула элек.';

  @override
  String get learnNoLessonsYet =>
      'Сабактар азырынча кошула элек — машыгуудан баштаңыз.';

  @override
  String get learnNoQuestionsBody =>
      'Бул жерде азырынча текшерилген суроолор жок. Кийинчерээк кириңиз же тез машыгууну байкап көрүңүз.';

  @override
  String get learnNoQuestionsTitle => 'Азырынча суроолор жок';

  @override
  String get learnNoSearchResults => 'Эч нерсе табылган жок';

  @override
  String get learnNoSubjectsBody =>
      'Окуу материалдары жакында пайда болот. Азырынча тез машыгуудан өтсөңүз болот.';

  @override
  String get learnNoSubjectsTitle => 'Азырынча предметтер жок';

  @override
  String get learnOpenMistakes => 'Каталар менен иштөө';

  @override
  String get learnPracticeAgain => 'Дагы бир машыгуу';

  @override
  String get learnPracticeBySubjectEmpty =>
      'Бир нече суроо чечиңиз — бул жерде предметтер боюнча тактык пайда болот.';

  @override
  String get learnPracticeBySubjectTitle => 'Предметтер боюнча машыгуу';

  @override
  String learnPracticeCorrectOfTotal(int correct, int total) {
    return '$total суроодон $correct туура';
  }

  @override
  String get learnPracticeNotOrtNote =>
      'Бул машыгуунун жыйынтыгы, ЖРТнын баллы эмес: кыска суроолор топтому боюнча экзамендин баллын баалоого болбойт.';

  @override
  String learnPracticePercentLabel(int percent) {
    return 'Машыгуу: $percent%';
  }

  @override
  String get learnPracticeSubject => 'Предмет боюнча машыгуу';

  @override
  String get learnPracticeTitle => 'Машыгуу';

  @override
  String get learnPracticeVerdictExcellent => 'Эң сонун! Ушундай улантыңыз.';

  @override
  String get learnPracticeVerdictFair =>
      'Жаман эмес. Каталарды талдаңыз — бул жыйынтыкты эң тез жакшыртат.';

  @override
  String get learnPracticeVerdictGood => 'Жакшы. Аз эле калды.';

  @override
  String get learnPracticeVerdictLow =>
      'Көбүрөөк машыгуу керек. Каталарды талдоодон баштаңыз.';

  @override
  String get learnProgressEmptyBody =>
      'Сабак же машыгуудан өтүңүз — бул жерде сиздин чыныгы статистикаңыз пайда болот.';

  @override
  String get learnProgressEmptyTitle => 'Азырынча маалымат жок';

  @override
  String get learnProgressTitle => 'Менин прогрессим';

  @override
  String learnQuestAnswer(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n суроого жооп бериңиз',
    );
    return '$_temp0';
  }

  @override
  String get learnQuestCompleteSet => 'Бир машыгууну аягына чыгарыңыз';

  @override
  String learnQuestRun(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Катары менен $n туура жооп',
    );
    return '$_temp0';
  }

  @override
  String learnQuestionNumber(int n) {
    return '$n-суроо';
  }

  @override
  String learnQuestionProgress(int current, int total) {
    return 'Суроо $current / $total';
  }

  @override
  String learnQuestsDone(int done, int total) {
    return '$total ичинен $done аткарылды';
  }

  @override
  String learnQuestsReset(int h, int m) {
    return '$h саат $m мүнөттөн кийин жаңыланат';
  }

  @override
  String get learnQuestsTitle => 'Күндүн тапшырмалары';

  @override
  String get learnQuickPracticeTitle => 'Тез машыгуу';

  @override
  String learnRecDueMistakesTitle(int n) {
    return 'Каталарды кайталоону сунуштайбыз ($n)';
  }

  @override
  String get learnRecDueMistakesWhy =>
      '…анткени бүгүн аларды кайталоо мөөнөтү келди: ушинтип материал узакка эсте калат.';

  @override
  String learnRecMoreDataTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Дагы $n суроо чечүүнү сунуштайбыз',
    );
    return '$_temp0';
  }

  @override
  String get learnRecMoreDataWhy =>
      '…анткени тактык боюнча тыянактар болжол менен 20 жооптон кийин ишенимдүү болот.';

  @override
  String get learnRecNoExamTitle => 'Сынамык экзамен тапшырууну сунуштайбыз';

  @override
  String get learnRecNoExamWhy =>
      '…анткени азырынча бардык бөлүмдөр боюнча бир да жыйынтык жок — ансыз кайсы бөлүм начар экени көрүнбөйт.';

  @override
  String get learnRecOpenExams => 'Экзамендерге';

  @override
  String learnRecWeakSectionTitle(String section) {
    return '«$section» бөлүмүн күчөтүүнү сунуштайбыз';
  }

  @override
  String learnRecWeakSectionWhy(int percent) {
    return '…анткени сынамык экзамендерде ал жерде орточо $percent% туура жооп — бул эң алсыз бөлүм.';
  }

  @override
  String learnRecWeakSubjectTitle(String subject) {
    return '«$subject» боюнча машыгууну сунуштайбыз';
  }

  @override
  String learnRecWeakSubjectWhy(int percent, int count) {
    return '…анткени ал жердеги тактык $percent% — башка предметтерге караганда төмөн (жооптордун саны: $count).';
  }

  @override
  String learnRecWeakTopicTitle(String topic) {
    return '«$topic» темасын кайталоону сунуштайбыз';
  }

  @override
  String learnRecWeakTopicWhy(int percent) {
    return '…анткени бул тема боюнча туура жооптор $percent% гана.';
  }

  @override
  String get learnRecommendationsNone =>
      'Азырынча баары жакшы — ушул темпте улантыңыз.';

  @override
  String get learnRecommendationsTitle => 'Сунуштар';

  @override
  String get learnResultsEmptyBody =>
      'Машыгуудан өтүңүз — бул жерде жоопторуңуздун талдоосу пайда болот.';

  @override
  String get learnResultsEmptyTitle => 'Азырынча жыйынтык жок';

  @override
  String get learnResultsTitle => 'Машыгуунун жыйынтыгы';

  @override
  String get learnReviewAnswers => 'Жоопторду талдоо';

  @override
  String get learnRightAnswer => 'Туура жооп';

  @override
  String get learnSearchSubjects => 'Предметтерди издөө';

  @override
  String get learnSignIn => 'Кирүү';

  @override
  String get learnSignInToPractice =>
      'Машыгуу жана прогрессти сактоо үчүн аккаунтка кириңиз.';

  @override
  String get learnSignInToSave => 'Прогрессти сактоо үчүн аккаунтка кириңиз.';

  @override
  String get learnSkip => 'Өткөрүп жиберүү';

  @override
  String get learnSkipAndFinish => 'Өткөрүп, аяктоо';

  @override
  String get learnStartPractice => 'Машыгууну баштоо';

  @override
  String get learnStatAnswered => 'Машыгуудагы жооптор';

  @override
  String learnStatBestStreak(int n) {
    return 'Эң жакшысы: $n';
  }

  @override
  String get learnStatCorrect => 'Туура';

  @override
  String get learnStatExams => 'Сынамык экзамендер';

  @override
  String learnStatLessonsCompleted(int n) {
    return 'өтүлгөн сабактар: $n';
  }

  @override
  String get learnStatLessonsDone => 'Өтүлгөн сабактар';

  @override
  String get learnStatLevel => 'Деңгээл';

  @override
  String get learnStatPracticeAccuracy => 'Машыгуудагы тактык';

  @override
  String get learnStatPracticeOnly => 'машыгуу гана';

  @override
  String get learnStatPracticeTime => 'Машыгуудагы убакыт';

  @override
  String get learnStatPracticeTimeHint => 'аяктаган машыгуулар боюнча';

  @override
  String learnStatSessions(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n машыгуу',
    );
    return '$_temp0';
  }

  @override
  String get learnStatSkipped => 'Өткөрүлдү';

  @override
  String get learnStatStreak => 'Катары менен, күн';

  @override
  String get learnStatTime => 'Убакыт';

  @override
  String get learnStatWrong => 'Туура эмес';

  @override
  String learnStreakDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n күн',
    );
    return '$_temp0';
  }

  @override
  String get learnSubjectNotFound => 'Предмет табылган жок';

  @override
  String get learnSubjectNotFoundBody => 'Шилтеме эскирген болушу мүмкүн.';

  @override
  String get learnSubjectsTitle => 'Предметтер';

  @override
  String get learnWeakTopicsEmpty =>
      'Алсыз темаларды аныктоо үчүн жооптор жетишсиз (тема боюнча кеминде 5 жооп керек).';

  @override
  String get learnWeakTopicsTitle => 'Кайталоо керек болгон темалар';

  @override
  String get learnWrong => 'Туура эмес';

  @override
  String learnXpAwarded(int xp) {
    return '+$xp XP';
  }

  @override
  String get learnXpNone => 'Бул машыгуу үчүн XP берилген жок.';

  @override
  String get learnXpPending => 'XP эсептелүүдө…';

  @override
  String get learnXpQueued => 'Байланыш калыбына келгенде XP эсептелет.';

  @override
  String learnXpShort(int xp) {
    return '$xp XP';
  }

  @override
  String learnXpToNextLevel(int xp, int level) {
    return '$level-деңгээлге чейин $xp XP';
  }

  @override
  String learnXpTotal(int xp) {
    return 'Бардыгы $xp XP';
  }

  @override
  String get learnYourAnswer => 'Сиздин жооп';

  @override
  String get lessons => 'Сабактар';

  @override
  String get light => 'Жарык';

  @override
  String get loading => 'Жүктөлүүдө...';

  @override
  String get login => 'Кирүү';

  @override
  String get logout => 'Чыгуу';

  @override
  String get mathematics => 'Математика';

  @override
  String get mbankPayment => 'MBank аркылуу төлөө';

  @override
  String get mockTest => 'Сынамык экзамен';

  @override
  String get mockTestDesc => 'Сынамык экзаменди чыныгы форматта тапшырыңыз';

  @override
  String get mockTestTitle => 'ЖРТнын толук симуляциясы';

  @override
  String get monthly => 'Айлык';

  @override
  String get myProgress => 'Менин прогрессим';

  @override
  String get next => 'Кийинки';

  @override
  String get nextOrtDate => 'ЖРТга кийинки каттоо';

  @override
  String get noConnection => 'Интернет байланышы жок';

  @override
  String get notifications => 'Билдирмелер';

  @override
  String get onboardingDesc1 =>
      'ЖРТга даярдануу үчүн бардык предметтер боюнча машыгуу тесттерин өтүңүз';

  @override
  String get onboardingDesc2 =>
      'Жетишкендиктериңизди көзөмөлдөп, алсыз жактарды аныктаңыз';

  @override
  String get onboardingDesc3 =>
      'ЖРТнын чыныгы форматында жана убактысында толук симуляцияларды өтүңүз';

  @override
  String get onboardingTitle1 => 'ЖРТга даярданыңыз';

  @override
  String get onboardingTitle2 => 'Прогрессти көзөмөлдөө';

  @override
  String get onboardingTitle3 => 'Сынамык экзамендер';

  @override
  String get orContinueWith => 'же менен улантыңыз';

  @override
  String get password => 'Сыр сөз';

  @override
  String get payNow => 'Төлөө';

  @override
  String get payment => 'Төлөм';

  @override
  String get paymentMethod => 'Төлөө ыкмасы';

  @override
  String get phoneSignIn => 'Телефон аркылуу кирүү';

  @override
  String get physics => 'Физика';

  @override
  String get practiceQuiz => 'Практикалык тест';

  @override
  String get previous => 'Мурунку';

  @override
  String get price => 'Баасы';

  @override
  String get privacy => 'Купуялуулук';

  @override
  String get privacyPolicy => 'Купуялуулук саясаты';

  @override
  String get profile => 'Профиль';

  @override
  String get progress => 'Прогресс';

  @override
  String get pushNotifications => 'Push-билдирмелер';

  @override
  String get pushNotificationsDesc => 'Сабактар жөнүндө эстеткичтер';

  @override
  String get retry => 'Кайталоо';

  @override
  String get review => 'Карап чыгуу';

  @override
  String get russian => 'Орусча';

  @override
  String get russianLanguage => 'Орус тили';

  @override
  String get score => 'Упай';

  @override
  String get section1 => 'Негизги тест';

  @override
  String get section2 => 'Предметтик тест';

  @override
  String get section3 => 'Тил тести';

  @override
  String get selectGrade => 'Классты тандаңыз';

  @override
  String get selectLanguage => 'Тилди тандаңыз';

  @override
  String get selectSubjects => 'Алсыз предметтерди тандаңыз';

  @override
  String get settings => 'Жөндөөлөр';

  @override
  String get shellAuthConfirmPasswordLabel => 'Сырсөздү кайталаңыз';

  @override
  String get shellAuthContinueWithGoogle => 'Google менен улантуу';

  @override
  String get shellAuthEmailInvalid =>
      'Даректи текшериңиз, мисалы name@example.com';

  @override
  String get shellAuthEmailLabel => 'Электрондук почта';

  @override
  String get shellAuthEmailRequired => 'Электрондук почтаны жазыңыз';

  @override
  String get shellAuthErrorDifferentCredential =>
      'Бул почта кирүүнүн башка жолуна байланган.';

  @override
  String get shellAuthErrorEmailInUse =>
      'Бул почта мурунтан катталган. Аккаунтуңузга кириңиз.';

  @override
  String get shellAuthErrorGoogleUnavailable =>
      'Бул түзмөктө Google аркылуу кирүү азырынча жеткиликсиз. Электрондук почта менен кириңиз.';

  @override
  String get shellAuthErrorInvalidCredentials =>
      'Электрондук почта же сырсөз туура эмес.';

  @override
  String get shellAuthErrorNetwork =>
      'Байланыш жок. Интернетти текшерип, кайра аракет кылыңыз.';

  @override
  String get shellAuthErrorNotAllowed =>
      'Кирүүнүн бул жолу убактылуу жеткиликсиз.';

  @override
  String get shellAuthErrorTooManyRequests =>
      'Аракет өтө көп болду. Бир нече мүнөт күтүп, кайра аракет кылыңыз.';

  @override
  String get shellAuthErrorUnknown =>
      'Бир нерсе туура эмес болду. Кайра аракет кылыңыз.';

  @override
  String get shellAuthErrorUserDisabled =>
      'Бул аккаунт бөгөттөлгөн. Колдоо кызматына кайрылыңыз.';

  @override
  String get shellAuthErrorUserNotFound =>
      'Бул почта менен аккаунт табылган жок. Адегенде катталыңыз.';

  @override
  String get shellAuthForgotPassword => 'Сырсөздү унуттуңузбу?';

  @override
  String get shellAuthHidePassword => 'Сырсөздү жашыруу';

  @override
  String get shellAuthNameLabel => 'Атыңыз';

  @override
  String get shellAuthNameRequired => 'Атыңызды жазыңыз';

  @override
  String get shellAuthNameTooShort => 'Аты өтө кыска';

  @override
  String get shellAuthOr => 'же';

  @override
  String shellAuthPasswordHint(int min) {
    return 'Кеминде $min белги, тамгалар жана сандар';
  }

  @override
  String get shellAuthPasswordLabel => 'Сырсөз';

  @override
  String get shellAuthPasswordMismatch => 'Сырсөздөр дал келбейт';

  @override
  String get shellAuthPasswordRequired => 'Сырсөздү жазыңыз';

  @override
  String shellAuthPasswordTooShort(int min) {
    return 'Сырсөз кеминде $min белгиден турушу керек';
  }

  @override
  String get shellAuthPasswordTooWeak =>
      'Тамгаларды да, сандарды да колдонуңуз';

  @override
  String get shellAuthResetMessage =>
      'Аккаунтуңуздун электрондук почтасын жазыңыз — жаңы сырсөз коюу үчүн шилтеме жөнөтөбүз.';

  @override
  String get shellAuthResetSend => 'Жөнөтүү';

  @override
  String get shellAuthResetSent =>
      'Бул почта менен аккаунт бар болсо, ага шилтеме жөнөтүлдү.';

  @override
  String get shellAuthResetTitle => 'Сырсөздү калыбына келтирүү';

  @override
  String get shellAuthShowPassword => 'Сырсөздү көрсөтүү';

  @override
  String get shellBootErrorMessage =>
      'Интернет байланышын текшерип, кайра аракет кылыңыз.';

  @override
  String get shellBootErrorTitle => 'Тиркемени иштетүү мүмкүн болбоду';

  @override
  String get shellCancel => 'Жокко чыгаруу';

  @override
  String get shellDaily10Desc => 'Жеңил башталыш';

  @override
  String get shellDaily20Desc => 'Туруктуу темп';

  @override
  String get shellDaily30Desc => 'Интенсивдүү даярдык';

  @override
  String shellDailyMinutes(int minutes) {
    return 'Күнүнө $minutes мүн.';
  }

  @override
  String get shellExitConfirm => 'Чыгуу';

  @override
  String get shellExitMessage => 'Прогрессиңиз сакталды.';

  @override
  String get shellExitTitle => 'Тиркемеден чыгасызбы?';

  @override
  String get shellGoHome => 'Башкы бетке';

  @override
  String get shellGoalBand110Desc => 'Бекем негиз';

  @override
  String get shellGoalBand150Desc => 'Күчтүү жыйынтык';

  @override
  String get shellGoalBand190Desc => 'Эң жогорку жыйынтык';

  @override
  String get shellGoalUnsure => 'Азырынча билбейм';

  @override
  String get shellGradeGraduate => 'Бүтүрүүчү';

  @override
  String get shellGradeLabel => 'Класс';

  @override
  String shellGradeNumber(int grade) {
    return '$grade-класс';
  }

  @override
  String get shellHide => 'Жашыруу';

  @override
  String shellHomeBestStreak(int count) {
    return 'Рекорд: $count';
  }

  @override
  String get shellHomeBuyExam => 'Сынамык экзамен сатып алуу';

  @override
  String shellHomeCredits(int count) {
    return 'Жеткиликтүү сынамык экзамендер: $count';
  }

  @override
  String get shellHomeDailyGoal => 'Күндүк максат';

  @override
  String get shellHomeEmptyStatsMessage =>
      'Тапшырма чечиңиз же сабак өтүңүз — бул жерде күн катарыңыз жана күндүк прогрессиңиз көрүнөт.';

  @override
  String get shellHomeEmptyStatsTitle => 'Күн катарын бүгүн баштаңыз';

  @override
  String get shellHomeEntitlementError =>
      'Жеткиликтүүлүктү текшерүү мүмкүн болбоду · Кайталоо';

  @override
  String get shellHomeFreeExam => 'Акысыз сынамык экзамен жеткиликтүү';

  @override
  String shellHomeGoalMinutes(int minutes) {
    return 'Максатыңыз: күнүнө $minutes мүн.';
  }

  @override
  String get shellHomeGoalReached => 'Күндүк максат аткарылды!';

  @override
  String get shellHomeGreeting => 'Салам!';

  @override
  String shellHomeGreetingName(String name) {
    return 'Салам, $name!';
  }

  @override
  String shellHomeLevelXp(int level, int xp) {
    return '$level-деңгээл · $xp XP';
  }

  @override
  String get shellHomeNextStepError => 'Сунушту жүктөө мүмкүн болбоду.';

  @override
  String get shellHomeReminderEnable => 'Күйгүзүү';

  @override
  String get shellHomeReminderMessage =>
      'Күнүнө бир кыска эскертүү күн катарын үзбөөгө жардам берет.';

  @override
  String get shellHomeReminderTitle => 'Окуу тууралуу эскертип турабызбы?';

  @override
  String get shellHomeSetupAction => 'Жөндөө';

  @override
  String get shellHomeSetupMessage =>
      'Классыңызды, аймагыңызды жана каалаган баллыңызды көрсөтүңүз — сунуштар тагыраак болот.';

  @override
  String get shellHomeSetupTitle => 'Максатыңызды коюңуз';

  @override
  String get shellHomeStatsError => 'Прогрессти жүктөө мүмкүн болбоду.';

  @override
  String shellHomeStreakDays(int count) {
    return 'Катары менен $count күн';
  }

  @override
  String get shellHomeStreakNone => 'Азырынча күн катары жок';

  @override
  String get shellHomeSubtitle => 'ЖРТга даярданууну улантабыз';

  @override
  String shellHomeTodayXp(int today) {
    return 'Бүгүн: $today XP';
  }

  @override
  String shellHomeTodayXpOfGoal(int today, int goal) {
    return 'Бүгүн: $today / $goal XP';
  }

  @override
  String get shellLangEn => 'Англисче';

  @override
  String get shellLangEnNative => 'English';

  @override
  String get shellLangKy => 'Кыргызча';

  @override
  String get shellLangKyNative => 'Кыргызча';

  @override
  String get shellLangRu => 'Орусча';

  @override
  String get shellLangRuNative => 'Русский';

  @override
  String get shellLater => 'Кийин';

  @override
  String get shellLinkOpenFailed => 'Шилтемени ачуу мүмкүн болбоду.';

  @override
  String get shellLoading => 'Жүктөлүүдө';

  @override
  String get shellLoginButton => 'Кирүү';

  @override
  String get shellLoginCreateAccount => 'Түзүү';

  @override
  String get shellLoginNoAccount => 'Аккаунтуңуз жокпу?';

  @override
  String get shellLoginSubtitle => 'ЖРТга даярданууну улантуу үчүн кириңиз.';

  @override
  String get shellLoginTitle => 'Кайра кош келиңиз';

  @override
  String get shellNavExams => 'Экзамендер';

  @override
  String get shellNavHome => 'Башкы бет';

  @override
  String get shellNavLearn => 'Окуу';

  @override
  String get shellNavProfile => 'Профиль';

  @override
  String get shellNavProgress => 'Прогресс';

  @override
  String get shellNextFirstMock =>
      'Деңгээлиңизди жана алсыз темаларыңызды билүү үчүн толук сынамык экзаменди тапшырыңыз.';

  @override
  String get shellNextFirstMockFree =>
      'Биринчи толук сынамык экзаменди тапшырыңыз — ал акысыз. Деңгээлиңизди жана алсыз темаларыңызды билесиз.';

  @override
  String get shellNextOpenExams => 'Экзамендерге өтүү';

  @override
  String get shellNextOpenLearn => 'Окууга өтүү';

  @override
  String get shellNextPractice =>
      'Жакшы иш! Жыйынтыкты тез тест менен бекемдеңиз же дагы бир сынамык экзамен тапшырыңыз.';

  @override
  String get shellNextStepTitle => 'Кийинки кадам';

  @override
  String shellNextWeakTopic(String area) {
    return 'Акыркы экзаменде эң алсыз бөлүм: $area. Баллыңызды көтөрүү үчүн ушул теманы кайталаңыз.';
  }

  @override
  String get shellNotFoundMessage =>
      'Шилтеме эскирген болушу мүмкүн. Башкы бетке кайтыңыз.';

  @override
  String get shellNotFoundTitle => 'Барак табылган жок';

  @override
  String get shellNotNow => 'Азыр эмес';

  @override
  String get shellNotSet => 'Көрсөтүлгөн эмес';

  @override
  String get shellOnbAboutSubtitle =>
      'Ушуга жараша тапшырмаларды тандап, аймагыңыздын рейтингин көрсөтөбүз.';

  @override
  String get shellOnbAboutTitle => 'Өзүңүз жөнүндө айтып бериңиз';

  @override
  String get shellOnbBack => 'Артка';

  @override
  String get shellOnbDailySubtitle =>
      'Күн сайын кыска окуу сейрек жана узак окуудан натыйжалуураак.';

  @override
  String get shellOnbDailyTitle => 'Күнүнө канча убакыт окуй аласыз?';

  @override
  String get shellOnbGoalSubtitle =>
      'Максат дагы канча калганын көрсөтөт. Аны профилден өзгөртсөңүз болот.';

  @override
  String get shellOnbGoalTitle => 'Канча балл алгыңыз келет?';

  @override
  String get shellOnbLangKyHint => 'ЖРТ кыргыз тилинде';

  @override
  String get shellOnbLangRuHint => 'ЖРТ орус тилинде';

  @override
  String get shellOnbLanguageSubtitle =>
      'Тиркеме жана сынамык экзамендер ушул тилде болот. Аны жөндөөлөрдөн өзгөртсөңүз болот.';

  @override
  String get shellOnbLanguageTitle => 'Кайсы тилде даярданасыз?';

  @override
  String get shellOnbNext => 'Кийинки';

  @override
  String get shellOnbSavedLater =>
      'Жооптор сакталды, интернет болгондо шайкештирилет.';

  @override
  String get shellOnbSkip => 'Өткөрүп жиберүү';

  @override
  String get shellOnbStart => 'Баштоо';

  @override
  String shellOnbStepOf(int current, int total) {
    return 'Кадам $current/$total';
  }

  @override
  String get shellOnbUniversityHint => 'Мисалы, КММА же КУУ';

  @override
  String get shellOnbUniversityLabel => 'Кыялыңыздагы ЖОЖ';

  @override
  String get shellOptional => 'Милдеттүү эмес';

  @override
  String get shellProfileAchievements => 'Жетишкендиктер';

  @override
  String get shellProfileComplete => 'Профилди толтуруу';

  @override
  String get shellProfileDailyGoal => 'Күндүк максат';

  @override
  String get shellProfileDeleteAccount => 'Аккаунтту өчүрүү';

  @override
  String get shellProfileEdit => 'Профилди түзөтүү';

  @override
  String get shellProfileEditTitle => 'Профилди түзөтүү';

  @override
  String get shellProfileExamLanguage => 'Экзамендин тили';

  @override
  String get shellProfileExams => 'Экзамендер';

  @override
  String get shellProfileGoal => 'Максаттуу балл';

  @override
  String get shellProfileLevel => 'Деңгээл';

  @override
  String get shellProfileLoadError => 'Профилди жүктөө мүмкүн болбоду.';

  @override
  String get shellProfileNoName => 'Окуучу';

  @override
  String get shellProfileRegionLocked =>
      'Аймакты жылына бир жолу гана өзгөртүүгө болот.';

  @override
  String get shellProfileSaveError =>
      'Сактоо мүмкүн болбоду. Байланышты текшерип, кайра аракет кылыңыз.';

  @override
  String get shellProfileSaved => 'Профиль сакталды.';

  @override
  String get shellProfileSavedOffline =>
      'Сакталды. Өзгөртүүлөр интернет болгондо шайкештирилет.';

  @override
  String get shellProfileSchool => 'Мектеп';

  @override
  String get shellProfileStreak => 'Катар';

  @override
  String get shellProfileTransactions => 'Сатып алуулар';

  @override
  String get shellQuickDailyLesson => 'Күндүн сабагы';

  @override
  String get shellQuickHandbook => 'Маалымдама';

  @override
  String get shellQuickLeaderboard => 'Рейтинг';

  @override
  String get shellQuickMockExam => 'Сынамык экзамен';

  @override
  String get shellQuickTest => 'Тез тест';

  @override
  String get shellQuickTitle => 'Тез аракеттер';

  @override
  String get shellQuickTutor => 'ЖИ-репетитор';

  @override
  String get shellRegionDistrict => 'Район';

  @override
  String get shellRegionLabel => 'Аймак';

  @override
  String get shellRegionLoadError =>
      'Аймактардын тизмесин жүктөө мүмкүн болбоду.';

  @override
  String get shellRegionOblast => 'Облус же шаар';

  @override
  String get shellReminderDenied =>
      'Тиркеменин билдирмелери өчүрүлгөн. Аларга телефондун жөндөөлөрүнөн уруксат бериңиз.';

  @override
  String get shellReminderEnabled => 'Эскертүүлөр күйгүзүлдү.';

  @override
  String get shellReminderFailed =>
      'Эскертүүлөрдү күйгүзүү мүмкүн болбоду. Кийинчерээк аракет кылыңыз.';

  @override
  String get shellReminderUnsupported =>
      'Бул түзмөктө эскертүүлөр жеткиликсиз.';

  @override
  String get shellRetry => 'Кайталоо';

  @override
  String get shellSave => 'Сактоо';

  @override
  String get shellSettingsAbout => 'Тиркеме жөнүндө';

  @override
  String get shellSettingsAppearance => 'Тиркеме';

  @override
  String get shellSettingsDisclaimer =>
      'Сынамык экзамендердин жыйынтыктары окуу үчүн гана жана ЖРТнын расмий баллы болуп эсептелбейт.';

  @override
  String get shellSettingsLanguage => 'Тил';

  @override
  String get shellSettingsNotifications => 'Билдирмелер';

  @override
  String get shellSettingsPrivacy => 'Купуялуулук саясаты';

  @override
  String get shellSettingsReminder => 'Күнүмдүк эскертүү';

  @override
  String get shellSettingsReminderHint =>
      'Күнүнө бир жолу окуу тууралуу кыска эскертүү';

  @override
  String get shellSettingsTerms => 'Колдонуу шарттары';

  @override
  String get shellSettingsTheme => 'Тема';

  @override
  String get shellSettingsTitle => 'Жөндөөлөр';

  @override
  String get shellSettingsVersion => 'Версия';

  @override
  String get shellSignOut => 'Чыгуу';

  @override
  String get shellSignOutMessage => 'Прогрессиңиз аккаунтуңузда калат.';

  @override
  String get shellSignOutTitle => 'Аккаунттан чыгасызбы?';

  @override
  String get shellSignupButton => 'Аккаунт түзүү';

  @override
  String get shellSignupHaveAccount => 'Аккаунтуңуз барбы?';

  @override
  String get shellSignupLegalAnd => ' жана ';

  @override
  String get shellSignupLegalPrefix =>
      'Катталуу менен сиз төмөнкү документтерге макул болосуз: ';

  @override
  String get shellSignupSubtitle =>
      'Бир мүнөт гана кетет. Прогрессиңиз аккаунтта сакталат.';

  @override
  String get shellSignupSuccess =>
      'Аккаунт түзүлдү. Почтаны ырастоо үчүн кат жөнөттүк.';

  @override
  String get shellSignupTitle => 'Катталуу';

  @override
  String get shellTagline => 'ЖРТга даярдануу';

  @override
  String get shellThemeDark => 'Караңгы';

  @override
  String get shellThemeLight => 'Жарык';

  @override
  String get shellThemeSystem => 'Түзмөктөгүдөй';

  @override
  String get shellVerifyCheck => 'Ырастадым';

  @override
  String get shellVerifyDone => 'Почта ырасталды. Рахмат!';

  @override
  String shellVerifyMessage(String email) {
    return '$email дарегине шилтеме жөнөттүк. Бул аккаунтка кирүүнү калыбына келтирүүгө жардам берет.';
  }

  @override
  String get shellVerifyNotYet =>
      'Азырынча ырастала элек. Каттагы шилтемени ачыңыз.';

  @override
  String get shellVerifyResend => 'Кайра жөнөтүү';

  @override
  String get shellVerifySendFailed =>
      'Катты жөнөтүү мүмкүн болбоду. Кийинчерээк аракет кылыңыз.';

  @override
  String get shellVerifySent =>
      'Кат жөнөтүлдү. «Кирүүчү» жана «Спам» папкаларын текшериңиз.';

  @override
  String get shellVerifyTitle => 'Почтаңызды ырастаңыз';

  @override
  String get signup => 'Катталуу';

  @override
  String get skip => 'Өткөрүп жиберүү';

  @override
  String get somethingWentWrong => 'Бир нерсе туура эмес болду';

  @override
  String get startLearning => 'Окууну баштоо';

  @override
  String get startQuiz => 'Тестти баштоо';

  @override
  String get startTest => 'Тестти баштоо';

  @override
  String get streak => 'Күн катары';

  @override
  String get strongTopics => 'Күчтүү темалар';

  @override
  String get studyTime => 'Окуу убактысы';

  @override
  String get subjects => 'Предметтер';

  @override
  String get submit => 'Жөнөтүү';

  @override
  String get subscribe => 'Жазылуу';

  @override
  String get subscription => 'Жазылуу';

  @override
  String get success => 'Ийгиликтүү';

  @override
  String get system => 'Системалык';

  @override
  String get takeQuiz => 'Тестти өтүү';

  @override
  String get terms => 'Колдонуу шарттары';

  @override
  String get termsOfService => 'Колдонуу шарттары';

  @override
  String get tests => 'Тесттер';

  @override
  String get testsTaken => 'Өтүлгөн тесттер';

  @override
  String get theme => 'Тема';

  @override
  String get timeSpent => 'Убакыт кеткен';

  @override
  String get tutorAssistant => 'Репетитор';

  @override
  String get tutorClear => 'Чатты тазалоо';

  @override
  String get tutorContextAttempt => 'Экзамен аракети тиркелди';

  @override
  String get tutorContextQuestion => 'Суроо тиркелди';

  @override
  String get tutorContextRemove => 'Тиркелгенди алып салуу';

  @override
  String get tutorDisclaimer =>
      'ЖИ ката кетириши мүмкүн. Маанилүү кадамдарды окуу китеби же мугалим менен текшериңиз.';

  @override
  String get tutorEmptyBody =>
      'Жогорудан режимди тандап, суроо бериңиз. Мен жөн гана жоопту айтпастан, чечүү жолун түшүндүрөм.';

  @override
  String get tutorEmptyTitle => 'Кантип жардам берейин?';

  @override
  String get tutorErrorDisabled => 'ЖИ-репетитор убактылуу жеткиликсиз.';

  @override
  String get tutorErrorExamInProgress =>
      'Экзамен учурунда репетитор жеткиликсиз. Аракетти аяктаңыз — андан кийин каталарды талдайбыз.';

  @override
  String get tutorErrorNetwork =>
      'Байланыш жок. Интернетти текшерип, кайталаңыз.';

  @override
  String get tutorErrorQuota =>
      'Бүгүнкү ЖИ суроолорунун лимити бүттү. Эртең кайра келиңиз.';

  @override
  String get tutorErrorSignIn =>
      'ЖИ-репетиторду колдонуу үчүн аккаунтка кириңиз.';

  @override
  String get tutorErrorUnknown =>
      'Репетитор жооп бере албады. Дагы бир жолу аракет кылыңыз.';

  @override
  String get tutorErrorValidation =>
      'Билдирүү бош же өтө узун. Аны кыскартып, кайталаңыз.';

  @override
  String tutorExplainPrompt(
    String stem,
    String options,
    String userAnswer,
    String correctAnswer,
  ) {
    return 'Катамды талдап бер.\nТапшырма: $stem\nВарианттар:\n$options\nМенин жообум: $userAnswer\nТуура жооп: $correctAnswer\nКайда жаңылганымды жана кантип туура ой жүгүртүү керектигин түшүндүрүп бер.';
  }

  @override
  String get tutorExplainerAiButton => 'Катамды түшүндүрүү';

  @override
  String get tutorExplainerAiTitle =>
      'Эмне үчүн туура эмес? ЖИ-репетитордон сураңыз';

  @override
  String get tutorExplainerClose => 'Жабуу';

  @override
  String get tutorExplainerCorrect => 'Туура!';

  @override
  String tutorExplainerCorrectAnswer(String answer) {
    return 'Туура жооп: $answer';
  }

  @override
  String get tutorExplainerExplanation => 'Түшүндүрмө';

  @override
  String get tutorExplainerIncorrect => 'Туура эмес';

  @override
  String get tutorExplainerNext => 'Кийинки';

  @override
  String get tutorExplainerNoAnswer => 'жооп жок';

  @override
  String get tutorExplainerOpenChat => 'Репетитор менен чатты ачуу';

  @override
  String get tutorExplainerTryAgain => 'Кайра аракет кылуу';

  @override
  String tutorExplainerYourAnswer(String answer) {
    return 'Сиздин жообуңуз: $answer';
  }

  @override
  String get tutorHintChat =>
      'ЖРТга даярдануу боюнча каалаган суроону бериңиз.';

  @override
  String get tutorHintExplainMistake =>
      'Тапшырманы жана жообуңузду жазыңыз — катанын кайда экенин түшүндүрөм.';

  @override
  String get tutorHintGrammar =>
      'Эреже жөнүндө сураңыз же текшерүү үчүн сүйлөм жазыңыз.';

  @override
  String get tutorHintPractice =>
      'Теманы жазыңыз — окшош тапшырмаларды сунуштайм.';

  @override
  String get tutorHintStepByStep =>
      'Маселени жазыңыз — аны кадам-кадам чыгарабыз.';

  @override
  String get tutorHintStudyPlan =>
      'Экзамендин күнүн жана начар предметтериңизди жазыңыз.';

  @override
  String get tutorModeChat => 'Эркин суроо';

  @override
  String get tutorModeExplainMistake => 'Катаны талдоо';

  @override
  String get tutorModeGrammar => 'Грамматика';

  @override
  String get tutorModePractice => 'Окшош тапшырмалар';

  @override
  String get tutorModeStepByStep => 'Кадам-кадам';

  @override
  String get tutorModeStudyPlan => 'Даярдык планы';

  @override
  String tutorRemainingToday(int count) {
    return 'Бүгүн калган суроолор: $count';
  }

  @override
  String get tutorRetry => 'Кайталоо';

  @override
  String get tutorSend => 'Жөнөтүү';

  @override
  String get tutorThinking => 'Репетитор ойлонуп жатат…';

  @override
  String get tutorTitle => 'ЖИ-репетитор';

  @override
  String get tutorYou => 'Сиз';

  @override
  String get weakTopics => 'Алсыз темалар';

  @override
  String get welcome => 'Кош келиңиз';

  @override
  String get yearly => 'Жылдык';
}
