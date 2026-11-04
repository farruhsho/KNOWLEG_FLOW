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

  /// No description provided for @shellNavExams.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get shellNavExams;

  /// No description provided for @shellNavProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get shellNavProgress;

  /// No description provided for @shellNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get shellNavProfile;

  /// No description provided for @shellExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit the app?'**
  String get shellExitTitle;

  /// No description provided for @shellExitMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress is saved.'**
  String get shellExitMessage;

  /// No description provided for @shellExitConfirm.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get shellExitConfirm;

  /// No description provided for @shellCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shellCancel;

  /// No description provided for @shellRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get shellRetry;

  /// No description provided for @shellLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get shellLoading;

  /// No description provided for @shellNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get shellNotFoundTitle;

  /// No description provided for @shellNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The link may be outdated. Go back to the home screen.'**
  String get shellNotFoundMessage;

  /// No description provided for @shellGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get shellGoHome;

  /// No description provided for @shellTagline.
  ///
  /// In en, this message translates to:
  /// **'ORT preparation'**
  String get shellTagline;

  /// No description provided for @shellBootErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the app'**
  String get shellBootErrorTitle;

  /// No description provided for @shellBootErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get shellBootErrorMessage;

  /// No description provided for @shellLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get shellLater;

  /// No description provided for @shellNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get shellNotNow;

  /// No description provided for @shellHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get shellHide;

  /// No description provided for @shellSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shellSave;

  /// No description provided for @shellOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get shellOptional;

  /// No description provided for @shellNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get shellNotSet;

  /// No description provided for @shellLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get shellLinkOpenFailed;

  /// No description provided for @shellLangRu.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get shellLangRu;

  /// No description provided for @shellLangKy.
  ///
  /// In en, this message translates to:
  /// **'Kyrgyz'**
  String get shellLangKy;

  /// No description provided for @shellLangEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get shellLangEn;

  /// No description provided for @shellLangRuNative.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get shellLangRuNative;

  /// No description provided for @shellLangKyNative.
  ///
  /// In en, this message translates to:
  /// **'Кыргызча'**
  String get shellLangKyNative;

  /// No description provided for @shellLangEnNative.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get shellLangEnNative;

  /// No description provided for @shellLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get shellLoginTitle;

  /// No description provided for @shellLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue preparing for the ORT.'**
  String get shellLoginSubtitle;

  /// No description provided for @shellLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get shellLoginButton;

  /// No description provided for @shellLoginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get shellLoginNoAccount;

  /// No description provided for @shellLoginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get shellLoginCreateAccount;

  /// No description provided for @shellAuthEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get shellAuthEmailLabel;

  /// No description provided for @shellAuthPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get shellAuthPasswordLabel;

  /// No description provided for @shellAuthConfirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get shellAuthConfirmPasswordLabel;

  /// No description provided for @shellAuthNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get shellAuthNameLabel;

  /// No description provided for @shellAuthPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters, letters and digits'**
  String shellAuthPasswordHint(int min);

  /// No description provided for @shellAuthForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get shellAuthForgotPassword;

  /// No description provided for @shellAuthShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get shellAuthShowPassword;

  /// No description provided for @shellAuthHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get shellAuthHidePassword;

  /// No description provided for @shellAuthOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get shellAuthOr;

  /// No description provided for @shellAuthContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get shellAuthContinueWithGoogle;

  /// No description provided for @shellAuthResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get shellAuthResetTitle;

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

  /// No description provided for @shellAuthEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get shellAuthEmailRequired;

  /// No description provided for @shellAuthEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the email address, e.g. name@example.com'**
  String get shellAuthEmailInvalid;

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

  /// No description provided for @shellAuthPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get shellAuthPasswordMismatch;

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

  /// No description provided for @shellAuthErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get shellAuthErrorInvalidCredentials;

  /// No description provided for @shellAuthErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account with this email. Create one first.'**
  String get shellAuthErrorUserNotFound;

  /// No description provided for @shellAuthErrorUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been blocked. Contact support.'**
  String get shellAuthErrorUserDisabled;

  /// No description provided for @shellAuthErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get shellAuthErrorTooManyRequests;

  /// No description provided for @shellAuthErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Sign in instead.'**
  String get shellAuthErrorEmailInUse;

  /// No description provided for @shellAuthErrorNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is temporarily unavailable.'**
  String get shellAuthErrorNotAllowed;

  /// No description provided for @shellAuthErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check the internet and try again.'**
  String get shellAuthErrorNetwork;

  /// No description provided for @shellAuthErrorGoogleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t available on this device yet. Use email instead.'**
  String get shellAuthErrorGoogleUnavailable;

  /// No description provided for @shellAuthErrorDifferentCredential.
  ///
  /// In en, this message translates to:
  /// **'This email is linked to another sign-in method.'**
  String get shellAuthErrorDifferentCredential;

  /// No description provided for @shellAuthErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get shellAuthErrorUnknown;

  /// No description provided for @shellSignupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get shellSignupTitle;

  /// No description provided for @shellSignupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'It takes a minute. Your progress will be saved in your account.'**
  String get shellSignupSubtitle;

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

  /// No description provided for @shellSignupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created. We\'ve sent a confirmation email.'**
  String get shellSignupSuccess;

  /// No description provided for @shellSignupLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By creating an account you agree to the '**
  String get shellSignupLegalPrefix;

  /// No description provided for @shellSignupLegalAnd.
  ///
  /// In en, this message translates to:
  /// **' and the '**
  String get shellSignupLegalAnd;

  /// No description provided for @shellVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email'**
  String get shellVerifyTitle;

  /// No description provided for @shellVerifyMessage.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}. It helps you recover your account.'**
  String shellVerifyMessage(String email);

  /// No description provided for @shellVerifyResend.
  ///
  /// In en, this message translates to:
  /// **'Send again'**
  String get shellVerifyResend;

  /// No description provided for @shellVerifyCheck.
  ///
  /// In en, this message translates to:
  /// **'I\'ve confirmed'**
  String get shellVerifyCheck;

  /// No description provided for @shellVerifySent.
  ///
  /// In en, this message translates to:
  /// **'Email sent. Check your inbox and spam folder.'**
  String get shellVerifySent;

  /// No description provided for @shellVerifySendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the email. Try again later.'**
  String get shellVerifySendFailed;

  /// No description provided for @shellVerifyDone.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed. Thank you!'**
  String get shellVerifyDone;

  /// No description provided for @shellVerifyNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet. Open the link from the email.'**
  String get shellVerifyNotYet;

  /// No description provided for @shellOnbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get shellOnbSkip;

  /// No description provided for @shellOnbBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get shellOnbBack;

  /// No description provided for @shellOnbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get shellOnbNext;

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

  /// No description provided for @shellOnbLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Which language will you prepare in?'**
  String get shellOnbLanguageTitle;

  /// No description provided for @shellOnbLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The app and mock exams will use this language. You can change it in Settings.'**
  String get shellOnbLanguageSubtitle;

  /// No description provided for @shellOnbLangRuHint.
  ///
  /// In en, this message translates to:
  /// **'ORT in Russian'**
  String get shellOnbLangRuHint;

  /// No description provided for @shellOnbLangKyHint.
  ///
  /// In en, this message translates to:
  /// **'ORT in Kyrgyz'**
  String get shellOnbLangKyHint;

  /// No description provided for @shellOnbAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself'**
  String get shellOnbAboutTitle;

  /// No description provided for @shellOnbAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tailor tasks and show your region\'s leaderboard.'**
  String get shellOnbAboutSubtitle;

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

  /// No description provided for @shellGradeGraduate.
  ///
  /// In en, this message translates to:
  /// **'Graduate'**
  String get shellGradeGraduate;

  /// No description provided for @shellRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get shellRegionLabel;

  /// No description provided for @shellRegionOblast.
  ///
  /// In en, this message translates to:
  /// **'Region or city'**
  String get shellRegionOblast;

  /// No description provided for @shellRegionDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get shellRegionDistrict;

  /// No description provided for @shellRegionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the list of regions.'**
  String get shellRegionLoadError;

  /// No description provided for @shellOnbGoalTitle.
  ///
  /// In en, this message translates to:
  /// **'What score are you aiming for?'**
  String get shellOnbGoalTitle;

  /// No description provided for @shellOnbGoalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A goal shows how far you still have to go. You can change it in your profile.'**
  String get shellOnbGoalSubtitle;

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

  /// No description provided for @shellOnbUniversityLabel.
  ///
  /// In en, this message translates to:
  /// **'Dream university'**
  String get shellOnbUniversityLabel;

  /// No description provided for @shellOnbUniversityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. KSMA or KNU'**
  String get shellOnbUniversityHint;

  /// No description provided for @shellOnbDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'How much time a day can you study?'**
  String get shellOnbDailyTitle;

  /// No description provided for @shellOnbDailySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short daily sessions work better than rare marathons.'**
  String get shellOnbDailySubtitle;

  /// No description provided for @shellDailyMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min a day'**
  String shellDailyMinutes(int minutes);

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

  /// No description provided for @shellOnbSavedLater.
  ///
  /// In en, this message translates to:
  /// **'Answers saved. They\'ll sync when you\'re online.'**
  String get shellOnbSavedLater;

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

  /// No description provided for @shellHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s keep preparing for the ORT'**
  String get shellHomeSubtitle;

  /// No description provided for @shellHomeStatsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your progress.'**
  String get shellHomeStatsError;

  /// No description provided for @shellHomeEmptyStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Start your streak today'**
  String get shellHomeEmptyStatsTitle;

  /// No description provided for @shellHomeEmptyStatsMessage.
  ///
  /// In en, this message translates to:
  /// **'Solve a task or take a lesson — your streak and daily progress will appear here.'**
  String get shellHomeEmptyStatsMessage;

  /// No description provided for @shellHomeGoalMinutes.
  ///
  /// In en, this message translates to:
  /// **'Your goal: {minutes} min a day'**
  String shellHomeGoalMinutes(int minutes);

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

  /// No description provided for @shellHomeBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best: {count}'**
  String shellHomeBestStreak(int count);

  /// No description provided for @shellHomeTodayXpOfGoal.
  ///
  /// In en, this message translates to:
  /// **'Today: {today} of {goal} XP'**
  String shellHomeTodayXpOfGoal(int today, int goal);

  /// No description provided for @shellHomeTodayXp.
  ///
  /// In en, this message translates to:
  /// **'Today: {today} XP'**
  String shellHomeTodayXp(int today);

  /// No description provided for @shellHomeDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get shellHomeDailyGoal;

  /// No description provided for @shellHomeGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached!'**
  String get shellHomeGoalReached;

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

  /// No description provided for @shellNextStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get shellNextStepTitle;

  /// No description provided for @shellNextFirstMockFree.
  ///
  /// In en, this message translates to:
  /// **'Take your first full mock exam — it\'s free. You\'ll see your level and weak topics.'**
  String get shellNextFirstMockFree;

  /// No description provided for @shellNextFirstMock.
  ///
  /// In en, this message translates to:
  /// **'Take a full mock exam to see your level and weak topics.'**
  String get shellNextFirstMock;

  /// No description provided for @shellNextOpenExams.
  ///
  /// In en, this message translates to:
  /// **'Go to exams'**
  String get shellNextOpenExams;

  /// No description provided for @shellNextWeakTopic.
  ///
  /// In en, this message translates to:
  /// **'Your weakest area in the last exam: {area}. Review it to raise your score.'**
  String shellNextWeakTopic(String area);

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

  /// No description provided for @shellHomeCredits.
  ///
  /// In en, this message translates to:
  /// **'Mock exams available: {count}'**
  String shellHomeCredits(int count);

  /// No description provided for @shellHomeBuyExam.
  ///
  /// In en, this message translates to:
  /// **'Get a mock exam'**
  String get shellHomeBuyExam;

  /// No description provided for @shellHomeSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set your goal'**
  String get shellHomeSetupTitle;

  /// No description provided for @shellHomeSetupMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your grade, region and target score to get better recommendations.'**
  String get shellHomeSetupMessage;

  /// No description provided for @shellHomeSetupAction.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get shellHomeSetupAction;

  /// No description provided for @shellHomeReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind you to study?'**
  String get shellHomeReminderTitle;

  /// No description provided for @shellHomeReminderMessage.
  ///
  /// In en, this message translates to:
  /// **'A short daily reminder helps keep your streak.'**
  String get shellHomeReminderMessage;

  /// No description provided for @shellHomeReminderEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get shellHomeReminderEnable;

  /// No description provided for @shellReminderEnabled.
  ///
  /// In en, this message translates to:
  /// **'Reminders are on.'**
  String get shellReminderEnabled;

  /// No description provided for @shellReminderDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off for the app. Allow them in your phone settings.'**
  String get shellReminderDenied;

  /// No description provided for @shellReminderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reminders aren\'t available on this device.'**
  String get shellReminderUnsupported;

  /// No description provided for @shellReminderFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t turn on reminders. Try again later.'**
  String get shellReminderFailed;

  /// No description provided for @shellQuickTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get shellQuickTitle;

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

  /// No description provided for @shellQuickDailyLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson of the day'**
  String get shellQuickDailyLesson;

  /// No description provided for @shellQuickTutor.
  ///
  /// In en, this message translates to:
  /// **'AI tutor'**
  String get shellQuickTutor;

  /// No description provided for @shellQuickLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get shellQuickLeaderboard;

  /// No description provided for @shellQuickHandbook.
  ///
  /// In en, this message translates to:
  /// **'Handbook'**
  String get shellQuickHandbook;

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

  /// No description provided for @shellProfileComplete.
  ///
  /// In en, this message translates to:
  /// **'Fill in profile'**
  String get shellProfileComplete;

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

  /// No description provided for @shellProfileLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get shellProfileLevel;

  /// No description provided for @shellProfileStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get shellProfileStreak;

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

  /// No description provided for @shellProfileDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get shellProfileDailyGoal;

  /// No description provided for @shellProfileExamLanguage.
  ///
  /// In en, this message translates to:
  /// **'Exam language'**
  String get shellProfileExamLanguage;

  /// No description provided for @shellProfileSchool.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get shellProfileSchool;

  /// No description provided for @shellProfileRegionLocked.
  ///
  /// In en, this message translates to:
  /// **'The region can be changed once a year.'**
  String get shellProfileRegionLocked;

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

  /// No description provided for @shellProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection and try again.'**
  String get shellProfileSaveError;

  /// No description provided for @shellProfileAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get shellProfileAchievements;

  /// No description provided for @shellProfileTransactions.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get shellProfileTransactions;

  /// No description provided for @shellProfileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get shellProfileDeleteAccount;

  /// No description provided for @shellSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get shellSignOut;

  /// No description provided for @shellSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get shellSignOutTitle;

  /// No description provided for @shellSignOutMessage.
  ///
  /// In en, this message translates to:
  /// **'Your progress stays in your account.'**
  String get shellSignOutMessage;

  /// No description provided for @shellSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettingsTitle;

  /// No description provided for @shellSettingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get shellSettingsAppearance;

  /// No description provided for @shellSettingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get shellSettingsNotifications;

  /// No description provided for @shellSettingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get shellSettingsAbout;

  /// No description provided for @shellSettingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get shellSettingsLanguage;

  /// No description provided for @shellSettingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get shellSettingsTheme;

  /// No description provided for @shellThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'As on device'**
  String get shellThemeSystem;

  /// No description provided for @shellThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get shellThemeLight;

  /// No description provided for @shellThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get shellThemeDark;

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

  /// No description provided for @shellSettingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get shellSettingsPrivacy;

  /// No description provided for @shellSettingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get shellSettingsTerms;

  /// No description provided for @shellSettingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get shellSettingsVersion;

  /// No description provided for @shellSettingsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Mock exam results are for practice and are not official ORT scores.'**
  String get shellSettingsDisclaimer;
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
