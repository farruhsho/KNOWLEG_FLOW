import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ky.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ky'),
    Locale('ru'),
  ];

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @accountDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete account permanently'**
  String get accountDeleteButton;

  /// No description provided for @accountDeleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type {word}'**
  String accountDeleteConfirmLabel(String word);

  /// Word the user must type to confirm deletion
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get accountDeleteConfirmWord;

  /// No description provided for @accountDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleteDone;

  /// No description provided for @accountDeleteGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountDeleteGoToLogin;

  /// No description provided for @accountDeleteInProgress.
  ///
  /// In en, this message translates to:
  /// **'Deleting your data…'**
  String get accountDeleteInProgress;

  /// No description provided for @accountDeleteItemAi.
  ///
  /// In en, this message translates to:
  /// **'AI tutor usage history'**
  String get accountDeleteItemAi;

  /// No description provided for @accountDeleteItemCredits.
  ///
  /// In en, this message translates to:
  /// **'Unused exam credits and the free exam — they are cancelled and can\'t be transferred'**
  String get accountDeleteItemCredits;

  /// No description provided for @accountDeleteItemExams.
  ///
  /// In en, this message translates to:
  /// **'Mock exam attempts and results'**
  String get accountDeleteItemExams;

  /// No description provided for @accountDeleteItemGamification.
  ///
  /// In en, this message translates to:
  /// **'XP, level, streaks, achievements and leaderboard entries'**
  String get accountDeleteItemGamification;

  /// No description provided for @accountDeleteItemLogin.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in (email and password or the Google link)'**
  String get accountDeleteItemLogin;

  /// No description provided for @accountDeleteItemProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile: name, email, photo, grade, region and settings'**
  String get accountDeleteItemProfile;

  /// No description provided for @accountDeleteItemProgress.
  ///
  /// In en, this message translates to:
  /// **'Learning progress, lesson history, mistakes and the review queue'**
  String get accountDeleteItemProgress;

  /// No description provided for @accountDeleteKeptGoogle.
  ///
  /// In en, this message translates to:
  /// **'Your Google Play payment history is kept by Google in your Google account.'**
  String get accountDeleteKeptGoogle;

  /// No description provided for @accountDeleteKeptPurchases.
  ///
  /// In en, this message translates to:
  /// **'Anonymized purchase records (date, product, amount, order number) without your name or email. We need them for financial reporting, refunds and fraud prevention.'**
  String get accountDeleteKeptPurchases;

  /// No description provided for @accountDeleteSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to delete your account.'**
  String get accountDeleteSignedOut;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Your account and learning data will be permanently deleted. You won\'t be able to restore them.'**
  String get accountDeleteWarningBody;

  /// No description provided for @accountDeleteWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone'**
  String get accountDeleteWarningTitle;

  /// No description provided for @accountDeleteWhatDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'What will be deleted'**
  String get accountDeleteWhatDeletedTitle;

  /// No description provided for @accountDeleteWhatKeptTitle.
  ///
  /// In en, this message translates to:
  /// **'What we keep'**
  String get accountDeleteWhatKeptTitle;

  /// No description provided for @accountErrorGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Try again.'**
  String get accountErrorGoogle;

  /// No description provided for @accountErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again.'**
  String get accountErrorNetwork;

  /// No description provided for @accountErrorRecentLogin.
  ///
  /// In en, this message translates to:
  /// **'For security, please sign in again and repeat.'**
  String get accountErrorRecentLogin;

  /// No description provided for @accountErrorService.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is temporarily unavailable. Try again later.'**
  String get accountErrorService;

  /// No description provided for @accountErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get accountErrorTooManyRequests;

  /// No description provided for @accountErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the account. Try again.'**
  String get accountErrorUnknown;

  /// No description provided for @accountErrorUserMismatch.
  ///
  /// In en, this message translates to:
  /// **'That\'s a different account. Sign in with the account you want to delete.'**
  String get accountErrorUserMismatch;

  /// No description provided for @accountErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get accountErrorWrongPassword;

  /// No description provided for @accountReauthBody.
  ///
  /// In en, this message translates to:
  /// **'For security, sign in again before deleting the account.'**
  String get accountReauthBody;

  /// No description provided for @accountReauthCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountReauthCancel;

  /// No description provided for @accountReauthConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get accountReauthConfirm;

  /// No description provided for @accountReauthEmail.
  ///
  /// In en, this message translates to:
  /// **'Account: {email}'**
  String accountReauthEmail(String email);

  /// No description provided for @accountReauthGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get accountReauthGoogle;

  /// No description provided for @accountReauthPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountReauthPassword;

  /// No description provided for @accountReauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get accountReauthTitle;

  /// No description provided for @adminAccountMenu.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminAccountMenu;

  /// No description provided for @adminActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get adminActivate;

  /// No description provided for @adminActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminActive;

  /// No description provided for @adminAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get adminAdd;

  /// No description provided for @adminAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get adminAddOption;

  /// No description provided for @adminAiCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get adminAiCount;

  /// No description provided for @adminAiDraftMeta.
  ///
  /// In en, this message translates to:
  /// **'{topic} · difficulty {difficulty}'**
  String adminAiDraftMeta(String topic, int difficulty);

  /// No description provided for @adminAiDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts: {n}'**
  String adminAiDrafts(int n);

  /// No description provided for @adminAiEmpty.
  ///
  /// In en, this message translates to:
  /// **'Fill in the request and generate drafts.'**
  String get adminAiEmpty;

  /// No description provided for @adminAiFillForm.
  ///
  /// In en, this message translates to:
  /// **'Choose structure, section, part and topic.'**
  String get adminAiFillForm;

  /// No description provided for @adminAiGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate drafts'**
  String get adminAiGenerate;

  /// No description provided for @adminAiGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get adminAiGenerating;

  /// No description provided for @adminAiNotice.
  ///
  /// In en, this message translates to:
  /// **'Drafts are generated on the server; no API key is stored in the app. Every draft is saved with the status \"Draft\" and must be approved by a methodologist before it can be used in a variant.'**
  String get adminAiNotice;

  /// No description provided for @adminAiOpenBank.
  ///
  /// In en, this message translates to:
  /// **'Open the exam bank'**
  String get adminAiOpenBank;

  /// No description provided for @adminAiRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get adminAiRequest;

  /// No description provided for @adminAiSaveSelected.
  ///
  /// In en, this message translates to:
  /// **'Save {n}'**
  String adminAiSaveSelected(int n);

  /// No description provided for @adminAiSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {n} drafts for review'**
  String adminAiSaved(int n);

  /// No description provided for @adminAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminAll;

  /// No description provided for @adminAppCheckPlatformNote.
  ///
  /// In en, this message translates to:
  /// **'App Check is not available on this platform: server functions that enforce it (roles, credits, publishing, pricing, AI drafts) may be rejected. Use the web build with App Check or Android.'**
  String get adminAppCheckPlatformNote;

  /// No description provided for @adminAppTitle.
  ///
  /// In en, this message translates to:
  /// **'ORT Master · CMS'**
  String get adminAppTitle;

  /// No description provided for @adminApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get adminApply;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminClose;

  /// No description provided for @adminCorrectMultiHelp.
  ///
  /// In en, this message translates to:
  /// **'Mark all correct options.'**
  String get adminCorrectMultiHelp;

  /// No description provided for @adminCorrectSingleHelp.
  ///
  /// In en, this message translates to:
  /// **'Mark the one correct option.'**
  String get adminCorrectSingleHelp;

  /// No description provided for @adminDashboardReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Open the exam bank with the status filter \"Draft\" or \"AI-checked\" to review questions. Only approved questions with an answer key can go into a published variant.'**
  String get adminDashboardReviewBody;

  /// No description provided for @adminDashboardReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review queue'**
  String get adminDashboardReviewTitle;

  /// No description provided for @adminDashboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get adminDashboardShortcuts;

  /// No description provided for @adminDashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Signed in as: {role}'**
  String adminDashboardWelcome(String role);

  /// No description provided for @adminDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get adminDeactivate;

  /// No description provided for @adminDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminDelete;

  /// No description provided for @adminDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get adminDeletePermanently;

  /// No description provided for @adminDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get adminDeleted;

  /// No description provided for @adminDifficulty1.
  ///
  /// In en, this message translates to:
  /// **'1 · easy'**
  String get adminDifficulty1;

  /// No description provided for @adminDifficulty2.
  ///
  /// In en, this message translates to:
  /// **'2 · medium'**
  String get adminDifficulty2;

  /// No description provided for @adminDifficulty3.
  ///
  /// In en, this message translates to:
  /// **'3 · hard'**
  String get adminDifficulty3;

  /// No description provided for @adminDifficultyN.
  ///
  /// In en, this message translates to:
  /// **'difficulty {n}'**
  String adminDifficultyN(int n);

  /// No description provided for @adminDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get adminDiscard;

  /// No description provided for @adminEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminEdit;

  /// No description provided for @adminErrAppCheckPlatform.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the request: App Check is not available on this platform (Windows/Linux, or web without an App Check key). Open the admin panel in the web build with App Check or on Android, or ask the owner to set APP_CHECK_ENFORCE_ADMIN=false.'**
  String get adminErrAppCheckPlatform;

  /// No description provided for @adminErrAppCheckRejected.
  ///
  /// In en, this message translates to:
  /// **'The server rejected the request (App Check token missing or invalid). Sign in again; if it repeats, check the App Check registration of this device.'**
  String get adminErrAppCheckRejected;

  /// No description provided for @adminErrFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large (max {mb} MB).'**
  String adminErrFileTooLarge(int mb);

  /// No description provided for @adminErrForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get adminErrForbidden;

  /// No description provided for @adminErrFunctionMissing.
  ///
  /// In en, this message translates to:
  /// **'The server function is not deployed yet.'**
  String get adminErrFunctionMissing;

  /// No description provided for @adminErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String adminErrGeneric(String message);

  /// No description provided for @adminErrIndex.
  ///
  /// In en, this message translates to:
  /// **'Firestore needs an index for this filter. Change the filter or create the index.'**
  String get adminErrIndex;

  /// No description provided for @adminErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Check the network and try again.'**
  String get adminErrNetwork;

  /// No description provided for @adminErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get adminErrNotFound;

  /// No description provided for @adminErrQuota.
  ///
  /// In en, this message translates to:
  /// **'Limit reached. Try again later.'**
  String get adminErrQuota;

  /// No description provided for @adminErrTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get adminErrTitle;

  /// No description provided for @adminErrUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get adminErrUnknown;

  /// No description provided for @adminErrUnsupportedMedia.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file format ({ext}). Allowed: PNG, JPEG, WEBP, GIF, PDF.'**
  String adminErrUnsupportedMedia(String ext);

  /// No description provided for @adminErrUserBanned.
  ///
  /// In en, this message translates to:
  /// **'This account is blocked. Server actions are not available.'**
  String get adminErrUserBanned;

  /// No description provided for @adminErrValidation.
  ///
  /// In en, this message translates to:
  /// **'Validation failed: {message}'**
  String adminErrValidation(String message);

  /// No description provided for @adminExamAddTable.
  ///
  /// In en, this message translates to:
  /// **'Add table'**
  String get adminExamAddTable;

  /// No description provided for @adminExamApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminExamApprove;

  /// No description provided for @adminExamBackToDraft.
  ///
  /// In en, this message translates to:
  /// **'Back to draft'**
  String get adminExamBackToDraft;

  /// No description provided for @adminExamChoosePlacement.
  ///
  /// In en, this message translates to:
  /// **'Choose the test structure and section first.'**
  String get adminExamChoosePlacement;

  /// No description provided for @adminExamColumnA.
  ///
  /// In en, this message translates to:
  /// **'Column A'**
  String get adminExamColumnA;

  /// No description provided for @adminExamColumnB.
  ///
  /// In en, this message translates to:
  /// **'Column B'**
  String get adminExamColumnB;

  /// No description provided for @adminExamColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns A / B'**
  String get adminExamColumns;

  /// No description provided for @adminExamColumnsHelp.
  ///
  /// In en, this message translates to:
  /// **'Quantitative comparison: the two quantities to compare. The stem holds only the shared condition (it may be empty).'**
  String get adminExamColumnsHelp;

  /// No description provided for @adminExamCorrectIs.
  ///
  /// In en, this message translates to:
  /// **'Correct option: {id}'**
  String adminExamCorrectIs(String id);

  /// No description provided for @adminExamCreateTranslation.
  ///
  /// In en, this message translates to:
  /// **'Create in {lang}'**
  String adminExamCreateTranslation(String lang);

  /// No description provided for @adminExamEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit exam question'**
  String get adminExamEdit;

  /// No description provided for @adminExamEmpty.
  ///
  /// In en, this message translates to:
  /// **'No exam questions match the filter.'**
  String get adminExamEmpty;

  /// No description provided for @adminExamErrApproveNoKey.
  ///
  /// In en, this message translates to:
  /// **'Cannot approve: the question has no answer key.'**
  String get adminExamErrApproveNoKey;

  /// No description provided for @adminExamFixedOptions.
  ///
  /// In en, this message translates to:
  /// **'This part uses fixed answer options. Mark the correct one.'**
  String get adminExamFixedOptions;

  /// No description provided for @adminExamGroup.
  ///
  /// In en, this message translates to:
  /// **'Translation group: {id}'**
  String adminExamGroup(String id);

  /// No description provided for @adminExamHasTranslation.
  ///
  /// In en, this message translates to:
  /// **'Has translation'**
  String get adminExamHasTranslation;

  /// No description provided for @adminExamImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get adminExamImage;

  /// No description provided for @adminExamIssueColumns.
  ///
  /// In en, this message translates to:
  /// **'Fill in both columns A and B.'**
  String get adminExamIssueColumns;

  /// No description provided for @adminExamIssueLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose the language (ru, ky or en).'**
  String get adminExamIssueLanguage;

  /// No description provided for @adminExamIssueOptionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Option ids must be unique.'**
  String get adminExamIssueOptionDuplicate;

  /// No description provided for @adminExamIssueOptionsCount.
  ///
  /// In en, this message translates to:
  /// **'The blueprint requires {n} options.'**
  String adminExamIssueOptionsCount(int n);

  /// No description provided for @adminExamIssuePart.
  ///
  /// In en, this message translates to:
  /// **'Choose the part of the section.'**
  String get adminExamIssuePart;

  /// No description provided for @adminExamIssuePassage.
  ///
  /// In en, this message translates to:
  /// **'This part needs a linked text (passage).'**
  String get adminExamIssuePassage;

  /// No description provided for @adminExamIssueSection.
  ///
  /// In en, this message translates to:
  /// **'Choose blueprint and section.'**
  String get adminExamIssueSection;

  /// No description provided for @adminExamIssueTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic id is required.'**
  String get adminExamIssueTopic;

  /// No description provided for @adminExamKey.
  ///
  /// In en, this message translates to:
  /// **'Answer key (never shown to students before the end)'**
  String get adminExamKey;

  /// No description provided for @adminExamLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get adminExamLink;

  /// No description provided for @adminExamLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Link existing translation'**
  String get adminExamLinkTitle;

  /// No description provided for @adminExamLinked.
  ///
  /// In en, this message translates to:
  /// **'Translations linked'**
  String get adminExamLinked;

  /// No description provided for @adminExamMarkAiVerified.
  ///
  /// In en, this message translates to:
  /// **'Mark as AI-checked'**
  String get adminExamMarkAiVerified;

  /// No description provided for @adminExamNew.
  ///
  /// In en, this message translates to:
  /// **'New exam question'**
  String get adminExamNew;

  /// No description provided for @adminExamNewPassage.
  ///
  /// In en, this message translates to:
  /// **'New text'**
  String get adminExamNewPassage;

  /// No description provided for @adminExamNoBlueprint.
  ///
  /// In en, this message translates to:
  /// **'No blueprint section matches {subject}/{section}. Choose the structure again.'**
  String adminExamNoBlueprint(String subject, String section);

  /// No description provided for @adminExamNoGroup.
  ///
  /// In en, this message translates to:
  /// **'Not linked to a translation yet.'**
  String get adminExamNoGroup;

  /// No description provided for @adminExamNoImage.
  ///
  /// In en, this message translates to:
  /// **'No image.'**
  String get adminExamNoImage;

  /// No description provided for @adminExamNoTable.
  ///
  /// In en, this message translates to:
  /// **'No table.'**
  String get adminExamNoTable;

  /// No description provided for @adminExamPartUnverified.
  ///
  /// In en, this message translates to:
  /// **'This split into parts is an assumption (not officially published).'**
  String get adminExamPartUnverified;

  /// No description provided for @adminExamPassage.
  ///
  /// In en, this message translates to:
  /// **'Linked text'**
  String get adminExamPassage;

  /// No description provided for @adminExamPassageEmpty.
  ///
  /// In en, this message translates to:
  /// **'The text is empty.'**
  String get adminExamPassageEmpty;

  /// No description provided for @adminExamPassageText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get adminExamPassageText;

  /// No description provided for @adminExamPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get adminExamPlacement;

  /// No description provided for @adminExamQuestionId.
  ///
  /// In en, this message translates to:
  /// **'Question id'**
  String get adminExamQuestionId;

  /// No description provided for @adminExamReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminExamReject;

  /// No description provided for @adminExamRemoveTable.
  ///
  /// In en, this message translates to:
  /// **'Remove table'**
  String get adminExamRemoveTable;

  /// No description provided for @adminExamReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get adminExamReview;

  /// No description provided for @adminExamReviewDone.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String adminExamReviewDone(String status);

  /// No description provided for @adminExamReviewNoRights.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot change the review status.'**
  String get adminExamReviewNoRights;

  /// No description provided for @adminExamReviewNotes.
  ///
  /// In en, this message translates to:
  /// **'Reviewer notes'**
  String get adminExamReviewNotes;

  /// No description provided for @adminExamReviewedBy.
  ///
  /// In en, this message translates to:
  /// **'{uid} · {date}'**
  String adminExamReviewedBy(String uid, String date);

  /// No description provided for @adminExamSaveBeforeReview.
  ///
  /// In en, this message translates to:
  /// **'Save your changes before changing the status.'**
  String get adminExamSaveBeforeReview;

  /// No description provided for @adminExamSavedBackToDraft.
  ///
  /// In en, this message translates to:
  /// **'Saved. The content changed, so the question went back to \"Draft\" for review.'**
  String get adminExamSavedBackToDraft;

  /// No description provided for @adminExamSolutionSteps.
  ///
  /// In en, this message translates to:
  /// **'Solution steps'**
  String get adminExamSolutionSteps;

  /// No description provided for @adminExamSolutionStepsHelp.
  ///
  /// In en, this message translates to:
  /// **'One step per line'**
  String get adminExamSolutionStepsHelp;

  /// No description provided for @adminExamSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get adminExamSource;

  /// No description provided for @adminExamSourceAdapted.
  ///
  /// In en, this message translates to:
  /// **'Adapted / translated'**
  String get adminExamSourceAdapted;

  /// No description provided for @adminExamSourceAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get adminExamSourceAi;

  /// No description provided for @adminExamSourceAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get adminExamSourceAuthor;

  /// No description provided for @adminExamSourceBasis.
  ///
  /// In en, this message translates to:
  /// **'Source / basis'**
  String get adminExamSourceBasis;

  /// No description provided for @adminExamSourceKind.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get adminExamSourceKind;

  /// No description provided for @adminExamSourceOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get adminExamSourceOriginal;

  /// No description provided for @adminExamStemLabel.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get adminExamStemLabel;

  /// No description provided for @adminExamTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get adminExamTable;

  /// No description provided for @adminExamTableAddColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get adminExamTableAddColumn;

  /// No description provided for @adminExamTableAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get adminExamTableAddRow;

  /// No description provided for @adminExamTableCell.
  ///
  /// In en, this message translates to:
  /// **'Cell'**
  String get adminExamTableCell;

  /// No description provided for @adminExamTableEmpty.
  ///
  /// In en, this message translates to:
  /// **'The table is empty and will not be saved.'**
  String get adminExamTableEmpty;

  /// No description provided for @adminExamTableHeader.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get adminExamTableHeader;

  /// No description provided for @adminExamTableHeaderShort.
  ///
  /// In en, this message translates to:
  /// **'Hdr'**
  String get adminExamTableHeaderShort;

  /// No description provided for @adminExamTableHelp.
  ///
  /// In en, this message translates to:
  /// **'Header row and body rows; cells accept Markdown and LaTeX (\$...\$). In comparison items the first row holds quantities A and B.'**
  String get adminExamTableHelp;

  /// No description provided for @adminExamTablePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get adminExamTablePreview;

  /// No description provided for @adminExamTableRemoveColumn.
  ///
  /// In en, this message translates to:
  /// **'Remove column'**
  String get adminExamTableRemoveColumn;

  /// No description provided for @adminExamTableRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove row'**
  String get adminExamTableRemoveRow;

  /// No description provided for @adminExamTranslations.
  ///
  /// In en, this message translates to:
  /// **'Translations'**
  String get adminExamTranslations;

  /// No description provided for @adminExamWrongNote.
  ///
  /// In en, this message translates to:
  /// **'Why {id} is wrong'**
  String adminExamWrongNote(String id);

  /// No description provided for @adminExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get adminExport;

  /// No description provided for @adminExportCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get adminExportCopied;

  /// No description provided for @adminExportCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get adminExportCopy;

  /// No description provided for @adminExportHelp.
  ///
  /// In en, this message translates to:
  /// **'Exports the questions matching the current filter (up to 5000). Dates are written as ISO strings.'**
  String get adminExportHelp;

  /// No description provided for @adminExportSave.
  ///
  /// In en, this message translates to:
  /// **'Save file'**
  String get adminExportSave;

  /// No description provided for @adminExportSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get adminExportSaved;

  /// No description provided for @adminExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export questions'**
  String get adminExportTitle;

  /// No description provided for @adminFieldBlueprint.
  ///
  /// In en, this message translates to:
  /// **'Test structure'**
  String get adminFieldBlueprint;

  /// No description provided for @adminFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get adminFieldDescription;

  /// No description provided for @adminFieldDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get adminFieldDifficulty;

  /// No description provided for @adminFieldExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get adminFieldExplanation;

  /// No description provided for @adminFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get adminFieldHint;

  /// No description provided for @adminFieldImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get adminFieldImageUrl;

  /// No description provided for @adminFieldLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get adminFieldLanguage;

  /// No description provided for @adminFieldOptions.
  ///
  /// In en, this message translates to:
  /// **'Answer options'**
  String get adminFieldOptions;

  /// No description provided for @adminFieldOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get adminFieldOrder;

  /// No description provided for @adminFieldPart.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get adminFieldPart;

  /// No description provided for @adminFieldPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get adminFieldPoints;

  /// No description provided for @adminFieldReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get adminFieldReview;

  /// No description provided for @adminFieldSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get adminFieldSection;

  /// No description provided for @adminFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminFieldStatus;

  /// No description provided for @adminFieldStem.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get adminFieldStem;

  /// No description provided for @adminFieldSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get adminFieldSubject;

  /// No description provided for @adminFieldSubtopicId.
  ///
  /// In en, this message translates to:
  /// **'Subtopic id (optional)'**
  String get adminFieldSubtopicId;

  /// No description provided for @adminFieldTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get adminFieldTags;

  /// No description provided for @adminFieldTagsHelp.
  ///
  /// In en, this message translates to:
  /// **'Comma separated'**
  String get adminFieldTagsHelp;

  /// No description provided for @adminFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminFieldTitle;

  /// No description provided for @adminFieldTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get adminFieldTopic;

  /// No description provided for @adminFieldTopicId.
  ///
  /// In en, this message translates to:
  /// **'Topic id'**
  String get adminFieldTopicId;

  /// No description provided for @adminFieldTopicIdHelp.
  ///
  /// In en, this message translates to:
  /// **'For example math.quadratic_equations'**
  String get adminFieldTopicIdHelp;

  /// No description provided for @adminFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminFieldType;

  /// No description provided for @adminForbiddenBody.
  ///
  /// In en, this message translates to:
  /// **'Your role does not allow opening this section.'**
  String get adminForbiddenBody;

  /// No description provided for @adminForbiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get adminForbiddenTitle;

  /// No description provided for @adminHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get adminHidden;

  /// No description provided for @adminImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get adminImport;

  /// No description provided for @adminImportDuplicateId.
  ///
  /// In en, this message translates to:
  /// **'Duplicate id in the file.'**
  String get adminImportDuplicateId;

  /// No description provided for @adminImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file has no data rows.'**
  String get adminImportEmpty;

  /// No description provided for @adminImportFailedAfter.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {done} rows: {error}'**
  String adminImportFailedAfter(int done, String error);

  /// No description provided for @adminImportHelp.
  ///
  /// In en, this message translates to:
  /// **'Rows are validated before writing; valid rows are written in batches of {batch}. CSV columns (separator , ; or tab):'**
  String adminImportHelp(int batch);

  /// No description provided for @adminImportParseError.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read.'**
  String get adminImportParseError;

  /// No description provided for @adminImportPick.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get adminImportPick;

  /// No description provided for @adminImportProgress.
  ///
  /// In en, this message translates to:
  /// **'Written {done} of {total}'**
  String adminImportProgress(int done, int total);

  /// No description provided for @adminImportRowIssue.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: {issue}'**
  String adminImportRowIssue(int row, String issue);

  /// No description provided for @adminImportRun.
  ///
  /// In en, this message translates to:
  /// **'Import {count}'**
  String adminImportRun(int count);

  /// No description provided for @adminImportSummary.
  ///
  /// In en, this message translates to:
  /// **'Rows: {total} · valid: {valid} · with errors: {invalid}'**
  String adminImportSummary(int total, int valid, int invalid);

  /// No description provided for @adminImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import questions (CSV or JSON)'**
  String get adminImportTitle;

  /// No description provided for @adminInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminInactive;

  /// No description provided for @adminIssueCorrectNotInOptions.
  ///
  /// In en, this message translates to:
  /// **'The correct answer is not among the options.'**
  String get adminIssueCorrectNotInOptions;

  /// No description provided for @adminIssueCorrectRequired.
  ///
  /// In en, this message translates to:
  /// **'Mark the correct answer.'**
  String get adminIssueCorrectRequired;

  /// No description provided for @adminIssueDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty must be 1–3.'**
  String get adminIssueDifficulty;

  /// No description provided for @adminIssueOptionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every option needs text.'**
  String get adminIssueOptionEmpty;

  /// No description provided for @adminIssueStem.
  ///
  /// In en, this message translates to:
  /// **'Question text is required.'**
  String get adminIssueStem;

  /// No description provided for @adminLangEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get adminLangEn;

  /// No description provided for @adminLangKy.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get adminLangKy;

  /// No description provided for @adminLangRu.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get adminLangRu;

  /// No description provided for @adminLessonAddExample.
  ///
  /// In en, this message translates to:
  /// **'Add example'**
  String get adminLessonAddExample;

  /// No description provided for @adminLessonAddFormula.
  ///
  /// In en, this message translates to:
  /// **'Add formula'**
  String get adminLessonAddFormula;

  /// No description provided for @adminLessonAddMistake.
  ///
  /// In en, this message translates to:
  /// **'Add mistake'**
  String get adminLessonAddMistake;

  /// No description provided for @adminLessonAddSection.
  ///
  /// In en, this message translates to:
  /// **'Add section'**
  String get adminLessonAddSection;

  /// No description provided for @adminLessonBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get adminLessonBasics;

  /// No description provided for @adminLessonCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get adminLessonCaption;

  /// No description provided for @adminLessonExamples.
  ///
  /// In en, this message translates to:
  /// **'Worked examples'**
  String get adminLessonExamples;

  /// No description provided for @adminLessonFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get adminLessonFormulas;

  /// No description provided for @adminLessonImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get adminLessonImages;

  /// No description provided for @adminLessonIssueContent.
  ///
  /// In en, this message translates to:
  /// **'Add a summary or at least one section.'**
  String get adminLessonIssueContent;

  /// No description provided for @adminLessonIssueMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration must be 1–240 minutes.'**
  String get adminLessonIssueMinutes;

  /// No description provided for @adminLessonIssueOrder.
  ///
  /// In en, this message translates to:
  /// **'Order must be 0–10000.'**
  String get adminLessonIssueOrder;

  /// No description provided for @adminLessonIssueSubject.
  ///
  /// In en, this message translates to:
  /// **'Choose a subject.'**
  String get adminLessonIssueSubject;

  /// No description provided for @adminLessonIssueUrl.
  ///
  /// In en, this message translates to:
  /// **'Video/PDF must be an http(s) link or an uploaded file.'**
  String get adminLessonIssueUrl;

  /// No description provided for @adminLessonLatex.
  ///
  /// In en, this message translates to:
  /// **'LaTeX'**
  String get adminLessonLatex;

  /// No description provided for @adminLessonMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get adminLessonMinutes;

  /// No description provided for @adminLessonMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake'**
  String get adminLessonMistake;

  /// No description provided for @adminLessonMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes'**
  String get adminLessonMistakes;

  /// No description provided for @adminLessonNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images.'**
  String get adminLessonNoImages;

  /// No description provided for @adminLessonPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get adminLessonPdf;

  /// No description provided for @adminLessonPdfHelp.
  ///
  /// In en, this message translates to:
  /// **'Link or an uploaded file (up to 20 MB)'**
  String get adminLessonPdfHelp;

  /// No description provided for @adminLessonPracticeAndMedia.
  ///
  /// In en, this message translates to:
  /// **'Practice and media'**
  String get adminLessonPracticeAndMedia;

  /// No description provided for @adminLessonPracticeIds.
  ///
  /// In en, this message translates to:
  /// **'Practice question ids'**
  String get adminLessonPracticeIds;

  /// No description provided for @adminLessonPracticeIdsHelp.
  ///
  /// In en, this message translates to:
  /// **'Ids from the \"questions\" collection, separated by commas'**
  String get adminLessonPracticeIdsHelp;

  /// No description provided for @adminLessonProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get adminLessonProblem;

  /// No description provided for @adminLessonPublishedHelp.
  ///
  /// In en, this message translates to:
  /// **'Unpublished lessons are hidden from students.'**
  String get adminLessonPublishedHelp;

  /// No description provided for @adminLessonSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Text (Markdown, LaTeX in \$…\$)'**
  String get adminLessonSectionBody;

  /// No description provided for @adminLessonSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Section title'**
  String get adminLessonSectionTitle;

  /// No description provided for @adminLessonSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get adminLessonSections;

  /// No description provided for @adminLessonSolution.
  ///
  /// In en, this message translates to:
  /// **'Solution'**
  String get adminLessonSolution;

  /// No description provided for @adminLessonSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get adminLessonSummary;

  /// No description provided for @adminLessonTitleSummary.
  ///
  /// In en, this message translates to:
  /// **'Title and summary'**
  String get adminLessonTitleSummary;

  /// No description provided for @adminLessonVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Video URL'**
  String get adminLessonVideoUrl;

  /// No description provided for @adminLessonsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Students will no longer see this lesson. To hide it temporarily, turn off \"Published\" instead.'**
  String get adminLessonsDeleteBody;

  /// No description provided for @adminLessonsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete lesson?'**
  String get adminLessonsDeleteTitle;

  /// No description provided for @adminLessonsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit lesson'**
  String get adminLessonsEdit;

  /// No description provided for @adminLessonsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lessons for this subject.'**
  String get adminLessonsEmpty;

  /// No description provided for @adminLessonsLegacy.
  ///
  /// In en, this message translates to:
  /// **'Old format'**
  String get adminLessonsLegacy;

  /// No description provided for @adminLessonsMeta.
  ///
  /// In en, this message translates to:
  /// **'#{order} · {minutes} min'**
  String adminLessonsMeta(int order, int minutes);

  /// No description provided for @adminLessonsNew.
  ///
  /// In en, this message translates to:
  /// **'New lesson'**
  String get adminLessonsNew;

  /// No description provided for @adminLessonsNoSubjects.
  ///
  /// In en, this message translates to:
  /// **'Create a subject first.'**
  String get adminLessonsNoSubjects;

  /// No description provided for @adminListEnd.
  ///
  /// In en, this message translates to:
  /// **'Shown: {count}'**
  String adminListEnd(int count);

  /// No description provided for @adminListNoItems.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet.'**
  String get adminListNoItems;

  /// No description provided for @adminLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get adminLoadMore;

  /// No description provided for @adminLoginBackToApp.
  ///
  /// In en, this message translates to:
  /// **'Back to the app'**
  String get adminLoginBackToApp;

  /// No description provided for @adminLoginContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get adminLoginContinue;

  /// No description provided for @adminLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminLoginEmail;

  /// No description provided for @adminLoginEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get adminLoginEmailInvalid;

  /// No description provided for @adminLoginErrCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get adminLoginErrCredentials;

  /// No description provided for @adminLoginErrDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled.'**
  String get adminLoginErrDisabled;

  /// No description provided for @adminLoginErrNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'This account has no admin role.'**
  String get adminLoginErrNotAdmin;

  /// No description provided for @adminLoginErrTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get adminLoginErrTooMany;

  /// No description provided for @adminLoginForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get adminLoginForgot;

  /// No description provided for @adminLoginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get adminLoginHidePassword;

  /// No description provided for @adminLoginOtherAccount.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get adminLoginOtherAccount;

  /// No description provided for @adminLoginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get adminLoginPassword;

  /// No description provided for @adminLoginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the password'**
  String get adminLoginPasswordRequired;

  /// No description provided for @adminLoginResetSend.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get adminLoginResetSend;

  /// No description provided for @adminLoginResetSent.
  ///
  /// In en, this message translates to:
  /// **'If the account exists, a reset link has been sent.'**
  String get adminLoginResetSent;

  /// No description provided for @adminLoginResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get adminLoginResetTitle;

  /// No description provided for @adminLoginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get adminLoginShowPassword;

  /// No description provided for @adminLoginSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String adminLoginSignedInAs(String email);

  /// No description provided for @adminLoginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get adminLoginSubmit;

  /// No description provided for @adminLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For ORT Master staff only.'**
  String get adminLoginSubtitle;

  /// No description provided for @adminLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminLoginTitle;

  /// No description provided for @adminLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get adminLogout;

  /// No description provided for @adminLogsActor.
  ///
  /// In en, this message translates to:
  /// **'by {uid}'**
  String adminLogsActor(String uid);

  /// No description provided for @adminLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The log is empty.'**
  String get adminLogsEmpty;

  /// No description provided for @adminLogsTarget.
  ///
  /// In en, this message translates to:
  /// **'target {uid}'**
  String adminLogsTarget(String uid);

  /// No description provided for @adminMarkCorrect.
  ///
  /// In en, this message translates to:
  /// **'Mark as correct'**
  String get adminMarkCorrect;

  /// No description provided for @adminMathHelp.
  ///
  /// In en, this message translates to:
  /// **'Markdown; formulas in \$…\$ or \$\$…\$\$'**
  String get adminMathHelp;

  /// No description provided for @adminMissingTranslation.
  ///
  /// In en, this message translates to:
  /// **'No {lang}'**
  String adminMissingTranslation(String lang);

  /// No description provided for @adminMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get adminMore;

  /// No description provided for @adminMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get adminMoveDown;

  /// No description provided for @adminMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get adminMoveUp;

  /// No description provided for @adminNavAiDrafts.
  ///
  /// In en, this message translates to:
  /// **'AI drafts'**
  String get adminNavAiDrafts;

  /// No description provided for @adminNavDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminNavDashboard;

  /// No description provided for @adminNavExamBank.
  ///
  /// In en, this message translates to:
  /// **'Exam bank'**
  String get adminNavExamBank;

  /// No description provided for @adminNavLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get adminNavLessons;

  /// No description provided for @adminNavLogs.
  ///
  /// In en, this message translates to:
  /// **'Admin log'**
  String get adminNavLogs;

  /// No description provided for @adminNavPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get adminNavPayments;

  /// No description provided for @adminNavPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice questions'**
  String get adminNavPractice;

  /// No description provided for @adminNavPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get adminNavPricing;

  /// No description provided for @adminNavSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects & topics'**
  String get adminNavSubjects;

  /// No description provided for @adminNavUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminNavUsers;

  /// No description provided for @adminNavVariants.
  ///
  /// In en, this message translates to:
  /// **'Exam variants'**
  String get adminNavVariants;

  /// No description provided for @adminNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get adminNo;

  /// No description provided for @adminNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get adminNone;

  /// No description provided for @adminOptionN.
  ///
  /// In en, this message translates to:
  /// **'Option {id}'**
  String adminOptionN(String id);

  /// No description provided for @adminOptionText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get adminOptionText;

  /// No description provided for @adminPaymentsCredits.
  ///
  /// In en, this message translates to:
  /// **'{n} credits'**
  String adminPaymentsCredits(int n);

  /// No description provided for @adminPaymentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases.'**
  String get adminPaymentsEmpty;

  /// No description provided for @adminPaymentsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only. Credits are granted by the server after Google Play verification.'**
  String get adminPaymentsReadOnly;

  /// No description provided for @adminPaymentsRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get adminPaymentsRefund;

  /// No description provided for @adminPracticeDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The question will be removed from practice. To hide it, make it inactive instead.'**
  String get adminPracticeDeleteBody;

  /// No description provided for @adminPracticeDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete question?'**
  String get adminPracticeDeleteTitle;

  /// No description provided for @adminPracticeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit question'**
  String get adminPracticeEdit;

  /// No description provided for @adminPracticeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No questions match the filter.'**
  String get adminPracticeEmpty;

  /// No description provided for @adminPracticeIssueOptionsMin.
  ///
  /// In en, this message translates to:
  /// **'At least two options are required.'**
  String get adminPracticeIssueOptionsMin;

  /// No description provided for @adminPracticeIssueSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject is required.'**
  String get adminPracticeIssueSubject;

  /// No description provided for @adminPracticeIssueType.
  ///
  /// In en, this message translates to:
  /// **'Unknown type'**
  String get adminPracticeIssueType;

  /// No description provided for @adminPracticeNew.
  ///
  /// In en, this message translates to:
  /// **'New question'**
  String get adminPracticeNew;

  /// No description provided for @adminPricingConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to new purchases immediately.'**
  String get adminPricingConfirmBody;

  /// No description provided for @adminPricingConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Save pricing?'**
  String get adminPricingConfirmTitle;

  /// No description provided for @adminPricingCreditsFor.
  ///
  /// In en, this message translates to:
  /// **'{id} — credits'**
  String adminPricingCreditsFor(String id);

  /// No description provided for @adminPricingDefaults.
  ///
  /// In en, this message translates to:
  /// **'config/pricing does not exist yet; defaults are shown.'**
  String get adminPricingDefaults;

  /// No description provided for @adminPricingFree.
  ///
  /// In en, this message translates to:
  /// **'Free exams'**
  String get adminPricingFree;

  /// No description provided for @adminPricingFreeHelp.
  ///
  /// In en, this message translates to:
  /// **'Product rule: 1 (the first full exam is free once per account)'**
  String get adminPricingFreeHelp;

  /// No description provided for @adminPricingFreeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free full exams per account'**
  String get adminPricingFreeLabel;

  /// No description provided for @adminPricingIssueCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits per product must be 1–100.'**
  String get adminPricingIssueCredits;

  /// No description provided for @adminPricingIssueFree.
  ///
  /// In en, this message translates to:
  /// **'Free exams per user must be 0–10.'**
  String get adminPricingIssueFree;

  /// No description provided for @adminPricingIssueProduct.
  ///
  /// In en, this message translates to:
  /// **'Unknown product id.'**
  String get adminPricingIssueProduct;

  /// No description provided for @adminPricingIssueSingle.
  ///
  /// In en, this message translates to:
  /// **'exam_single must grant exactly 1 credit.'**
  String get adminPricingIssueSingle;

  /// No description provided for @adminPricingProducts.
  ///
  /// In en, this message translates to:
  /// **'Credits per product'**
  String get adminPricingProducts;

  /// No description provided for @adminPricingSingleHelp.
  ///
  /// In en, this message translates to:
  /// **'Fixed: 1 credit = 1 exam'**
  String get adminPricingSingleHelp;

  /// No description provided for @adminPricingWarning.
  ///
  /// In en, this message translates to:
  /// **'Prices are set in Google Play Console, not here. This page only maps products to exam credits. Do not change the base price of 100 som (exam_single) without the owner\'s approval.'**
  String get adminPricingWarning;

  /// No description provided for @adminPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminPublished;

  /// No description provided for @adminPurchaseGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get adminPurchaseGranted;

  /// No description provided for @adminPurchaseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get adminPurchaseInvalid;

  /// No description provided for @adminPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminPurchasePending;

  /// No description provided for @adminPurchaseRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get adminPurchaseRefunded;

  /// No description provided for @adminPurchaseRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get adminPurchaseRevoked;

  /// No description provided for @adminQuestionExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get adminQuestionExtra;

  /// No description provided for @adminQuestionMeta.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get adminQuestionMeta;

  /// No description provided for @adminReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adminReason;

  /// No description provided for @adminReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Give a reason (at least 3 characters).'**
  String get adminReasonRequired;

  /// No description provided for @adminRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminRemove;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminReviewAiVerified.
  ///
  /// In en, this message translates to:
  /// **'AI-checked'**
  String get adminReviewAiVerified;

  /// No description provided for @adminReviewApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminReviewApproved;

  /// No description provided for @adminReviewDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminReviewDraft;

  /// No description provided for @adminReviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adminReviewRejected;

  /// No description provided for @adminRoleContentManager.
  ///
  /// In en, this message translates to:
  /// **'Content manager'**
  String get adminRoleContentManager;

  /// No description provided for @adminRoleMethodologist.
  ///
  /// In en, this message translates to:
  /// **'Methodologist'**
  String get adminRoleMethodologist;

  /// No description provided for @adminRoleModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get adminRoleModerator;

  /// No description provided for @adminRoleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super admin'**
  String get adminRoleSuperAdmin;

  /// No description provided for @adminRoleSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get adminRoleSupport;

  /// No description provided for @adminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminSave;

  /// No description provided for @adminSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get adminSaved;

  /// No description provided for @adminSessionExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get adminSessionExpiredBody;

  /// No description provided for @adminSessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin session ended'**
  String get adminSessionExpiredTitle;

  /// No description provided for @adminSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get adminSignInAgain;

  /// No description provided for @adminStatApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminStatApproved;

  /// No description provided for @adminStatExam.
  ///
  /// In en, this message translates to:
  /// **'Exam questions'**
  String get adminStatExam;

  /// No description provided for @adminStatLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get adminStatLessons;

  /// No description provided for @adminStatPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get adminStatPendingReview;

  /// No description provided for @adminStatPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice questions'**
  String get adminStatPractice;

  /// No description provided for @adminStatPurchases.
  ///
  /// In en, this message translates to:
  /// **'Granted purchases'**
  String get adminStatPurchases;

  /// No description provided for @adminStatSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get adminStatSubjects;

  /// No description provided for @adminStatUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminStatUsers;

  /// No description provided for @adminStatVariants.
  ///
  /// In en, this message translates to:
  /// **'Published variants'**
  String get adminStatVariants;

  /// No description provided for @adminSubjectsActiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Inactive subjects stay in the database (soft delete).'**
  String get adminSubjectsActiveHelp;

  /// No description provided for @adminSubjectsAddTopic.
  ///
  /// In en, this message translates to:
  /// **'Add topic'**
  String get adminSubjectsAddTopic;

  /// No description provided for @adminSubjectsColor.
  ///
  /// In en, this message translates to:
  /// **'Colour (#RRGGBB)'**
  String get adminSubjectsColor;

  /// No description provided for @adminSubjectsColorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use #RRGGBB'**
  String get adminSubjectsColorInvalid;

  /// No description provided for @adminSubjectsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The subject {id} will be deleted only if no lessons or questions use it. Otherwise deactivate it.'**
  String adminSubjectsDeleteBody(String id);

  /// No description provided for @adminSubjectsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete subject?'**
  String get adminSubjectsDeleteTitle;

  /// No description provided for @adminSubjectsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit subject'**
  String get adminSubjectsEdit;

  /// No description provided for @adminSubjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No subjects yet.'**
  String get adminSubjectsEmpty;

  /// No description provided for @adminSubjectsErrExists.
  ///
  /// In en, this message translates to:
  /// **'A subject with this id already exists.'**
  String get adminSubjectsErrExists;

  /// No description provided for @adminSubjectsErrInUse.
  ///
  /// In en, this message translates to:
  /// **'The subject is still used: {lessons} lessons, {questions} practice questions, {exam} exam questions. Deactivate it instead.'**
  String adminSubjectsErrInUse(int lessons, int questions, int exam);

  /// No description provided for @adminSubjectsIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon name'**
  String get adminSubjectsIcon;

  /// No description provided for @adminSubjectsId.
  ///
  /// In en, this message translates to:
  /// **'Subject id'**
  String get adminSubjectsId;

  /// No description provided for @adminSubjectsIdHelp.
  ///
  /// In en, this message translates to:
  /// **'Latin letters, digits and _; cannot be changed later'**
  String get adminSubjectsIdHelp;

  /// No description provided for @adminSubjectsIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'2–41 characters: a–z, 0–9, _ (starts with a letter)'**
  String get adminSubjectsIdInvalid;

  /// No description provided for @adminSubjectsNew.
  ///
  /// In en, this message translates to:
  /// **'New subject'**
  String get adminSubjectsNew;

  /// No description provided for @adminSubjectsTopicDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate topic id: {id}'**
  String adminSubjectsTopicDuplicate(String id);

  /// No description provided for @adminSubjectsTopicId.
  ///
  /// In en, this message translates to:
  /// **'Topic id'**
  String get adminSubjectsTopicId;

  /// No description provided for @adminSubjectsTopicIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid topic id: {id} (use a–z, 0–9, _ and dots)'**
  String adminSubjectsTopicIdInvalid(String id);

  /// No description provided for @adminSubjectsTopicN.
  ///
  /// In en, this message translates to:
  /// **'Topic {n}'**
  String adminSubjectsTopicN(int n);

  /// No description provided for @adminSubjectsTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get adminSubjectsTopics;

  /// No description provided for @adminSubjectsTopicsCount.
  ///
  /// In en, this message translates to:
  /// **'topics: {count}'**
  String adminSubjectsTopicsCount(int count);

  /// No description provided for @adminSubjectsTopicsHelp.
  ///
  /// In en, this message translates to:
  /// **'Topic ids become subject.topic (e.g. math.quadratic_equations) and are used by exam questions.'**
  String get adminSubjectsTopicsHelp;

  /// No description provided for @adminTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title in Russian or Kyrgyz.'**
  String get adminTitleRequired;

  /// No description provided for @adminTypeAnalogy.
  ///
  /// In en, this message translates to:
  /// **'Analogy'**
  String get adminTypeAnalogy;

  /// No description provided for @adminTypeComparison.
  ///
  /// In en, this message translates to:
  /// **'Quantitative comparison'**
  String get adminTypeComparison;

  /// No description provided for @adminTypeCompletion.
  ///
  /// In en, this message translates to:
  /// **'Sentence completion'**
  String get adminTypeCompletion;

  /// No description provided for @adminTypeMatching.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get adminTypeMatching;

  /// No description provided for @adminTypeMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get adminTypeMultiple;

  /// No description provided for @adminTypeOrdering.
  ///
  /// In en, this message translates to:
  /// **'Ordering'**
  String get adminTypeOrdering;

  /// No description provided for @adminTypeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single choice'**
  String get adminTypeSingle;

  /// No description provided for @adminTypeTextBased.
  ///
  /// In en, this message translates to:
  /// **'Reading (text-based)'**
  String get adminTypeTextBased;

  /// No description provided for @adminTypeTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'True / false'**
  String get adminTypeTrueFalse;

  /// No description provided for @adminUnsavedBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes.'**
  String get adminUnsavedBody;

  /// No description provided for @adminUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get adminUnsavedTitle;

  /// No description provided for @adminUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get adminUpdated;

  /// No description provided for @adminUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get adminUploadImage;

  /// No description provided for @adminUploadPdf.
  ///
  /// In en, this message translates to:
  /// **'Upload PDF'**
  String get adminUploadPdf;

  /// No description provided for @adminUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get adminUploaded;

  /// No description provided for @adminUserActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get adminUserActions;

  /// No description provided for @adminUserBalance.
  ///
  /// In en, this message translates to:
  /// **'balance {n}'**
  String adminUserBalance(int n);

  /// No description provided for @adminUserBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get adminUserBan;

  /// No description provided for @adminUserBanTitle.
  ///
  /// In en, this message translates to:
  /// **'Ban user?'**
  String get adminUserBanTitle;

  /// No description provided for @adminUserCreated.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get adminUserCreated;

  /// No description provided for @adminUserCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get adminUserCredits;

  /// No description provided for @adminUserEntitlements.
  ///
  /// In en, this message translates to:
  /// **'Exam access'**
  String get adminUserEntitlements;

  /// No description provided for @adminUserFreeUsed.
  ///
  /// In en, this message translates to:
  /// **'Free exam used'**
  String get adminUserFreeUsed;

  /// No description provided for @adminUserGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get adminUserGrade;

  /// No description provided for @adminUserGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get adminUserGrant;

  /// No description provided for @adminUserGrantDelta.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get adminUserGrantDelta;

  /// No description provided for @adminUserGrantDeltaHelp.
  ///
  /// In en, this message translates to:
  /// **'1 credit = 1 exam; negative to take back'**
  String get adminUserGrantDeltaHelp;

  /// No description provided for @adminUserGrantDeltaInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-zero number from -100 to 100.'**
  String get adminUserGrantDeltaInvalid;

  /// No description provided for @adminUserGrantDone.
  ///
  /// In en, this message translates to:
  /// **'Credits updated'**
  String get adminUserGrantDone;

  /// No description provided for @adminUserGrantTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant credits'**
  String get adminUserGrantTitle;

  /// No description provided for @adminUserLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get adminUserLanguage;

  /// No description provided for @adminUserLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get adminUserLastActive;

  /// No description provided for @adminUserLedger.
  ///
  /// In en, this message translates to:
  /// **'Credit history'**
  String get adminUserLedger;

  /// No description provided for @adminUserLifetime.
  ///
  /// In en, this message translates to:
  /// **'Credits purchased'**
  String get adminUserLifetime;

  /// No description provided for @adminUserNoEntitlements.
  ///
  /// In en, this message translates to:
  /// **'No entitlement record yet (first exam not used).'**
  String get adminUserNoEntitlements;

  /// No description provided for @adminUserPremiumOff.
  ///
  /// In en, this message translates to:
  /// **'Remove premium'**
  String get adminUserPremiumOff;

  /// No description provided for @adminUserPremiumOffBody.
  ///
  /// In en, this message translates to:
  /// **'The subscription returns to free.'**
  String get adminUserPremiumOffBody;

  /// No description provided for @adminUserPremiumOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove premium?'**
  String get adminUserPremiumOffTitle;

  /// No description provided for @adminUserPremiumOn.
  ///
  /// In en, this message translates to:
  /// **'Grant premium'**
  String get adminUserPremiumOn;

  /// No description provided for @adminUserPremiumOnBody.
  ///
  /// In en, this message translates to:
  /// **'Sets the subscription to yearly for 365 days. Exam credits are separate and are granted only with credits.'**
  String get adminUserPremiumOnBody;

  /// No description provided for @adminUserPremiumOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant premium?'**
  String get adminUserPremiumOnTitle;

  /// No description provided for @adminUserRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminUserRole;

  /// No description provided for @adminUserRoleBody.
  ///
  /// In en, this message translates to:
  /// **'Sets the role claim through the server. The user must sign in again for it to apply.'**
  String get adminUserRoleBody;

  /// No description provided for @adminUserRoleDone.
  ///
  /// In en, this message translates to:
  /// **'Role updated'**
  String get adminUserRoleDone;

  /// No description provided for @adminUserRoleNone.
  ///
  /// In en, this message translates to:
  /// **'No admin role'**
  String get adminUserRoleNone;

  /// No description provided for @adminUserRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin role'**
  String get adminUserRoleTitle;

  /// No description provided for @adminUserSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get adminUserSchool;

  /// No description provided for @adminUserStats.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get adminUserStats;

  /// No description provided for @adminUserSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get adminUserSubscription;

  /// No description provided for @adminUserTitle.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get adminUserTitle;

  /// No description provided for @adminUserUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get adminUserUnban;

  /// No description provided for @adminUserUnbanBody.
  ///
  /// In en, this message translates to:
  /// **'The ban flag will be removed.'**
  String get adminUserUnbanBody;

  /// No description provided for @adminUserUnbanTitle.
  ///
  /// In en, this message translates to:
  /// **'Unban user?'**
  String get adminUserUnbanTitle;

  /// No description provided for @adminUsersBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get adminUsersBanned;

  /// No description provided for @adminUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get adminUsersEmpty;

  /// No description provided for @adminUsersLegacyAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin (legacy)'**
  String get adminUsersLegacyAdmin;

  /// No description provided for @adminUsersPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get adminUsersPremium;

  /// No description provided for @adminUsersSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by email (start)'**
  String get adminUsersSearch;

  /// No description provided for @adminVariantAddIds.
  ///
  /// In en, this message translates to:
  /// **'Add question ids'**
  String get adminVariantAddIds;

  /// No description provided for @adminVariantAddIdsHelp.
  ///
  /// In en, this message translates to:
  /// **'Separate ids with spaces, commas or new lines'**
  String get adminVariantAddIdsHelp;

  /// No description provided for @adminVariantAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get adminVariantAdvanced;

  /// No description provided for @adminVariantArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get adminVariantArchived;

  /// No description provided for @adminVariantAutoFill.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill approved'**
  String get adminVariantAutoFill;

  /// No description provided for @adminVariantAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'Added {n} approved questions'**
  String adminVariantAutoFilled(int n);

  /// No description provided for @adminVariantBasics.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get adminVariantBasics;

  /// No description provided for @adminVariantBlocked.
  ///
  /// In en, this message translates to:
  /// **'Publishing is blocked: {n} problems.'**
  String adminVariantBlocked(int n);

  /// No description provided for @adminVariantBlueprintLocked.
  ///
  /// In en, this message translates to:
  /// **'Remove all questions to change the structure.'**
  String get adminVariantBlueprintLocked;

  /// No description provided for @adminVariantCheck.
  ///
  /// In en, this message translates to:
  /// **'Check against the structure'**
  String get adminVariantCheck;

  /// No description provided for @adminVariantChooseBlueprint.
  ///
  /// In en, this message translates to:
  /// **'Choose the test structure.'**
  String get adminVariantChooseBlueprint;

  /// No description provided for @adminVariantClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adminVariantClear;

  /// No description provided for @adminVariantDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get adminVariantDifficulty;

  /// No description provided for @adminVariantDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminVariantDraft;

  /// No description provided for @adminVariantInReview.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get adminVariantInReview;

  /// No description provided for @adminVariantN.
  ///
  /// In en, this message translates to:
  /// **'Variant {n}'**
  String adminVariantN(int n);

  /// No description provided for @adminVariantNoKey.
  ///
  /// In en, this message translates to:
  /// **'no key'**
  String get adminVariantNoKey;

  /// No description provided for @adminVariantNoProblems.
  ///
  /// In en, this message translates to:
  /// **'No problems reported.'**
  String get adminVariantNoProblems;

  /// No description provided for @adminVariantNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get adminVariantNumber;

  /// No description provided for @adminVariantNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Variant number must be 1–1000.'**
  String get adminVariantNumberInvalid;

  /// No description provided for @adminVariantPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get adminVariantPublish;

  /// No description provided for @adminVariantPublishBody.
  ///
  /// In en, this message translates to:
  /// **'The server checks the variant again. Students will be able to start it right after publishing.'**
  String get adminVariantPublishBody;

  /// No description provided for @adminVariantPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish variant?'**
  String get adminVariantPublishTitle;

  /// No description provided for @adminVariantPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminVariantPublished;

  /// No description provided for @adminVariantReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only: only a super admin or a content manager can create and edit variants.'**
  String get adminVariantReadOnly;

  /// No description provided for @adminVariantReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to publish (the server checks again).'**
  String get adminVariantReady;

  /// No description provided for @adminVariantRecheck.
  ///
  /// In en, this message translates to:
  /// **'Re-check'**
  String get adminVariantRecheck;

  /// No description provided for @adminVariantResync.
  ///
  /// In en, this message translates to:
  /// **'Re-sync to blueprint version {version}'**
  String adminVariantResync(int version);

  /// No description provided for @adminVariantResyncDone.
  ///
  /// In en, this message translates to:
  /// **'The variant now targets blueprint version {version}. Save to apply.'**
  String adminVariantResyncDone(int version);

  /// No description provided for @adminVariantResyncHelp.
  ///
  /// In en, this message translates to:
  /// **'The server publishes only variants built for the current blueprint version. Re-syncing keeps every question; then save and check the report.'**
  String get adminVariantResyncHelp;

  /// No description provided for @adminVariantServerResult.
  ///
  /// In en, this message translates to:
  /// **'Server: {status}'**
  String adminVariantServerResult(String status);

  /// No description provided for @adminVariantStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get adminVariantStandard;

  /// No description provided for @adminVariantUnknownQuestion.
  ///
  /// In en, this message translates to:
  /// **'not found'**
  String get adminVariantUnknownQuestion;

  /// No description provided for @adminVariantUnpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get adminVariantUnpublish;

  /// No description provided for @adminVariantUnpublishBody.
  ///
  /// In en, this message translates to:
  /// **'New attempts will not be possible. Attempts already started can still be finished.'**
  String get adminVariantUnpublishBody;

  /// No description provided for @adminVariantUnpublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Unpublish variant?'**
  String get adminVariantUnpublishTitle;

  /// No description provided for @adminVariantsEdit.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get adminVariantsEdit;

  /// No description provided for @adminVariantsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No variants match the filter.'**
  String get adminVariantsEmpty;

  /// No description provided for @adminVariantsErrPublished.
  ///
  /// In en, this message translates to:
  /// **'The variant is published. Unpublish it before editing.'**
  String get adminVariantsErrPublished;

  /// No description provided for @adminVariantsMeta.
  ///
  /// In en, this message translates to:
  /// **'{blueprint} · {count}/{expected} questions'**
  String adminVariantsMeta(String blueprint, int count, int expected);

  /// No description provided for @adminVariantsNew.
  ///
  /// In en, this message translates to:
  /// **'New variant'**
  String get adminVariantsNew;

  /// No description provided for @adminVpBlueprintVersion.
  ///
  /// In en, this message translates to:
  /// **'Built for blueprint version {actual}, current is {expected}.'**
  String adminVpBlueprintVersion(int expected, int actual);

  /// No description provided for @adminVpLanguage.
  ///
  /// In en, this message translates to:
  /// **'This language is not allowed by the blueprint.'**
  String get adminVpLanguage;

  /// No description provided for @adminVpPartCount.
  ///
  /// In en, this message translates to:
  /// **'Part {part}: {actual} questions, needs {expected}.'**
  String adminVpPartCount(String part, int expected, int actual);

  /// No description provided for @adminVpPartUnknown.
  ///
  /// In en, this message translates to:
  /// **'{id}: part unknown (set the part in the question).'**
  String adminVpPartUnknown(String id);

  /// No description provided for @adminVpQuestionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'{id}: used more than once.'**
  String adminVpQuestionDuplicate(String id);

  /// No description provided for @adminVpQuestionLanguage.
  ///
  /// In en, this message translates to:
  /// **'{id}: wrong language.'**
  String adminVpQuestionLanguage(String id);

  /// No description provided for @adminVpQuestionMissing.
  ///
  /// In en, this message translates to:
  /// **'{id}: question not found.'**
  String adminVpQuestionMissing(String id);

  /// No description provided for @adminVpQuestionNoKey.
  ///
  /// In en, this message translates to:
  /// **'{id}: no answer key.'**
  String adminVpQuestionNoKey(String id);

  /// No description provided for @adminVpQuestionNotApproved.
  ///
  /// In en, this message translates to:
  /// **'{id}: not approved by a methodologist.'**
  String adminVpQuestionNotApproved(String id);

  /// No description provided for @adminVpQuestionOptions.
  ///
  /// In en, this message translates to:
  /// **'{id}: {actual} options, needs {expected}.'**
  String adminVpQuestionOptions(String id, int expected, int actual);

  /// No description provided for @adminVpQuestionPart.
  ///
  /// In en, this message translates to:
  /// **'{id}: its part is not in this section.'**
  String adminVpQuestionPart(String id);

  /// No description provided for @adminVpQuestionPassage.
  ///
  /// In en, this message translates to:
  /// **'{id}: needs a linked text.'**
  String adminVpQuestionPassage(String id);

  /// No description provided for @adminVpQuestionSection.
  ///
  /// In en, this message translates to:
  /// **'{id}: belongs to another section than {section}.'**
  String adminVpQuestionSection(String id, String section);

  /// No description provided for @adminVpSectionCount.
  ///
  /// In en, this message translates to:
  /// **'{section}: {actual} questions, needs {expected}.'**
  String adminVpSectionCount(String section, int expected, int actual);

  /// No description provided for @adminVpSectionMissing.
  ///
  /// In en, this message translates to:
  /// **'Section {section} is empty.'**
  String adminVpSectionMissing(String section);

  /// No description provided for @adminVpSectionOrder.
  ///
  /// In en, this message translates to:
  /// **'Sections are not in blueprint order.'**
  String get adminVpSectionOrder;

  /// No description provided for @adminVpSectionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Section {section} is not in the blueprint.'**
  String adminVpSectionUnknown(String section);

  /// No description provided for @adminYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get adminYes;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'ORT Master KG'**
  String get appName;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @averageScore.
  ///
  /// In en, this message translates to:
  /// **'Average Score'**
  String get averageScore;

  /// No description provided for @billingBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance: {balance}'**
  String billingBalanceAfter(int balance);

  /// No description provided for @billingBalanceError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your balance.'**
  String get billingBalanceError;

  /// No description provided for @billingBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get billingBalanceTitle;

  /// No description provided for @billingBuySemantics.
  ///
  /// In en, this message translates to:
  /// **'Buy {title} for {price}'**
  String billingBuySemantics(String title, String price);

  /// No description provided for @billingCreditRule.
  ///
  /// In en, this message translates to:
  /// **'1 credit = 1 full mock exam'**
  String get billingCreditRule;

  /// Exam credit balance
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 credit} other{{count} credits}}'**
  String billingCreditsCount(int count);

  /// No description provided for @billingErrorAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'This purchase belongs to another account in the app. Sign in with that account to use it.'**
  String get billingErrorAccountMismatch;

  /// No description provided for @billingErrorAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'Your previous purchase is still being processed. We\'re checking it now.'**
  String get billingErrorAlreadyOwned;

  /// No description provided for @billingErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'The purchase couldn\'t be verified. If you were charged, Google Play will refund it automatically within 3 days.'**
  String get billingErrorInvalid;

  /// No description provided for @billingErrorLaunch.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the purchase. Try again.'**
  String get billingErrorLaunch;

  /// No description provided for @billingErrorNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to buy tests.'**
  String get billingErrorNotSignedIn;

  /// No description provided for @billingErrorProductUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This offer is no longer available.'**
  String get billingErrorProductUnavailable;

  /// No description provided for @billingErrorStore.
  ///
  /// In en, this message translates to:
  /// **'Google Play returned an error. Try again.'**
  String get billingErrorStore;

  /// No description provided for @billingErrorStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Play is unavailable right now. Try again later.'**
  String get billingErrorStoreUnavailable;

  /// No description provided for @billingErrorVerifyDeferred.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm the purchase yet. We\'ll retry automatically, and your payment won\'t be lost.'**
  String get billingErrorVerifyDeferred;

  /// No description provided for @billingExternalInfo.
  ///
  /// In en, this message translates to:
  /// **'Access to additional tests can be purchased on our website.'**
  String get billingExternalInfo;

  /// No description provided for @billingExternalNote.
  ///
  /// In en, this message translates to:
  /// **'Purchased credits appear here automatically.'**
  String get billingExternalNote;

  /// No description provided for @billingFreeExamAvailable.
  ///
  /// In en, this message translates to:
  /// **'Your first full mock exam is free'**
  String get billingFreeExamAvailable;

  /// No description provided for @billingFreeExamUsed.
  ///
  /// In en, this message translates to:
  /// **'Free mock exam already used'**
  String get billingFreeExamUsed;

  /// No description provided for @billingHistoryError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the history.'**
  String get billingHistoryError;

  /// No description provided for @billingHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Purchase history'**
  String get billingHistoryTooltip;

  /// No description provided for @billingHonestNoGuarantee.
  ///
  /// In en, this message translates to:
  /// **'Mock exams help you practise; they don\'t guarantee an ORT result.'**
  String get billingHonestNoGuarantee;

  /// No description provided for @billingHonestPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment is processed by Google Play.'**
  String get billingHonestPayment;

  /// No description provided for @billingHonestServer.
  ///
  /// In en, this message translates to:
  /// **'Credits are added only after our server confirms the purchase.'**
  String get billingHonestServer;

  /// No description provided for @billingLedgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No credit changes yet.'**
  String get billingLedgerEmpty;

  /// No description provided for @billingLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get billingLoadMore;

  /// No description provided for @billingLoadingProducts.
  ///
  /// In en, this message translates to:
  /// **'Loading offers…'**
  String get billingLoadingProducts;

  /// No description provided for @billingOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order {id}'**
  String billingOrderId(String id);

  /// No description provided for @billingProductSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 full mock exam} other{{count} full mock exams}}'**
  String billingProductSubtitle(int count);

  /// Product title by number of tests
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 test} other{{count} tests}}'**
  String billingProductTests(int count);

  /// No description provided for @billingProductsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Offers are temporarily unavailable. Please try again later.'**
  String get billingProductsEmpty;

  /// No description provided for @billingProductsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load offers from Google Play.'**
  String get billingProductsError;

  /// No description provided for @billingProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy mock exams'**
  String get billingProductsTitle;

  /// No description provided for @billingPurchasesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet.'**
  String get billingPurchasesEmpty;

  /// No description provided for @billingReasonAdminGrant.
  ///
  /// In en, this message translates to:
  /// **'Added by support'**
  String get billingReasonAdminGrant;

  /// No description provided for @billingReasonExamStart.
  ///
  /// In en, this message translates to:
  /// **'Mock exam started'**
  String get billingReasonExamStart;

  /// No description provided for @billingReasonFreeFirst.
  ///
  /// In en, this message translates to:
  /// **'Free first exam'**
  String get billingReasonFreeFirst;

  /// No description provided for @billingReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Balance change'**
  String get billingReasonOther;

  /// No description provided for @billingReasonPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get billingReasonPurchase;

  /// No description provided for @billingReasonRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get billingReasonRefund;

  /// No description provided for @billingRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get billingRestore;

  /// No description provided for @billingRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Check finished. Your balance updates automatically.'**
  String get billingRestoreDone;

  /// No description provided for @billingRestoreStarted.
  ///
  /// In en, this message translates to:
  /// **'Checking unfinished purchases…'**
  String get billingRestoreStarted;

  /// No description provided for @billingRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get billingRetry;

  /// No description provided for @billingSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your balance and history.'**
  String get billingSignInRequired;

  /// No description provided for @billingStateGranted.
  ///
  /// In en, this message translates to:
  /// **'Credited'**
  String get billingStateGranted;

  /// No description provided for @billingStateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get billingStateInvalid;

  /// No description provided for @billingStatePending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get billingStatePending;

  /// No description provided for @billingStateRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get billingStateRefunded;

  /// No description provided for @billingStateRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get billingStateRevoked;

  /// No description provided for @billingStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled.'**
  String get billingStatusCanceled;

  /// No description provided for @billingStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'Purchase confirmed. Credits have been added.'**
  String get billingStatusGranted;

  /// No description provided for @billingStatusLaunching.
  ///
  /// In en, this message translates to:
  /// **'Opening Google Play…'**
  String get billingStatusLaunching;

  /// No description provided for @billingStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment. Credits will be added once Google Play confirms the payment.'**
  String get billingStatusPending;

  /// No description provided for @billingStatusVerifying.
  ///
  /// In en, this message translates to:
  /// **'Confirming your purchase…'**
  String get billingStatusVerifying;

  /// No description provided for @billingStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Exam access'**
  String get billingStoreTitle;

  /// No description provided for @billingTabLedger.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get billingTabLedger;

  /// No description provided for @billingTabPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get billingTabPurchases;

  /// No description provided for @billingTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase history'**
  String get billingTransactionsTitle;

  /// No description provided for @billingUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Google Play billing isn\'t available on this device. Make sure Google Play is installed and you\'re signed in to it.'**
  String get billingUnavailableBody;

  /// No description provided for @billingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases are unavailable'**
  String get billingUnavailableTitle;

  /// No description provided for @biology.
  ///
  /// In en, this message translates to:
  /// **'Biology'**
  String get biology;

  /// No description provided for @buyTest.
  ///
  /// In en, this message translates to:
  /// **'Buy Test'**
  String get buyTest;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cardPayment.
  ///
  /// In en, this message translates to:
  /// **'Card Payment'**
  String get cardPayment;

  /// No description provided for @chemistry.
  ///
  /// In en, this message translates to:
  /// **'Chemistry'**
  String get chemistry;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearCacheConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache?'**
  String get clearCacheConfirmation;

  /// No description provided for @clearCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Free up space'**
  String get clearCacheDesc;

  /// No description provided for @clearCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete all downloaded content. You can download it again when online.'**
  String get clearCacheMessage;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @continueTest.
  ///
  /// In en, this message translates to:
  /// **'Continue Test'**
  String get continueTest;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

  /// No description provided for @dailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily Goal'**
  String get dailyGoal;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @dataAndStorage.
  ///
  /// In en, this message translates to:
  /// **'Data & Storage'**
  String get dataAndStorage;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @downloadedContent.
  ///
  /// In en, this message translates to:
  /// **'Downloaded Content'**
  String get downloadedContent;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email Notifications'**
  String get emailNotifications;

  /// No description provided for @emailNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'News and updates'**
  String get emailNotificationsDesc;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Answered {answered} of {total}'**
  String examAnsweredOf(int answered, int total);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Time is up. The section has been submitted.'**
  String get examAutoSubmitted;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get examBuy;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Buy a test'**
  String get examBuyToStart;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No exams are available yet.'**
  String get examCatalogEmpty;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Full timed tests in the official ORT format.'**
  String get examCatalogIntro;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Main test'**
  String get examCatalogMainTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'State language'**
  String get examCatalogStateLanguageTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Subject tests'**
  String get examCatalogSubjectsTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Clear answer'**
  String get examClearAnswer;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Column A'**
  String get examColumnA;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Column B'**
  String get examColumnB;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get examContinue;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'1 credit (you have {credits})'**
  String examCostCredit(int credits);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Free — this is your first test'**
  String get examCostFree;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'You need 1 credit to start this test.'**
  String get examCostNeedCredit;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Free — you are continuing your attempt'**
  String get examCostResume;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Practice result. Not an official ORT score.'**
  String get examDisclaimerFallback;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Credits: {count}'**
  String examEntitlementCredits(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Your first test is free'**
  String get examEntitlementFree;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'One credit = one full test. Continuing an unfinished test is free.'**
  String get examEntitlementHint;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No credits left'**
  String get examEntitlementNone;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'This attempt was not found.'**
  String get examErrorAttemptNotFound;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get examErrorGeneric;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again.'**
  String get examErrorNetwork;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Sign in to take exams.'**
  String get examErrorSignIn;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'This variant is not available right now.'**
  String get examErrorVariantUnavailable;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Leave test'**
  String get examExit;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The section timer keeps running on the server while you are away. Your answers are saved — you can continue from the home screen.'**
  String get examExitBody;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get examExitLeave;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get examExitStay;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Leave the test?'**
  String get examExitTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Finish section'**
  String get examFinishSection;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get examFinishSectionConfirm;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Marked for review: {count}'**
  String examFinishSectionFlagged(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Finish “{section}”?'**
  String examFinishSectionTitle(String section);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Unanswered: {count}'**
  String examFinishSectionUnanswered(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'After finishing you cannot return to this section.'**
  String get examFinishSectionWarning;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Test finished. Loading your result…'**
  String get examFinishedLoading;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Mark for review'**
  String get examFlag;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get examHistoryAction;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Attempts: {count}'**
  String examHistoryAttempts(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No finished tests yet. Your results will appear here.'**
  String get examHistoryEmpty;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Last: {percent}%'**
  String examHistoryLast(String percent);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Exam history'**
  String get examHistoryTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'−{delta}% vs previous'**
  String examHistoryTrendDown(String delta);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Same as previous'**
  String get examHistoryTrendSame;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'+{delta}% vs previous'**
  String examHistoryTrendUp(String delta);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The image could not be loaded'**
  String get examImageError;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get examIntroCost;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Test language: {language}'**
  String examIntroLanguage(String language);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get examIntroRules;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get examIntroStructure;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Keep working'**
  String get examKeepWorking;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get examLangEn;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get examLangKy;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get examLangRu;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Test language'**
  String get examLanguageLabel;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get examLoading;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String examMinutesCount(int minutes);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Mock ORT'**
  String get examMockTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get examNext;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The timer of this section is already running:'**
  String get examNextSectionTimeRunning;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Next section'**
  String get examNextSectionTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'This section has no questions. Please contact support.'**
  String get examNoQuestions;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'We will also retry automatically.'**
  String get examOfflineAutoRetry;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Offline — answers are saved on the device'**
  String get examOfflineBadge;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved on this device. The next section starts only after the server receives this one.'**
  String get examOfflineBody;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get examOfflineTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Only in {language}'**
  String examOnlyLanguage(String language);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Option {letter}'**
  String examOptionSemantics(String letter);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get examPalette;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get examPaletteAnswered;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get examPaletteCurrent;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Marked'**
  String get examPaletteFlagged;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get examPaletteUnanswered;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The official split between these parts is not published; this is an approximation.'**
  String get examPartAssumption;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get examPassage;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Hide text'**
  String get examPassageHide;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Show text'**
  String get examPassageShow;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get examPrevious;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String examQuestionOf(int current, int total);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String examQuestionsCount(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'By section'**
  String get examResultBySection;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get examResultCorrect;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get examResultIncorrect;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The official result of the state language test is a level from 1 to 4. The level boundaries are not published, so the app shows only your percentage of correct answers and does not guess your level.'**
  String get examResultLevelsBody;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'How the official result works'**
  String get examResultLevelsTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No weak topics found — great job!'**
  String get examResultNoWeak;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Some sections were closed late, so this attempt does not count for the leaderboard.'**
  String get examResultNotEligible;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The result is still being calculated. Try again in a few seconds.'**
  String get examResultPending;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Review “{topic}”: go back to the theory and solve 10–15 practice questions on it.'**
  String examResultRecommendation(String topic);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get examResultReview;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String examResultScore(int correct, int total);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get examResultSkipped;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Strong topics'**
  String get examResultStrong;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get examResultTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'To exams'**
  String get examResultToExams;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total}'**
  String examResultTopicScore(int correct, int total);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'What to review'**
  String get examResultWeak;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Wrong or skipped'**
  String get examResultWrongOrSkipped;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'XP earned: {xp}'**
  String examResultXp(int xp);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Waiting to be submitted'**
  String get examResumeAwaitingSubmit;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Section time is up'**
  String get examResumeTimeUp;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Unfinished test'**
  String get examResumeTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get examRetry;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Ask the AI tutor'**
  String get examReviewAskTutor;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String examReviewCorrectAnswer(String answer);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Nothing here for this filter.'**
  String get examReviewEmpty;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get examReviewExplanation;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get examReviewFilterAll;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Marked'**
  String get examReviewFilterFlagged;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get examReviewFilterWrong;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'no answer'**
  String get examReviewNoAnswer;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String examReviewQuestionNumber(int number);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Answer review'**
  String get examReviewTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String examReviewYourAnswer(String answer);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Sections go strictly in order. A finished section is closed — you cannot return to it.'**
  String get examRuleForwardOnly;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Inside a section you can move between questions freely and mark them to come back later.'**
  String get examRuleFreeNavigation;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'If you leave the app, the timer keeps running. Your answers are saved on the device.'**
  String get examRuleKeepsRunning;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Calculators are not allowed.'**
  String get examRuleNoCalculator;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Scratch paper is allowed in: {sections}.'**
  String examRuleScratchpad(String sections);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Each section has its own timer. You will be warned 5 minutes and 1 minute before the end; at zero the section is submitted automatically.'**
  String get examRuleTimer;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Section submitted'**
  String get examSectionDone;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Section {index} of {count}'**
  String examSectionLabel(int index, int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 section} other{{count} sections}}'**
  String examSectionsCount(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get examShowMore;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Start test'**
  String get examStart;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Start section'**
  String get examStartSection;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Preparing your test…'**
  String get examStarting;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Submitting the section…'**
  String get examSubmitting;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get examTabTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Time left'**
  String get examTimeLeftLabel;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get examTotal;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Remove mark'**
  String get examUnflag;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get examVariantAdvanced;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Best: {percent}%'**
  String examVariantBest(String percent);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get examVariantInProgress;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get examVariantNotStarted;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Variant {number}'**
  String examVariantTitle(int number);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get examVariants;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No variants in this language yet. New ones are added regularly.'**
  String get examVariantsEmpty;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'5 minutes left in this section'**
  String get examWarningFive;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'1 minute left — the section will be submitted automatically'**
  String get examWarningOne;

  /// No description provided for @explanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get explanation;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @flashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get flashcards;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @geography.
  ///
  /// In en, this message translates to:
  /// **'Geography'**
  String get geography;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleSignIn;

  /// No description provided for @grade10.
  ///
  /// In en, this message translates to:
  /// **'Grade 10'**
  String get grade10;

  /// No description provided for @grade11.
  ///
  /// In en, this message translates to:
  /// **'Grade 11'**
  String get grade11;

  /// No description provided for @grade9.
  ///
  /// In en, this message translates to:
  /// **'Grade 9'**
  String get grade9;

  /// No description provided for @graduate.
  ///
  /// In en, this message translates to:
  /// **'Graduate'**
  String get graduate;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History of Kyrgyzstan'**
  String get history;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrect;

  /// No description provided for @kgs.
  ///
  /// In en, this message translates to:
  /// **'KGS'**
  String get kgs;

  /// No description provided for @kyrgyz.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get kyrgyz;

  /// No description provided for @kyrgyzLanguage.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz Language'**
  String get kyrgyzLanguage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @learnAchAccuracy90Desc.
  ///
  /// In en, this message translates to:
  /// **'Score 90% on a mock exam'**
  String get learnAchAccuracy90Desc;

  /// No description provided for @learnAchAccuracy90Title.
  ///
  /// In en, this message translates to:
  /// **'90% accuracy'**
  String get learnAchAccuracy90Title;

  /// No description provided for @learnAchAnalogiesDesc.
  ///
  /// In en, this message translates to:
  /// **'A high score in the analogies section'**
  String get learnAchAnalogiesDesc;

  /// No description provided for @learnAchAnalogiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Analogies master'**
  String get learnAchAnalogiesTitle;

  /// No description provided for @learnAchDays30Desc.
  ///
  /// In en, this message translates to:
  /// **'Study on 30 different days'**
  String get learnAchDays30Desc;

  /// No description provided for @learnAchDays30Title.
  ///
  /// In en, this message translates to:
  /// **'30 study days'**
  String get learnAchDays30Title;

  /// No description provided for @learnAchExamChampionDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete 10 mock exams'**
  String get learnAchExamChampionDesc;

  /// No description provided for @learnAchExamChampionTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock exam champion'**
  String get learnAchExamChampionTitle;

  /// No description provided for @learnAchFirstLessonDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete your first lesson'**
  String get learnAchFirstLessonDesc;

  /// No description provided for @learnAchFirstLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'First lesson'**
  String get learnAchFirstLessonTitle;

  /// No description provided for @learnAchMathExpertDesc.
  ///
  /// In en, this message translates to:
  /// **'90% in math on three mock exams'**
  String get learnAchMathExpertDesc;

  /// No description provided for @learnAchMathExpertTitle.
  ///
  /// In en, this message translates to:
  /// **'Math expert'**
  String get learnAchMathExpertTitle;

  /// No description provided for @learnAchReaderDesc.
  ///
  /// In en, this message translates to:
  /// **'A high score in the reading section'**
  String get learnAchReaderDesc;

  /// No description provided for @learnAchReaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get learnAchReaderTitle;

  /// No description provided for @learnAchStreak7Desc.
  ///
  /// In en, this message translates to:
  /// **'Study 7 days in a row'**
  String get learnAchStreak7Desc;

  /// No description provided for @learnAchStreak7Title.
  ///
  /// In en, this message translates to:
  /// **'Week streak'**
  String get learnAchStreak7Title;

  /// No description provided for @learnAchXp100Desc.
  ///
  /// In en, this message translates to:
  /// **'Earn 100 XP'**
  String get learnAchXp100Desc;

  /// No description provided for @learnAchXp100Title.
  ///
  /// In en, this message translates to:
  /// **'First 100 XP'**
  String get learnAchXp100Title;

  /// No description provided for @learnAchievementLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get learnAchievementLocked;

  /// No description provided for @learnAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get learnAchievementUnlocked;

  /// No description provided for @learnAchievementUnlockedOn.
  ///
  /// In en, this message translates to:
  /// **'Unlocked on {date}'**
  String learnAchievementUnlockedOn(String date);

  /// No description provided for @learnAchievementsServerNote.
  ///
  /// In en, this message translates to:
  /// **'Achievements are granted automatically from your results on the server.'**
  String get learnAchievementsServerNote;

  /// No description provided for @learnAchievementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get learnAchievementsTitle;

  /// No description provided for @learnAchievementsUnlocked.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total} unlocked'**
  String learnAchievementsUnlocked(int n, int total);

  /// No description provided for @learnAnswersCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 answer} other{{n} answers}}'**
  String learnAnswersCount(int n);

  /// No description provided for @learnAskTutor.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI tutor'**
  String get learnAskTutor;

  /// No description provided for @learnAvgPerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Average {seconds} s per question'**
  String learnAvgPerQuestion(int seconds);

  /// No description provided for @learnBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get learnBack;

  /// No description provided for @learnBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get learnBackHome;

  /// No description provided for @learnBestResult.
  ///
  /// In en, this message translates to:
  /// **'Best result'**
  String get learnBestResult;

  /// No description provided for @learnCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get learnCorrect;

  /// No description provided for @learnCorrectAnswerIs.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String learnCorrectAnswerIs(String answer);

  /// No description provided for @learnDailyLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson of the day'**
  String get learnDailyLessonTitle;

  /// No description provided for @learnDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get learnDifficultyEasy;

  /// No description provided for @learnDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get learnDifficultyHard;

  /// No description provided for @learnDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get learnDifficultyMedium;

  /// No description provided for @learnDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String learnDurationMinutes(int n);

  /// No description provided for @learnElapsedTime.
  ///
  /// In en, this message translates to:
  /// **'Elapsed time'**
  String get learnElapsedTime;

  /// No description provided for @learnErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not load data. Please try again.'**
  String get learnErrorGeneric;

  /// No description provided for @learnErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get learnErrorNotFound;

  /// No description provided for @learnErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again.'**
  String get learnErrorOffline;

  /// No description provided for @learnErrorPermission.
  ///
  /// In en, this message translates to:
  /// **'No access to the data. Please sign in again.'**
  String get learnErrorPermission;

  /// No description provided for @learnExamHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'Full history'**
  String get learnExamHistoryAll;

  /// No description provided for @learnExamHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t finished a mock exam yet.'**
  String get learnExamHistoryEmpty;

  /// No description provided for @learnExamHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent attempts'**
  String get learnExamHistoryTitle;

  /// No description provided for @learnExamHistoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Exam history is unavailable right now.'**
  String get learnExamHistoryUnavailable;

  /// No description provided for @learnExamResultUnofficial.
  ///
  /// In en, this message translates to:
  /// **'Practice result, not an official ORT score.'**
  String get learnExamResultUnofficial;

  /// No description provided for @learnExamResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock exams'**
  String get learnExamResultsTitle;

  /// No description provided for @learnExamSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Average by section'**
  String get learnExamSectionsTitle;

  /// No description provided for @learnExitBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{You haven\'t answered any questions yet.} =1{Your answer to 1 question can be saved.} other{Your answers to {count} questions can be saved.}}'**
  String learnExitBody(int count);

  /// No description provided for @learnExitContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get learnExitContinue;

  /// No description provided for @learnExitDiscard.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get learnExitDiscard;

  /// No description provided for @learnExitFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish and save'**
  String get learnExitFinish;

  /// No description provided for @learnExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish practice?'**
  String get learnExitTitle;

  /// No description provided for @learnExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get learnExplanation;

  /// No description provided for @learnFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get learnFinish;

  /// No description provided for @learnHandbookFactsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the exam structure.'**
  String get learnHandbookFactsUnavailable;

  /// No description provided for @learnHandbookNotFound.
  ///
  /// In en, this message translates to:
  /// **'Handbook section not found'**
  String get learnHandbookNotFound;

  /// No description provided for @learnHandbookRussianOnly.
  ///
  /// In en, this message translates to:
  /// **'This section is available in Russian only.'**
  String get learnHandbookRussianOnly;

  /// No description provided for @learnHandbookSearch.
  ///
  /// In en, this message translates to:
  /// **'Search the handbook'**
  String get learnHandbookSearch;

  /// No description provided for @learnHandbookSections.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 section} other{{n} sections}}'**
  String learnHandbookSections(int n);

  /// No description provided for @learnHandbookTitle.
  ///
  /// In en, this message translates to:
  /// **'Handbook'**
  String get learnHandbookTitle;

  /// No description provided for @learnHbAssumption.
  ///
  /// In en, this message translates to:
  /// **'(split is an assumption)'**
  String get learnHbAssumption;

  /// No description provided for @learnHbMainTest.
  ///
  /// In en, this message translates to:
  /// **'ORT main test ({year})'**
  String learnHbMainTest(String year);

  /// No description provided for @learnHbMainTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {questions, plural, =1{1 item} other{{questions} items}}, {minutes} min.'**
  String learnHbMainTotal(int questions, int minutes);

  /// No description provided for @learnHbMaxScore.
  ///
  /// In en, this message translates to:
  /// **'The official maximum score of the main test is {score}.'**
  String learnHbMaxScore(int score);

  /// No description provided for @learnHbPartLine.
  ///
  /// In en, this message translates to:
  /// **'{title}: {questions} items, {options, plural, =1{1 answer option} other{{options} answer options}}'**
  String learnHbPartLine(String title, int questions, int options);

  /// No description provided for @learnHbSectionLine.
  ///
  /// In en, this message translates to:
  /// **'{title}: {questions, plural, =1{1 item} other{{questions} items}}, {minutes} min'**
  String learnHbSectionLine(String title, int questions, int minutes);

  /// No description provided for @learnHbStateLanguage.
  ///
  /// In en, this message translates to:
  /// **'{questions, plural, =1{1 item} other{{questions} items}}, {minutes} min. Required for the certificate; reported as level 1–4.'**
  String learnHbStateLanguage(int questions, int minutes);

  /// No description provided for @learnHbSubjectTests.
  ///
  /// In en, this message translates to:
  /// **'Subject tests (optional)'**
  String get learnHbSubjectTests;

  /// No description provided for @learnHbThresholdCollege.
  ///
  /// In en, this message translates to:
  /// **'Colleges: {n} on the main test.'**
  String learnHbThresholdCollege(int n);

  /// No description provided for @learnHbThresholdsUniversity.
  ///
  /// In en, this message translates to:
  /// **'University thresholds: {main} on the main test and {subject} on subject tests (2026–2027).'**
  String learnHbThresholdsUniversity(int main, int subject);

  /// No description provided for @learnHbThresholdsYearly.
  ///
  /// In en, this message translates to:
  /// **'Thresholds are set anew every year — check testing.kg.'**
  String get learnHbThresholdsYearly;

  /// No description provided for @learnLeaderboardAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get learnLeaderboardAllTime;

  /// No description provided for @learnLeaderboardAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get learnLeaderboardAnonymous;

  /// No description provided for @learnLeaderboardBySubject.
  ///
  /// In en, this message translates to:
  /// **'By subject'**
  String get learnLeaderboardBySubject;

  /// No description provided for @learnLeaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'The leaderboard is empty'**
  String get learnLeaderboardEmpty;

  /// No description provided for @learnLeaderboardEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'It will fill up as students earn XP.'**
  String get learnLeaderboardEmptyBody;

  /// No description provided for @learnLeaderboardNotRanked.
  ///
  /// In en, this message translates to:
  /// **'You\'re not on this board yet. XP from studying is added automatically.'**
  String get learnLeaderboardNotRanked;

  /// No description provided for @learnLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get learnLeaderboardTitle;

  /// No description provided for @learnLeaderboardWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get learnLeaderboardWeekly;

  /// No description provided for @learnLeaderboardYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String learnLeaderboardYou(String name);

  /// No description provided for @learnLessonAllDone.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed every lesson in this subject.'**
  String get learnLessonAllDone;

  /// No description provided for @learnLessonCommonMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes'**
  String get learnLessonCommonMistakes;

  /// No description provided for @learnLessonCompletedToast.
  ///
  /// In en, this message translates to:
  /// **'Lesson marked as completed.'**
  String get learnLessonCompletedToast;

  /// No description provided for @learnLessonDone.
  ///
  /// In en, this message translates to:
  /// **'Lesson completed'**
  String get learnLessonDone;

  /// No description provided for @learnLessonExampleN.
  ///
  /// In en, this message translates to:
  /// **'Example {n}'**
  String learnLessonExampleN(int n);

  /// No description provided for @learnLessonExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get learnLessonExamples;

  /// No description provided for @learnLessonFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get learnLessonFormulas;

  /// No description provided for @learnLessonHideSolution.
  ///
  /// In en, this message translates to:
  /// **'Hide solution'**
  String get learnLessonHideSolution;

  /// No description provided for @learnLessonMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark lesson as completed'**
  String get learnLessonMarkDone;

  /// No description provided for @learnLessonMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get learnLessonMaterials;

  /// No description provided for @learnLessonNoContent.
  ///
  /// In en, this message translates to:
  /// **'The lesson content hasn\'t been added yet.'**
  String get learnLessonNoContent;

  /// No description provided for @learnLessonNotFound.
  ///
  /// In en, this message translates to:
  /// **'Lesson not found'**
  String get learnLessonNotFound;

  /// No description provided for @learnLessonNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The lesson may not be published yet or was removed.'**
  String get learnLessonNotFoundBody;

  /// No description provided for @learnLessonNumber.
  ///
  /// In en, this message translates to:
  /// **'Lesson {n}'**
  String learnLessonNumber(int n);

  /// No description provided for @learnLessonOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get learnLessonOpenPdf;

  /// No description provided for @learnLessonPracticeBody.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 question on this lesson.} other{{n} questions on this lesson.}}'**
  String learnLessonPracticeBody(int n);

  /// No description provided for @learnLessonPracticeSubjectBody.
  ///
  /// In en, this message translates to:
  /// **'Reinforce the material with questions on this subject.'**
  String get learnLessonPracticeSubjectBody;

  /// No description provided for @learnLessonPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson practice'**
  String get learnLessonPracticeTitle;

  /// No description provided for @learnLessonShowSolution.
  ///
  /// In en, this message translates to:
  /// **'Show solution'**
  String get learnLessonShowSolution;

  /// No description provided for @learnLessonSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get learnLessonSummary;

  /// No description provided for @learnLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get learnLessonTitle;

  /// No description provided for @learnLessonWatchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch the video'**
  String get learnLessonWatchVideo;

  /// No description provided for @learnLessonsCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 lesson} other{{n} lessons}}'**
  String learnLessonsCount(int n);

  /// No description provided for @learnLessonsHeading.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get learnLessonsHeading;

  /// No description provided for @learnLevelN.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String learnLevelN(int n);

  /// No description provided for @learnLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get learnLinkFailed;

  /// No description provided for @learnLoadingLesson.
  ///
  /// In en, this message translates to:
  /// **'Loading the lesson…'**
  String get learnLoadingLesson;

  /// No description provided for @learnLoadingQuestions.
  ///
  /// In en, this message translates to:
  /// **'Picking questions…'**
  String get learnLoadingQuestions;

  /// No description provided for @learnLoadingSubject.
  ///
  /// In en, this message translates to:
  /// **'Loading the subject…'**
  String get learnLoadingSubject;

  /// No description provided for @learnLoadingSubjects.
  ///
  /// In en, this message translates to:
  /// **'Loading subjects…'**
  String get learnLoadingSubjects;

  /// No description provided for @learnMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String learnMinutes(int n);

  /// No description provided for @learnMistakeFromExam.
  ///
  /// In en, this message translates to:
  /// **'Question from a mock exam'**
  String get learnMistakeFromExam;

  /// No description provided for @learnMistakeOpenReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get learnMistakeOpenReview;

  /// No description provided for @learnMistakePractice.
  ///
  /// In en, this message translates to:
  /// **'Practise'**
  String get learnMistakePractice;

  /// No description provided for @learnMistakeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get learnMistakeQuestion;

  /// No description provided for @learnMistakeResolve.
  ///
  /// In en, this message translates to:
  /// **'Mark as resolved'**
  String get learnMistakeResolve;

  /// No description provided for @learnMistakeReviewOn.
  ///
  /// In en, this message translates to:
  /// **'review on {date}'**
  String learnMistakeReviewOn(String date);

  /// No description provided for @learnMistakeReviewToday.
  ///
  /// In en, this message translates to:
  /// **'due today'**
  String get learnMistakeReviewToday;

  /// No description provided for @learnMistakeWrongCount.
  ///
  /// In en, this message translates to:
  /// **'wrong: {n}'**
  String learnMistakeWrongCount(int n);

  /// No description provided for @learnMistakesAllSubjects.
  ///
  /// In en, this message translates to:
  /// **'All subjects'**
  String get learnMistakesAllSubjects;

  /// No description provided for @learnMistakesDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today: {n}'**
  String learnMistakesDueToday(int n);

  /// No description provided for @learnMistakesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Wrong answers from practice and exams will appear here.'**
  String get learnMistakesEmptyBody;

  /// No description provided for @learnMistakesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No mistakes to review'**
  String get learnMistakesEmptyTitle;

  /// No description provided for @learnMistakesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get learnMistakesFilterAll;

  /// No description provided for @learnMistakesFilterDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get learnMistakesFilterDue;

  /// No description provided for @learnMistakesNothingDue.
  ///
  /// In en, this message translates to:
  /// **'All caught up for today. Come back tomorrow.'**
  String get learnMistakesNothingDue;

  /// No description provided for @learnMistakesPracticeN.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Review 1 question} other{Review {n} questions}}'**
  String learnMistakesPracticeN(int n);

  /// No description provided for @learnMistakesPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Mistakes review'**
  String get learnMistakesPracticeTitle;

  /// No description provided for @learnMistakesSrsNote.
  ///
  /// In en, this message translates to:
  /// **'Each mistake comes back after 1, 3, 7, 14 and 30 days. A correct answer moves it further; a wrong one restarts it.'**
  String get learnMistakesSrsNote;

  /// No description provided for @learnMistakesTitle.
  ///
  /// In en, this message translates to:
  /// **'Mistakes & review'**
  String get learnMistakesTitle;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get learnMore;

  /// No description provided for @learnNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get learnNext;

  /// No description provided for @learnNextLesson.
  ///
  /// In en, this message translates to:
  /// **'Next lesson'**
  String get learnNextLesson;

  /// No description provided for @learnNoExplanation.
  ///
  /// In en, this message translates to:
  /// **'No explanation has been added for this question yet.'**
  String get learnNoExplanation;

  /// No description provided for @learnNoLessonsYet.
  ///
  /// In en, this message translates to:
  /// **'No lessons yet — start with practice.'**
  String get learnNoLessonsYet;

  /// No description provided for @learnNoQuestionsBody.
  ///
  /// In en, this message translates to:
  /// **'There are no reviewed questions here yet. Check back later or try quick practice.'**
  String get learnNoQuestionsBody;

  /// No description provided for @learnNoQuestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No questions yet'**
  String get learnNoQuestionsTitle;

  /// No description provided for @learnNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get learnNoSearchResults;

  /// No description provided for @learnNoSubjectsBody.
  ///
  /// In en, this message translates to:
  /// **'Learning materials are coming soon. Meanwhile, try quick practice.'**
  String get learnNoSubjectsBody;

  /// No description provided for @learnNoSubjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'No subjects yet'**
  String get learnNoSubjectsTitle;

  /// No description provided for @learnOpenMistakes.
  ///
  /// In en, this message translates to:
  /// **'Work on mistakes'**
  String get learnOpenMistakes;

  /// No description provided for @learnPracticeAgain.
  ///
  /// In en, this message translates to:
  /// **'Practice again'**
  String get learnPracticeAgain;

  /// No description provided for @learnPracticeBySubjectEmpty.
  ///
  /// In en, this message translates to:
  /// **'Answer a few questions to see accuracy by subject.'**
  String get learnPracticeBySubjectEmpty;

  /// No description provided for @learnPracticeBySubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice by subject'**
  String get learnPracticeBySubjectTitle;

  /// No description provided for @learnPracticeCorrectOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String learnPracticeCorrectOfTotal(int correct, int total);

  /// No description provided for @learnPracticeNotOrtNote.
  ///
  /// In en, this message translates to:
  /// **'This is a practice result, not an ORT score: a short set of questions cannot estimate an exam score.'**
  String get learnPracticeNotOrtNote;

  /// No description provided for @learnPracticePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Practice: {percent}%'**
  String learnPracticePercentLabel(int percent);

  /// No description provided for @learnPracticeSubject.
  ///
  /// In en, this message translates to:
  /// **'Practise this subject'**
  String get learnPracticeSubject;

  /// No description provided for @learnPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get learnPracticeTitle;

  /// No description provided for @learnPracticeVerdictExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent! Keep it up.'**
  String get learnPracticeVerdictExcellent;

  /// No description provided for @learnPracticeVerdictFair.
  ///
  /// In en, this message translates to:
  /// **'Not bad. Reviewing mistakes improves results fastest.'**
  String get learnPracticeVerdictFair;

  /// No description provided for @learnPracticeVerdictGood.
  ///
  /// In en, this message translates to:
  /// **'Good. Almost there.'**
  String get learnPracticeVerdictGood;

  /// No description provided for @learnPracticeVerdictLow.
  ///
  /// In en, this message translates to:
  /// **'More practice needed. Start by reviewing mistakes.'**
  String get learnPracticeVerdictLow;

  /// No description provided for @learnProgressEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Complete a lesson or practice set to see your real statistics.'**
  String get learnProgressEmptyBody;

  /// No description provided for @learnProgressEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get learnProgressEmptyTitle;

  /// No description provided for @learnProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get learnProgressTitle;

  /// No description provided for @learnQuestAnswer.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Answer 1 question} other{Answer {n} questions}}'**
  String learnQuestAnswer(int n);

  /// No description provided for @learnQuestCompleteSet.
  ///
  /// In en, this message translates to:
  /// **'Finish one practice set'**
  String get learnQuestCompleteSet;

  /// No description provided for @learnQuestRun.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 correct answer in a row} other{{n} correct answers in a row}}'**
  String learnQuestRun(int n);

  /// No description provided for @learnQuestionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {n}'**
  String learnQuestionNumber(int n);

  /// No description provided for @learnQuestionProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String learnQuestionProgress(int current, int total);

  /// No description provided for @learnQuestsDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String learnQuestsDone(int done, int total);

  /// No description provided for @learnQuestsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset in {h} h {m} min'**
  String learnQuestsReset(int h, int m);

  /// No description provided for @learnQuestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily quests'**
  String get learnQuestsTitle;

  /// No description provided for @learnQuickPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick practice'**
  String get learnQuickPracticeTitle;

  /// No description provided for @learnRecDueMistakesTitle.
  ///
  /// In en, this message translates to:
  /// **'We recommend reviewing your mistakes ({n})'**
  String learnRecDueMistakesTitle(int n);

  /// No description provided for @learnRecDueMistakesWhy.
  ///
  /// In en, this message translates to:
  /// **'…because they are due today, and spaced review makes material stick.'**
  String get learnRecDueMistakesWhy;

  /// No description provided for @learnRecMoreDataTitle.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{We recommend answering 1 more question} other{We recommend answering {n} more questions}}'**
  String learnRecMoreDataTitle(int n);

  /// No description provided for @learnRecMoreDataWhy.
  ///
  /// In en, this message translates to:
  /// **'…because accuracy becomes meaningful after about 20 answers.'**
  String get learnRecMoreDataWhy;

  /// No description provided for @learnRecNoExamTitle.
  ///
  /// In en, this message translates to:
  /// **'We recommend taking a mock exam'**
  String get learnRecNoExamTitle;

  /// No description provided for @learnRecNoExamWhy.
  ///
  /// In en, this message translates to:
  /// **'…because there\'s no result across all sections yet, so it\'s unclear which one lags.'**
  String get learnRecNoExamWhy;

  /// No description provided for @learnRecOpenExams.
  ///
  /// In en, this message translates to:
  /// **'Go to exams'**
  String get learnRecOpenExams;

  /// No description provided for @learnRecWeakSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'We recommend working on {section}'**
  String learnRecWeakSectionTitle(String section);

  /// No description provided for @learnRecWeakSectionWhy.
  ///
  /// In en, this message translates to:
  /// **'…because you average {percent}% there on mock exams — your lowest section.'**
  String learnRecWeakSectionWhy(int percent);

  /// No description provided for @learnRecWeakSubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'We recommend practising {subject}'**
  String learnRecWeakSubjectTitle(String subject);

  /// No description provided for @learnRecWeakSubjectWhy.
  ///
  /// In en, this message translates to:
  /// **'…because your accuracy there is {percent}%, lower than in other subjects ({count} answers).'**
  String learnRecWeakSubjectWhy(int percent, int count);

  /// No description provided for @learnRecWeakTopicTitle.
  ///
  /// In en, this message translates to:
  /// **'We recommend revisiting {topic}'**
  String learnRecWeakTopicTitle(String topic);

  /// No description provided for @learnRecWeakTopicWhy.
  ///
  /// In en, this message translates to:
  /// **'…because only {percent}% of your answers on this topic are correct.'**
  String learnRecWeakTopicWhy(int percent);

  /// No description provided for @learnRecommendationsNone.
  ///
  /// In en, this message translates to:
  /// **'Everything looks good — keep going.'**
  String get learnRecommendationsNone;

  /// No description provided for @learnRecommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get learnRecommendationsTitle;

  /// No description provided for @learnResultsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Do a practice set and the answer review will appear here.'**
  String get learnResultsEmptyBody;

  /// No description provided for @learnResultsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get learnResultsEmptyTitle;

  /// No description provided for @learnResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice result'**
  String get learnResultsTitle;

  /// No description provided for @learnReviewAnswers.
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get learnReviewAnswers;

  /// No description provided for @learnRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get learnRightAnswer;

  /// No description provided for @learnSearchSubjects.
  ///
  /// In en, this message translates to:
  /// **'Search subjects'**
  String get learnSearchSubjects;

  /// No description provided for @learnSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get learnSignIn;

  /// No description provided for @learnSignInToPractice.
  ///
  /// In en, this message translates to:
  /// **'Sign in to practise and save your progress.'**
  String get learnSignInToPractice;

  /// No description provided for @learnSignInToSave.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your progress.'**
  String get learnSignInToSave;

  /// No description provided for @learnSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get learnSkip;

  /// No description provided for @learnSkipAndFinish.
  ///
  /// In en, this message translates to:
  /// **'Skip and finish'**
  String get learnSkipAndFinish;

  /// No description provided for @learnStartPractice.
  ///
  /// In en, this message translates to:
  /// **'Start practice'**
  String get learnStartPractice;

  /// No description provided for @learnStatAnswered.
  ///
  /// In en, this message translates to:
  /// **'Practice answers'**
  String get learnStatAnswered;

  /// No description provided for @learnStatBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best: {n}'**
  String learnStatBestStreak(int n);

  /// No description provided for @learnStatCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get learnStatCorrect;

  /// No description provided for @learnStatExams.
  ///
  /// In en, this message translates to:
  /// **'Mock exams'**
  String get learnStatExams;

  /// No description provided for @learnStatLessonsCompleted.
  ///
  /// In en, this message translates to:
  /// **'lessons done: {n}'**
  String learnStatLessonsCompleted(int n);

  /// No description provided for @learnStatLessonsDone.
  ///
  /// In en, this message translates to:
  /// **'Lessons done'**
  String get learnStatLessonsDone;

  /// No description provided for @learnStatLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get learnStatLevel;

  /// No description provided for @learnStatPracticeAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Practice accuracy'**
  String get learnStatPracticeAccuracy;

  /// No description provided for @learnStatPracticeOnly.
  ///
  /// In en, this message translates to:
  /// **'practice only'**
  String get learnStatPracticeOnly;

  /// No description provided for @learnStatPracticeTime.
  ///
  /// In en, this message translates to:
  /// **'Practice time'**
  String get learnStatPracticeTime;

  /// No description provided for @learnStatPracticeTimeHint.
  ///
  /// In en, this message translates to:
  /// **'from finished sets'**
  String get learnStatPracticeTimeHint;

  /// No description provided for @learnStatSessions.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 set} other{{n} sets}}'**
  String learnStatSessions(int n);

  /// No description provided for @learnStatSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get learnStatSkipped;

  /// No description provided for @learnStatStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak, days'**
  String get learnStatStreak;

  /// No description provided for @learnStatTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get learnStatTime;

  /// No description provided for @learnStatWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get learnStatWrong;

  /// No description provided for @learnStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day} other{{n} days}}'**
  String learnStreakDays(int n);

  /// No description provided for @learnSubjectNotFound.
  ///
  /// In en, this message translates to:
  /// **'Subject not found'**
  String get learnSubjectNotFound;

  /// No description provided for @learnSubjectNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The link may be out of date.'**
  String get learnSubjectNotFoundBody;

  /// No description provided for @learnSubjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get learnSubjectsTitle;

  /// No description provided for @learnWeakTopicsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough answers to spot weak topics yet (5+ per topic needed).'**
  String get learnWeakTopicsEmpty;

  /// No description provided for @learnWeakTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Topics to review'**
  String get learnWeakTopicsTitle;

  /// No description provided for @learnWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get learnWrong;

  /// No description provided for @learnXpAwarded.
  ///
  /// In en, this message translates to:
  /// **'+{xp} XP'**
  String learnXpAwarded(int xp);

  /// No description provided for @learnXpNone.
  ///
  /// In en, this message translates to:
  /// **'No XP was awarded for this set.'**
  String get learnXpNone;

  /// No description provided for @learnXpPending.
  ///
  /// In en, this message translates to:
  /// **'Awarding XP…'**
  String get learnXpPending;

  /// No description provided for @learnXpQueued.
  ///
  /// In en, this message translates to:
  /// **'XP will be credited once you\'re back online.'**
  String get learnXpQueued;

  /// No description provided for @learnXpShort.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String learnXpShort(int xp);

  /// No description provided for @learnXpToNextLevel.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP to level {level}'**
  String learnXpToNextLevel(int xp, int level);

  /// No description provided for @learnXpTotal.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP total'**
  String learnXpTotal(int xp);

  /// No description provided for @learnYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get learnYourAnswer;

  /// No description provided for @lessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessons;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @mathematics.
  ///
  /// In en, this message translates to:
  /// **'Mathematics'**
  String get mathematics;

  /// No description provided for @mbankPayment.
  ///
  /// In en, this message translates to:
  /// **'MBank Payment'**
  String get mbankPayment;

  /// No description provided for @mockTest.
  ///
  /// In en, this message translates to:
  /// **'Mock Test'**
  String get mockTest;

  /// No description provided for @mockTestDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete mock test with real exam format'**
  String get mockTestDesc;

  /// No description provided for @mockTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Full ORT Simulation'**
  String get mockTestTitle;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @myProgress.
  ///
  /// In en, this message translates to:
  /// **'My Progress'**
  String get myProgress;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @nextOrtDate.
  ///
  /// In en, this message translates to:
  /// **'Next ORT Registration'**
  String get nextOrtDate;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noConnection;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Complete practice tests and master all subjects for the ORT exam'**
  String get onboardingDesc1;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Monitor your performance and identify weak areas to improve'**
  String get onboardingDesc2;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Take full-length simulations with real ORT format and timing'**
  String get onboardingDesc3;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Prepare for ORT'**
  String get onboardingTitle1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Track Your Progress'**
  String get onboardingTitle2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Mock Exams'**
  String get onboardingTitle3;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @phoneSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Phone'**
  String get phoneSignIn;

  /// No description provided for @physics.
  ///
  /// In en, this message translates to:
  /// **'Physics'**
  String get physics;

  /// No description provided for @practiceQuiz.
  ///
  /// In en, this message translates to:
  /// **'Practice Quiz'**
  String get practiceQuiz;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Study reminders'**
  String get pushNotificationsDesc;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @russianLanguage.
  ///
  /// In en, this message translates to:
  /// **'Russian Language'**
  String get russianLanguage;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @section1.
  ///
  /// In en, this message translates to:
  /// **'Main Test'**
  String get section1;

  /// No description provided for @section2.
  ///
  /// In en, this message translates to:
  /// **'Subject Test'**
  String get section2;

  /// No description provided for @section3.
  ///
  /// In en, this message translates to:
  /// **'Language Test'**
  String get section3;

  /// No description provided for @selectGrade.
  ///
  /// In en, this message translates to:
  /// **'Select Your Grade'**
  String get selectGrade;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectSubjects.
  ///
  /// In en, this message translates to:
  /// **'Select Weak Subjects'**
  String get selectSubjects;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @shellAuthConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get shellAuthConfirmPasswordLabel;

  /// No description provided for @shellAuthContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get shellAuthContinueWithGoogle;

  /// No description provided for @shellAuthEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the email address, e.g. name@example.com'**
  String get shellAuthEmailInvalid;

  /// No description provided for @shellAuthEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get shellAuthEmailLabel;

  /// No description provided for @shellAuthEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get shellAuthEmailRequired;

  /// No description provided for @shellAuthErrorDifferentCredential.
  ///
  /// In en, this message translates to:
  /// **'This email is linked to another sign-in method.'**
  String get shellAuthErrorDifferentCredential;

  /// No description provided for @shellAuthErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Sign in instead.'**
  String get shellAuthErrorEmailInUse;

  /// No description provided for @shellAuthErrorGoogleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t available on this device yet. Use email instead.'**
  String get shellAuthErrorGoogleUnavailable;

  /// No description provided for @shellAuthErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get shellAuthErrorInvalidCredentials;

  /// No description provided for @shellAuthErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again.'**
  String get shellAuthErrorNetwork;

  /// No description provided for @shellAuthErrorNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is temporarily unavailable.'**
  String get shellAuthErrorNotAllowed;

  /// No description provided for @shellAuthErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get shellAuthErrorTooManyRequests;

  /// No description provided for @shellAuthErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get shellAuthErrorUnknown;

  /// No description provided for @shellAuthErrorUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been blocked. Contact support.'**
  String get shellAuthErrorUserDisabled;

  /// No description provided for @shellAuthErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account with this email. Create one first.'**
  String get shellAuthErrorUserNotFound;

  /// No description provided for @shellAuthForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get shellAuthForgotPassword;

  /// No description provided for @shellAuthHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get shellAuthHidePassword;

  /// No description provided for @shellAuthNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get shellAuthNameLabel;

  /// No description provided for @shellAuthNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get shellAuthNameRequired;

  /// No description provided for @shellAuthNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name is too short'**
  String get shellAuthNameTooShort;

  /// No description provided for @shellAuthOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get shellAuthOr;

  /// No description provided for @shellAuthPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters, letters and digits'**
  String shellAuthPasswordHint(int min);

  /// No description provided for @shellAuthPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get shellAuthPasswordLabel;

  /// No description provided for @shellAuthPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get shellAuthPasswordMismatch;

  /// No description provided for @shellAuthPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get shellAuthPasswordRequired;

  /// No description provided for @shellAuthPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {min} characters'**
  String shellAuthPasswordTooShort(int min);

  /// No description provided for @shellAuthPasswordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Use both letters and digits'**
  String get shellAuthPasswordTooWeak;

  /// No description provided for @shellAuthResetMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter your account email and we\'ll send a link to set a new password.'**
  String get shellAuthResetMessage;

  /// No description provided for @shellAuthResetSend.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get shellAuthResetSend;

  /// No description provided for @shellAuthResetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account with this email exists, we\'ve sent a reset link.'**
  String get shellAuthResetSent;

  /// No description provided for @shellAuthResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get shellAuthResetTitle;

  /// No description provided for @shellAuthShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get shellAuthShowPassword;

  /// No description provided for @shellBootErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get shellBootErrorMessage;

  /// No description provided for @shellBootErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the app'**
  String get shellBootErrorTitle;

  /// No description provided for @shellCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shellCancel;

  /// No description provided for @shellDaily10Desc.
  ///
  /// In en, this message translates to:
  /// **'Easy start'**
  String get shellDaily10Desc;

  /// No description provided for @shellDaily20Desc.
  ///
  /// In en, this message translates to:
  /// **'Steady pace'**
  String get shellDaily20Desc;

  /// No description provided for @shellDaily30Desc.
  ///
  /// In en, this message translates to:
  /// **'Intensive preparation'**
  String get shellDaily30Desc;

  /// No description provided for @shellDailyMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min a day'**
  String shellDailyMinutes(int minutes);

  /// No description provided for @shellExitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get shellExitConfirm;

  /// No description provided for @shellExitMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress is saved.'**
  String get shellExitMessage;

  /// No description provided for @shellExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit the app?'**
  String get shellExitTitle;

  /// No description provided for @shellGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get shellGoHome;

  /// No description provided for @shellGoalBand110Desc.
  ///
  /// In en, this message translates to:
  /// **'Solid base'**
  String get shellGoalBand110Desc;

  /// No description provided for @shellGoalBand150Desc.
  ///
  /// In en, this message translates to:
  /// **'Strong result'**
  String get shellGoalBand150Desc;

  /// No description provided for @shellGoalBand190Desc.
  ///
  /// In en, this message translates to:
  /// **'Top result'**
  String get shellGoalBand190Desc;

  /// No description provided for @shellGoalUnsure.
  ///
  /// In en, this message translates to:
  /// **'Not sure yet'**
  String get shellGoalUnsure;

  /// No description provided for @shellGradeGraduate.
  ///
  /// In en, this message translates to:
  /// **'Graduate'**
  String get shellGradeGraduate;

  /// No description provided for @shellGradeLabel.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get shellGradeLabel;

  /// No description provided for @shellGradeNumber.
  ///
  /// In en, this message translates to:
  /// **'Grade {grade}'**
  String shellGradeNumber(int grade);

  /// No description provided for @shellHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get shellHide;

  /// No description provided for @shellHomeBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best: {count}'**
  String shellHomeBestStreak(int count);

  /// No description provided for @shellHomeBuyExam.
  ///
  /// In en, this message translates to:
  /// **'Get a mock exam'**
  String get shellHomeBuyExam;

  /// No description provided for @shellHomeCredits.
  ///
  /// In en, this message translates to:
  /// **'Mock exams available: {count}'**
  String shellHomeCredits(int count);

  /// No description provided for @shellHomeDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get shellHomeDailyGoal;

  /// No description provided for @shellHomeEmptyStatsMessage.
  ///
  /// In en, this message translates to:
  /// **'Solve a task or take a lesson — your streak and daily progress will appear here.'**
  String get shellHomeEmptyStatsMessage;

  /// No description provided for @shellHomeEmptyStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Start your streak today'**
  String get shellHomeEmptyStatsTitle;

  /// No description provided for @shellHomeEntitlementError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check access · Retry'**
  String get shellHomeEntitlementError;

  /// No description provided for @shellHomeFreeExam.
  ///
  /// In en, this message translates to:
  /// **'Free mock exam available'**
  String get shellHomeFreeExam;

  /// No description provided for @shellHomeGoalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Your goal: {minutes} min a day'**
  String shellHomeGoalMinutes(int minutes);

  /// No description provided for @shellHomeGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached!'**
  String get shellHomeGoalReached;

  /// No description provided for @shellHomeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi!'**
  String get shellHomeGreeting;

  /// No description provided for @shellHomeGreetingName.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}!'**
  String shellHomeGreetingName(String name);

  /// No description provided for @shellHomeLevelXp.
  ///
  /// In en, this message translates to:
  /// **'Level {level} · {xp} XP'**
  String shellHomeLevelXp(int level, int xp);

  /// No description provided for @shellHomeNextStepError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your recommendation.'**
  String get shellHomeNextStepError;

  /// No description provided for @shellHomeReminderEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get shellHomeReminderEnable;

  /// No description provided for @shellHomeReminderMessage.
  ///
  /// In en, this message translates to:
  /// **'A short daily reminder helps keep your streak.'**
  String get shellHomeReminderMessage;

  /// No description provided for @shellHomeReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind you to study?'**
  String get shellHomeReminderTitle;

  /// No description provided for @shellHomeSetupAction.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get shellHomeSetupAction;

  /// No description provided for @shellHomeSetupMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your grade, region and target score to get better recommendations.'**
  String get shellHomeSetupMessage;

  /// No description provided for @shellHomeSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your goal'**
  String get shellHomeSetupTitle;

  /// No description provided for @shellHomeStatsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your progress.'**
  String get shellHomeStatsError;

  /// No description provided for @shellHomeStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day in a row} other{{count} days in a row}}'**
  String shellHomeStreakDays(int count);

  /// No description provided for @shellHomeStreakNone.
  ///
  /// In en, this message translates to:
  /// **'No streak yet'**
  String get shellHomeStreakNone;

  /// No description provided for @shellHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s keep preparing for the ORT'**
  String get shellHomeSubtitle;

  /// No description provided for @shellHomeTodayXp.
  ///
  /// In en, this message translates to:
  /// **'Today: {today} XP'**
  String shellHomeTodayXp(int today);

  /// No description provided for @shellHomeTodayXpOfGoal.
  ///
  /// In en, this message translates to:
  /// **'Today: {today} of {goal} XP'**
  String shellHomeTodayXpOfGoal(int today, int goal);

  /// No description provided for @shellLangEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get shellLangEn;

  /// No description provided for @shellLangEnNative.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get shellLangEnNative;

  /// No description provided for @shellLangKy.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get shellLangKy;

  /// No description provided for @shellLangKyNative.
  ///
  /// In en, this message translates to:
  /// **'Кыргызча'**
  String get shellLangKyNative;

  /// No description provided for @shellLangRu.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get shellLangRu;

  /// No description provided for @shellLangRuNative.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get shellLangRuNative;

  /// No description provided for @shellLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get shellLater;

  /// No description provided for @shellLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get shellLinkOpenFailed;

  /// No description provided for @shellLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get shellLoading;

  /// No description provided for @shellLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get shellLoginButton;

  /// No description provided for @shellLoginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get shellLoginCreateAccount;

  /// No description provided for @shellLoginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get shellLoginNoAccount;

  /// No description provided for @shellLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue preparing for the ORT.'**
  String get shellLoginSubtitle;

  /// No description provided for @shellLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get shellLoginTitle;

  /// No description provided for @shellNavExams.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get shellNavExams;

  /// No description provided for @shellNavHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellNavHome;

  /// No description provided for @shellNavLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get shellNavLearn;

  /// No description provided for @shellNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get shellNavProfile;

  /// No description provided for @shellNavProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get shellNavProgress;

  /// No description provided for @shellNextFirstMock.
  ///
  /// In en, this message translates to:
  /// **'Take a full mock exam to see your level and weak topics.'**
  String get shellNextFirstMock;

  /// No description provided for @shellNextFirstMockFree.
  ///
  /// In en, this message translates to:
  /// **'Take your first full mock exam — it\'s free. You\'ll see your level and weak topics.'**
  String get shellNextFirstMockFree;

  /// No description provided for @shellNextOpenExams.
  ///
  /// In en, this message translates to:
  /// **'Go to exams'**
  String get shellNextOpenExams;

  /// No description provided for @shellNextOpenLearn.
  ///
  /// In en, this message translates to:
  /// **'Go to study'**
  String get shellNextOpenLearn;

  /// No description provided for @shellNextPractice.
  ///
  /// In en, this message translates to:
  /// **'Good work! Reinforce it with a quick test or take another mock exam.'**
  String get shellNextPractice;

  /// No description provided for @shellNextStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get shellNextStepTitle;

  /// No description provided for @shellNextWeakTopic.
  ///
  /// In en, this message translates to:
  /// **'Your weakest area in the last exam: {area}. Review it to raise your score.'**
  String shellNextWeakTopic(String area);

  /// No description provided for @shellNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The link may be outdated. Go back to the home screen.'**
  String get shellNotFoundMessage;

  /// No description provided for @shellNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get shellNotFoundTitle;

  /// No description provided for @shellNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get shellNotNow;

  /// No description provided for @shellNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get shellNotSet;

  /// No description provided for @shellOnbAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tailor tasks and show your region\'s leaderboard.'**
  String get shellOnbAboutSubtitle;

  /// No description provided for @shellOnbAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get shellOnbAboutTitle;

  /// No description provided for @shellOnbBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get shellOnbBack;

  /// No description provided for @shellOnbDailySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short daily sessions work better than rare marathons.'**
  String get shellOnbDailySubtitle;

  /// No description provided for @shellOnbDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'How much time a day can you study?'**
  String get shellOnbDailyTitle;

  /// No description provided for @shellOnbGoalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A goal shows how far you still have to go. You can change it in your profile.'**
  String get shellOnbGoalSubtitle;

  /// No description provided for @shellOnbGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'What score are you aiming for?'**
  String get shellOnbGoalTitle;

  /// No description provided for @shellOnbLangKyHint.
  ///
  /// In en, this message translates to:
  /// **'ORT in Kyrgyz'**
  String get shellOnbLangKyHint;

  /// No description provided for @shellOnbLangRuHint.
  ///
  /// In en, this message translates to:
  /// **'ORT in Russian'**
  String get shellOnbLangRuHint;

  /// No description provided for @shellOnbLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app and mock exams will use this language. You can change it in Settings.'**
  String get shellOnbLanguageSubtitle;

  /// No description provided for @shellOnbLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Which language will you prepare in?'**
  String get shellOnbLanguageTitle;

  /// No description provided for @shellOnbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get shellOnbNext;

  /// No description provided for @shellOnbSavedLater.
  ///
  /// In en, this message translates to:
  /// **'Answers saved. They\'ll sync when you\'re online.'**
  String get shellOnbSavedLater;

  /// No description provided for @shellOnbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get shellOnbSkip;

  /// No description provided for @shellOnbStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get shellOnbStart;

  /// No description provided for @shellOnbStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String shellOnbStepOf(int current, int total);

  /// No description provided for @shellOnbUniversityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. KSMA or KNU'**
  String get shellOnbUniversityHint;

  /// No description provided for @shellOnbUniversityLabel.
  ///
  /// In en, this message translates to:
  /// **'Dream university'**
  String get shellOnbUniversityLabel;

  /// No description provided for @shellOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get shellOptional;

  /// No description provided for @shellProfileAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get shellProfileAchievements;

  /// No description provided for @shellProfileComplete.
  ///
  /// In en, this message translates to:
  /// **'Fill in profile'**
  String get shellProfileComplete;

  /// No description provided for @shellProfileDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get shellProfileDailyGoal;

  /// No description provided for @shellProfileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get shellProfileDeleteAccount;

  /// No description provided for @shellProfileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get shellProfileEdit;

  /// No description provided for @shellProfileEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get shellProfileEditTitle;

  /// No description provided for @shellProfileExamLanguage.
  ///
  /// In en, this message translates to:
  /// **'Exam language'**
  String get shellProfileExamLanguage;

  /// No description provided for @shellProfileExams.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get shellProfileExams;

  /// No description provided for @shellProfileGoal.
  ///
  /// In en, this message translates to:
  /// **'Target score'**
  String get shellProfileGoal;

  /// No description provided for @shellProfileLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get shellProfileLevel;

  /// No description provided for @shellProfileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your profile.'**
  String get shellProfileLoadError;

  /// No description provided for @shellProfileNoName.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get shellProfileNoName;

  /// No description provided for @shellProfileRegionLocked.
  ///
  /// In en, this message translates to:
  /// **'The region can be changed once a year.'**
  String get shellProfileRegionLocked;

  /// No description provided for @shellProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection and try again.'**
  String get shellProfileSaveError;

  /// No description provided for @shellProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get shellProfileSaved;

  /// No description provided for @shellProfileSavedOffline.
  ///
  /// In en, this message translates to:
  /// **'Saved. Changes will sync when you\'re online.'**
  String get shellProfileSavedOffline;

  /// No description provided for @shellProfileSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get shellProfileSchool;

  /// No description provided for @shellProfileStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get shellProfileStreak;

  /// No description provided for @shellProfileTransactions.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get shellProfileTransactions;

  /// No description provided for @shellQuickDailyLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson of the day'**
  String get shellQuickDailyLesson;

  /// No description provided for @shellQuickHandbook.
  ///
  /// In en, this message translates to:
  /// **'Handbook'**
  String get shellQuickHandbook;

  /// No description provided for @shellQuickLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get shellQuickLeaderboard;

  /// No description provided for @shellQuickMockExam.
  ///
  /// In en, this message translates to:
  /// **'Mock exam'**
  String get shellQuickMockExam;

  /// No description provided for @shellQuickTest.
  ///
  /// In en, this message translates to:
  /// **'Quick test'**
  String get shellQuickTest;

  /// No description provided for @shellQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get shellQuickTitle;

  /// No description provided for @shellQuickTutor.
  ///
  /// In en, this message translates to:
  /// **'AI tutor'**
  String get shellQuickTutor;

  /// No description provided for @shellRegionDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get shellRegionDistrict;

  /// No description provided for @shellRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get shellRegionLabel;

  /// No description provided for @shellRegionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the list of regions.'**
  String get shellRegionLoadError;

  /// No description provided for @shellRegionOblast.
  ///
  /// In en, this message translates to:
  /// **'Region or city'**
  String get shellRegionOblast;

  /// No description provided for @shellReminderDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for the app. Allow them in your phone settings.'**
  String get shellReminderDenied;

  /// No description provided for @shellReminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders are on.'**
  String get shellReminderEnabled;

  /// No description provided for @shellReminderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn on reminders. Try again later.'**
  String get shellReminderFailed;

  /// No description provided for @shellReminderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reminders aren\'t available on this device.'**
  String get shellReminderUnsupported;

  /// No description provided for @shellRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get shellRetry;

  /// No description provided for @shellSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shellSave;

  /// No description provided for @shellSettingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get shellSettingsAbout;

  /// No description provided for @shellSettingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get shellSettingsAppearance;

  /// No description provided for @shellSettingsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Mock exam results are for practice and are not official ORT scores.'**
  String get shellSettingsDisclaimer;

  /// No description provided for @shellSettingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get shellSettingsLanguage;

  /// No description provided for @shellSettingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get shellSettingsNotifications;

  /// No description provided for @shellSettingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get shellSettingsPrivacy;

  /// No description provided for @shellSettingsReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get shellSettingsReminder;

  /// No description provided for @shellSettingsReminderHint.
  ///
  /// In en, this message translates to:
  /// **'A short reminder to study once a day'**
  String get shellSettingsReminderHint;

  /// No description provided for @shellSettingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get shellSettingsTerms;

  /// No description provided for @shellSettingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get shellSettingsTheme;

  /// No description provided for @shellSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettingsTitle;

  /// No description provided for @shellSettingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get shellSettingsVersion;

  /// No description provided for @shellSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get shellSignOut;

  /// No description provided for @shellSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress stays in your account.'**
  String get shellSignOutMessage;

  /// No description provided for @shellSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get shellSignOutTitle;

  /// No description provided for @shellSignupButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get shellSignupButton;

  /// No description provided for @shellSignupHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get shellSignupHaveAccount;

  /// No description provided for @shellSignupLegalAnd.
  ///
  /// In en, this message translates to:
  /// **' and the '**
  String get shellSignupLegalAnd;

  /// No description provided for @shellSignupLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to the '**
  String get shellSignupLegalPrefix;

  /// No description provided for @shellSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It takes a minute. Your progress will be saved in your account.'**
  String get shellSignupSubtitle;

  /// No description provided for @shellSignupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created. We\'ve sent a confirmation email.'**
  String get shellSignupSuccess;

  /// No description provided for @shellSignupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get shellSignupTitle;

  /// No description provided for @shellTagline.
  ///
  /// In en, this message translates to:
  /// **'ORT preparation'**
  String get shellTagline;

  /// No description provided for @shellThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get shellThemeDark;

  /// No description provided for @shellThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get shellThemeLight;

  /// No description provided for @shellThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'As on device'**
  String get shellThemeSystem;

  /// No description provided for @shellVerifyCheck.
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed'**
  String get shellVerifyCheck;

  /// No description provided for @shellVerifyDone.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed. Thank you!'**
  String get shellVerifyDone;

  /// No description provided for @shellVerifyMessage.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. It helps you recover your account.'**
  String shellVerifyMessage(String email);

  /// No description provided for @shellVerifyNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Open the link from the email.'**
  String get shellVerifyNotYet;

  /// No description provided for @shellVerifyResend.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get shellVerifyResend;

  /// No description provided for @shellVerifySendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the email. Try again later.'**
  String get shellVerifySendFailed;

  /// No description provided for @shellVerifySent.
  ///
  /// In en, this message translates to:
  /// **'Email sent. Check your inbox and spam folder.'**
  String get shellVerifySent;

  /// No description provided for @shellVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get shellVerifyTitle;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get startLearning;

  /// No description provided for @startQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get startQuiz;

  /// No description provided for @startTest.
  ///
  /// In en, this message translates to:
  /// **'Start Test'**
  String get startTest;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get streak;

  /// No description provided for @strongTopics.
  ///
  /// In en, this message translates to:
  /// **'Strong Topics'**
  String get strongTopics;

  /// No description provided for @studyTime.
  ///
  /// In en, this message translates to:
  /// **'Study Time'**
  String get studyTime;

  /// No description provided for @subjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjects;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @takeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Take Quiz'**
  String get takeQuiz;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @tests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get tests;

  /// No description provided for @testsTaken.
  ///
  /// In en, this message translates to:
  /// **'Tests Taken'**
  String get testsTaken;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @timeSpent.
  ///
  /// In en, this message translates to:
  /// **'Time Spent'**
  String get timeSpent;

  /// No description provided for @tutorAssistant.
  ///
  /// In en, this message translates to:
  /// **'Tutor'**
  String get tutorAssistant;

  /// No description provided for @tutorClear.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get tutorClear;

  /// No description provided for @tutorContextAttempt.
  ///
  /// In en, this message translates to:
  /// **'Exam attempt attached'**
  String get tutorContextAttempt;

  /// No description provided for @tutorContextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question attached'**
  String get tutorContextQuestion;

  /// No description provided for @tutorContextRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get tutorContextRemove;

  /// No description provided for @tutorDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI can make mistakes. Check important steps with your textbook or teacher.'**
  String get tutorDisclaimer;

  /// No description provided for @tutorEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a mode above and ask a question. I explain the reasoning instead of just giving the answer.'**
  String get tutorEmptyBody;

  /// No description provided for @tutorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get tutorEmptyTitle;

  /// No description provided for @tutorErrorDisabled.
  ///
  /// In en, this message translates to:
  /// **'The AI tutor is temporarily unavailable.'**
  String get tutorErrorDisabled;

  /// No description provided for @tutorErrorExamInProgress.
  ///
  /// In en, this message translates to:
  /// **'The tutor can\'t help during an active exam. Finish the attempt, then review your mistakes here.'**
  String get tutorErrorExamInProgress;

  /// No description provided for @tutorErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again.'**
  String get tutorErrorNetwork;

  /// No description provided for @tutorErrorQuota.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used today\'s AI requests. Come back tomorrow.'**
  String get tutorErrorQuota;

  /// No description provided for @tutorErrorSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use the AI tutor.'**
  String get tutorErrorSignIn;

  /// No description provided for @tutorErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'The tutor couldn\'t answer. Try again.'**
  String get tutorErrorUnknown;

  /// No description provided for @tutorErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'The message is empty or too long. Shorten it and try again.'**
  String get tutorErrorValidation;

  /// Message sent to the AI tutor on behalf of the student
  ///
  /// In en, this message translates to:
  /// **'Help me understand my mistake.\nTask: {stem}\nOptions:\n{options}\nMy answer: {userAnswer}\nCorrect answer: {correctAnswer}\nExplain where I went wrong and how to reason correctly.'**
  String tutorExplainPrompt(
    String stem,
    String options,
    String userAnswer,
    String correctAnswer,
  );

  /// No description provided for @tutorExplainerAiButton.
  ///
  /// In en, this message translates to:
  /// **'Explain my mistake'**
  String get tutorExplainerAiButton;

  /// No description provided for @tutorExplainerAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Why is it wrong? Ask the AI tutor'**
  String get tutorExplainerAiTitle;

  /// No description provided for @tutorExplainerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tutorExplainerClose;

  /// No description provided for @tutorExplainerCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get tutorExplainerCorrect;

  /// No description provided for @tutorExplainerCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String tutorExplainerCorrectAnswer(String answer);

  /// No description provided for @tutorExplainerExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get tutorExplainerExplanation;

  /// No description provided for @tutorExplainerIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get tutorExplainerIncorrect;

  /// No description provided for @tutorExplainerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutorExplainerNext;

  /// No description provided for @tutorExplainerNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'no answer'**
  String get tutorExplainerNoAnswer;

  /// No description provided for @tutorExplainerOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open tutor chat'**
  String get tutorExplainerOpenChat;

  /// No description provided for @tutorExplainerTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tutorExplainerTryAgain;

  /// No description provided for @tutorExplainerYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String tutorExplainerYourAnswer(String answer);

  /// No description provided for @tutorHintChat.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about ORT preparation.'**
  String get tutorHintChat;

  /// No description provided for @tutorHintExplainMistake.
  ///
  /// In en, this message translates to:
  /// **'Paste the task and your answer — I\'ll explain where the mistake is.'**
  String get tutorHintExplainMistake;

  /// No description provided for @tutorHintGrammar.
  ///
  /// In en, this message translates to:
  /// **'Ask about a rule or paste a sentence to check.'**
  String get tutorHintGrammar;

  /// No description provided for @tutorHintPractice.
  ///
  /// In en, this message translates to:
  /// **'Name a topic — I\'ll suggest similar tasks.'**
  String get tutorHintPractice;

  /// No description provided for @tutorHintStepByStep.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem — we\'ll solve it step by step.'**
  String get tutorHintStepByStep;

  /// No description provided for @tutorHintStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Tell me your exam date and weak subjects.'**
  String get tutorHintStudyPlan;

  /// No description provided for @tutorModeChat.
  ///
  /// In en, this message translates to:
  /// **'Free question'**
  String get tutorModeChat;

  /// No description provided for @tutorModeExplainMistake.
  ///
  /// In en, this message translates to:
  /// **'Explain a mistake'**
  String get tutorModeExplainMistake;

  /// No description provided for @tutorModeGrammar.
  ///
  /// In en, this message translates to:
  /// **'Grammar'**
  String get tutorModeGrammar;

  /// No description provided for @tutorModePractice.
  ///
  /// In en, this message translates to:
  /// **'Similar tasks'**
  String get tutorModePractice;

  /// No description provided for @tutorModeStepByStep.
  ///
  /// In en, this message translates to:
  /// **'Step by step'**
  String get tutorModeStepByStep;

  /// No description provided for @tutorModeStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Study plan'**
  String get tutorModeStudyPlan;

  /// No description provided for @tutorRemainingToday.
  ///
  /// In en, this message translates to:
  /// **'Requests left today: {count}'**
  String tutorRemainingToday(int count);

  /// No description provided for @tutorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get tutorRetry;

  /// No description provided for @tutorSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get tutorSend;

  /// No description provided for @tutorThinking.
  ///
  /// In en, this message translates to:
  /// **'The tutor is thinking…'**
  String get tutorThinking;

  /// No description provided for @tutorTitle.
  ///
  /// In en, this message translates to:
  /// **'AI tutor'**
  String get tutorTitle;

  /// No description provided for @tutorYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get tutorYou;

  /// No description provided for @weakTopics.
  ///
  /// In en, this message translates to:
  /// **'Weak Topics'**
  String get weakTopics;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ky', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ky':
      return AppLocalizationsKy();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
