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

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get examTabTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Mock ORT'**
  String get examMockTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get examLoading;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get examRetry;

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
  /// **'This variant is not available right now.'**
  String get examErrorVariantUnavailable;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'This attempt was not found.'**
  String get examErrorAttemptNotFound;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Sign in to take exams.'**
  String get examErrorSignIn;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String examQuestionsCount(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String examMinutesCount(int minutes);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 section} other{{count} sections}}'**
  String examSectionsCount(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Section {index} of {count}'**
  String examSectionLabel(int index, int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get examLangRu;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get examLangKy;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get examLangEn;

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
  /// **'Subject tests'**
  String get examCatalogSubjectsTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'State language'**
  String get examCatalogStateLanguageTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No exams are available yet.'**
  String get examCatalogEmpty;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get examHistoryAction;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Test language'**
  String get examLanguageLabel;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Only in {language}'**
  String examOnlyLanguage(String language);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Your first test is free'**
  String get examEntitlementFree;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Credits: {count}'**
  String examEntitlementCredits(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No credits left'**
  String get examEntitlementNone;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'One credit = one full test. Continuing an unfinished test is free.'**
  String get examEntitlementHint;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get examBuy;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get examVariants;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Variant {number}'**
  String examVariantTitle(int number);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get examVariantNotStarted;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get examVariantInProgress;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Best: {percent}%'**
  String examVariantBest(String percent);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get examVariantAdvanced;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No variants in this language yet. New ones are added regularly.'**
  String get examVariantsEmpty;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get examShowMore;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get examIntroStructure;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get examIntroRules;

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
  /// **'Total'**
  String get examTotal;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The official split between these parts is not published; this is an approximation.'**
  String get examPartAssumption;

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
  /// **'Each section has its own timer. You will be warned 5 minutes and 1 minute before the end; at zero the section is submitted automatically.'**
  String get examRuleTimer;

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
  /// **'If you leave the app, the timer keeps running. Your answers are saved on the device.'**
  String get examRuleKeepsRunning;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Free — this is your first test'**
  String get examCostFree;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'1 credit (you have {credits})'**
  String examCostCredit(int credits);

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
  /// **'Start test'**
  String get examStart;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get examContinue;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Buy a test'**
  String get examBuyToStart;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Preparing your test…'**
  String get examStarting;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Practice result. Not an official ORT score.'**
  String get examDisclaimerFallback;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Time left'**
  String get examTimeLeftLabel;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String examQuestionOf(int current, int total);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Answered {answered} of {total}'**
  String examAnsweredOf(int answered, int total);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Mark for review'**
  String get examFlag;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Remove mark'**
  String get examUnflag;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get examPrevious;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get examNext;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get examPalette;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Clear answer'**
  String get examClearAnswer;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Leave test'**
  String get examExit;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Finish section'**
  String get examFinishSection;

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
  /// **'Marked for review: {count}'**
  String examFinishSectionFlagged(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'After finishing you cannot return to this section.'**
  String get examFinishSectionWarning;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get examFinishSectionConfirm;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Keep working'**
  String get examKeepWorking;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Leave the test?'**
  String get examExitTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The section timer keeps running on the server while you are away. Your answers are saved — you can continue from the home screen.'**
  String get examExitBody;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get examExitStay;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get examExitLeave;

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

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Time is up. The section has been submitted.'**
  String get examAutoSubmitted;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Submitting the section…'**
  String get examSubmitting;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get examOfflineTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved on this device. The next section starts only after the server receives this one.'**
  String get examOfflineBody;

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
  /// **'Answered'**
  String get examPaletteAnswered;

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
  /// **'Current'**
  String get examPaletteCurrent;

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
  /// **'Text'**
  String get examPassage;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Show text'**
  String get examPassageShow;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Hide text'**
  String get examPassageHide;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The image could not be loaded'**
  String get examImageError;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'This section has no questions. Please contact support.'**
  String get examNoQuestions;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Option {letter}'**
  String examOptionSemantics(String letter);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Section submitted'**
  String get examSectionDone;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Next section'**
  String get examNextSectionTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The timer of this section is already running:'**
  String get examNextSectionTimeRunning;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Start section'**
  String get examStartSection;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Test finished. Loading your result…'**
  String get examFinishedLoading;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get examResultTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String examResultScore(int correct, int total);

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
  /// **'Skipped'**
  String get examResultSkipped;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Wrong or skipped'**
  String get examResultWrongOrSkipped;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'By section'**
  String get examResultBySection;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'What to review'**
  String get examResultWeak;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Strong topics'**
  String get examResultStrong;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'No weak topics found — great job!'**
  String get examResultNoWeak;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Review “{topic}”: go back to the theory and solve 10–15 practice questions on it.'**
  String examResultRecommendation(String topic);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total}'**
  String examResultTopicScore(int correct, int total);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'XP earned: {xp}'**
  String examResultXp(int xp);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Some sections were closed late, so this attempt does not count for the leaderboard.'**
  String get examResultNotEligible;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'How the official result works'**
  String get examResultLevelsTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The official result of the state language test is a level from 1 to 4. The level boundaries are not published, so the app shows only your percentage of correct answers and does not guess your level.'**
  String get examResultLevelsBody;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get examResultReview;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'To exams'**
  String get examResultToExams;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'The result is still being calculated. Try again in a few seconds.'**
  String get examResultPending;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Answer review'**
  String get examReviewTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get examReviewFilterAll;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get examReviewFilterWrong;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Marked'**
  String get examReviewFilterFlagged;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String examReviewYourAnswer(String answer);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String examReviewCorrectAnswer(String answer);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'no answer'**
  String get examReviewNoAnswer;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get examReviewExplanation;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Ask the AI tutor'**
  String get examReviewAskTutor;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Nothing here for this filter.'**
  String get examReviewEmpty;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Question {number}'**
  String examReviewQuestionNumber(int number);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Exam history'**
  String get examHistoryTitle;

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
  /// **'Attempts: {count}'**
  String examHistoryAttempts(int count);

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'+{delta}% vs previous'**
  String examHistoryTrendUp(String delta);

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
  /// **'Unfinished test'**
  String get examResumeTitle;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Section time is up'**
  String get examResumeTimeUp;

  /// Exam mode
  ///
  /// In en, this message translates to:
  /// **'Waiting to be submitted'**
  String get examResumeAwaitingSubmit;
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
