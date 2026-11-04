// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutApp => 'About App';

  @override
  String get accountDeleteButton => 'Delete account permanently';

  @override
  String accountDeleteConfirmAlt(String word) {
    return 'You can also type $word';
  }

  @override
  String accountDeleteConfirmLabel(String word) {
    return 'To confirm, type $word';
  }

  @override
  String get accountDeleteConfirmWord => 'DELETE';

  @override
  String get accountDeleteDone => 'Your account has been deleted.';

  @override
  String get accountDeleteGoToLogin => 'Sign in';

  @override
  String get accountDeleteInProgress => 'Deleting your data…';

  @override
  String get accountDeleteItemAi => 'AI tutor usage history';

  @override
  String get accountDeleteItemCredits =>
      'Unused exam credits and the free exam — they are cancelled and can\'t be transferred';

  @override
  String get accountDeleteItemExams => 'Mock exam attempts and results';

  @override
  String get accountDeleteItemGamification =>
      'XP, level, streaks, achievements and leaderboard entries';

  @override
  String get accountDeleteItemLogin =>
      'Your sign-in (email and password or the Google link)';

  @override
  String get accountDeleteItemProfile =>
      'Profile: name, email, photo, grade, region and settings';

  @override
  String get accountDeleteItemProgress =>
      'Learning progress, lesson history, mistakes and the review queue';

  @override
  String get accountDeleteKeptGoogle =>
      'Your Google Play payment history is kept by Google in your Google account.';

  @override
  String get accountDeleteKeptPurchases =>
      'Anonymized purchase records (date, product, amount, order number) without your name or email. We need them for financial reporting, refunds and fraud prevention.';

  @override
  String get accountDeleteSignedOut => 'Sign in to delete your account.';

  @override
  String get accountDeleteTitle => 'Delete account';

  @override
  String get accountDeleteUnavailablePlatform =>
      'Account deletion isn\'t available on this platform. Open the app on an Android device to delete your account.';

  @override
  String get accountDeleteWarningBody =>
      'Your account and learning data will be permanently deleted. You won\'t be able to restore them.';

  @override
  String get accountDeleteWarningTitle => 'This can\'t be undone';

  @override
  String get accountDeleteWhatDeletedTitle => 'What will be deleted';

  @override
  String get accountDeleteWhatKeptTitle => 'What we keep';

  @override
  String get accountErrorGoogle => 'Google sign-in failed. Try again.';

  @override
  String get accountErrorNetwork =>
      'No connection. Check the internet and try again.';

  @override
  String get accountErrorRecentLogin =>
      'For security, please sign in again and repeat.';

  @override
  String get accountErrorService =>
      'Account deletion is temporarily unavailable. Try again later.';

  @override
  String get accountErrorTooManyRequests =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get accountErrorUnauthenticated =>
      'The server couldn\'t verify this app or your session. Update the app, sign in again and retry.';

  @override
  String get accountErrorUnknown => 'Couldn\'t delete the account. Try again.';

  @override
  String get accountErrorUserMismatch =>
      'That\'s a different account. Sign in with the account you want to delete.';

  @override
  String get accountErrorWrongPassword => 'Wrong password.';

  @override
  String get accountReauthBody =>
      'For security, sign in again before deleting the account.';

  @override
  String get accountReauthCancel => 'Cancel';

  @override
  String get accountReauthConfirm => 'Confirm';

  @override
  String accountReauthEmail(String email) {
    return 'Account: $email';
  }

  @override
  String get accountReauthGoogle => 'Continue with Google';

  @override
  String get accountReauthPassword => 'Password';

  @override
  String get accountReauthSignInAgain => 'Sign in again';

  @override
  String get accountReauthTitle => 'Confirm it\'s you';

  @override
  String get adminAccountMenu => 'Account';

  @override
  String adminAchDefaultHint(String text) {
    return 'Default: $text';
  }

  @override
  String get adminAchDisabled => 'Disabled';

  @override
  String get adminAchDisabledHelp => 'Disabled: hidden from students.';

  @override
  String get adminAchEnabled => 'Enabled';

  @override
  String get adminAchFieldDescription => 'Description';

  @override
  String get adminAchFieldTitle => 'Title';

  @override
  String get adminAchFixErrors => 'Fix the highlighted fields';

  @override
  String get adminAchIntro =>
      'Texts and visibility of achievements. Thresholds and award rules stay on the server. Leave a field empty to keep the app\'s built-in text.';

  @override
  String get adminAchMissingTranslation =>
      'Fill in both languages or leave both empty';

  @override
  String get adminAchNoDoc =>
      'config/achievements does not exist yet: the built-in texts are used everywhere. Saving creates it.';

  @override
  String get adminAchPreview => 'Preview';

  @override
  String get adminAchPreviewHelp =>
      'How students see it in Russian and Kyrgyz.';

  @override
  String get adminAchReset => 'Reset texts';

  @override
  String get adminAchUnsaved => 'Unsaved changes';

  @override
  String get adminActivate => 'Activate';

  @override
  String get adminActive => 'Active';

  @override
  String get adminAdd => 'Add';

  @override
  String get adminAddOption => 'Add option';

  @override
  String get adminAiCount => 'Count';

  @override
  String adminAiDraftMeta(String topic, int difficulty) {
    return '$topic · difficulty $difficulty';
  }

  @override
  String adminAiDrafts(int n) {
    return 'Drafts: $n';
  }

  @override
  String get adminAiEmpty => 'Fill in the request and generate drafts.';

  @override
  String get adminAiFillForm => 'Choose structure, section, part and topic.';

  @override
  String get adminAiGenerate => 'Generate drafts';

  @override
  String get adminAiGenerating => 'Generating…';

  @override
  String get adminAiNotice =>
      'Drafts are generated on the server; no API key is stored in the app. Every draft is saved with the status \"Draft\" and must be approved by a methodologist before it can be used in a variant.';

  @override
  String get adminAiOpenBank => 'Open the exam bank';

  @override
  String get adminAiRequest => 'Request';

  @override
  String adminAiSaveSelected(int n) {
    return 'Save $n';
  }

  @override
  String adminAiSaved(int n) {
    return 'Saved $n drafts for review';
  }

  @override
  String get adminAll => 'All';

  @override
  String get adminAppCheckPlatformNote =>
      'This build expects the server to require App Check for admin functions (APP_CHECK_ENFORCE_ADMIN), but App Check is not available on this platform: roles, credits, publishing, pricing and AI drafts will be rejected. Use the web build with App Check or Android.';

  @override
  String get adminAppTitle => 'ORT Master · CMS';

  @override
  String get adminApply => 'Apply';

  @override
  String adminBanReasonTooLong(int max) {
    return 'The reason must be at most $max characters.';
  }

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminClose => 'Close';

  @override
  String get adminCorrectMultiHelp => 'Mark all correct options.';

  @override
  String get adminCorrectSingleHelp => 'Mark the one correct option.';

  @override
  String get adminDashboardReviewBody =>
      'Open the exam bank with the status filter \"Draft\" or \"AI-checked\" to review questions. Only approved questions with an answer key can go into a published variant.';

  @override
  String get adminDashboardReviewTitle => 'Review queue';

  @override
  String get adminDashboardShortcuts => 'Sections';

  @override
  String adminDashboardWelcome(String role) {
    return 'Signed in as: $role';
  }

  @override
  String get adminDeactivate => 'Deactivate';

  @override
  String get adminDelete => 'Delete';

  @override
  String get adminDeletePermanently => 'Delete permanently';

  @override
  String get adminDeleted => 'Deleted';

  @override
  String get adminDifficulty1 => '1 · easy';

  @override
  String get adminDifficulty2 => '2 · medium';

  @override
  String get adminDifficulty3 => '3 · hard';

  @override
  String adminDifficultyN(int n) {
    return 'difficulty $n';
  }

  @override
  String get adminDiscard => 'Discard';

  @override
  String get adminEdit => 'Edit';

  @override
  String get adminErrAppCheckPlatform =>
      'The server rejected the request: App Check is not available on this platform (Windows/Linux, or web without an App Check key). Open the admin panel in the web build with App Check or on Android, or ask the owner to set APP_CHECK_ENFORCE_ADMIN=false.';

  @override
  String get adminErrAppCheckRejected =>
      'The server rejected the request (App Check token missing or invalid). Sign in again; if it repeats, check the App Check registration of this device.';

  @override
  String adminErrFileTooLarge(int mb) {
    return 'File is too large (max $mb MB).';
  }

  @override
  String get adminErrForbidden => 'You do not have permission for this action.';

  @override
  String get adminErrFunctionMissing =>
      'The server function is not deployed yet.';

  @override
  String adminErrGeneric(String message) {
    return 'Error: $message';
  }

  @override
  String get adminErrIndex =>
      'Firestore needs an index for this filter. Change the filter or create the index.';

  @override
  String get adminErrLimitReached =>
      'The limit for this action has been reached. Try again later.';

  @override
  String get adminErrNetwork =>
      'No connection to the server. Check the network and try again.';

  @override
  String get adminErrNotFound => 'Not found.';

  @override
  String get adminErrQuota => 'Limit reached. Try again later.';

  @override
  String get adminErrRateLimited =>
      'Too many requests. Wait a little and try again.';

  @override
  String get adminErrSessionExpired =>
      'Your admin session has expired. Sign in again.';

  @override
  String get adminErrTitle => 'Could not load';

  @override
  String get adminErrUnknown => 'Something went wrong. Try again.';

  @override
  String adminErrUnsupportedMedia(String ext) {
    return 'Unsupported file format ($ext). Allowed: PNG, JPEG, WEBP, GIF, PDF.';
  }

  @override
  String get adminErrUserBanned =>
      'This account is blocked. Server actions are not available.';

  @override
  String adminErrValidation(String message) {
    return 'Validation failed: $message';
  }

  @override
  String get adminExamAddTable => 'Add table';

  @override
  String get adminExamApprove => 'Approve';

  @override
  String get adminExamBackToDraft => 'Back to draft';

  @override
  String get adminExamChoosePlacement =>
      'Choose the test structure and section first.';

  @override
  String get adminExamColumnA => 'Column A';

  @override
  String get adminExamColumnB => 'Column B';

  @override
  String get adminExamColumns => 'Columns A / B';

  @override
  String get adminExamColumnsHelp =>
      'Quantitative comparison: the two quantities to compare. The stem holds only the shared condition (it may be empty).';

  @override
  String adminExamCorrectIs(String id) {
    return 'Correct option: $id';
  }

  @override
  String adminExamCreateTranslation(String lang) {
    return 'Create in $lang';
  }

  @override
  String get adminExamEdit => 'Edit exam question';

  @override
  String get adminExamEmpty => 'No exam questions match the filter.';

  @override
  String get adminExamErrApproveNoKey =>
      'Cannot approve: the question has no answer key.';

  @override
  String get adminExamFixedOptions =>
      'This part uses fixed answer options. Mark the correct one.';

  @override
  String adminExamGroup(String id) {
    return 'Translation group: $id';
  }

  @override
  String get adminExamHasTranslation => 'Has translation';

  @override
  String get adminExamImage => 'Image';

  @override
  String get adminExamIssueColumns => 'Fill in both columns A and B.';

  @override
  String get adminExamIssueLanguage => 'Choose the language (ru, ky or en).';

  @override
  String get adminExamIssueOptionDuplicate => 'Option ids must be unique.';

  @override
  String adminExamIssueOptionsCount(int n) {
    return 'The blueprint requires $n options.';
  }

  @override
  String get adminExamIssuePart => 'Choose the part of the section.';

  @override
  String get adminExamIssuePassage =>
      'This part needs a linked text (passage).';

  @override
  String get adminExamIssueSection => 'Choose blueprint and section.';

  @override
  String get adminExamIssueTopic => 'Topic id is required.';

  @override
  String get adminExamKey =>
      'Answer key (never shown to students before the end)';

  @override
  String get adminExamLink => 'Link';

  @override
  String get adminExamLinkTitle => 'Link existing translation';

  @override
  String get adminExamLinked => 'Translations linked';

  @override
  String get adminExamMarkAiVerified => 'Mark as AI-checked';

  @override
  String get adminExamNew => 'New exam question';

  @override
  String get adminExamNewPassage => 'New text';

  @override
  String adminExamNoBlueprint(String subject, String section) {
    return 'No blueprint section matches $subject/$section. Choose the structure again.';
  }

  @override
  String get adminExamNoGroup => 'Not linked to a translation yet.';

  @override
  String get adminExamNoImage => 'No image.';

  @override
  String get adminExamNoTable => 'No table.';

  @override
  String get adminExamPartUnverified =>
      'This split into parts is an assumption (not officially published).';

  @override
  String get adminExamPassage => 'Linked text';

  @override
  String get adminExamPassageEmpty => 'The text is empty.';

  @override
  String get adminExamPassageText => 'Text';

  @override
  String get adminExamPlacement => 'Placement';

  @override
  String get adminExamQuestionId => 'Question id';

  @override
  String get adminExamReject => 'Reject';

  @override
  String get adminExamRemoveTable => 'Remove table';

  @override
  String get adminExamReview => 'Review';

  @override
  String adminExamReviewDone(String status) {
    return 'Status: $status';
  }

  @override
  String get adminExamReviewNoRights =>
      'Your role cannot change the review status.';

  @override
  String get adminExamReviewNotes => 'Reviewer notes';

  @override
  String adminExamReviewedBy(String uid, String date) {
    return '$uid · $date';
  }

  @override
  String get adminExamSaveBeforeReview =>
      'Save your changes before changing the status.';

  @override
  String get adminExamSavedBackToDraft =>
      'Saved. The content changed, so the question went back to \"Draft\" for review.';

  @override
  String get adminExamSolutionSteps => 'Solution steps';

  @override
  String get adminExamSolutionStepsHelp => 'One step per line';

  @override
  String get adminExamSource => 'Source';

  @override
  String get adminExamSourceAdapted => 'Adapted / translated';

  @override
  String get adminExamSourceAi => 'AI';

  @override
  String get adminExamSourceAuthor => 'Author';

  @override
  String get adminExamSourceBasis => 'Source / basis';

  @override
  String get adminExamSourceKind => 'Origin';

  @override
  String get adminExamSourceOriginal => 'Original';

  @override
  String get adminExamStemLabel => 'Question text';

  @override
  String get adminExamTable => 'Table';

  @override
  String get adminExamTableAddColumn => 'Add column';

  @override
  String get adminExamTableAddRow => 'Add row';

  @override
  String get adminExamTableCell => 'Cell';

  @override
  String get adminExamTableEmpty => 'The table is empty and will not be saved.';

  @override
  String get adminExamTableHeader => 'Header';

  @override
  String get adminExamTableHeaderShort => 'Hdr';

  @override
  String get adminExamTableHelp =>
      'Header row and body rows; cells accept Markdown and LaTeX (\$...\$). In comparison items the first row holds quantities A and B.';

  @override
  String get adminExamTablePreview => 'Preview';

  @override
  String get adminExamTableRemoveColumn => 'Remove column';

  @override
  String get adminExamTableRemoveRow => 'Remove row';

  @override
  String get adminExamTranslations => 'Translations';

  @override
  String adminExamWrongNote(String id) {
    return 'Why $id is wrong';
  }

  @override
  String get adminExport => 'Export';

  @override
  String get adminExportCopied => 'Copied to clipboard';

  @override
  String get adminExportCopy => 'Copy';

  @override
  String get adminExportHelp =>
      'Exports the questions matching the current filter (up to 5000). Dates are written as ISO strings.';

  @override
  String get adminExportSave => 'Save file';

  @override
  String get adminExportSaved => 'File saved';

  @override
  String get adminExportTitle => 'Export questions';

  @override
  String get adminFieldBlueprint => 'Test structure';

  @override
  String get adminFieldDescription => 'Description';

  @override
  String get adminFieldDifficulty => 'Difficulty';

  @override
  String get adminFieldExplanation => 'Explanation';

  @override
  String get adminFieldHint => 'Hint';

  @override
  String get adminFieldImageUrl => 'Image URL';

  @override
  String get adminFieldLanguage => 'Language';

  @override
  String get adminFieldOptions => 'Answer options';

  @override
  String get adminFieldOrder => 'Order';

  @override
  String get adminFieldPart => 'Part';

  @override
  String get adminFieldPoints => 'Points';

  @override
  String get adminFieldRequired => 'Required';

  @override
  String get adminFieldReview => 'Review';

  @override
  String get adminFieldSection => 'Section';

  @override
  String get adminFieldStatus => 'Status';

  @override
  String get adminFieldStem => 'Question text';

  @override
  String get adminFieldSubject => 'Subject';

  @override
  String get adminFieldSubtopicId => 'Subtopic id (optional)';

  @override
  String get adminFieldTags => 'Tags';

  @override
  String get adminFieldTagsHelp => 'Comma separated';

  @override
  String get adminFieldTitle => 'Title';

  @override
  String get adminFieldTopic => 'Topic';

  @override
  String get adminFieldTopicId => 'Topic id';

  @override
  String get adminFieldTopicIdHelp => 'For example math.quadratic_equations';

  @override
  String get adminFieldType => 'Type';

  @override
  String get adminForbiddenBody =>
      'Your role does not allow opening this section.';

  @override
  String get adminForbiddenTitle => 'No access';

  @override
  String get adminHidden => 'Hidden';

  @override
  String get adminImport => 'Import';

  @override
  String get adminImportDuplicateId => 'Duplicate id in the file.';

  @override
  String get adminImportEmpty => 'The file has no data rows.';

  @override
  String adminImportFailedAfter(int done, String error) {
    return 'Stopped after $done rows: $error';
  }

  @override
  String adminImportHelp(int batch) {
    return 'Rows are validated before writing; valid rows are written in batches of $batch. CSV columns (separator , ; or tab):';
  }

  @override
  String get adminImportParseError => 'The file could not be read.';

  @override
  String get adminImportPick => 'Choose file';

  @override
  String adminImportProgress(int done, int total) {
    return 'Written $done of $total';
  }

  @override
  String adminImportRowIssue(int row, String issue) {
    return 'Row $row: $issue';
  }

  @override
  String adminImportRun(int count) {
    return 'Import $count';
  }

  @override
  String adminImportSummary(int total, int valid, int invalid) {
    return 'Rows: $total · valid: $valid · with errors: $invalid';
  }

  @override
  String get adminImportTitle => 'Import questions (CSV or JSON)';

  @override
  String get adminInactive => 'Inactive';

  @override
  String get adminIssueCorrectNotInOptions =>
      'The correct answer is not among the options.';

  @override
  String get adminIssueCorrectRequired => 'Mark the correct answer.';

  @override
  String get adminIssueDifficulty => 'Difficulty must be 1–3.';

  @override
  String get adminIssueOptionEmpty => 'Every option needs text.';

  @override
  String get adminIssueStem => 'Question text is required.';

  @override
  String get adminLangEn => 'English';

  @override
  String get adminLangKy => 'Kyrgyz';

  @override
  String get adminLangRu => 'Russian';

  @override
  String get adminLessonAddExample => 'Add example';

  @override
  String get adminLessonAddFormula => 'Add formula';

  @override
  String get adminLessonAddMistake => 'Add mistake';

  @override
  String get adminLessonAddSection => 'Add section';

  @override
  String get adminLessonBasics => 'Basics';

  @override
  String get adminLessonCaption => 'Caption';

  @override
  String get adminLessonExamples => 'Worked examples';

  @override
  String get adminLessonFormulas => 'Formulas';

  @override
  String get adminLessonImages => 'Images';

  @override
  String get adminLessonIssueContent =>
      'Add a summary or at least one section.';

  @override
  String get adminLessonIssueMinutes => 'Duration must be 1–240 minutes.';

  @override
  String get adminLessonIssueOrder => 'Order must be 0–10000.';

  @override
  String get adminLessonIssueSubject => 'Choose a subject.';

  @override
  String get adminLessonIssueUrl =>
      'Video/PDF must be an http(s) link or an uploaded file.';

  @override
  String get adminLessonLatex => 'LaTeX';

  @override
  String get adminLessonMinutes => 'Minutes';

  @override
  String get adminLessonMistake => 'Mistake';

  @override
  String get adminLessonMistakes => 'Common mistakes';

  @override
  String get adminLessonNoImages => 'No images.';

  @override
  String get adminLessonPdf => 'PDF';

  @override
  String get adminLessonPdfHelp => 'Link or an uploaded file (up to 20 MB)';

  @override
  String get adminLessonPracticeAndMedia => 'Practice and media';

  @override
  String get adminLessonPracticeIds => 'Practice question ids';

  @override
  String get adminLessonPracticeIdsHelp =>
      'Ids from the \"questions\" collection, separated by commas';

  @override
  String get adminLessonProblem => 'Problem';

  @override
  String get adminLessonPublishedHelp =>
      'Unpublished lessons are hidden from students.';

  @override
  String get adminLessonSectionBody => 'Text (Markdown, LaTeX in \$…\$)';

  @override
  String get adminLessonSectionTitle => 'Section title';

  @override
  String get adminLessonSections => 'Sections';

  @override
  String get adminLessonSolution => 'Solution';

  @override
  String get adminLessonSummary => 'Summary';

  @override
  String get adminLessonTitleSummary => 'Title and summary';

  @override
  String get adminLessonVideoUrl => 'Video URL';

  @override
  String get adminLessonsDeleteBody =>
      'Students will no longer see this lesson. To hide it temporarily, turn off \"Published\" instead.';

  @override
  String get adminLessonsDeleteTitle => 'Delete lesson?';

  @override
  String get adminLessonsEdit => 'Edit lesson';

  @override
  String get adminLessonsEmpty => 'No lessons for this subject.';

  @override
  String get adminLessonsLegacy => 'Old format';

  @override
  String adminLessonsMeta(int order, int minutes) {
    return '#$order · $minutes min';
  }

  @override
  String get adminLessonsNew => 'New lesson';

  @override
  String get adminLessonsNoSubjects => 'Create a subject first.';

  @override
  String adminListEnd(int count) {
    return 'Shown: $count';
  }

  @override
  String get adminListNoItems => 'Nothing added yet.';

  @override
  String get adminLoadMore => 'Load more';

  @override
  String get adminLoginBackToApp => 'Back to the app';

  @override
  String get adminLoginContinue => 'Continue';

  @override
  String get adminLoginEmail => 'Email';

  @override
  String get adminLoginEmailInvalid => 'Enter a valid email';

  @override
  String get adminLoginErrCredentials => 'Wrong email or password.';

  @override
  String get adminLoginErrDisabled => 'This account is disabled.';

  @override
  String get adminLoginErrNotAdmin => 'This account has no admin role.';

  @override
  String get adminLoginErrTooMany => 'Too many attempts. Try again later.';

  @override
  String get adminLoginForgot => 'Forgot password?';

  @override
  String get adminLoginHidePassword => 'Hide password';

  @override
  String get adminLoginOtherAccount => 'Use another account';

  @override
  String get adminLoginPassword => 'Password';

  @override
  String get adminLoginPasswordRequired => 'Enter the password';

  @override
  String get adminLoginResetSend => 'Send link';

  @override
  String get adminLoginResetSent =>
      'If the account exists, a reset link has been sent.';

  @override
  String get adminLoginResetTitle => 'Reset password';

  @override
  String get adminLoginShowPassword => 'Show password';

  @override
  String adminLoginSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get adminLoginSubmit => 'Sign in';

  @override
  String get adminLoginSubtitle => 'For ORT Master staff only.';

  @override
  String get adminLoginTitle => 'Admin panel';

  @override
  String get adminLogout => 'Log out';

  @override
  String adminLogsActor(String uid) {
    return 'by $uid';
  }

  @override
  String get adminLogsEmpty => 'The log is empty.';

  @override
  String adminLogsTarget(String uid) {
    return 'target $uid';
  }

  @override
  String get adminMarkCorrect => 'Mark as correct';

  @override
  String get adminMathHelp => 'Markdown; formulas in \$…\$ or \$\$…\$\$';

  @override
  String adminMissingTranslation(String lang) {
    return 'No $lang';
  }

  @override
  String get adminMore => 'More';

  @override
  String get adminMoveDown => 'Move down';

  @override
  String get adminMoveUp => 'Move up';

  @override
  String get adminNavAchievements => 'Achievements';

  @override
  String get adminNavAiDrafts => 'AI drafts';

  @override
  String get adminNavDashboard => 'Dashboard';

  @override
  String get adminNavExamBank => 'Exam bank';

  @override
  String get adminNavLessons => 'Lessons';

  @override
  String get adminNavLogs => 'Admin log';

  @override
  String get adminNavNotifications => 'Notifications';

  @override
  String get adminNavPayments => 'Payments';

  @override
  String get adminNavPractice => 'Practice questions';

  @override
  String get adminNavPricing => 'Pricing';

  @override
  String get adminNavPromoCodes => 'Promo codes';

  @override
  String get adminNavSubjects => 'Subjects & topics';

  @override
  String get adminNavUsers => 'Users';

  @override
  String get adminNavVariants => 'Exam variants';

  @override
  String get adminNo => 'no';

  @override
  String get adminNone => 'Not set';

  @override
  String get adminNotifAudienceAll => 'Everyone';

  @override
  String get adminNotifAudienceAllHint =>
      'All users with notifications enabled.';

  @override
  String get adminNotifAudienceAllUsers => 'All users';

  @override
  String get adminNotifAudienceGroup => 'Group';

  @override
  String adminNotifAudienceGroupIs(String group) {
    return 'Group: $group';
  }

  @override
  String get adminNotifAudienceLanguage => 'By language';

  @override
  String adminNotifAudienceLanguageIs(String language) {
    return 'Language: $language';
  }

  @override
  String get adminNotifAudienceRegion => 'By region';

  @override
  String adminNotifAudienceRegionIs(String region) {
    return 'Region: $region';
  }

  @override
  String get adminNotifAudienceTitle => 'Audience';

  @override
  String get adminNotifAudienceValueRequired => 'Choose who receives it';

  @override
  String get adminNotifCheckFirst =>
      'Check the reach to see how many people will receive the notification.';

  @override
  String get adminNotifCheckReach => 'Check reach';

  @override
  String get adminNotifCheckStale =>
      'The text or audience changed — check the reach again.';

  @override
  String adminNotifConfirmBody(int count, String audience) {
    return '$count users will receive the notification ($audience). A sent broadcast cannot be recalled.';
  }

  @override
  String get adminNotifConfirmTitle => 'Send the broadcast?';

  @override
  String adminNotifFailedShort(int count) {
    return 'failed: $count';
  }

  @override
  String get adminNotifFieldBody => 'Message';

  @override
  String get adminNotifFieldTitle => 'Title';

  @override
  String get adminNotifFixErrors =>
      'Fill in the texts in both languages and choose the audience.';

  @override
  String get adminNotifGroupId => 'Group ID';

  @override
  String get adminNotifGroupIdHelp =>
      'The group document id (collection groups)';

  @override
  String get adminNotifGroupIdInvalid =>
      'Only Latin letters, digits, _ and -, up to 128 characters';

  @override
  String get adminNotifHistoryEmpty => 'No broadcasts yet';

  @override
  String adminNotifIntro(int limit) {
    return 'The push notification goes to users with notifications enabled, in their app language. Check the reach first, then send. At most $limit broadcasts per day.';
  }

  @override
  String adminNotifLimitReached(int limit) {
    return 'Today\'s broadcast limit is used up ($limit per day). You can send the next one tomorrow.';
  }

  @override
  String get adminNotifNoRecipients =>
      'No recipients for this audience. Choose a different one.';

  @override
  String adminNotifRecipients(int count) {
    return 'Recipients: $count';
  }

  @override
  String adminNotifRecipientsShort(int count) {
    return 'recipients: $count';
  }

  @override
  String adminNotifResult(int recipients, int sent, int failed) {
    return 'Recipients: $recipients · sent: $sent · failed: $failed';
  }

  @override
  String get adminNotifResultLabel => 'Result';

  @override
  String get adminNotifSend => 'Send';

  @override
  String get adminNotifSendTitle => 'Reach and sending';

  @override
  String adminNotifSentShort(int count) {
    return 'sent: $count';
  }

  @override
  String adminNotifSentSnack(int count) {
    return 'Sent: $count';
  }

  @override
  String get adminNotifTabCompose => 'New broadcast';

  @override
  String get adminNotifTabHistory => 'History';

  @override
  String get adminNotifTextTitle => 'Text';

  @override
  String adminNotifTodayCount(int count, int limit) {
    return 'Sent today: $count of $limit. The server enforces the limit.';
  }

  @override
  String adminOptionN(String id) {
    return 'Option $id';
  }

  @override
  String get adminOptionText => 'Text';

  @override
  String adminPaymentsCredits(int n) {
    return '$n credits';
  }

  @override
  String get adminPaymentsEmpty => 'No purchases.';

  @override
  String get adminPaymentsReadOnly =>
      'Read only. Credits are granted by the server after Google Play verification.';

  @override
  String get adminPaymentsRefund => 'Refund';

  @override
  String get adminPracticeDeleteBody =>
      'The question will be removed from practice. To hide it, make it inactive instead.';

  @override
  String get adminPracticeDeleteTitle => 'Delete question?';

  @override
  String get adminPracticeEdit => 'Edit question';

  @override
  String get adminPracticeEmpty => 'No questions match the filter.';

  @override
  String get adminPracticeIssueOptionsMin =>
      'At least two options are required.';

  @override
  String get adminPracticeIssueSubject => 'Subject is required.';

  @override
  String get adminPracticeIssueType => 'Unknown type';

  @override
  String get adminPracticeNew => 'New question';

  @override
  String get adminPricingConfirmBody =>
      'Changes apply to new purchases immediately.';

  @override
  String get adminPricingConfirmTitle => 'Save pricing?';

  @override
  String adminPricingCreditsFor(String id) {
    return '$id — credits';
  }

  @override
  String get adminPricingDefaults =>
      'config/pricing does not exist yet; defaults are shown.';

  @override
  String get adminPricingFree => 'Free exams';

  @override
  String get adminPricingFreeHelp =>
      'Product rule: 1 (the first full exam is free once per account)';

  @override
  String get adminPricingFreeLabel => 'Free full exams per account';

  @override
  String get adminPricingIssueCredits => 'Credits per product must be 1–100.';

  @override
  String adminPricingIssueFree(int min, int max) {
    return 'Free exams per user must be $min–$max.';
  }

  @override
  String get adminPricingIssueProduct => 'Unknown product id.';

  @override
  String get adminPricingIssueSingle =>
      'exam_single must grant exactly 1 credit.';

  @override
  String get adminPricingProducts => 'Credits per product';

  @override
  String get adminPricingSingleHelp => 'Fixed: 1 credit = 1 exam';

  @override
  String get adminPricingWarning =>
      'Prices are set in Google Play Console, not here. This page only maps products to exam credits. Do not change the base price of 100 som (exam_single) without the owner\'s approval.';

  @override
  String get adminPromoActive => 'Active';

  @override
  String get adminPromoActiveHelp => 'Students can redeem only active codes.';

  @override
  String get adminPromoClearDate => 'No expiry';

  @override
  String get adminPromoCode => 'Code';

  @override
  String adminPromoCodeHelp(int min, int max) {
    return 'Latin letters A–Z and digits, $min–$max characters';
  }

  @override
  String adminPromoConfirmBody(
    String code,
    int credits,
    String max,
    String expiry,
    String status,
  ) {
    return 'Code $code: $credits free credits per redemption; max redemptions: $max; expiry: $expiry; status: $status. The change will be recorded in the action log.';
  }

  @override
  String get adminPromoConfirmCreateTitle => 'Create the promo code?';

  @override
  String get adminPromoConfirmEditTitle => 'Save the changes?';

  @override
  String get adminPromoCreate => 'New promo code';

  @override
  String get adminPromoCredits => 'Credits per redemption';

  @override
  String adminPromoCreditsValue(int n) {
    return 'credits: $n';
  }

  @override
  String get adminPromoDeactivate => 'Deactivate';

  @override
  String get adminPromoDeactivateBody =>
      'Students will no longer be able to redeem it. Credits already granted stay. The change is recorded in the action log.';

  @override
  String adminPromoDeactivateTitle(String code) {
    return 'Deactivate $code?';
  }

  @override
  String adminPromoDeactivated(String code) {
    return '$code deactivated';
  }

  @override
  String get adminPromoDialogWarning =>
      'Every redemption grants free credits. The change is recorded in the action log.';

  @override
  String adminPromoEditTitle(String code) {
    return 'Promo code $code';
  }

  @override
  String get adminPromoEmpty => 'No promo codes yet';

  @override
  String adminPromoErrCode(int min, int max) {
    return '$min–$max characters: A–Z and 0–9 only';
  }

  @override
  String adminPromoErrCredits(int min, int max) {
    return 'From $min to $max credits';
  }

  @override
  String get adminPromoErrExpiry =>
      'The date has passed: pick a future date or deactivate the code';

  @override
  String adminPromoErrMax(int limit) {
    return 'From 1 to $limit';
  }

  @override
  String adminPromoErrMaxBelow(int used) {
    return 'Already used $used times — the limit cannot be lower';
  }

  @override
  String get adminPromoExpiry => 'Expiry';

  @override
  String get adminPromoExpiryHelp =>
      'The code works through 23:59 Bishkek time on the chosen day.';

  @override
  String get adminPromoGenerate => 'Generate a code';

  @override
  String get adminPromoMaxHelp => 'Empty = unlimited.';

  @override
  String get adminPromoMaxRedemptions => 'Max redemptions';

  @override
  String get adminPromoNoExpiry => 'no expiry';

  @override
  String get adminPromoNote => 'Note (internal)';

  @override
  String get adminPromoNoteHelp =>
      'Who the code is for: campaign, partner, school.';

  @override
  String get adminPromoPickDate => 'Pick a date';

  @override
  String adminPromoSaved(String code) {
    return 'Promo code $code saved';
  }

  @override
  String get adminPromoStatusActive => 'Active';

  @override
  String get adminPromoStatusExhausted => 'Used up';

  @override
  String get adminPromoStatusExpired => 'Expired';

  @override
  String get adminPromoStatusInactive => 'Off';

  @override
  String get adminPromoUnlimited => 'unlimited';

  @override
  String adminPromoUntil(String date) {
    return 'valid through $date';
  }

  @override
  String adminPromoUsage(int used, String max) {
    return 'used: $used / $max';
  }

  @override
  String get adminPromoWarning =>
      'Promo codes grant free exam credits (1 credit = 1 exam), so they are a finance operation: only super admins manage them, and every change is recorded in the action log.';

  @override
  String get adminPublished => 'Published';

  @override
  String get adminPurchaseGranted => 'Granted';

  @override
  String get adminPurchaseInvalid => 'Invalid';

  @override
  String get adminPurchasePending => 'Pending';

  @override
  String get adminPurchaseRefunded => 'Refunded';

  @override
  String get adminPurchaseRevoked => 'Revoked';

  @override
  String get adminQuestionExtra => 'Extra';

  @override
  String get adminQuestionMeta => 'Classification';

  @override
  String get adminReason => 'Reason';

  @override
  String get adminReasonRequired => 'Give a reason (at least 3 characters).';

  @override
  String get adminRemove => 'Remove';

  @override
  String get adminRetry => 'Retry';

  @override
  String get adminReviewAiVerified => 'AI-checked';

  @override
  String get adminReviewApproved => 'Approved';

  @override
  String get adminReviewDraft => 'Draft';

  @override
  String get adminReviewRejected => 'Rejected';

  @override
  String get adminRoleContentManager => 'Content manager';

  @override
  String get adminRoleMethodologist => 'Methodologist';

  @override
  String get adminRoleModerator => 'Moderator';

  @override
  String get adminRoleSuperAdmin => 'Super admin';

  @override
  String get adminRoleSupport => 'Support';

  @override
  String get adminSave => 'Save';

  @override
  String get adminSaved => 'Saved';

  @override
  String get adminSessionExpiredBody => 'Sign in again to continue.';

  @override
  String get adminSessionExpiredTitle => 'Admin session ended';

  @override
  String get adminSignInAgain => 'Sign in';

  @override
  String get adminStatApproved => 'Approved';

  @override
  String get adminStatExam => 'Exam questions';

  @override
  String get adminStatLessons => 'Lessons';

  @override
  String get adminStatPendingReview => 'Awaiting review';

  @override
  String get adminStatPractice => 'Practice questions';

  @override
  String get adminStatPurchases => 'Granted purchases';

  @override
  String get adminStatSubjects => 'Subjects';

  @override
  String get adminStatUsers => 'Users';

  @override
  String get adminStatVariants => 'Published variants';

  @override
  String get adminSubjectsActiveHelp =>
      'Inactive subjects stay in the database (soft delete).';

  @override
  String get adminSubjectsAddTopic => 'Add topic';

  @override
  String get adminSubjectsColor => 'Colour (#RRGGBB)';

  @override
  String get adminSubjectsColorInvalid => 'Use #RRGGBB';

  @override
  String adminSubjectsDeleteBody(String id) {
    return 'The subject $id will be deleted only if no lessons or questions use it. Otherwise deactivate it.';
  }

  @override
  String get adminSubjectsDeleteTitle => 'Delete subject?';

  @override
  String get adminSubjectsEdit => 'Edit subject';

  @override
  String get adminSubjectsEmpty => 'No subjects yet.';

  @override
  String get adminSubjectsErrExists => 'A subject with this id already exists.';

  @override
  String adminSubjectsErrInUse(int lessons, int questions, int exam) {
    return 'The subject is still used: $lessons lessons, $questions practice questions, $exam exam questions. Deactivate it instead.';
  }

  @override
  String get adminSubjectsIcon => 'Icon name';

  @override
  String get adminSubjectsId => 'Subject id';

  @override
  String get adminSubjectsIdHelp =>
      'Latin letters, digits and _; cannot be changed later';

  @override
  String get adminSubjectsIdInvalid =>
      '2–41 characters: a–z, 0–9, _ (starts with a letter)';

  @override
  String get adminSubjectsNew => 'New subject';

  @override
  String adminSubjectsTopicDuplicate(String id) {
    return 'Duplicate topic id: $id';
  }

  @override
  String get adminSubjectsTopicId => 'Topic id';

  @override
  String adminSubjectsTopicIdInvalid(String id) {
    return 'Invalid topic id: $id (use a–z, 0–9, _ and dots)';
  }

  @override
  String adminSubjectsTopicN(int n) {
    return 'Topic $n';
  }

  @override
  String get adminSubjectsTopics => 'Topics';

  @override
  String adminSubjectsTopicsCount(int count) {
    return 'topics: $count';
  }

  @override
  String get adminSubjectsTopicsHelp =>
      'Topic ids become subject.topic (e.g. math.quadratic_equations) and are used by exam questions.';

  @override
  String adminTextTooLong(int max) {
    return 'No longer than $max characters';
  }

  @override
  String get adminTitleRequired => 'Enter a title in Russian or Kyrgyz.';

  @override
  String get adminTypeAnalogy => 'Analogy';

  @override
  String get adminTypeComparison => 'Quantitative comparison';

  @override
  String get adminTypeCompletion => 'Sentence completion';

  @override
  String get adminTypeMatching => 'Matching';

  @override
  String get adminTypeMultiple => 'Multiple choice';

  @override
  String get adminTypeOrdering => 'Ordering';

  @override
  String get adminTypeSingle => 'Single choice';

  @override
  String get adminTypeTextBased => 'Reading (text-based)';

  @override
  String get adminTypeTrueFalse => 'True / false';

  @override
  String get adminUnsavedBody => 'You have unsaved changes.';

  @override
  String get adminUnsavedTitle => 'Discard changes?';

  @override
  String get adminUpdated => 'Updated';

  @override
  String get adminUploadImage => 'Upload image';

  @override
  String get adminUploadPdf => 'Upload PDF';

  @override
  String get adminUploaded => 'Uploaded';

  @override
  String get adminUserActions => 'Actions';

  @override
  String adminUserBalance(int n) {
    return 'balance $n';
  }

  @override
  String get adminUserBan => 'Ban';

  @override
  String get adminUserBanTitle => 'Ban user?';

  @override
  String get adminUserCreated => 'Registered';

  @override
  String get adminUserCredits => 'Credits';

  @override
  String get adminUserEntitlements => 'Exam access';

  @override
  String get adminUserFreeUsed => 'Free exam used';

  @override
  String get adminUserGrade => 'Grade';

  @override
  String get adminUserGrant => 'Grant';

  @override
  String get adminUserGrantDelta => 'Credits';

  @override
  String get adminUserGrantDeltaHelp =>
      '1 credit = 1 exam; negative to take back';

  @override
  String get adminUserGrantDeltaInvalid =>
      'Enter a non-zero number from -100 to 100.';

  @override
  String get adminUserGrantDone => 'Credits updated';

  @override
  String get adminUserGrantTitle => 'Grant credits';

  @override
  String get adminUserGroupMissing => 'Group not found (deleted?)';

  @override
  String adminUserGroups(int count) {
    return 'Groups ($count)';
  }

  @override
  String get adminUserGrowth => 'Referrals and groups';

  @override
  String get adminUserLanguage => 'Language';

  @override
  String get adminUserLastActive => 'Last active';

  @override
  String get adminUserLedger => 'Credit history';

  @override
  String get adminUserLifetime => 'Credits purchased';

  @override
  String get adminUserNoEntitlements =>
      'No entitlement record yet (first exam not used).';

  @override
  String get adminUserNoGroups => 'Not in any group';

  @override
  String get adminUserOpenProfile => 'Open';

  @override
  String get adminUserPremiumOff => 'Remove premium';

  @override
  String get adminUserPremiumOffBody => 'The subscription returns to free.';

  @override
  String get adminUserPremiumOffTitle => 'Remove premium?';

  @override
  String get adminUserPremiumOn => 'Grant premium';

  @override
  String get adminUserPremiumOnBody =>
      'Sets the subscription to yearly for 365 days. Exam credits are separate and are granted only with credits.';

  @override
  String get adminUserPremiumOnTitle => 'Grant premium?';

  @override
  String get adminUserReferralCode => 'Referral code';

  @override
  String get adminUserReferralsCount => 'Invited';

  @override
  String get adminUserReferredBy => 'Invited by';

  @override
  String get adminUserRole => 'Role';

  @override
  String get adminUserRoleBody =>
      'Sets the role claim through the server. The user must sign in again for it to apply.';

  @override
  String get adminUserRoleDone => 'Role updated';

  @override
  String get adminUserRoleNone => 'No admin role';

  @override
  String get adminUserRoleTitle => 'Admin role';

  @override
  String get adminUserSchool => 'School';

  @override
  String get adminUserStats => 'Progress';

  @override
  String get adminUserSubscription => 'Subscription';

  @override
  String get adminUserTitle => 'User';

  @override
  String get adminUserUnban => 'Unban';

  @override
  String get adminUserUnbanBody => 'The ban flag will be removed.';

  @override
  String get adminUserUnbanTitle => 'Unban user?';

  @override
  String get adminUsersBanned => 'Banned';

  @override
  String get adminUsersEmpty => 'No users found.';

  @override
  String get adminUsersLegacyAdmin => 'admin (legacy)';

  @override
  String get adminUsersPremium => 'Premium';

  @override
  String get adminUsersSearch => 'Search by email (start)';

  @override
  String get adminVariantAddIds => 'Add question ids';

  @override
  String get adminVariantAddIdsHelp =>
      'Separate ids with spaces, commas or new lines';

  @override
  String get adminVariantAdvanced => 'Advanced';

  @override
  String get adminVariantArchived => 'Archived';

  @override
  String get adminVariantAutoFill => 'Auto-fill approved';

  @override
  String adminVariantAutoFilled(int n) {
    return 'Added $n approved questions';
  }

  @override
  String get adminVariantBasics => 'Variant';

  @override
  String adminVariantBlocked(int n) {
    return 'Publishing is blocked: $n problems.';
  }

  @override
  String get adminVariantBlueprintLocked =>
      'Remove all questions to change the structure.';

  @override
  String get adminVariantCheck => 'Check against the structure';

  @override
  String get adminVariantChooseBlueprint => 'Choose the test structure.';

  @override
  String get adminVariantClear => 'Clear';

  @override
  String get adminVariantDifficulty => 'Level';

  @override
  String get adminVariantDraft => 'Draft';

  @override
  String get adminVariantInReview => 'In review';

  @override
  String adminVariantN(int n) {
    return 'Variant $n';
  }

  @override
  String get adminVariantNoKey => 'no key';

  @override
  String get adminVariantNoProblems => 'No problems reported.';

  @override
  String get adminVariantNumber => 'Number';

  @override
  String get adminVariantNumberInvalid => 'Variant number must be 1–1000.';

  @override
  String get adminVariantPublish => 'Publish';

  @override
  String get adminVariantPublishBody =>
      'The server checks the variant again. Students will be able to start it right after publishing.';

  @override
  String get adminVariantPublishTitle => 'Publish variant?';

  @override
  String get adminVariantPublished => 'Published';

  @override
  String get adminVariantReadOnly =>
      'Read-only: only a super admin or a content manager can create and edit variants.';

  @override
  String get adminVariantReady => 'Ready to publish (the server checks again).';

  @override
  String get adminVariantRecheck => 'Re-check';

  @override
  String adminVariantResync(int version) {
    return 'Re-sync to blueprint version $version';
  }

  @override
  String adminVariantResyncDone(int version) {
    return 'The variant now targets blueprint version $version. Save to apply.';
  }

  @override
  String get adminVariantResyncHelp =>
      'The server publishes only variants built for the current blueprint version. Re-syncing keeps every question; then save and check the report.';

  @override
  String adminVariantServerResult(String status) {
    return 'Server: $status';
  }

  @override
  String get adminVariantStandard => 'Standard';

  @override
  String get adminVariantUnknownQuestion => 'not found';

  @override
  String get adminVariantUnpublish => 'Unpublish';

  @override
  String get adminVariantUnpublishBody =>
      'New attempts will not be possible. Attempts already started can still be finished.';

  @override
  String get adminVariantUnpublishTitle => 'Unpublish variant?';

  @override
  String get adminVariantsEdit => 'Variant';

  @override
  String get adminVariantsEmpty => 'No variants match the filter.';

  @override
  String get adminVariantsErrPublished =>
      'The variant is published. Unpublish it before editing.';

  @override
  String adminVariantsMeta(String blueprint, int count, int expected) {
    return '$blueprint · $count/$expected questions';
  }

  @override
  String get adminVariantsNew => 'New variant';

  @override
  String adminVpBlueprintVersion(int expected, int actual) {
    return 'Built for blueprint version $actual, current is $expected.';
  }

  @override
  String get adminVpLanguage =>
      'This language is not allowed by the blueprint.';

  @override
  String adminVpPartCount(String part, int expected, int actual) {
    return 'Part $part: $actual questions, needs $expected.';
  }

  @override
  String adminVpPartUnknown(String id) {
    return '$id: part unknown (set the part in the question).';
  }

  @override
  String adminVpQuestionDuplicate(String id) {
    return '$id: used more than once.';
  }

  @override
  String adminVpQuestionLanguage(String id) {
    return '$id: wrong language.';
  }

  @override
  String adminVpQuestionMissing(String id) {
    return '$id: question not found.';
  }

  @override
  String adminVpQuestionNoKey(String id) {
    return '$id: no answer key.';
  }

  @override
  String adminVpQuestionNotApproved(String id) {
    return '$id: not approved by a methodologist.';
  }

  @override
  String adminVpQuestionOptions(String id, int expected, int actual) {
    return '$id: $actual options, needs $expected.';
  }

  @override
  String adminVpQuestionPart(String id) {
    return '$id: its part is not in this section.';
  }

  @override
  String adminVpQuestionPassage(String id) {
    return '$id: needs a linked text.';
  }

  @override
  String adminVpQuestionSection(String id, String section) {
    return '$id: belongs to another section than $section.';
  }

  @override
  String adminVpSectionCount(String section, int expected, int actual) {
    return '$section: $actual questions, needs $expected.';
  }

  @override
  String adminVpSectionMissing(String section) {
    return 'Section $section is empty.';
  }

  @override
  String get adminVpSectionOrder => 'Sections are not in blueprint order.';

  @override
  String adminVpSectionUnknown(String section) {
    return 'Section $section is not in the blueprint.';
  }

  @override
  String get adminYes => 'yes';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get analytics => 'Analytics';

  @override
  String get appName => 'ORT Master KG';

  @override
  String get appVersion => 'App Version';

  @override
  String get appearance => 'Appearance';

  @override
  String get averageScore => 'Average Score';

  @override
  String billingBalanceAfter(int balance) {
    return 'Balance: $balance';
  }

  @override
  String get billingBalanceError => 'Couldn\'t load your balance.';

  @override
  String get billingBalanceTitle => 'Your balance';

  @override
  String billingBuySemantics(String title, String price) {
    return 'Buy $title for $price';
  }

  @override
  String get billingCreditHistoryTitle => 'Credit history';

  @override
  String get billingCreditRule => '1 credit = 1 full mock exam';

  @override
  String billingCreditsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count credits',
      one: '1 credit',
    );
    return '$_temp0';
  }

  @override
  String get billingErrorAccountMismatch =>
      'This purchase belongs to another account in the app. Sign in with that account to use it.';

  @override
  String get billingErrorAlreadyOwned =>
      'Your previous purchase is still being processed. We\'re checking it now.';

  @override
  String get billingErrorInvalid =>
      'The purchase couldn\'t be verified. If you were charged, Google Play will refund it automatically within 3 days.';

  @override
  String get billingErrorLaunch => 'Couldn\'t start the purchase. Try again.';

  @override
  String get billingErrorNotSignedIn => 'Sign in to buy tests.';

  @override
  String get billingErrorProductUnavailable =>
      'This offer is no longer available.';

  @override
  String get billingErrorStore => 'Google Play returned an error. Try again.';

  @override
  String get billingErrorStoreUnavailable =>
      'Google Play is unavailable right now. Try again later.';

  @override
  String get billingErrorVerifyDeferred =>
      'We couldn\'t confirm the purchase yet. We\'ll retry automatically, and your payment won\'t be lost.';

  @override
  String get billingExternalInfo => 'Credits on your account are shown here.';

  @override
  String get billingExternalNote => 'Your balance updates automatically.';

  @override
  String get billingFreeExamAvailable => 'Your first full mock exam is free';

  @override
  String get billingFreeExamUsed => 'Free mock exam already used';

  @override
  String billingFreeExamsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free mock exams left',
      one: '1 free mock exam left',
    );
    return '$_temp0';
  }

  @override
  String get billingHistoryError => 'Couldn\'t load the history.';

  @override
  String get billingHistoryTooltip => 'Purchase history';

  @override
  String get billingHonestNoGuarantee =>
      'Mock exams help you practise; they don\'t guarantee an ORT result.';

  @override
  String get billingHonestPayment => 'Payment is processed by Google Play.';

  @override
  String get billingHonestServer =>
      'Credits are added only after our server confirms the purchase.';

  @override
  String get billingLedgerEmpty => 'No credit changes yet.';

  @override
  String get billingLoadMore => 'Load more';

  @override
  String get billingLoadingProducts => 'Loading offers…';

  @override
  String billingOrderId(String id) {
    return 'Order $id';
  }

  @override
  String billingProductSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count full mock exams',
      one: '1 full mock exam',
    );
    return '$_temp0';
  }

  @override
  String billingProductTests(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tests',
      one: '1 test',
    );
    return '$_temp0';
  }

  @override
  String get billingProductsEmpty =>
      'Offers are temporarily unavailable. Please try again later.';

  @override
  String get billingProductsError => 'Couldn\'t load offers from Google Play.';

  @override
  String get billingProductsTitle => 'Buy mock exams';

  @override
  String get billingPurchasesEmpty => 'No purchases yet.';

  @override
  String get billingReasonAdminGrant => 'Added by support';

  @override
  String get billingReasonCreditsAdded => 'Credits added';

  @override
  String get billingReasonExamStart => 'Mock exam started';

  @override
  String get billingReasonFreeFirst => 'Free first exam';

  @override
  String get billingReasonOther => 'Balance change';

  @override
  String get billingReasonPurchase => 'Purchase';

  @override
  String get billingReasonRefund => 'Refund';

  @override
  String get billingRestore => 'Restore purchases';

  @override
  String get billingRestoreDone =>
      'Check finished. Your balance updates automatically.';

  @override
  String get billingRestoreStarted => 'Checking unfinished purchases…';

  @override
  String get billingRetry => 'Try again';

  @override
  String get billingSignInRequired =>
      'Sign in to see your balance and history.';

  @override
  String get billingStateGranted => 'Credited';

  @override
  String get billingStateInvalid => 'Not confirmed';

  @override
  String get billingStatePending => 'Awaiting payment';

  @override
  String get billingStateRefunded => 'Refunded';

  @override
  String get billingStateRevoked => 'Revoked';

  @override
  String get billingStatusCanceled => 'Purchase canceled.';

  @override
  String get billingStatusGranted =>
      'Purchase confirmed. Credits have been added.';

  @override
  String get billingStatusLaunching => 'Opening Google Play…';

  @override
  String get billingStatusPending =>
      'Awaiting payment. Credits will be added once Google Play confirms the payment.';

  @override
  String get billingStatusVerifying => 'Confirming your purchase…';

  @override
  String get billingStoreTitle => 'Exam access';

  @override
  String get billingTabLedger => 'Credits';

  @override
  String get billingTabPurchases => 'Purchases';

  @override
  String get billingTransactionsTitle => 'Purchase history';

  @override
  String get billingUnavailableBody =>
      'Google Play billing isn\'t available on this device. Make sure Google Play is installed and you\'re signed in to it.';

  @override
  String get billingUnavailableTitle => 'Purchases are unavailable';

  @override
  String get billingUnsupportedPlatformBody =>
      'Tests can be bought in the Android app through Google Play. Your balance is the same on every device.';

  @override
  String get billingUnsupportedPlatformTitle =>
      'Purchases aren\'t available here';

  @override
  String get biology => 'Biology';

  @override
  String get buyTest => 'Buy Test';

  @override
  String get cancel => 'Cancel';

  @override
  String get cardPayment => 'Card Payment';

  @override
  String get chemistry => 'Chemistry';

  @override
  String get clear => 'Clear';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get clearCacheConfirmation => 'Clear Cache?';

  @override
  String get clearCacheDesc => 'Free up space';

  @override
  String get clearCacheMessage =>
      'This will delete all downloaded content. You can download it again when online.';

  @override
  String get community => 'Community';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get continueTest => 'Continue Test';

  @override
  String get correct => 'Correct';

  @override
  String get currentPlan => 'Current Plan';

  @override
  String get dailyGoal => 'Daily Goal';

  @override
  String get dark => 'Dark';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get dataAndStorage => 'Data & Storage';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get done => 'Done';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get downloadedContent => 'Downloaded Content';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get email => 'Email';

  @override
  String get emailNotifications => 'Email Notifications';

  @override
  String get emailNotificationsDesc => 'News and updates';

  @override
  String get english => 'English';

  @override
  String get error => 'Error';

  @override
  String examAnsweredOf(int answered, int total) {
    return 'Answered $answered of $total';
  }

  @override
  String get examAutoSubmitted => 'Time is up. The section has been submitted.';

  @override
  String get examBuy => 'Buy';

  @override
  String get examBuyToStart => 'Buy a test';

  @override
  String get examCatalogEmpty => 'No exams are available yet.';

  @override
  String get examCatalogIntro => 'Full timed tests in the official ORT format.';

  @override
  String get examCatalogMainTitle => 'Main test';

  @override
  String get examCatalogStateLanguageTitle => 'State language';

  @override
  String get examCatalogSubjectsTitle => 'Subject tests';

  @override
  String get examClearAnswer => 'Clear answer';

  @override
  String get examColumnA => 'Column A';

  @override
  String get examColumnB => 'Column B';

  @override
  String get examContinue => 'Continue';

  @override
  String examCostCredit(int credits) {
    return '1 credit (you have $credits)';
  }

  @override
  String get examCostFree => 'Free — this is your first test';

  @override
  String get examCostNeedCredit => 'You need 1 credit to start this test.';

  @override
  String get examCostResume => 'Free — you are continuing your attempt';

  @override
  String get examDisclaimerFallback =>
      'Practice result. Not an official ORT score.';

  @override
  String examEntitlementCredits(int count) {
    return 'Credits: $count';
  }

  @override
  String get examEntitlementFree => 'Your first test is free';

  @override
  String examEntitlementFreeLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free tests left',
      one: '1 free test left',
    );
    return '$_temp0';
  }

  @override
  String get examEntitlementHint =>
      'One credit = one full test. Continuing an unfinished test is free.';

  @override
  String get examEntitlementNone => 'No credits left';

  @override
  String get examErrorAttemptNotFound => 'This attempt was not found.';

  @override
  String get examErrorBanned =>
      'Your account has been blocked by a moderator, so tests are not available. If you think this is a mistake, contact support.';

  @override
  String get examErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get examErrorNetwork =>
      'No connection. Check the internet and try again.';

  @override
  String get examErrorPlatformUnsupported =>
      'Practice tests are not available on this device. Open the app on your phone (Android or iPhone).';

  @override
  String get examErrorSignIn => 'Sign in to take exams.';

  @override
  String get examErrorVariantUnavailable =>
      'This variant is not available right now.';

  @override
  String get examExit => 'Leave test';

  @override
  String get examExitBody =>
      'The section timer keeps running on the server while you are away. Your answers are saved — you can continue from the home screen.';

  @override
  String get examExitLeave => 'Leave';

  @override
  String get examExitStay => 'Stay';

  @override
  String get examExitTitle => 'Leave the test?';

  @override
  String get examFinishSection => 'Finish section';

  @override
  String get examFinishSectionConfirm => 'Finish';

  @override
  String examFinishSectionFlagged(int count) {
    return 'Marked for review: $count';
  }

  @override
  String examFinishSectionTitle(String section) {
    return 'Finish “$section”?';
  }

  @override
  String examFinishSectionUnanswered(int count) {
    return 'Unanswered: $count';
  }

  @override
  String get examFinishSectionWarning =>
      'After finishing you cannot return to this section.';

  @override
  String get examFinishedLoading => 'Test finished. Loading your result…';

  @override
  String get examFlag => 'Mark for review';

  @override
  String get examHistoryAction => 'History';

  @override
  String examHistoryAttempts(int count) {
    return 'Attempts: $count';
  }

  @override
  String get examHistoryEmpty =>
      'No finished tests yet. Your results will appear here.';

  @override
  String examHistoryLast(String percent) {
    return 'Last: $percent%';
  }

  @override
  String get examHistoryTitle => 'Exam history';

  @override
  String examHistoryTrendDown(String delta) {
    return '−$delta% vs previous';
  }

  @override
  String get examHistoryTrendSame => 'Same as previous';

  @override
  String examHistoryTrendUp(String delta) {
    return '+$delta% vs previous';
  }

  @override
  String get examImageError => 'The image could not be loaded';

  @override
  String get examIntroCost => 'Cost';

  @override
  String examIntroLanguage(String language) {
    return 'Test language: $language';
  }

  @override
  String get examIntroRules => 'Rules';

  @override
  String get examIntroStructure => 'Structure';

  @override
  String get examKeepWorking => 'Keep working';

  @override
  String get examLangEn => 'English';

  @override
  String get examLangKy => 'Kyrgyz';

  @override
  String get examLangRu => 'Russian';

  @override
  String get examLanguageLabel => 'Test language';

  @override
  String get examLoading => 'Loading…';

  @override
  String examMinutesCount(int minutes) {
    return '$minutes min';
  }

  @override
  String get examMockTitle => 'Mock ORT';

  @override
  String get examNext => 'Next';

  @override
  String get examNextSectionTimeRunning =>
      'The timer of this section is already running:';

  @override
  String get examNextSectionTitle => 'Next section';

  @override
  String get examNoCreditsAvailable => 'No credits available';

  @override
  String get examNoQuestions =>
      'This section has no questions. Please contact support.';

  @override
  String get examOfflineAutoRetry => 'We will also retry automatically.';

  @override
  String get examOfflineBadge => 'Offline — answers are saved on the device';

  @override
  String get examOfflineBody =>
      'Your answers are saved on this device. The next section starts only after the server receives this one.';

  @override
  String get examOfflineTitle => 'No connection';

  @override
  String examOnlyLanguage(String language) {
    return 'Only in $language';
  }

  @override
  String examOptionSemantics(String letter) {
    return 'Option $letter';
  }

  @override
  String get examPalette => 'Questions';

  @override
  String get examPaletteAnswered => 'Answered';

  @override
  String get examPaletteCurrent => 'Current';

  @override
  String get examPaletteFlagged => 'Marked';

  @override
  String get examPaletteUnanswered => 'Not answered';

  @override
  String get examPartAssumption =>
      'The official split between these parts is not published; this is an approximation.';

  @override
  String get examPassage => 'Text';

  @override
  String get examPlatformUnsupportedShort => 'Not available on this device';

  @override
  String get examPassageHide => 'Hide text';

  @override
  String get examPassageShow => 'Show text';

  @override
  String get examPrevious => 'Previous';

  @override
  String examQuestionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String examQuestionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String get examResultBySection => 'By section';

  @override
  String get examResultCorrect => 'Correct';

  @override
  String get examResultIncorrect => 'Wrong';

  @override
  String get examResultLevelsBody =>
      'The official result of the state language test is a level from 1 to 4. The level boundaries are not published, so the app shows only your percentage of correct answers and does not guess your level.';

  @override
  String get examResultLevelsTitle => 'How the official result works';

  @override
  String get examResultNoWeak => 'No weak topics found — great job!';

  @override
  String get examResultNotEligible =>
      'Some sections were closed late, so this attempt does not count for the leaderboard.';

  @override
  String get examResultPending =>
      'The result is still being calculated. Try again in a few seconds.';

  @override
  String examResultRecommendation(String topic) {
    return 'Review “$topic”: go back to the theory and solve 10–15 practice questions on it.';
  }

  @override
  String get examResultReview => 'Review answers';

  @override
  String examResultScore(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get examResultSkipped => 'Skipped';

  @override
  String get examResultStrong => 'Strong topics';

  @override
  String get examResultTitle => 'Result';

  @override
  String get examResultToExams => 'To exams';

  @override
  String examResultTopicScore(int correct, int total) {
    return '$correct of $total';
  }

  @override
  String get examResultWeak => 'What to review';

  @override
  String get examResultWrongOrSkipped => 'Wrong or skipped';

  @override
  String examResultXp(int xp) {
    return 'XP earned: $xp';
  }

  @override
  String get examResumeAwaitingSubmit => 'Waiting to be submitted';

  @override
  String get examResumeTimeUp => 'Section time is up';

  @override
  String get examResumeTitle => 'Unfinished test';

  @override
  String get examRetry => 'Try again';

  @override
  String get examReviewAskTutor => 'Ask the AI tutor';

  @override
  String examReviewCorrectAnswer(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get examReviewEmpty => 'Nothing here for this filter.';

  @override
  String get examReviewExplanation => 'Explanation';

  @override
  String get examReviewFilterAll => 'All';

  @override
  String get examReviewFilterFlagged => 'Marked';

  @override
  String get examReviewFilterWrong => 'Mistakes';

  @override
  String get examReviewNoAnswer => 'no answer';

  @override
  String examReviewQuestionNumber(int number) {
    return 'Question $number';
  }

  @override
  String get examReviewTitle => 'Answer review';

  @override
  String examReviewYourAnswer(String answer) {
    return 'Your answer: $answer';
  }

  @override
  String get examRuleForwardOnly =>
      'Sections go strictly in order. A finished section is closed — you cannot return to it.';

  @override
  String get examRuleFreeNavigation =>
      'Inside a section you can move between questions freely and mark them to come back later.';

  @override
  String get examRuleKeepsRunning =>
      'If you leave the app, the timer keeps running. Your answers are saved on the device.';

  @override
  String get examRuleNoCalculator => 'Calculators are not allowed.';

  @override
  String examRuleScratchpad(String sections) {
    return 'Scratch paper is allowed in: $sections.';
  }

  @override
  String get examRuleTimer =>
      'Each section has its own timer. You will be warned 5 minutes and 1 minute before the end; at zero the section is submitted automatically.';

  @override
  String get examSectionDone => 'Section submitted';

  @override
  String examSectionLabel(int index, int count) {
    return 'Section $index of $count';
  }

  @override
  String examSectionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sections',
      one: '1 section',
    );
    return '$_temp0';
  }

  @override
  String get examShowMore => 'Show more';

  @override
  String get examStart => 'Start test';

  @override
  String get examStartSection => 'Start section';

  @override
  String get examStarting => 'Preparing your test…';

  @override
  String get examSubmitting => 'Submitting the section…';

  @override
  String get examTabTitle => 'Exams';

  @override
  String get examTimeLeftLabel => 'Time left';

  @override
  String get examTotal => 'Total';

  @override
  String get examUnflag => 'Remove mark';

  @override
  String get examVariantAdvanced => 'Advanced';

  @override
  String examVariantBest(String percent) {
    return 'Best: $percent%';
  }

  @override
  String get examVariantInProgress => 'In progress';

  @override
  String get examVariantNotStarted => 'Not started';

  @override
  String examVariantTitle(int number) {
    return 'Variant $number';
  }

  @override
  String get examVariants => 'Variants';

  @override
  String get examVariantsEmpty =>
      'No variants in this language yet. New ones are added regularly.';

  @override
  String get examWarningFive => '5 minutes left in this section';

  @override
  String get examWarningOne =>
      '1 minute left — the section will be submitted automatically';

  @override
  String get explanation => 'Explanation';

  @override
  String get finish => 'Finish';

  @override
  String get flashcards => 'Flashcards';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get free => 'Free';

  @override
  String get geography => 'Geography';

  @override
  String get getStarted => 'Get Started';

  @override
  String get googleSignIn => 'Sign in with Google';

  @override
  String get grade10 => 'Grade 10';

  @override
  String get grade11 => 'Grade 11';

  @override
  String get grade9 => 'Grade 9';

  @override
  String get graduate => 'Graduate';

  @override
  String get history => 'History of Kyrgyzstan';

  @override
  String get hours => 'hours';

  @override
  String get incorrect => 'Incorrect';

  @override
  String get kgs => 'KGS';

  @override
  String get kyrgyz => 'Kyrgyz';

  @override
  String get kyrgyzLanguage => 'Kyrgyz Language';

  @override
  String get language => 'Language';

  @override
  String get learnAchAccuracy90Desc => 'Score 90% on a mock exam';

  @override
  String get learnAchAccuracy90Title => '90% accuracy';

  @override
  String get learnAchAnalogiesDesc => 'A high score in the analogies section';

  @override
  String get learnAchAnalogiesTitle => 'Analogies master';

  @override
  String get learnAchDays30Desc => 'Study on 30 different days';

  @override
  String get learnAchDays30Title => '30 study days';

  @override
  String get learnAchExamChampionDesc => 'Complete 10 mock exams';

  @override
  String get learnAchExamChampionTitle => 'Mock exam champion';

  @override
  String get learnAchFirstLessonDesc => 'Complete your first lesson';

  @override
  String get learnAchFirstLessonTitle => 'First lesson';

  @override
  String get learnAchMathExpertDesc => '90% in math on three mock exams';

  @override
  String get learnAchMathExpertTitle => 'Math expert';

  @override
  String get learnAchReaderDesc => 'A high score in the reading section';

  @override
  String get learnAchReaderTitle => 'Reader';

  @override
  String get learnAchStreak7Desc => 'Study 7 days in a row';

  @override
  String get learnAchStreak7Title => 'Week streak';

  @override
  String get learnAchXp100Desc => 'Earn 100 XP';

  @override
  String get learnAchXp100Title => 'First 100 XP';

  @override
  String get learnAchievementLocked => 'Locked';

  @override
  String get learnAchievementUnlocked => 'Unlocked';

  @override
  String learnAchievementUnlockedOn(String date) {
    return 'Unlocked on $date';
  }

  @override
  String get learnAchievementsServerNote =>
      'Achievements are granted automatically from your results on the server.';

  @override
  String get learnAchievementsTitle => 'Achievements';

  @override
  String learnAchievementsUnlocked(int n, int total) {
    return '$n of $total unlocked';
  }

  @override
  String learnAnswersCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n answers',
      one: '1 answer',
    );
    return '$_temp0';
  }

  @override
  String get learnAskTutor => 'Ask the AI tutor';

  @override
  String learnAvgPerQuestion(int seconds) {
    return 'Average $seconds s per question';
  }

  @override
  String get learnBack => 'Back';

  @override
  String get learnBackHome => 'Back to home';

  @override
  String get learnBestResult => 'Best result';

  @override
  String get learnCorrect => 'Correct!';

  @override
  String learnCorrectAnswerIs(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get learnDailyLessonTitle => 'Lesson of the day';

  @override
  String get learnDifficultyEasy => 'Easy';

  @override
  String get learnDifficultyHard => 'Hard';

  @override
  String get learnDifficultyMedium => 'Medium';

  @override
  String learnDurationMinutes(int n) {
    return '$n min';
  }

  @override
  String get learnElapsedTime => 'Elapsed time';

  @override
  String get learnErrorGeneric => 'Could not load data. Please try again.';

  @override
  String get learnErrorNotFound => 'Not found.';

  @override
  String get learnErrorOffline =>
      'No connection. Check the internet and try again.';

  @override
  String get learnErrorPermission =>
      'No access to the data. Please sign in again.';

  @override
  String get learnExamHistoryAll => 'Full history';

  @override
  String get learnExamHistoryEmpty => 'You haven\'t finished a mock exam yet.';

  @override
  String get learnExamHistoryTitle => 'Recent attempts';

  @override
  String get learnExamHistoryUnavailable =>
      'Exam history is unavailable right now.';

  @override
  String get learnExamResultUnofficial =>
      'Practice result, not an official ORT score.';

  @override
  String get learnExamResultsTitle => 'Mock exams';

  @override
  String get learnExamSectionsTitle => 'Average by section';

  @override
  String learnExitBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your answers to $count questions can be saved.',
      one: 'Your answer to 1 question can be saved.',
      zero: 'You haven\'t answered any questions yet.',
    );
    return '$_temp0';
  }

  @override
  String get learnExitContinue => 'Continue';

  @override
  String get learnExitDiscard => 'Leave without saving';

  @override
  String get learnExitFinish => 'Finish and save';

  @override
  String get learnExitTitle => 'Finish practice?';

  @override
  String get learnExplanation => 'Explanation';

  @override
  String get learnFinish => 'Finish';

  @override
  String get learnHandbookFactsUnavailable =>
      'Couldn\'t load the exam structure.';

  @override
  String get learnHandbookNotFound => 'Handbook section not found';

  @override
  String get learnHandbookRussianOnly =>
      'This section is available in Russian only.';

  @override
  String get learnHandbookSearch => 'Search the handbook';

  @override
  String learnHandbookSections(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sections',
      one: '1 section',
    );
    return '$_temp0';
  }

  @override
  String get learnHandbookTitle => 'Handbook';

  @override
  String get learnHbAssumption => '(split is an assumption)';

  @override
  String learnHbMainTest(String year) {
    return 'ORT main test ($year)';
  }

  @override
  String learnHbMainTotal(int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions items',
      one: '1 item',
    );
    return 'Total: $_temp0, $minutes min.';
  }

  @override
  String learnHbMaxScore(int score) {
    return 'The official maximum score of the main test is $score.';
  }

  @override
  String learnHbPartLine(String title, int questions, int options) {
    String _temp0 = intl.Intl.pluralLogic(
      options,
      locale: localeName,
      other: '$options answer options',
      one: '1 answer option',
    );
    return '$title: $questions items, $_temp0';
  }

  @override
  String learnHbSectionLine(String title, int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions items',
      one: '1 item',
    );
    return '$title: $_temp0, $minutes min';
  }

  @override
  String learnHbStateLanguage(int questions, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      questions,
      locale: localeName,
      other: '$questions items',
      one: '1 item',
    );
    return '$_temp0, $minutes min. Required for the certificate; reported as level 1–4.';
  }

  @override
  String get learnHbSubjectTests => 'Subject tests (optional)';

  @override
  String learnHbThresholdCollege(int n) {
    return 'Colleges: $n on the main test.';
  }

  @override
  String learnHbThresholdsUniversity(int main, int subject) {
    return 'University thresholds: $main on the main test and $subject on subject tests (2026–2027).';
  }

  @override
  String get learnHbThresholdsYearly =>
      'Thresholds are set anew every year — check testing.kg.';

  @override
  String get learnLeaderboardAllTime => 'All time';

  @override
  String get learnLeaderboardAnonymous => 'Student';

  @override
  String get learnLeaderboardBySubject => 'By subject';

  @override
  String get learnLeaderboardEmpty => 'The leaderboard is empty';

  @override
  String get learnLeaderboardEmptyBody =>
      'It will fill up as students earn XP.';

  @override
  String get learnLeaderboardNotRanked =>
      'You\'re not on this board yet. XP from lessons, practice and mock exams is added automatically.';

  @override
  String get learnLeaderboardSubjectEmptyBody =>
      'It will fill up as students complete mock exams in this test.';

  @override
  String get learnLeaderboardSubjectHint =>
      'Only this week\'s XP from mock exams in the selected test counts here.';

  @override
  String get learnLeaderboardSubjectNotRanked =>
      'You\'re not on this board yet. Only XP from mock exams in this test counts here.';

  @override
  String get learnLeaderboardTitle => 'Leaderboard';

  @override
  String get learnLeaderboardWeekly => 'Weekly';

  @override
  String learnLeaderboardYou(String name) {
    return '$name (you)';
  }

  @override
  String get learnLessonAllDone =>
      'You\'ve completed every lesson in this subject.';

  @override
  String get learnLessonCommonMistakes => 'Common mistakes';

  @override
  String get learnLessonCompletedToast => 'Lesson marked as completed.';

  @override
  String get learnLessonDone => 'Lesson completed';

  @override
  String learnLessonExampleN(int n) {
    return 'Example $n';
  }

  @override
  String get learnLessonExamples => 'Examples';

  @override
  String get learnLessonFormulas => 'Formulas';

  @override
  String get learnLessonHideSolution => 'Hide solution';

  @override
  String get learnLessonMarkDone => 'Mark lesson as completed';

  @override
  String get learnLessonMaterials => 'Materials';

  @override
  String get learnLessonNoContent =>
      'The lesson content hasn\'t been added yet.';

  @override
  String get learnLessonNotFound => 'Lesson not found';

  @override
  String get learnLessonNotFoundBody =>
      'The lesson may not be published yet or was removed.';

  @override
  String learnLessonNumber(int n) {
    return 'Lesson $n';
  }

  @override
  String get learnLessonOpenPdf => 'Open PDF';

  @override
  String learnLessonPracticeBody(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n questions on this lesson.',
      one: '1 question on this lesson.',
    );
    return '$_temp0';
  }

  @override
  String get learnLessonPracticeSubjectBody =>
      'Reinforce the material with questions on this subject.';

  @override
  String get learnLessonPracticeTitle => 'Lesson practice';

  @override
  String get learnLessonShowSolution => 'Show solution';

  @override
  String get learnLessonSummary => 'Summary';

  @override
  String get learnLessonTitle => 'Lesson';

  @override
  String get learnLessonWatchVideo => 'Watch the video';

  @override
  String learnLessonsCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lessons',
      one: '1 lesson',
    );
    return '$_temp0';
  }

  @override
  String get learnLessonsHeading => 'Lessons';

  @override
  String learnLevelN(int n) {
    return 'Level $n';
  }

  @override
  String get learnLinkFailed => 'Couldn\'t open the link.';

  @override
  String get learnLoadingLesson => 'Loading the lesson…';

  @override
  String get learnLoadingQuestions => 'Picking questions…';

  @override
  String get learnLoadingSubject => 'Loading the subject…';

  @override
  String get learnLoadingSubjects => 'Loading subjects…';

  @override
  String learnMinutes(int n) {
    return '$n min';
  }

  @override
  String get learnMistakeFromExam => 'Question from a mock exam';

  @override
  String get learnMistakeMarkReviewed => 'Mark as reviewed';

  @override
  String get learnMistakeOpenReview => 'Review';

  @override
  String get learnMistakePractice => 'Practise';

  @override
  String get learnMistakeQuestion => 'Question';

  @override
  String get learnMistakeResolve => 'Mark as resolved';

  @override
  String learnMistakeReviewOn(String date) {
    return 'review on $date';
  }

  @override
  String get learnMistakeReviewToday => 'due today';

  @override
  String get learnMistakeReviewedPrompt =>
      'Reviewed this question? Mark it and it will come back later.';

  @override
  String learnMistakeWrongCount(int n) {
    return 'wrong: $n';
  }

  @override
  String get learnMistakesAllSubjects => 'All subjects';

  @override
  String learnMistakesDueToday(int n) {
    return 'Due today: $n';
  }

  @override
  String get learnMistakesEmptyBody =>
      'Wrong answers from practice and exams will appear here.';

  @override
  String get learnMistakesEmptyTitle => 'No mistakes to review';

  @override
  String get learnMistakesFilterAll => 'All';

  @override
  String get learnMistakesFilterDue => 'Due';

  @override
  String get learnMistakesNothingDue =>
      'All caught up for today. Come back tomorrow.';

  @override
  String learnMistakesPracticeN(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Review $n questions',
      one: 'Review 1 question',
    );
    return '$_temp0';
  }

  @override
  String get learnMistakesPracticeTitle => 'Mistakes review';

  @override
  String get learnMistakesSrsNote =>
      'Each mistake comes back after 1, 3, 7, 14 and 30 days. A correct answer moves it further; a wrong one restarts it.';

  @override
  String get learnMistakesTitle => 'Mistakes & review';

  @override
  String get learnMore => 'More';

  @override
  String get learnNext => 'Next';

  @override
  String get learnNextLesson => 'Next lesson';

  @override
  String get learnNoExplanation =>
      'No explanation has been added for this question yet.';

  @override
  String get learnNoLessonsYet => 'No lessons yet — start with practice.';

  @override
  String get learnNoQuestionsBody =>
      'There are no reviewed questions here yet. Check back later or try quick practice.';

  @override
  String get learnNoQuestionsTitle => 'No questions yet';

  @override
  String get learnNoSearchResults => 'Nothing found';

  @override
  String get learnNoSubjectsBody =>
      'Learning materials are coming soon. Meanwhile, try quick practice.';

  @override
  String get learnNoSubjectsTitle => 'No subjects yet';

  @override
  String get learnOpenMistakes => 'Work on mistakes';

  @override
  String get learnPracticeAgain => 'Practice again';

  @override
  String get learnPracticeBySubjectEmpty =>
      'Answer a few questions to see accuracy by subject.';

  @override
  String get learnPracticeBySubjectTitle => 'Practice by subject';

  @override
  String learnPracticeCorrectOfTotal(int correct, int total) {
    return '$correct of $total correct';
  }

  @override
  String get learnPracticeNotOrtNote =>
      'This is a practice result, not an ORT score: a short set of questions cannot estimate an exam score.';

  @override
  String learnPracticePercentLabel(int percent) {
    return 'Practice: $percent%';
  }

  @override
  String get learnPracticeSubject => 'Practise this subject';

  @override
  String get learnPracticeTitle => 'Practice';

  @override
  String get learnPracticeVerdictExcellent => 'Excellent! Keep it up.';

  @override
  String get learnPracticeVerdictFair =>
      'Not bad. Reviewing mistakes improves results fastest.';

  @override
  String get learnPracticeVerdictGood => 'Good. Almost there.';

  @override
  String get learnPracticeVerdictLow =>
      'More practice needed. Start by reviewing mistakes.';

  @override
  String get learnProgressEmptyBody =>
      'Complete a lesson or practice set to see your real statistics.';

  @override
  String get learnProgressEmptyTitle => 'No data yet';

  @override
  String get learnProgressTitle => 'My progress';

  @override
  String learnQuestAnswer(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Answer $n questions',
      one: 'Answer 1 question',
    );
    return '$_temp0';
  }

  @override
  String get learnQuestCompleteSet => 'Finish one practice set';

  @override
  String learnQuestRun(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n correct answers in a row',
      one: '1 correct answer in a row',
    );
    return '$_temp0';
  }

  @override
  String learnQuestionNumber(int n) {
    return 'Question $n';
  }

  @override
  String learnQuestionProgress(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String learnQuestsDone(int done, int total) {
    return '$done of $total done';
  }

  @override
  String learnQuestsReset(int h, int m) {
    return 'Reset in $h h $m min';
  }

  @override
  String get learnQuestsTitle => 'Daily quests';

  @override
  String get learnQuickPracticeTitle => 'Quick practice';

  @override
  String learnRecDueMistakesTitle(int n) {
    return 'We recommend reviewing your mistakes ($n)';
  }

  @override
  String get learnRecDueMistakesWhy =>
      '…because they are due today, and spaced review makes material stick.';

  @override
  String learnRecMoreDataTitle(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'We recommend answering $n more questions',
      one: 'We recommend answering 1 more question',
    );
    return '$_temp0';
  }

  @override
  String get learnRecMoreDataWhy =>
      '…because accuracy becomes meaningful after about 20 answers.';

  @override
  String get learnRecNoExamTitle => 'We recommend taking a mock exam';

  @override
  String get learnRecNoExamWhy =>
      '…because there\'s no result across all sections yet, so it\'s unclear which one lags.';

  @override
  String get learnRecOpenExams => 'Go to exams';

  @override
  String learnRecWeakSectionTitle(String section) {
    return 'We recommend working on $section';
  }

  @override
  String learnRecWeakSectionWhy(int percent) {
    return '…because you average $percent% there on mock exams — your lowest section.';
  }

  @override
  String learnRecWeakSubjectTitle(String subject) {
    return 'We recommend practising $subject';
  }

  @override
  String learnRecWeakSubjectWhy(int percent, int count) {
    return '…because your accuracy there is $percent%, lower than in other subjects ($count answers).';
  }

  @override
  String learnRecWeakTopicTitle(String topic) {
    return 'We recommend revisiting $topic';
  }

  @override
  String learnRecWeakTopicWhy(int percent) {
    return '…because only $percent% of your answers on this topic are correct.';
  }

  @override
  String get learnRecommendationsNone => 'Everything looks good — keep going.';

  @override
  String get learnRecommendationsTitle => 'Recommendations';

  @override
  String get learnResultsEmptyBody =>
      'Do a practice set and the answer review will appear here.';

  @override
  String get learnResultsEmptyTitle => 'No results yet';

  @override
  String get learnResultsTitle => 'Practice result';

  @override
  String get learnReviewAnswers => 'Review answers';

  @override
  String get learnRightAnswer => 'Correct answer';

  @override
  String get learnSearchSubjects => 'Search subjects';

  @override
  String get learnSignIn => 'Sign in';

  @override
  String get learnSignInToPractice =>
      'Sign in to practise and save your progress.';

  @override
  String get learnSignInToSave => 'Sign in to save your progress.';

  @override
  String get learnSkip => 'Skip';

  @override
  String get learnSkipAndFinish => 'Skip and finish';

  @override
  String get learnStartPractice => 'Start practice';

  @override
  String get learnStatAnswered => 'Practice answers';

  @override
  String learnStatBestStreak(int n) {
    return 'Best: $n';
  }

  @override
  String get learnStatCorrect => 'Correct';

  @override
  String get learnStatExams => 'Mock exams';

  @override
  String learnStatLessonsCompleted(int n) {
    return 'lessons done: $n';
  }

  @override
  String get learnStatLessonsDone => 'Lessons done';

  @override
  String get learnStatLevel => 'Level';

  @override
  String get learnStatPracticeAccuracy => 'Practice accuracy';

  @override
  String get learnStatPracticeOnly => 'practice only';

  @override
  String get learnStatPracticeTime => 'Practice time';

  @override
  String get learnStatPracticeTimeHint => 'from finished sets';

  @override
  String learnStatSessions(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sets',
      one: '1 set',
    );
    return '$_temp0';
  }

  @override
  String get learnStatSkipped => 'Skipped';

  @override
  String get learnStatStreak => 'Streak, days';

  @override
  String get learnStatTime => 'Time';

  @override
  String get learnStatWrong => 'Wrong';

  @override
  String learnStreakDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get learnSubjectNotFound => 'Subject not found';

  @override
  String get learnSubjectNotFoundBody => 'The link may be out of date.';

  @override
  String get learnSubjectsTitle => 'Subjects';

  @override
  String get learnWeakTopicsEmpty =>
      'Not enough answers to spot weak topics yet (5+ per topic needed).';

  @override
  String get learnWeakTopicsTitle => 'Topics to review';

  @override
  String get learnWrong => 'Incorrect';

  @override
  String learnXpAwarded(int xp) {
    return '+$xp XP';
  }

  @override
  String get learnXpNone => 'No XP was awarded for this set.';

  @override
  String get learnXpPending => 'Awarding XP…';

  @override
  String get learnXpQueued => 'XP will be credited once you\'re back online.';

  @override
  String learnXpShort(int xp) {
    return '$xp XP';
  }

  @override
  String learnXpToNextLevel(int xp, int level) {
    return '$xp XP to level $level';
  }

  @override
  String learnXpTotal(int xp) {
    return '$xp XP total';
  }

  @override
  String get learnYourAnswer => 'Your answer';

  @override
  String get lessons => 'Lessons';

  @override
  String get light => 'Light';

  @override
  String get loading => 'Loading...';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get mathematics => 'Mathematics';

  @override
  String get mbankPayment => 'MBank Payment';

  @override
  String get mockTest => 'Mock Test';

  @override
  String get mockTestDesc => 'Complete mock test with real exam format';

  @override
  String get mockTestTitle => 'Full ORT Simulation';

  @override
  String get monthly => 'Monthly';

  @override
  String get myProgress => 'My Progress';

  @override
  String get next => 'Next';

  @override
  String get nextOrtDate => 'Next ORT Registration';

  @override
  String get noConnection => 'No internet connection';

  @override
  String get notifications => 'Notifications';

  @override
  String get onboardingDesc1 =>
      'Complete practice tests and master all subjects for the ORT exam';

  @override
  String get onboardingDesc2 =>
      'Monitor your performance and identify weak areas to improve';

  @override
  String get onboardingDesc3 =>
      'Take full-length simulations with real ORT format and timing';

  @override
  String get onboardingTitle1 => 'Prepare for ORT';

  @override
  String get onboardingTitle2 => 'Track Your Progress';

  @override
  String get onboardingTitle3 => 'Mock Exams';

  @override
  String get orContinueWith => 'Or continue with';

  @override
  String get password => 'Password';

  @override
  String get payNow => 'Pay Now';

  @override
  String get payment => 'Payment';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get phoneSignIn => 'Sign in with Phone';

  @override
  String get physics => 'Physics';

  @override
  String get practiceQuiz => 'Practice Quiz';

  @override
  String get previous => 'Previous';

  @override
  String get price => 'Price';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get profile => 'Profile';

  @override
  String get progress => 'Progress';

  @override
  String get pushNotifications => 'Push Notifications';

  @override
  String get pushNotificationsDesc => 'Study reminders';

  @override
  String get retry => 'Retry';

  @override
  String get review => 'Review';

  @override
  String get russian => 'Russian';

  @override
  String get russianLanguage => 'Russian Language';

  @override
  String get score => 'Score';

  @override
  String get section1 => 'Main Test';

  @override
  String get section2 => 'Subject Test';

  @override
  String get section3 => 'Language Test';

  @override
  String get selectGrade => 'Select Your Grade';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get selectSubjects => 'Select Weak Subjects';

  @override
  String get settings => 'Settings';

  @override
  String get shellAuthConfirmPasswordLabel => 'Repeat password';

  @override
  String get shellAuthContinueWithGoogle => 'Continue with Google';

  @override
  String get shellAuthEmailInvalid =>
      'Check the email address, e.g. name@example.com';

  @override
  String get shellAuthEmailLabel => 'Email';

  @override
  String get shellAuthEmailRequired => 'Enter your email';

  @override
  String get shellAuthErrorDifferentCredential =>
      'This email is linked to another sign-in method.';

  @override
  String get shellAuthErrorEmailInUse =>
      'This email is already registered. Sign in instead.';

  @override
  String get shellAuthErrorGoogleUnavailable =>
      'Google sign-in isn\'t available on this device yet. Use email instead.';

  @override
  String get shellAuthErrorInvalidCredentials => 'Wrong email or password.';

  @override
  String get shellAuthErrorNetwork =>
      'No connection. Check the internet and try again.';

  @override
  String get shellAuthErrorNotAllowed =>
      'This sign-in method is temporarily unavailable.';

  @override
  String get shellAuthErrorTooManyRequests =>
      'Too many attempts. Wait a few minutes and try again.';

  @override
  String get shellAuthErrorUnknown => 'Something went wrong. Please try again.';

  @override
  String get shellAuthErrorUserDisabled =>
      'This account has been blocked. Contact support.';

  @override
  String get shellAuthErrorUserNotFound =>
      'No account with this email. Create one first.';

  @override
  String get shellAuthForgotPassword => 'Forgot password?';

  @override
  String get shellAuthHidePassword => 'Hide password';

  @override
  String get shellAuthNameLabel => 'Name';

  @override
  String get shellAuthNameRequired => 'Enter your name';

  @override
  String get shellAuthNameTooShort => 'Name is too short';

  @override
  String get shellAuthOr => 'or';

  @override
  String shellAuthPasswordHint(int min) {
    return 'At least $min characters, letters and digits';
  }

  @override
  String get shellAuthPasswordLabel => 'Password';

  @override
  String get shellAuthPasswordMismatch => 'Passwords don\'t match';

  @override
  String get shellAuthPasswordRequired => 'Enter a password';

  @override
  String shellAuthPasswordTooShort(int min) {
    return 'Password must be at least $min characters';
  }

  @override
  String get shellAuthPasswordTooWeak => 'Use both letters and digits';

  @override
  String get shellAuthResetMessage =>
      'Enter your account email and we\'ll send a link to set a new password.';

  @override
  String get shellAuthResetSend => 'Send link';

  @override
  String get shellAuthResetSent =>
      'If an account with this email exists, we\'ve sent a reset link.';

  @override
  String get shellAuthResetTitle => 'Reset password';

  @override
  String get shellAuthShowPassword => 'Show password';

  @override
  String get shellBootErrorMessage =>
      'Check your internet connection and try again.';

  @override
  String get shellBootErrorTitle => 'Couldn\'t start the app';

  @override
  String get shellCancel => 'Cancel';

  @override
  String get shellDaily10Desc => 'Easy start';

  @override
  String get shellDaily20Desc => 'Steady pace';

  @override
  String get shellDaily30Desc => 'Intensive preparation';

  @override
  String shellDailyMinutes(int minutes) {
    return '$minutes min a day';
  }

  @override
  String get shellExitConfirm => 'Exit';

  @override
  String get shellExitMessage => 'Your progress is saved.';

  @override
  String get shellExitTitle => 'Exit the app?';

  @override
  String get shellGoHome => 'Go to home';

  @override
  String get shellGoalBand110Desc => 'Solid base';

  @override
  String get shellGoalBand150Desc => 'Strong result';

  @override
  String get shellGoalBand190Desc => 'Top result';

  @override
  String get shellGoalUnsure => 'Not sure yet';

  @override
  String get shellGradeGraduate => 'Graduate';

  @override
  String get shellGradeLabel => 'Grade';

  @override
  String shellGradeNumber(int grade) {
    return 'Grade $grade';
  }

  @override
  String get shellHide => 'Hide';

  @override
  String shellHomeBestStreak(int count) {
    return 'Best: $count';
  }

  @override
  String get shellHomeBuyExam => 'Get a mock exam';

  @override
  String shellHomeCredits(int count) {
    return 'Mock exams available: $count';
  }

  @override
  String get shellHomeDailyGoal => 'Daily goal';

  @override
  String get shellHomeEmptyStatsMessage =>
      'Solve a task or take a lesson — your streak and daily progress will appear here.';

  @override
  String get shellHomeEmptyStatsTitle => 'Start your streak today';

  @override
  String get shellHomeEntitlementError => 'Couldn\'t check access · Retry';

  @override
  String get shellHomeFreeExam => 'Free mock exam available';

  @override
  String shellHomeGoalMinutes(int minutes) {
    return 'Your goal: $minutes min a day';
  }

  @override
  String get shellHomeGoalReached => 'Daily goal reached!';

  @override
  String get shellHomeGreeting => 'Hi!';

  @override
  String shellHomeGreetingName(String name) {
    return 'Hi, $name!';
  }

  @override
  String shellHomeLevelXp(int level, int xp) {
    return 'Level $level · $xp XP';
  }

  @override
  String get shellHomeNextStepError => 'Couldn\'t load your recommendation.';

  @override
  String get shellHomeNoCredits => 'No mock exams available';

  @override
  String get shellHomeReminderEnable => 'Turn on';

  @override
  String get shellHomeReminderMessage =>
      'A short daily reminder helps keep your streak.';

  @override
  String get shellHomeReminderTitle => 'Remind you to study?';

  @override
  String get shellHomeSetupAction => 'Set up';

  @override
  String get shellHomeSetupMessage =>
      'Add your grade, region and target score to get better recommendations.';

  @override
  String get shellHomeSetupTitle => 'Set your goal';

  @override
  String get shellHomeStatsError => 'Couldn\'t load your progress.';

  @override
  String shellHomeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days in a row',
      one: '1 day in a row',
    );
    return '$_temp0';
  }

  @override
  String get shellHomeStreakNone => 'No streak yet';

  @override
  String get shellHomeSubtitle => 'Let\'s keep preparing for the ORT';

  @override
  String shellHomeTodayXp(int today) {
    return 'Today: $today XP';
  }

  @override
  String shellHomeTodayXpOfGoal(int today, int goal) {
    return 'Today: $today of $goal XP';
  }

  @override
  String get shellLangEn => 'English';

  @override
  String get shellLangEnNative => 'English';

  @override
  String get shellLangKy => 'Kyrgyz';

  @override
  String get shellLangKyNative => 'Кыргызча';

  @override
  String get shellLangRu => 'Russian';

  @override
  String get shellLangRuNative => 'Русский';

  @override
  String get shellLater => 'Later';

  @override
  String get shellLinkOpenFailed => 'Couldn\'t open the link.';

  @override
  String get shellLoading => 'Loading';

  @override
  String get shellLoginButton => 'Sign in';

  @override
  String get shellLoginCreateAccount => 'Create one';

  @override
  String get shellLoginNoAccount => 'No account yet?';

  @override
  String get shellLoginSubtitle => 'Sign in to continue preparing for the ORT.';

  @override
  String get shellLoginTitle => 'Welcome back';

  @override
  String get shellNavExams => 'Exams';

  @override
  String get shellNavHome => 'Home';

  @override
  String get shellNavLearn => 'Learn';

  @override
  String get shellNavProfile => 'Profile';

  @override
  String get shellNavProgress => 'Progress';

  @override
  String get shellNextFirstMock =>
      'Take a full mock exam to see your level and weak topics.';

  @override
  String get shellNextFirstMockFree =>
      'Take your first full mock exam — it\'s free. You\'ll see your level and weak topics.';

  @override
  String get shellNextOpenExams => 'Go to exams';

  @override
  String get shellNextOpenLearn => 'Go to study';

  @override
  String get shellNextPractice =>
      'Good work! Reinforce it with a quick test or take another mock exam.';

  @override
  String get shellNextStepTitle => 'Next step';

  @override
  String shellNextWeakTopic(String area) {
    return 'Your weakest area in the last exam: $area. Review it to raise your score.';
  }

  @override
  String get shellNotFoundMessage =>
      'The link may be outdated. Go back to the home screen.';

  @override
  String get shellNotFoundTitle => 'Page not found';

  @override
  String get shellNotNow => 'Not now';

  @override
  String get shellNotSet => 'Not set';

  @override
  String get shellOnbAboutSubtitle =>
      'We\'ll tailor tasks and show your region\'s leaderboard.';

  @override
  String get shellOnbAboutTitle => 'Tell us about yourself';

  @override
  String get shellOnbBack => 'Back';

  @override
  String get shellOnbDailySubtitle =>
      'Short daily sessions work better than rare marathons.';

  @override
  String get shellOnbDailyTitle => 'How much time a day can you study?';

  @override
  String get shellOnbGoalSubtitle =>
      'A goal shows how far you still have to go. You can change it in your profile.';

  @override
  String get shellOnbGoalTitle => 'What score are you aiming for?';

  @override
  String get shellOnbLangKyHint => 'ORT in Kyrgyz';

  @override
  String get shellOnbLangRuHint => 'ORT in Russian';

  @override
  String get shellOnbLanguageSubtitle =>
      'The app and mock exams will use this language. You can change it in Settings.';

  @override
  String get shellOnbLanguageTitle => 'Which language will you prepare in?';

  @override
  String get shellOnbNext => 'Next';

  @override
  String get shellOnbSavedLater =>
      'Answers saved. They\'ll sync when you\'re online.';

  @override
  String get shellOnbSkip => 'Skip';

  @override
  String get shellOnbStart => 'Get started';

  @override
  String shellOnbStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get shellOnbUniversityHint => 'e.g. KSMA or KNU';

  @override
  String get shellOnbUniversityLabel => 'Dream university';

  @override
  String get shellOptional => 'Optional';

  @override
  String get shellProfileAchievements => 'Achievements';

  @override
  String get shellProfileComplete => 'Fill in profile';

  @override
  String get shellProfileDailyGoal => 'Daily goal';

  @override
  String get shellProfileDeleteAccount => 'Delete account';

  @override
  String get shellProfileEdit => 'Edit profile';

  @override
  String get shellProfileEditTitle => 'Edit profile';

  @override
  String get shellProfileExamLanguage => 'Exam language';

  @override
  String get shellProfileExams => 'Exams';

  @override
  String get shellProfileGoal => 'Target score';

  @override
  String get shellProfileLevel => 'Level';

  @override
  String get shellProfileLoadError => 'Couldn\'t load your profile.';

  @override
  String get shellProfileNoName => 'Student';

  @override
  String get shellProfileRegionLocked =>
      'The region can be changed once a year.';

  @override
  String get shellProfileSaveError =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String get shellProfileSaved => 'Profile saved.';

  @override
  String get shellProfileSavedOffline =>
      'Saved. Changes will sync when you\'re online.';

  @override
  String get shellProfileSchool => 'School';

  @override
  String get shellProfileStreak => 'Streak';

  @override
  String get shellProfileTransactions => 'Purchases';

  @override
  String get shellQuickDailyLesson => 'Lesson of the day';

  @override
  String get shellQuickHandbook => 'Handbook';

  @override
  String get shellQuickLeaderboard => 'Leaderboard';

  @override
  String get shellQuickMockExam => 'Mock exam';

  @override
  String get shellQuickTest => 'Quick test';

  @override
  String get shellQuickTitle => 'Quick actions';

  @override
  String get shellQuickTutor => 'AI tutor';

  @override
  String get shellRegionDistrict => 'District';

  @override
  String get shellRegionLabel => 'Region';

  @override
  String get shellRegionLoadError => 'Couldn\'t load the list of regions.';

  @override
  String get shellRegionOblast => 'Region or city';

  @override
  String get shellReminderDenied =>
      'Notifications are off for the app. Allow them in your phone settings.';

  @override
  String get shellReminderEnabled => 'Reminders are on.';

  @override
  String get shellReminderFailed =>
      'Couldn\'t turn on reminders. Try again later.';

  @override
  String get shellReminderUnsupported =>
      'Reminders aren\'t available on this device.';

  @override
  String get shellRetry => 'Try again';

  @override
  String get shellSave => 'Save';

  @override
  String get shellSettingsAbout => 'About';

  @override
  String get shellSettingsAppearance => 'App';

  @override
  String get shellSettingsDisclaimer =>
      'Mock exam results are for practice and are not official ORT scores.';

  @override
  String get shellSettingsLanguage => 'Language';

  @override
  String get shellSettingsNotifications => 'Notifications';

  @override
  String get shellSettingsPrivacy => 'Privacy Policy';

  @override
  String get shellSettingsReminder => 'Daily reminder';

  @override
  String get shellSettingsReminderHint =>
      'A short reminder to study once a day';

  @override
  String get shellSettingsTerms => 'Terms of Service';

  @override
  String get shellSettingsTheme => 'Theme';

  @override
  String get shellSettingsTitle => 'Settings';

  @override
  String get shellSettingsVersion => 'Version';

  @override
  String get shellSignOut => 'Sign out';

  @override
  String get shellSignOutMessage => 'Your progress stays in your account.';

  @override
  String get shellSignOutTitle => 'Sign out?';

  @override
  String get shellSignupButton => 'Create account';

  @override
  String get shellSignupHaveAccount => 'Already have an account?';

  @override
  String get shellSignupLegalAnd => ' and the ';

  @override
  String get shellSignupLegalPrefix =>
      'By creating an account you agree to the ';

  @override
  String get shellSignupSubtitle =>
      'It takes a minute. Your progress will be saved in your account.';

  @override
  String get shellSignupSuccess =>
      'Account created. We\'ve sent a confirmation email.';

  @override
  String get shellSignupTitle => 'Create account';

  @override
  String get shellTagline => 'ORT preparation';

  @override
  String get shellThemeDark => 'Dark';

  @override
  String get shellThemeLight => 'Light';

  @override
  String get shellThemeSystem => 'As on device';

  @override
  String get shellVerifyCheck => 'I\'ve confirmed';

  @override
  String get shellVerifyDone => 'Email confirmed. Thank you!';

  @override
  String shellVerifyMessage(String email) {
    return 'We sent a link to $email. It helps you recover your account.';
  }

  @override
  String get shellVerifyNotYet =>
      'Not confirmed yet. Open the link from the email.';

  @override
  String get shellVerifyResend => 'Send again';

  @override
  String get shellVerifySendFailed =>
      'Couldn\'t send the email. Try again later.';

  @override
  String get shellVerifySent => 'Email sent. Check your inbox and spam folder.';

  @override
  String get shellVerifyTitle => 'Confirm your email';

  @override
  String get signup => 'Sign Up';

  @override
  String get skip => 'Skip';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get startLearning => 'Start Learning';

  @override
  String get startQuiz => 'Start Quiz';

  @override
  String get startTest => 'Start Test';

  @override
  String get streak => 'Day Streak';

  @override
  String get strongTopics => 'Strong Topics';

  @override
  String get studyTime => 'Study Time';

  @override
  String get subjects => 'Subjects';

  @override
  String get submit => 'Submit';

  @override
  String get subscribe => 'Subscribe';

  @override
  String get subscription => 'Subscription';

  @override
  String get success => 'Success';

  @override
  String get system => 'System';

  @override
  String get takeQuiz => 'Take Quiz';

  @override
  String get terms => 'Terms of Service';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get tests => 'Tests';

  @override
  String get testsTaken => 'Tests Taken';

  @override
  String get theme => 'Theme';

  @override
  String get timeSpent => 'Time Spent';

  @override
  String get tutorAssistant => 'Tutor';

  @override
  String get tutorClear => 'Clear chat';

  @override
  String get tutorContextAttempt => 'Exam attempt attached';

  @override
  String get tutorContextQuestion => 'Question attached';

  @override
  String get tutorContextRemove => 'Remove attachment';

  @override
  String get tutorDisclaimer =>
      'AI can make mistakes. Check important steps with your textbook or teacher.';

  @override
  String get tutorEmptyBody =>
      'Choose a mode above and ask a question. I explain the reasoning instead of just giving the answer.';

  @override
  String get tutorEmptyTitle => 'How can I help?';

  @override
  String get tutorErrorBanned =>
      'Your account is restricted, so the AI tutor isn\'t available. If you think this is a mistake, contact support.';

  @override
  String get tutorErrorDisabled => 'The AI tutor is temporarily unavailable.';

  @override
  String get tutorErrorExamInProgress =>
      'The tutor can\'t help during an active exam. Finish the attempt, then review your mistakes here.';

  @override
  String get tutorErrorNetwork =>
      'No connection. Check the internet and try again.';

  @override
  String get tutorErrorQuota =>
      'You\'ve used today\'s AI requests. Come back tomorrow.';

  @override
  String get tutorErrorSignIn => 'Sign in to use the AI tutor.';

  @override
  String get tutorErrorUnknown => 'The tutor couldn\'t answer. Try again.';

  @override
  String get tutorErrorValidation =>
      'The message is empty or too long. Shorten it and try again.';

  @override
  String tutorExplainPrompt(
    String stem,
    String options,
    String userAnswer,
    String correctAnswer,
  ) {
    return 'Help me understand my mistake.\nTask: $stem\nOptions:\n$options\nMy answer: $userAnswer\nCorrect answer: $correctAnswer\nExplain where I went wrong and how to reason correctly.';
  }

  @override
  String get tutorExplainerAiButton => 'Explain my mistake';

  @override
  String get tutorExplainerAiTitle => 'Why is it wrong? Ask the AI tutor';

  @override
  String get tutorExplainerClose => 'Close';

  @override
  String get tutorExplainerCorrect => 'Correct!';

  @override
  String tutorExplainerCorrectAnswer(String answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get tutorExplainerExplanation => 'Explanation';

  @override
  String get tutorExplainerIncorrect => 'Incorrect';

  @override
  String get tutorExplainerNext => 'Next';

  @override
  String get tutorExplainerNoAnswer => 'no answer';

  @override
  String get tutorExplainerOpenChat => 'Open tutor chat';

  @override
  String get tutorExplainerTryAgain => 'Try again';

  @override
  String tutorExplainerYourAnswer(String answer) {
    return 'Your answer: $answer';
  }

  @override
  String get tutorHintChat => 'Ask anything about ORT preparation.';

  @override
  String get tutorHintExplainMistake =>
      'Paste the task and your answer — I\'ll explain where the mistake is.';

  @override
  String get tutorHintGrammar =>
      'Ask about a rule or paste a sentence to check.';

  @override
  String get tutorHintPractice => 'Name a topic — I\'ll suggest similar tasks.';

  @override
  String get tutorHintStepByStep =>
      'Describe the problem — we\'ll solve it step by step.';

  @override
  String get tutorHintStudyPlan => 'Tell me your exam date and weak subjects.';

  @override
  String tutorMessageTooLong(int count, int max) {
    return 'The message is too long ($count/$max characters). Shorten it to send.';
  }

  @override
  String get tutorModeChat => 'Free question';

  @override
  String get tutorModeExplainMistake => 'Explain a mistake';

  @override
  String get tutorModeGrammar => 'Grammar';

  @override
  String get tutorModePractice => 'Similar tasks';

  @override
  String get tutorModeStepByStep => 'Step by step';

  @override
  String get tutorModeStudyPlan => 'Study plan';

  @override
  String tutorRemainingToday(int count) {
    return 'Requests left today: $count';
  }

  @override
  String get tutorRetry => 'Retry';

  @override
  String get tutorSend => 'Send';

  @override
  String get tutorThinking => 'The tutor is thinking…';

  @override
  String get tutorTitle => 'AI tutor';

  @override
  String get tutorUnavailablePlatform =>
      'The AI tutor isn\'t available on this platform. Use the Android app.';

  @override
  String get tutorYou => 'You';

  @override
  String get weakTopics => 'Weak Topics';

  @override
  String get welcome => 'Welcome';

  @override
  String get yearly => 'Yearly';
}
