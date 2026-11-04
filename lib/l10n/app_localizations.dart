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

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'ORT Master KG'**
  String get appName;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleSignIn;

  /// No description provided for @phoneSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Phone'**
  String get phoneSignIn;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Prepare for ORT'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Complete practice tests and master all subjects for the ORT exam'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Track Your Progress'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Monitor your performance and identify weak areas to improve'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Mock Exams'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Take full-length simulations with real ORT format and timing'**
  String get onboardingDesc3;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @selectGrade.
  ///
  /// In en, this message translates to:
  /// **'Select Your Grade'**
  String get selectGrade;

  /// No description provided for @grade9.
  ///
  /// In en, this message translates to:
  /// **'Grade 9'**
  String get grade9;

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

  /// No description provided for @graduate.
  ///
  /// In en, this message translates to:
  /// **'Graduate'**
  String get graduate;

  /// No description provided for @selectSubjects.
  ///
  /// In en, this message translates to:
  /// **'Select Weak Subjects'**
  String get selectSubjects;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @kyrgyz.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get kyrgyz;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @subjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get subjects;

  /// No description provided for @tests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get tests;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @myProgress.
  ///
  /// In en, this message translates to:
  /// **'My Progress'**
  String get myProgress;

  /// No description provided for @dailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily Goal'**
  String get dailyGoal;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get streak;

  /// No description provided for @nextOrtDate.
  ///
  /// In en, this message translates to:
  /// **'Next ORT Registration'**
  String get nextOrtDate;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get startLearning;

  /// No description provided for @takeQuiz.
  ///
  /// In en, this message translates to:
  /// **'Take Quiz'**
  String get takeQuiz;

  /// No description provided for @mockTest.
  ///
  /// In en, this message translates to:
  /// **'Mock Test'**
  String get mockTest;

  /// No description provided for @mathematics.
  ///
  /// In en, this message translates to:
  /// **'Mathematics'**
  String get mathematics;

  /// No description provided for @physics.
  ///
  /// In en, this message translates to:
  /// **'Physics'**
  String get physics;

  /// No description provided for @chemistry.
  ///
  /// In en, this message translates to:
  /// **'Chemistry'**
  String get chemistry;

  /// No description provided for @biology.
  ///
  /// In en, this message translates to:
  /// **'Biology'**
  String get biology;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History of Kyrgyzstan'**
  String get history;

  /// No description provided for @geography.
  ///
  /// In en, this message translates to:
  /// **'Geography'**
  String get geography;

  /// No description provided for @kyrgyzLanguage.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz Language'**
  String get kyrgyzLanguage;

  /// No description provided for @russianLanguage.
  ///
  /// In en, this message translates to:
  /// **'Russian Language'**
  String get russianLanguage;

  /// No description provided for @lessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get lessons;

  /// No description provided for @practiceQuiz.
  ///
  /// In en, this message translates to:
  /// **'Practice Quiz'**
  String get practiceQuiz;

  /// No description provided for @flashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get flashcards;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @startQuiz.
  ///
  /// In en, this message translates to:
  /// **'Start Quiz'**
  String get startQuiz;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get score;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrect;

  /// No description provided for @explanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get explanation;

  /// No description provided for @timeSpent.
  ///
  /// In en, this message translates to:
  /// **'Time Spent'**
  String get timeSpent;

  /// No description provided for @mockTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Full ORT Simulation'**
  String get mockTestTitle;

  /// No description provided for @mockTestDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete mock test with real exam format'**
  String get mockTestDesc;

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

  /// No description provided for @startTest.
  ///
  /// In en, this message translates to:
  /// **'Start Test'**
  String get startTest;

  /// No description provided for @continueTest.
  ///
  /// In en, this message translates to:
  /// **'Continue Test'**
  String get continueTest;

  /// No description provided for @buyTest.
  ///
  /// In en, this message translates to:
  /// **'Buy Test'**
  String get buyTest;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @kgs.
  ///
  /// In en, this message translates to:
  /// **'KGS'**
  String get kgs;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @weakTopics.
  ///
  /// In en, this message translates to:
  /// **'Weak Topics'**
  String get weakTopics;

  /// No description provided for @strongTopics.
  ///
  /// In en, this message translates to:
  /// **'Strong Topics'**
  String get strongTopics;

  /// No description provided for @averageScore.
  ///
  /// In en, this message translates to:
  /// **'Average Score'**
  String get averageScore;

  /// No description provided for @testsTaken.
  ///
  /// In en, this message translates to:
  /// **'Tests Taken'**
  String get testsTaken;

  /// No description provided for @studyTime.
  ///
  /// In en, this message translates to:
  /// **'Study Time'**
  String get studyTime;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get terms;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @currentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current Plan'**
  String get currentPlan;

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

  /// No description provided for @cardPayment.
  ///
  /// In en, this message translates to:
  /// **'Card Payment'**
  String get cardPayment;

  /// No description provided for @mbankPayment.
  ///
  /// In en, this message translates to:
  /// **'MBank Payment'**
  String get mbankPayment;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noConnection;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

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

  /// No description provided for @dataAndStorage.
  ///
  /// In en, this message translates to:
  /// **'Data & Storage'**
  String get dataAndStorage;

  /// No description provided for @downloadedContent.
  ///
  /// In en, this message translates to:
  /// **'Downloaded Content'**
  String get downloadedContent;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCache;

  /// No description provided for @clearCacheDesc.
  ///
  /// In en, this message translates to:
  /// **'Free up space'**
  String get clearCacheDesc;

  /// No description provided for @aboutApp.
  ///
  /// In en, this message translates to:
  /// **'About App'**
  String get aboutApp;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @clearCacheConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache?'**
  String get clearCacheConfirmation;

  /// No description provided for @clearCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete all downloaded content. You can download it again when online.'**
  String get clearCacheMessage;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @adminErrForbidden.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission for this action.'**
  String get adminErrForbidden;

  /// No description provided for @adminErrValidation.
  ///
  /// In en, this message translates to:
  /// **'Validation failed: {message}'**
  String adminErrValidation(String message);

  /// No description provided for @adminErrFunctionMissing.
  ///
  /// In en, this message translates to:
  /// **'The server function is not deployed yet.'**
  String get adminErrFunctionMissing;

  /// No description provided for @adminErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Check the network and try again.'**
  String get adminErrNetwork;

  /// No description provided for @adminErrQuota.
  ///
  /// In en, this message translates to:
  /// **'Limit reached. Try again later.'**
  String get adminErrQuota;

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

  /// No description provided for @adminErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get adminErrNotFound;

  /// No description provided for @adminErrUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get adminErrUnknown;

  /// No description provided for @adminErrTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load'**
  String get adminErrTitle;

  /// No description provided for @adminErrFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File is too large (max {mb} MB).'**
  String adminErrFileTooLarge(int mb);

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

  /// No description provided for @adminLoginErrTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get adminLoginErrTooMany;

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

  /// No description provided for @adminExamErrApproveNoKey.
  ///
  /// In en, this message translates to:
  /// **'Cannot approve: the question has no answer key.'**
  String get adminExamErrApproveNoKey;

  /// No description provided for @adminVariantsErrPublished.
  ///
  /// In en, this message translates to:
  /// **'The variant is published. Unpublish it before editing.'**
  String get adminVariantsErrPublished;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminForbiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get adminForbiddenTitle;

  /// No description provided for @adminForbiddenBody.
  ///
  /// In en, this message translates to:
  /// **'Your role does not allow opening this section.'**
  String get adminForbiddenBody;

  /// No description provided for @adminListEnd.
  ///
  /// In en, this message translates to:
  /// **'Shown: {count}'**
  String adminListEnd(int count);

  /// No description provided for @adminLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get adminLoadMore;

  /// No description provided for @adminReviewDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminReviewDraft;

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

  /// No description provided for @adminReviewRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adminReviewRejected;

  /// No description provided for @adminLangRu.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get adminLangRu;

  /// No description provided for @adminLangKy.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get adminLangKy;

  /// No description provided for @adminLangEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get adminLangEn;

  /// No description provided for @adminNavDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get adminNavDashboard;

  /// No description provided for @adminNavSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects & topics'**
  String get adminNavSubjects;

  /// No description provided for @adminNavLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get adminNavLessons;

  /// No description provided for @adminNavPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice questions'**
  String get adminNavPractice;

  /// No description provided for @adminNavExamBank.
  ///
  /// In en, this message translates to:
  /// **'Exam bank'**
  String get adminNavExamBank;

  /// No description provided for @adminNavVariants.
  ///
  /// In en, this message translates to:
  /// **'Exam variants'**
  String get adminNavVariants;

  /// No description provided for @adminNavAiDrafts.
  ///
  /// In en, this message translates to:
  /// **'AI drafts'**
  String get adminNavAiDrafts;

  /// No description provided for @adminNavUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminNavUsers;

  /// No description provided for @adminNavPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get adminNavPayments;

  /// No description provided for @adminNavPricing.
  ///
  /// In en, this message translates to:
  /// **'Pricing'**
  String get adminNavPricing;

  /// No description provided for @adminNavLogs.
  ///
  /// In en, this message translates to:
  /// **'Admin log'**
  String get adminNavLogs;

  /// No description provided for @adminRoleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super admin'**
  String get adminRoleSuperAdmin;

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

  /// No description provided for @adminRoleSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get adminRoleSupport;

  /// No description provided for @adminSessionExpiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin session ended'**
  String get adminSessionExpiredTitle;

  /// No description provided for @adminSessionExpiredBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get adminSessionExpiredBody;

  /// No description provided for @adminSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get adminSignInAgain;

  /// No description provided for @adminAppTitle.
  ///
  /// In en, this message translates to:
  /// **'ORT Master · CMS'**
  String get adminAppTitle;

  /// No description provided for @adminAccountMenu.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminAccountMenu;

  /// No description provided for @adminLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get adminLogout;

  /// No description provided for @adminLoginErrNotAdmin.
  ///
  /// In en, this message translates to:
  /// **'This account has no admin role.'**
  String get adminLoginErrNotAdmin;

  /// No description provided for @adminLoginResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get adminLoginResetTitle;

  /// No description provided for @adminLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminLoginEmail;

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

  /// No description provided for @adminLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminLoginTitle;

  /// No description provided for @adminLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For ORT Master staff only.'**
  String get adminLoginSubtitle;

  /// No description provided for @adminLoginBackToApp.
  ///
  /// In en, this message translates to:
  /// **'Back to the app'**
  String get adminLoginBackToApp;

  /// No description provided for @adminLoginSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String adminLoginSignedInAs(String email);

  /// No description provided for @adminLoginContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get adminLoginContinue;

  /// No description provided for @adminLoginOtherAccount.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get adminLoginOtherAccount;

  /// No description provided for @adminLoginEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get adminLoginEmailInvalid;

  /// No description provided for @adminLoginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get adminLoginPassword;

  /// No description provided for @adminLoginShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get adminLoginShowPassword;

  /// No description provided for @adminLoginHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get adminLoginHidePassword;

  /// No description provided for @adminLoginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the password'**
  String get adminLoginPasswordRequired;

  /// No description provided for @adminLoginForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get adminLoginForgot;

  /// No description provided for @adminLoginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get adminLoginSubmit;

  /// No description provided for @adminDashboardWelcome.
  ///
  /// In en, this message translates to:
  /// **'Signed in as: {role}'**
  String adminDashboardWelcome(String role);

  /// No description provided for @adminDashboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get adminDashboardShortcuts;

  /// No description provided for @adminDashboardReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review queue'**
  String get adminDashboardReviewTitle;

  /// No description provided for @adminDashboardReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Open the exam bank with the status filter \"Draft\" or \"AI-checked\" to review questions. Only approved questions with an answer key can go into a published variant.'**
  String get adminDashboardReviewBody;

  /// No description provided for @adminStatUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminStatUsers;

  /// No description provided for @adminStatSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get adminStatSubjects;

  /// No description provided for @adminStatLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get adminStatLessons;

  /// No description provided for @adminStatPractice.
  ///
  /// In en, this message translates to:
  /// **'Practice questions'**
  String get adminStatPractice;

  /// No description provided for @adminStatExam.
  ///
  /// In en, this message translates to:
  /// **'Exam questions'**
  String get adminStatExam;

  /// No description provided for @adminStatPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Awaiting review'**
  String get adminStatPendingReview;

  /// No description provided for @adminStatApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminStatApproved;

  /// No description provided for @adminStatVariants.
  ///
  /// In en, this message translates to:
  /// **'Published variants'**
  String get adminStatVariants;

  /// No description provided for @adminStatPurchases.
  ///
  /// In en, this message translates to:
  /// **'Granted purchases'**
  String get adminStatPurchases;

  /// No description provided for @adminDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminDelete;

  /// No description provided for @adminDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get adminDeleted;

  /// No description provided for @adminActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminActive;

  /// No description provided for @adminInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get adminInactive;

  /// No description provided for @adminMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get adminMore;

  /// No description provided for @adminEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminEdit;

  /// No description provided for @adminDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get adminDeactivate;

  /// No description provided for @adminActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get adminActivate;

  /// No description provided for @adminDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get adminDeletePermanently;

  /// No description provided for @adminTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title in Russian or Kyrgyz.'**
  String get adminTitleRequired;

  /// No description provided for @adminFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminFieldTitle;

  /// No description provided for @adminFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get adminFieldDescription;

  /// No description provided for @adminFieldOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get adminFieldOrder;

  /// No description provided for @adminRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminRemove;

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

  /// No description provided for @adminUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get adminUploaded;

  /// No description provided for @adminFieldSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get adminFieldSubject;

  /// No description provided for @adminFieldTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get adminFieldTopic;

  /// No description provided for @adminNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get adminNone;

  /// No description provided for @adminPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminPublished;

  /// No description provided for @adminHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get adminHidden;

  /// No description provided for @adminMissingTranslation.
  ///
  /// In en, this message translates to:
  /// **'No {lang}'**
  String adminMissingTranslation(String lang);

  /// No description provided for @adminListNoItems.
  ///
  /// In en, this message translates to:
  /// **'Nothing added yet.'**
  String get adminListNoItems;

  /// No description provided for @adminMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get adminMoveUp;

  /// No description provided for @adminMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get adminMoveDown;

  /// No description provided for @adminAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminAll;

  /// No description provided for @adminFieldDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get adminFieldDifficulty;

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

  /// No description provided for @adminFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminFieldType;

  /// No description provided for @adminFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminFieldStatus;

  /// No description provided for @adminFieldSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get adminFieldSection;

  /// No description provided for @adminFieldPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get adminFieldPoints;

  /// No description provided for @adminFieldStem.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get adminFieldStem;

  /// No description provided for @adminFieldOptions.
  ///
  /// In en, this message translates to:
  /// **'Answer options'**
  String get adminFieldOptions;

  /// No description provided for @adminAddOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get adminAddOption;

  /// No description provided for @adminCorrectSingleHelp.
  ///
  /// In en, this message translates to:
  /// **'Mark the one correct option.'**
  String get adminCorrectSingleHelp;

  /// No description provided for @adminCorrectMultiHelp.
  ///
  /// In en, this message translates to:
  /// **'Mark all correct options.'**
  String get adminCorrectMultiHelp;

  /// No description provided for @adminMarkCorrect.
  ///
  /// In en, this message translates to:
  /// **'Mark as correct'**
  String get adminMarkCorrect;

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

  /// No description provided for @adminFieldImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get adminFieldImageUrl;

  /// No description provided for @adminQuestionMeta.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get adminQuestionMeta;

  /// No description provided for @adminQuestionExtra.
  ///
  /// In en, this message translates to:
  /// **'Extra'**
  String get adminQuestionExtra;

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

  /// No description provided for @adminSubjectsNew.
  ///
  /// In en, this message translates to:
  /// **'New subject'**
  String get adminSubjectsNew;

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

  /// No description provided for @adminSubjectsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete subject?'**
  String get adminSubjectsDeleteTitle;

  /// No description provided for @adminSubjectsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The subject {id} will be deleted only if no lessons or questions use it. Otherwise deactivate it.'**
  String adminSubjectsDeleteBody(String id);

  /// No description provided for @adminSubjectsTopicsCount.
  ///
  /// In en, this message translates to:
  /// **'topics: {count}'**
  String adminSubjectsTopicsCount(int count);

  /// No description provided for @adminSubjectsTopicDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate topic id: {id}'**
  String adminSubjectsTopicDuplicate(String id);

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

  /// No description provided for @adminSubjectsIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon name'**
  String get adminSubjectsIcon;

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

  /// No description provided for @adminSubjectsActiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Inactive subjects stay in the database (soft delete).'**
  String get adminSubjectsActiveHelp;

  /// No description provided for @adminSubjectsTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get adminSubjectsTopics;

  /// No description provided for @adminSubjectsAddTopic.
  ///
  /// In en, this message translates to:
  /// **'Add topic'**
  String get adminSubjectsAddTopic;

  /// No description provided for @adminSubjectsTopicsHelp.
  ///
  /// In en, this message translates to:
  /// **'Topic ids become subject.topic (e.g. math.quadratic_equations) and are used by exam questions.'**
  String get adminSubjectsTopicsHelp;

  /// No description provided for @adminSubjectsTopicN.
  ///
  /// In en, this message translates to:
  /// **'Topic {n}'**
  String adminSubjectsTopicN(int n);

  /// No description provided for @adminSubjectsTopicId.
  ///
  /// In en, this message translates to:
  /// **'Topic id'**
  String get adminSubjectsTopicId;

  /// No description provided for @adminLessonsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete lesson?'**
  String get adminLessonsDeleteTitle;

  /// No description provided for @adminLessonsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Students will no longer see this lesson. To hide it temporarily, turn off \"Published\" instead.'**
  String get adminLessonsDeleteBody;

  /// No description provided for @adminLessonsNew.
  ///
  /// In en, this message translates to:
  /// **'New lesson'**
  String get adminLessonsNew;

  /// No description provided for @adminLessonsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit lesson'**
  String get adminLessonsEdit;

  /// No description provided for @adminLessonsNoSubjects.
  ///
  /// In en, this message translates to:
  /// **'Create a subject first.'**
  String get adminLessonsNoSubjects;

  /// No description provided for @adminLessonsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No lessons for this subject.'**
  String get adminLessonsEmpty;

  /// No description provided for @adminLessonsMeta.
  ///
  /// In en, this message translates to:
  /// **'#{order} · {minutes} min'**
  String adminLessonsMeta(int order, int minutes);

  /// No description provided for @adminLessonsLegacy.
  ///
  /// In en, this message translates to:
  /// **'Old format'**
  String get adminLessonsLegacy;

  /// No description provided for @adminLessonIssueSubject.
  ///
  /// In en, this message translates to:
  /// **'Choose a subject.'**
  String get adminLessonIssueSubject;

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

  /// No description provided for @adminLessonIssueUrl.
  ///
  /// In en, this message translates to:
  /// **'Video/PDF must be an http(s) link or an uploaded file.'**
  String get adminLessonIssueUrl;

  /// No description provided for @adminLessonBasics.
  ///
  /// In en, this message translates to:
  /// **'Basics'**
  String get adminLessonBasics;

  /// No description provided for @adminLessonMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get adminLessonMinutes;

  /// No description provided for @adminLessonPublishedHelp.
  ///
  /// In en, this message translates to:
  /// **'Unpublished lessons are hidden from students.'**
  String get adminLessonPublishedHelp;

  /// No description provided for @adminLessonTitleSummary.
  ///
  /// In en, this message translates to:
  /// **'Title and summary'**
  String get adminLessonTitleSummary;

  /// No description provided for @adminLessonSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get adminLessonSummary;

  /// No description provided for @adminLessonSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get adminLessonSections;

  /// No description provided for @adminLessonAddSection.
  ///
  /// In en, this message translates to:
  /// **'Add section'**
  String get adminLessonAddSection;

  /// No description provided for @adminLessonSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Section title'**
  String get adminLessonSectionTitle;

  /// No description provided for @adminLessonSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Text (Markdown, LaTeX in \$…\$)'**
  String get adminLessonSectionBody;

  /// No description provided for @adminLessonFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get adminLessonFormulas;

  /// No description provided for @adminLessonAddFormula.
  ///
  /// In en, this message translates to:
  /// **'Add formula'**
  String get adminLessonAddFormula;

  /// No description provided for @adminLessonLatex.
  ///
  /// In en, this message translates to:
  /// **'LaTeX'**
  String get adminLessonLatex;

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

  /// No description provided for @adminLessonAddExample.
  ///
  /// In en, this message translates to:
  /// **'Add example'**
  String get adminLessonAddExample;

  /// No description provided for @adminLessonProblem.
  ///
  /// In en, this message translates to:
  /// **'Problem'**
  String get adminLessonProblem;

  /// No description provided for @adminLessonSolution.
  ///
  /// In en, this message translates to:
  /// **'Solution'**
  String get adminLessonSolution;

  /// No description provided for @adminLessonMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes'**
  String get adminLessonMistakes;

  /// No description provided for @adminLessonAddMistake.
  ///
  /// In en, this message translates to:
  /// **'Add mistake'**
  String get adminLessonAddMistake;

  /// No description provided for @adminLessonMistake.
  ///
  /// In en, this message translates to:
  /// **'Mistake'**
  String get adminLessonMistake;

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

  /// No description provided for @adminLessonVideoUrl.
  ///
  /// In en, this message translates to:
  /// **'Video URL'**
  String get adminLessonVideoUrl;

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

  /// No description provided for @adminLessonImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get adminLessonImages;

  /// No description provided for @adminLessonNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images.'**
  String get adminLessonNoImages;

  /// No description provided for @adminPracticeIssueSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject is required.'**
  String get adminPracticeIssueSubject;

  /// No description provided for @adminIssueStem.
  ///
  /// In en, this message translates to:
  /// **'Question text is required.'**
  String get adminIssueStem;

  /// No description provided for @adminPracticeIssueOptionsMin.
  ///
  /// In en, this message translates to:
  /// **'At least two options are required.'**
  String get adminPracticeIssueOptionsMin;

  /// No description provided for @adminIssueOptionEmpty.
  ///
  /// In en, this message translates to:
  /// **'Every option needs text.'**
  String get adminIssueOptionEmpty;

  /// No description provided for @adminIssueCorrectRequired.
  ///
  /// In en, this message translates to:
  /// **'Mark the correct answer.'**
  String get adminIssueCorrectRequired;

  /// No description provided for @adminIssueCorrectNotInOptions.
  ///
  /// In en, this message translates to:
  /// **'The correct answer is not among the options.'**
  String get adminIssueCorrectNotInOptions;

  /// No description provided for @adminIssueDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty must be 1–3.'**
  String get adminIssueDifficulty;

  /// No description provided for @adminPracticeIssueType.
  ///
  /// In en, this message translates to:
  /// **'Unknown type'**
  String get adminPracticeIssueType;

  /// No description provided for @adminImportParseError.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read.'**
  String get adminImportParseError;

  /// No description provided for @adminImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file has no data rows.'**
  String get adminImportEmpty;

  /// No description provided for @adminImportDuplicateId.
  ///
  /// In en, this message translates to:
  /// **'Duplicate id in the file.'**
  String get adminImportDuplicateId;

  /// No description provided for @adminTypeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single choice'**
  String get adminTypeSingle;

  /// No description provided for @adminTypeMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get adminTypeMultiple;

  /// No description provided for @adminTypeAnalogy.
  ///
  /// In en, this message translates to:
  /// **'Analogy'**
  String get adminTypeAnalogy;

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

  /// No description provided for @adminTypeOrdering.
  ///
  /// In en, this message translates to:
  /// **'Ordering'**
  String get adminTypeOrdering;

  /// No description provided for @adminTypeTrueFalse.
  ///
  /// In en, this message translates to:
  /// **'True / false'**
  String get adminTypeTrueFalse;

  /// No description provided for @adminTypeTextBased.
  ///
  /// In en, this message translates to:
  /// **'Reading (text-based)'**
  String get adminTypeTextBased;

  /// No description provided for @adminTypeComparison.
  ///
  /// In en, this message translates to:
  /// **'Quantitative comparison'**
  String get adminTypeComparison;

  /// No description provided for @adminPracticeNew.
  ///
  /// In en, this message translates to:
  /// **'New question'**
  String get adminPracticeNew;

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

  /// No description provided for @adminPracticeDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete question?'**
  String get adminPracticeDeleteTitle;

  /// No description provided for @adminPracticeDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The question will be removed from practice. To hide it, make it inactive instead.'**
  String get adminPracticeDeleteBody;

  /// No description provided for @adminImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get adminImport;

  /// No description provided for @adminExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get adminExport;

  /// No description provided for @adminImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import questions (CSV or JSON)'**
  String get adminImportTitle;

  /// No description provided for @adminImportHelp.
  ///
  /// In en, this message translates to:
  /// **'Rows are validated before writing; valid rows are written in batches of {batch}. CSV columns (separator , ; or tab):'**
  String adminImportHelp(int batch);

  /// No description provided for @adminImportPick.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get adminImportPick;

  /// No description provided for @adminImportSummary.
  ///
  /// In en, this message translates to:
  /// **'Rows: {total} · valid: {valid} · with errors: {invalid}'**
  String adminImportSummary(int total, int valid, int invalid);

  /// No description provided for @adminImportRowIssue.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: {issue}'**
  String adminImportRowIssue(int row, String issue);

  /// No description provided for @adminImportProgress.
  ///
  /// In en, this message translates to:
  /// **'Written {done} of {total}'**
  String adminImportProgress(int done, int total);

  /// No description provided for @adminImportFailedAfter.
  ///
  /// In en, this message translates to:
  /// **'Stopped after {done} rows: {error}'**
  String adminImportFailedAfter(int done, String error);

  /// No description provided for @adminImportRun.
  ///
  /// In en, this message translates to:
  /// **'Import {count}'**
  String adminImportRun(int count);

  /// No description provided for @adminExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export questions'**
  String get adminExportTitle;

  /// No description provided for @adminExportHelp.
  ///
  /// In en, this message translates to:
  /// **'Exports the questions matching the current filter (up to 5000). Dates are written as ISO strings.'**
  String get adminExportHelp;

  /// No description provided for @adminExportCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get adminExportCopy;

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

  /// No description provided for @adminExportCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get adminExportCopied;

  /// No description provided for @adminExamNew.
  ///
  /// In en, this message translates to:
  /// **'New exam question'**
  String get adminExamNew;

  /// No description provided for @adminExamEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit exam question'**
  String get adminExamEdit;

  /// No description provided for @adminApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get adminApply;

  /// No description provided for @adminFieldLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get adminFieldLanguage;

  /// No description provided for @adminFieldReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get adminFieldReview;

  /// No description provided for @adminExamEmpty.
  ///
  /// In en, this message translates to:
  /// **'No exam questions match the filter.'**
  String get adminExamEmpty;

  /// No description provided for @adminExamHasTranslation.
  ///
  /// In en, this message translates to:
  /// **'Has translation'**
  String get adminExamHasTranslation;

  /// No description provided for @adminExamSourceAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get adminExamSourceAi;

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

  /// No description provided for @adminExamIssueLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose the language (ru, ky or en).'**
  String get adminExamIssueLanguage;

  /// No description provided for @adminExamIssueOptionsCount.
  ///
  /// In en, this message translates to:
  /// **'The blueprint requires {n} options.'**
  String adminExamIssueOptionsCount(int n);

  /// No description provided for @adminExamIssueOptionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Option ids must be unique.'**
  String get adminExamIssueOptionDuplicate;

  /// No description provided for @adminExamIssuePassage.
  ///
  /// In en, this message translates to:
  /// **'This part needs a linked text (passage).'**
  String get adminExamIssuePassage;

  /// No description provided for @adminExamSavedBackToDraft.
  ///
  /// In en, this message translates to:
  /// **'Saved. The content changed, so the question went back to \"Draft\" for review.'**
  String get adminExamSavedBackToDraft;

  /// No description provided for @adminExamReviewDone.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String adminExamReviewDone(String status);

  /// No description provided for @adminExamLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Link existing translation'**
  String get adminExamLinkTitle;

  /// No description provided for @adminExamQuestionId.
  ///
  /// In en, this message translates to:
  /// **'Question id'**
  String get adminExamQuestionId;

  /// No description provided for @adminExamLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get adminExamLink;

  /// No description provided for @adminExamLinked.
  ///
  /// In en, this message translates to:
  /// **'Translations linked'**
  String get adminExamLinked;

  /// No description provided for @adminExamNewPassage.
  ///
  /// In en, this message translates to:
  /// **'New text'**
  String get adminExamNewPassage;

  /// No description provided for @adminExamPassageText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get adminExamPassageText;

  /// No description provided for @adminExamPassageEmpty.
  ///
  /// In en, this message translates to:
  /// **'The text is empty.'**
  String get adminExamPassageEmpty;

  /// No description provided for @adminExamSourceBasis.
  ///
  /// In en, this message translates to:
  /// **'Source / basis'**
  String get adminExamSourceBasis;

  /// No description provided for @adminUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get adminUnsavedTitle;

  /// No description provided for @adminUnsavedBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes.'**
  String get adminUnsavedBody;

  /// No description provided for @adminDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get adminDiscard;

  /// No description provided for @adminExamPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get adminExamPlacement;

  /// No description provided for @adminFieldBlueprint.
  ///
  /// In en, this message translates to:
  /// **'Test structure'**
  String get adminFieldBlueprint;

  /// No description provided for @adminFieldPart.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get adminFieldPart;

  /// No description provided for @adminExamNoBlueprint.
  ///
  /// In en, this message translates to:
  /// **'No blueprint section matches {subject}/{section}. Choose the structure again.'**
  String adminExamNoBlueprint(String subject, String section);

  /// No description provided for @adminExamPartUnverified.
  ///
  /// In en, this message translates to:
  /// **'This split into parts is an assumption (not officially published).'**
  String get adminExamPartUnverified;

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

  /// No description provided for @adminFieldSubtopicId.
  ///
  /// In en, this message translates to:
  /// **'Subtopic id (optional)'**
  String get adminFieldSubtopicId;

  /// No description provided for @adminExamStemLabel.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get adminExamStemLabel;

  /// No description provided for @adminMathHelp.
  ///
  /// In en, this message translates to:
  /// **'Markdown; formulas in \$…\$ or \$\$…\$\$'**
  String get adminMathHelp;

  /// No description provided for @adminExamPassage.
  ///
  /// In en, this message translates to:
  /// **'Linked text'**
  String get adminExamPassage;

  /// No description provided for @adminExamImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get adminExamImage;

  /// No description provided for @adminExamNoImage.
  ///
  /// In en, this message translates to:
  /// **'No image.'**
  String get adminExamNoImage;

  /// No description provided for @adminExamFixedOptions.
  ///
  /// In en, this message translates to:
  /// **'This part uses fixed answer options. Mark the correct one.'**
  String get adminExamFixedOptions;

  /// No description provided for @adminExamChoosePlacement.
  ///
  /// In en, this message translates to:
  /// **'Choose the test structure and section first.'**
  String get adminExamChoosePlacement;

  /// No description provided for @adminExamKey.
  ///
  /// In en, this message translates to:
  /// **'Answer key (never shown to students before the end)'**
  String get adminExamKey;

  /// No description provided for @adminExamCorrectIs.
  ///
  /// In en, this message translates to:
  /// **'Correct option: {id}'**
  String adminExamCorrectIs(String id);

  /// No description provided for @adminExamWrongNote.
  ///
  /// In en, this message translates to:
  /// **'Why {id} is wrong'**
  String adminExamWrongNote(String id);

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

  /// No description provided for @adminExamSourceAdapted.
  ///
  /// In en, this message translates to:
  /// **'Adapted / translated'**
  String get adminExamSourceAdapted;

  /// No description provided for @adminExamSourceAuthor.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get adminExamSourceAuthor;

  /// No description provided for @adminExamTranslations.
  ///
  /// In en, this message translates to:
  /// **'Translations'**
  String get adminExamTranslations;

  /// No description provided for @adminExamNoGroup.
  ///
  /// In en, this message translates to:
  /// **'Not linked to a translation yet.'**
  String get adminExamNoGroup;

  /// No description provided for @adminExamGroup.
  ///
  /// In en, this message translates to:
  /// **'Translation group: {id}'**
  String adminExamGroup(String id);

  /// No description provided for @adminExamCreateTranslation.
  ///
  /// In en, this message translates to:
  /// **'Create in {lang}'**
  String adminExamCreateTranslation(String lang);

  /// No description provided for @adminExamApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminExamApprove;

  /// No description provided for @adminExamReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminExamReject;

  /// No description provided for @adminExamBackToDraft.
  ///
  /// In en, this message translates to:
  /// **'Back to draft'**
  String get adminExamBackToDraft;

  /// No description provided for @adminExamMarkAiVerified.
  ///
  /// In en, this message translates to:
  /// **'Mark as AI-checked'**
  String get adminExamMarkAiVerified;

  /// No description provided for @adminExamReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get adminExamReview;

  /// No description provided for @adminExamReviewedBy.
  ///
  /// In en, this message translates to:
  /// **'{uid} · {date}'**
  String adminExamReviewedBy(String uid, String date);

  /// No description provided for @adminExamReviewNotes.
  ///
  /// In en, this message translates to:
  /// **'Reviewer notes'**
  String get adminExamReviewNotes;

  /// No description provided for @adminExamReviewNoRights.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot change the review status.'**
  String get adminExamReviewNoRights;

  /// No description provided for @adminExamSaveBeforeReview.
  ///
  /// In en, this message translates to:
  /// **'Save your changes before changing the status.'**
  String get adminExamSaveBeforeReview;

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

  /// No description provided for @adminVariantPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminVariantPublished;

  /// No description provided for @adminVariantArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get adminVariantArchived;

  /// No description provided for @adminVariantsNew.
  ///
  /// In en, this message translates to:
  /// **'New variant'**
  String get adminVariantsNew;

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

  /// No description provided for @adminVariantN.
  ///
  /// In en, this message translates to:
  /// **'Variant {n}'**
  String adminVariantN(int n);

  /// No description provided for @adminVariantsMeta.
  ///
  /// In en, this message translates to:
  /// **'{blueprint} · {count}/{expected} questions'**
  String adminVariantsMeta(String blueprint, int count, int expected);

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

  /// No description provided for @adminVpSectionMissing.
  ///
  /// In en, this message translates to:
  /// **'Section {section} is empty.'**
  String adminVpSectionMissing(String section);

  /// No description provided for @adminVpSectionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Section {section} is not in the blueprint.'**
  String adminVpSectionUnknown(String section);

  /// No description provided for @adminVpSectionOrder.
  ///
  /// In en, this message translates to:
  /// **'Sections are not in blueprint order.'**
  String get adminVpSectionOrder;

  /// No description provided for @adminVpSectionCount.
  ///
  /// In en, this message translates to:
  /// **'{section}: {actual} questions, needs {expected}.'**
  String adminVpSectionCount(String section, int expected, int actual);

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

  /// No description provided for @adminVpQuestionMissing.
  ///
  /// In en, this message translates to:
  /// **'{id}: question not found.'**
  String adminVpQuestionMissing(String id);

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

  /// No description provided for @adminVpQuestionSection.
  ///
  /// In en, this message translates to:
  /// **'{id}: belongs to another section than {section}.'**
  String adminVpQuestionSection(String id, String section);

  /// No description provided for @adminVpQuestionPart.
  ///
  /// In en, this message translates to:
  /// **'{id}: its part is not in this section.'**
  String adminVpQuestionPart(String id);

  /// No description provided for @adminVpQuestionNotApproved.
  ///
  /// In en, this message translates to:
  /// **'{id}: not approved by a methodologist.'**
  String adminVpQuestionNotApproved(String id);

  /// No description provided for @adminVpQuestionNoKey.
  ///
  /// In en, this message translates to:
  /// **'{id}: no answer key.'**
  String adminVpQuestionNoKey(String id);

  /// No description provided for @adminVpQuestionOptions.
  ///
  /// In en, this message translates to:
  /// **'{id}: {actual} options, needs {expected}.'**
  String adminVpQuestionOptions(String id, int expected, int actual);

  /// No description provided for @adminVpQuestionPassage.
  ///
  /// In en, this message translates to:
  /// **'{id}: needs a linked text.'**
  String adminVpQuestionPassage(String id);

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

  /// No description provided for @adminAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get adminAdd;

  /// No description provided for @adminVariantAutoFilled.
  ///
  /// In en, this message translates to:
  /// **'Added {n} approved questions'**
  String adminVariantAutoFilled(int n);

  /// No description provided for @adminVariantChooseBlueprint.
  ///
  /// In en, this message translates to:
  /// **'Choose the test structure.'**
  String get adminVariantChooseBlueprint;

  /// No description provided for @adminVariantNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Variant number must be 1–1000.'**
  String get adminVariantNumberInvalid;

  /// No description provided for @adminVariantPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish variant?'**
  String get adminVariantPublishTitle;

  /// No description provided for @adminVariantUnpublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Unpublish variant?'**
  String get adminVariantUnpublishTitle;

  /// No description provided for @adminVariantPublishBody.
  ///
  /// In en, this message translates to:
  /// **'The server checks the variant again. Students will be able to start it right after publishing.'**
  String get adminVariantPublishBody;

  /// No description provided for @adminVariantUnpublishBody.
  ///
  /// In en, this message translates to:
  /// **'New attempts will not be possible. Attempts already started can still be finished.'**
  String get adminVariantUnpublishBody;

  /// No description provided for @adminVariantPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get adminVariantPublish;

  /// No description provided for @adminVariantUnpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get adminVariantUnpublish;

  /// No description provided for @adminVariantServerResult.
  ///
  /// In en, this message translates to:
  /// **'Server: {status}'**
  String adminVariantServerResult(String status);

  /// No description provided for @adminVariantNoProblems.
  ///
  /// In en, this message translates to:
  /// **'No problems reported.'**
  String get adminVariantNoProblems;

  /// No description provided for @adminClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminClose;

  /// No description provided for @adminVariantBasics.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get adminVariantBasics;

  /// No description provided for @adminVariantNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get adminVariantNumber;

  /// No description provided for @adminVariantDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get adminVariantDifficulty;

  /// No description provided for @adminVariantStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get adminVariantStandard;

  /// No description provided for @adminVariantAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get adminVariantAdvanced;

  /// No description provided for @adminVariantBlueprintLocked.
  ///
  /// In en, this message translates to:
  /// **'Remove all questions to change the structure.'**
  String get adminVariantBlueprintLocked;

  /// No description provided for @adminVariantAutoFill.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill approved'**
  String get adminVariantAutoFill;

  /// No description provided for @adminVariantClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adminVariantClear;

  /// No description provided for @adminVariantUnknownQuestion.
  ///
  /// In en, this message translates to:
  /// **'not found'**
  String get adminVariantUnknownQuestion;

  /// No description provided for @adminVariantNoKey.
  ///
  /// In en, this message translates to:
  /// **'no key'**
  String get adminVariantNoKey;

  /// No description provided for @adminVariantCheck.
  ///
  /// In en, this message translates to:
  /// **'Check against the structure'**
  String get adminVariantCheck;

  /// No description provided for @adminVariantRecheck.
  ///
  /// In en, this message translates to:
  /// **'Re-check'**
  String get adminVariantRecheck;

  /// No description provided for @adminVariantReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to publish (the server checks again).'**
  String get adminVariantReady;

  /// No description provided for @adminVariantBlocked.
  ///
  /// In en, this message translates to:
  /// **'Publishing is blocked: {n} problems.'**
  String adminVariantBlocked(int n);

  /// No description provided for @adminAiFillForm.
  ///
  /// In en, this message translates to:
  /// **'Choose structure, section, part and topic.'**
  String get adminAiFillForm;

  /// No description provided for @adminAiSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved {n} drafts for review'**
  String adminAiSaved(int n);

  /// No description provided for @adminAiNotice.
  ///
  /// In en, this message translates to:
  /// **'Drafts are generated on the server; no API key is stored in the app. Every draft is saved with the status \"Draft\" and must be approved by a methodologist before it can be used in a variant.'**
  String get adminAiNotice;

  /// No description provided for @adminAiRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get adminAiRequest;

  /// No description provided for @adminAiCount.
  ///
  /// In en, this message translates to:
  /// **'Count'**
  String get adminAiCount;

  /// No description provided for @adminAiGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get adminAiGenerating;

  /// No description provided for @adminAiGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate drafts'**
  String get adminAiGenerate;

  /// No description provided for @adminAiDrafts.
  ///
  /// In en, this message translates to:
  /// **'Drafts: {n}'**
  String adminAiDrafts(int n);

  /// No description provided for @adminAiSaveSelected.
  ///
  /// In en, this message translates to:
  /// **'Save {n}'**
  String adminAiSaveSelected(int n);

  /// No description provided for @adminAiOpenBank.
  ///
  /// In en, this message translates to:
  /// **'Open the exam bank'**
  String get adminAiOpenBank;

  /// No description provided for @adminAiEmpty.
  ///
  /// In en, this message translates to:
  /// **'Fill in the request and generate drafts.'**
  String get adminAiEmpty;

  /// No description provided for @adminAiDraftMeta.
  ///
  /// In en, this message translates to:
  /// **'{topic} · difficulty {difficulty}'**
  String adminAiDraftMeta(String topic, int difficulty);

  /// No description provided for @adminUsersSearch.
  ///
  /// In en, this message translates to:
  /// **'Search by email (start)'**
  String get adminUsersSearch;

  /// No description provided for @adminUsersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get adminUsersEmpty;

  /// No description provided for @adminUsersBanned.
  ///
  /// In en, this message translates to:
  /// **'Banned'**
  String get adminUsersBanned;

  /// No description provided for @adminUsersPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get adminUsersPremium;

  /// No description provided for @adminUsersLegacyAdmin.
  ///
  /// In en, this message translates to:
  /// **'admin (legacy)'**
  String get adminUsersLegacyAdmin;

  /// No description provided for @adminUserTitle.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get adminUserTitle;

  /// No description provided for @adminUserBanTitle.
  ///
  /// In en, this message translates to:
  /// **'Ban user?'**
  String get adminUserBanTitle;

  /// No description provided for @adminUserUnbanTitle.
  ///
  /// In en, this message translates to:
  /// **'Unban user?'**
  String get adminUserUnbanTitle;

  /// No description provided for @adminUserUnbanBody.
  ///
  /// In en, this message translates to:
  /// **'The ban flag will be removed.'**
  String get adminUserUnbanBody;

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

  /// No description provided for @adminUserBan.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get adminUserBan;

  /// No description provided for @adminUserUnban.
  ///
  /// In en, this message translates to:
  /// **'Unban'**
  String get adminUserUnban;

  /// No description provided for @adminUserPremiumOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant premium?'**
  String get adminUserPremiumOnTitle;

  /// No description provided for @adminUserPremiumOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove premium?'**
  String get adminUserPremiumOffTitle;

  /// No description provided for @adminUserPremiumOnBody.
  ///
  /// In en, this message translates to:
  /// **'Sets the subscription to yearly for 365 days. Exam credits are separate and are granted only with credits.'**
  String get adminUserPremiumOnBody;

  /// No description provided for @adminUserPremiumOffBody.
  ///
  /// In en, this message translates to:
  /// **'The subscription returns to free.'**
  String get adminUserPremiumOffBody;

  /// No description provided for @adminUserPremiumOn.
  ///
  /// In en, this message translates to:
  /// **'Grant premium'**
  String get adminUserPremiumOn;

  /// No description provided for @adminUserPremiumOff.
  ///
  /// In en, this message translates to:
  /// **'Remove premium'**
  String get adminUserPremiumOff;

  /// No description provided for @adminUserRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin role'**
  String get adminUserRoleTitle;

  /// No description provided for @adminUserRoleBody.
  ///
  /// In en, this message translates to:
  /// **'Sets the role claim through the server. The user must sign in again for it to apply.'**
  String get adminUserRoleBody;

  /// No description provided for @adminUserRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminUserRole;

  /// No description provided for @adminUserRoleNone.
  ///
  /// In en, this message translates to:
  /// **'No admin role'**
  String get adminUserRoleNone;

  /// No description provided for @adminUserRoleDone.
  ///
  /// In en, this message translates to:
  /// **'Role updated'**
  String get adminUserRoleDone;

  /// No description provided for @adminUserGrantTitle.
  ///
  /// In en, this message translates to:
  /// **'Grant credits'**
  String get adminUserGrantTitle;

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

  /// No description provided for @adminUserGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get adminUserGrant;

  /// No description provided for @adminUserGrantDone.
  ///
  /// In en, this message translates to:
  /// **'Credits updated'**
  String get adminUserGrantDone;

  /// No description provided for @adminUserCreated.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get adminUserCreated;

  /// No description provided for @adminUserLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active'**
  String get adminUserLastActive;

  /// No description provided for @adminUserLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get adminUserLanguage;

  /// No description provided for @adminUserGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get adminUserGrade;

  /// No description provided for @adminUserSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get adminUserSchool;

  /// No description provided for @adminUserSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get adminUserSubscription;

  /// No description provided for @adminUserActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get adminUserActions;

  /// No description provided for @adminUserEntitlements.
  ///
  /// In en, this message translates to:
  /// **'Exam access'**
  String get adminUserEntitlements;

  /// No description provided for @adminUserNoEntitlements.
  ///
  /// In en, this message translates to:
  /// **'No entitlement record yet (first exam not used).'**
  String get adminUserNoEntitlements;

  /// No description provided for @adminUserCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get adminUserCredits;

  /// No description provided for @adminUserFreeUsed.
  ///
  /// In en, this message translates to:
  /// **'Free exam used'**
  String get adminUserFreeUsed;

  /// No description provided for @adminYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get adminYes;

  /// No description provided for @adminNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get adminNo;

  /// No description provided for @adminUserLifetime.
  ///
  /// In en, this message translates to:
  /// **'Credits purchased'**
  String get adminUserLifetime;

  /// No description provided for @adminUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get adminUpdated;

  /// No description provided for @adminUserLedger.
  ///
  /// In en, this message translates to:
  /// **'Credit history'**
  String get adminUserLedger;

  /// No description provided for @adminUserBalance.
  ///
  /// In en, this message translates to:
  /// **'balance {n}'**
  String adminUserBalance(int n);

  /// No description provided for @adminUserStats.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get adminUserStats;

  /// No description provided for @adminPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminPurchasePending;

  /// No description provided for @adminPurchaseGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get adminPurchaseGranted;

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

  /// No description provided for @adminPurchaseInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid'**
  String get adminPurchaseInvalid;

  /// No description provided for @adminPaymentsReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only. Credits are granted by the server after Google Play verification.'**
  String get adminPaymentsReadOnly;

  /// No description provided for @adminPaymentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases.'**
  String get adminPaymentsEmpty;

  /// No description provided for @adminPaymentsCredits.
  ///
  /// In en, this message translates to:
  /// **'{n} credits'**
  String adminPaymentsCredits(int n);

  /// No description provided for @adminPaymentsRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get adminPaymentsRefund;

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

  /// No description provided for @adminPricingConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Save pricing?'**
  String get adminPricingConfirmTitle;

  /// No description provided for @adminPricingConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Changes apply to new purchases immediately.'**
  String get adminPricingConfirmBody;

  /// No description provided for @adminPricingWarning.
  ///
  /// In en, this message translates to:
  /// **'Prices are set in Google Play Console, not here. This page only maps products to exam credits. Do not change the base price of 100 som (exam_single) without the owner\'s approval.'**
  String get adminPricingWarning;

  /// No description provided for @adminPricingDefaults.
  ///
  /// In en, this message translates to:
  /// **'config/pricing does not exist yet; defaults are shown.'**
  String get adminPricingDefaults;

  /// No description provided for @adminPricingProducts.
  ///
  /// In en, this message translates to:
  /// **'Credits per product'**
  String get adminPricingProducts;

  /// No description provided for @adminPricingCreditsFor.
  ///
  /// In en, this message translates to:
  /// **'{id} — credits'**
  String adminPricingCreditsFor(String id);

  /// No description provided for @adminPricingSingleHelp.
  ///
  /// In en, this message translates to:
  /// **'Fixed: 1 credit = 1 exam'**
  String get adminPricingSingleHelp;

  /// No description provided for @adminPricingFree.
  ///
  /// In en, this message translates to:
  /// **'Free exams'**
  String get adminPricingFree;

  /// No description provided for @adminPricingFreeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free full exams per account'**
  String get adminPricingFreeLabel;

  /// No description provided for @adminPricingFreeHelp.
  ///
  /// In en, this message translates to:
  /// **'Product rule: 1 (the first full exam is free once per account)'**
  String get adminPricingFreeHelp;

  /// No description provided for @adminLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The log is empty.'**
  String get adminLogsEmpty;

  /// No description provided for @adminLogsActor.
  ///
  /// In en, this message translates to:
  /// **'by {uid}'**
  String adminLogsActor(String uid);

  /// No description provided for @adminLogsTarget.
  ///
  /// In en, this message translates to:
  /// **'target {uid}'**
  String adminLogsTarget(String uid);

  /// No description provided for @adminExamIssuePart.
  ///
  /// In en, this message translates to:
  /// **'Choose the part of the section.'**
  String get adminExamIssuePart;

  /// No description provided for @adminSubjectsTopicIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid topic id: {id} (use a–z, 0–9, _ and dots)'**
  String adminSubjectsTopicIdInvalid(String id);
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
