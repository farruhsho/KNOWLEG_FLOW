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

  /// No description provided for @learnErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get learnErrorNotFound;

  /// No description provided for @learnErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not load data. Please try again.'**
  String get learnErrorGeneric;

  /// No description provided for @learnPracticePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Practice: {percent}%'**
  String learnPracticePercentLabel(int percent);

  /// No description provided for @learnPracticeCorrectOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {total} correct'**
  String learnPracticeCorrectOfTotal(int correct, int total);

  /// No description provided for @learnPracticeVerdictExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent! Keep it up.'**
  String get learnPracticeVerdictExcellent;

  /// No description provided for @learnPracticeVerdictGood.
  ///
  /// In en, this message translates to:
  /// **'Good. Almost there.'**
  String get learnPracticeVerdictGood;

  /// No description provided for @learnPracticeVerdictFair.
  ///
  /// In en, this message translates to:
  /// **'Not bad. Reviewing mistakes improves results fastest.'**
  String get learnPracticeVerdictFair;

  /// No description provided for @learnPracticeVerdictLow.
  ///
  /// In en, this message translates to:
  /// **'More practice needed. Start by reviewing mistakes.'**
  String get learnPracticeVerdictLow;

  /// No description provided for @learnPracticeNotOrtNote.
  ///
  /// In en, this message translates to:
  /// **'This is a practice result, not an ORT score: a short set of questions cannot estimate an exam score.'**
  String get learnPracticeNotOrtNote;

  /// No description provided for @learnQuickPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick practice'**
  String get learnQuickPracticeTitle;

  /// No description provided for @learnLessonPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson practice'**
  String get learnLessonPracticeTitle;

  /// No description provided for @learnMistakesPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Mistakes review'**
  String get learnMistakesPracticeTitle;

  /// No description provided for @learnPracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get learnPracticeTitle;

  /// No description provided for @learnSignInToPractice.
  ///
  /// In en, this message translates to:
  /// **'Sign in to practise and save your progress.'**
  String get learnSignInToPractice;

  /// No description provided for @learnSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get learnSignIn;

  /// No description provided for @learnLoadingQuestions.
  ///
  /// In en, this message translates to:
  /// **'Picking questions…'**
  String get learnLoadingQuestions;

  /// No description provided for @learnNoQuestionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No questions yet'**
  String get learnNoQuestionsTitle;

  /// No description provided for @learnNoQuestionsBody.
  ///
  /// In en, this message translates to:
  /// **'There are no reviewed questions here yet. Check back later or try quick practice.'**
  String get learnNoQuestionsBody;

  /// No description provided for @learnBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get learnBack;

  /// No description provided for @learnQuestionProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String learnQuestionProgress(int current, int total);

  /// No description provided for @learnElapsedTime.
  ///
  /// In en, this message translates to:
  /// **'Elapsed time'**
  String get learnElapsedTime;

  /// No description provided for @learnFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get learnFinish;

  /// No description provided for @learnNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get learnNext;

  /// No description provided for @learnSkipAndFinish.
  ///
  /// In en, this message translates to:
  /// **'Skip and finish'**
  String get learnSkipAndFinish;

  /// No description provided for @learnSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get learnSkip;

  /// No description provided for @learnExitTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish practice?'**
  String get learnExitTitle;

  /// No description provided for @learnExitBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{You haven\'t answered any questions yet.} =1{Your answer to 1 question can be saved.} other{Your answers to {count} questions can be saved.}}'**
  String learnExitBody(int count);

  /// No description provided for @learnExitDiscard.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving'**
  String get learnExitDiscard;

  /// No description provided for @learnExitContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get learnExitContinue;

  /// No description provided for @learnExitFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish and save'**
  String get learnExitFinish;

  /// No description provided for @learnCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get learnCorrect;

  /// No description provided for @learnWrong.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get learnWrong;

  /// No description provided for @learnCorrectAnswerIs.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String learnCorrectAnswerIs(String answer);

  /// No description provided for @learnExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get learnExplanation;

  /// No description provided for @learnNoExplanation.
  ///
  /// In en, this message translates to:
  /// **'No explanation has been added for this question yet.'**
  String get learnNoExplanation;

  /// No description provided for @learnAskTutor.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI tutor'**
  String get learnAskTutor;

  /// No description provided for @learnDifficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get learnDifficultyEasy;

  /// No description provided for @learnDifficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get learnDifficultyMedium;

  /// No description provided for @learnDifficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get learnDifficultyHard;

  /// No description provided for @learnResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice result'**
  String get learnResultsTitle;

  /// No description provided for @learnResultsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No results yet'**
  String get learnResultsEmptyTitle;

  /// No description provided for @learnResultsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Do a practice set and the answer review will appear here.'**
  String get learnResultsEmptyBody;

  /// No description provided for @learnStatCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get learnStatCorrect;

  /// No description provided for @learnStatWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong'**
  String get learnStatWrong;

  /// No description provided for @learnStatSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get learnStatSkipped;

  /// No description provided for @learnStatTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get learnStatTime;

  /// No description provided for @learnAvgPerQuestion.
  ///
  /// In en, this message translates to:
  /// **'Average {seconds} s per question'**
  String learnAvgPerQuestion(int seconds);

  /// No description provided for @learnReviewAnswers.
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get learnReviewAnswers;

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

  /// No description provided for @learnBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get learnBackHome;

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

  /// No description provided for @learnQuestionNumber.
  ///
  /// In en, this message translates to:
  /// **'Question {n}'**
  String learnQuestionNumber(int n);

  /// No description provided for @learnYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get learnYourAnswer;

  /// No description provided for @learnRightAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get learnRightAnswer;

  /// No description provided for @learnLessonSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get learnLessonSummary;

  /// No description provided for @learnLessonFormulas.
  ///
  /// In en, this message translates to:
  /// **'Formulas'**
  String get learnLessonFormulas;

  /// No description provided for @learnLessonExamples.
  ///
  /// In en, this message translates to:
  /// **'Examples'**
  String get learnLessonExamples;

  /// No description provided for @learnLessonCommonMistakes.
  ///
  /// In en, this message translates to:
  /// **'Common mistakes'**
  String get learnLessonCommonMistakes;

  /// No description provided for @learnLessonNoContent.
  ///
  /// In en, this message translates to:
  /// **'The lesson content hasn\'t been added yet.'**
  String get learnLessonNoContent;

  /// No description provided for @learnLessonExampleN.
  ///
  /// In en, this message translates to:
  /// **'Example {n}'**
  String learnLessonExampleN(int n);

  /// No description provided for @learnLessonHideSolution.
  ///
  /// In en, this message translates to:
  /// **'Hide solution'**
  String get learnLessonHideSolution;

  /// No description provided for @learnLessonShowSolution.
  ///
  /// In en, this message translates to:
  /// **'Show solution'**
  String get learnLessonShowSolution;

  /// No description provided for @learnLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get learnLessonTitle;

  /// No description provided for @learnLoadingLesson.
  ///
  /// In en, this message translates to:
  /// **'Loading the lesson…'**
  String get learnLoadingLesson;

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

  /// No description provided for @learnMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String learnMinutes(int n);

  /// No description provided for @learnLessonDone.
  ///
  /// In en, this message translates to:
  /// **'Lesson completed'**
  String get learnLessonDone;

  /// No description provided for @learnLessonMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get learnLessonMaterials;

  /// No description provided for @learnLessonWatchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch the video'**
  String get learnLessonWatchVideo;

  /// No description provided for @learnLessonOpenPdf.
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get learnLessonOpenPdf;

  /// No description provided for @learnLessonMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark lesson as completed'**
  String get learnLessonMarkDone;

  /// No description provided for @learnLessonAllDone.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed every lesson in this subject.'**
  String get learnLessonAllDone;

  /// No description provided for @learnSignInToSave.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save your progress.'**
  String get learnSignInToSave;

  /// No description provided for @learnLessonCompletedToast.
  ///
  /// In en, this message translates to:
  /// **'Lesson marked as completed.'**
  String get learnLessonCompletedToast;

  /// No description provided for @learnLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link.'**
  String get learnLinkFailed;

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

  /// No description provided for @learnStartPractice.
  ///
  /// In en, this message translates to:
  /// **'Start practice'**
  String get learnStartPractice;

  /// No description provided for @learnNextLesson.
  ///
  /// In en, this message translates to:
  /// **'Next lesson'**
  String get learnNextLesson;

  /// No description provided for @learnDailyLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'Lesson of the day'**
  String get learnDailyLessonTitle;

  /// No description provided for @learnSubjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get learnSubjectsTitle;

  /// No description provided for @learnSearchSubjects.
  ///
  /// In en, this message translates to:
  /// **'Search subjects'**
  String get learnSearchSubjects;

  /// No description provided for @learnLoadingSubjects.
  ///
  /// In en, this message translates to:
  /// **'Loading subjects…'**
  String get learnLoadingSubjects;

  /// No description provided for @learnNoSubjectsTitle.
  ///
  /// In en, this message translates to:
  /// **'No subjects yet'**
  String get learnNoSubjectsTitle;

  /// No description provided for @learnNoSubjectsBody.
  ///
  /// In en, this message translates to:
  /// **'Learning materials are coming soon. Meanwhile, try quick practice.'**
  String get learnNoSubjectsBody;

  /// No description provided for @learnMistakesTitle.
  ///
  /// In en, this message translates to:
  /// **'Mistakes & review'**
  String get learnMistakesTitle;

  /// No description provided for @learnLeaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get learnLeaderboardTitle;

  /// No description provided for @learnLessonsCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 lesson} other{{n} lessons}}'**
  String learnLessonsCount(int n);

  /// No description provided for @learnLoadingSubject.
  ///
  /// In en, this message translates to:
  /// **'Loading the subject…'**
  String get learnLoadingSubject;

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

  /// No description provided for @learnStatLessonsDone.
  ///
  /// In en, this message translates to:
  /// **'Lessons done'**
  String get learnStatLessonsDone;

  /// No description provided for @learnStatPracticeAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Practice accuracy'**
  String get learnStatPracticeAccuracy;

  /// No description provided for @learnAnswersCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 answer} other{{n} answers}}'**
  String learnAnswersCount(int n);

  /// No description provided for @learnPracticeSubject.
  ///
  /// In en, this message translates to:
  /// **'Practise this subject'**
  String get learnPracticeSubject;

  /// No description provided for @learnLessonsHeading.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get learnLessonsHeading;

  /// No description provided for @learnNoLessonsYet.
  ///
  /// In en, this message translates to:
  /// **'No lessons yet — start with practice.'**
  String get learnNoLessonsYet;

  /// No description provided for @learnNoSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get learnNoSearchResults;

  /// No description provided for @learnHandbookTitle.
  ///
  /// In en, this message translates to:
  /// **'Handbook'**
  String get learnHandbookTitle;

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

  /// No description provided for @learnHandbookFactsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the exam structure.'**
  String get learnHandbookFactsUnavailable;

  /// No description provided for @learnHbMainTest.
  ///
  /// In en, this message translates to:
  /// **'ORT main test ({year})'**
  String learnHbMainTest(String year);

  /// No description provided for @learnHbSectionLine.
  ///
  /// In en, this message translates to:
  /// **'{title}: {questions, plural, =1{1 item} other{{questions} items}}, {minutes} min'**
  String learnHbSectionLine(String title, int questions, int minutes);

  /// No description provided for @learnHbAssumption.
  ///
  /// In en, this message translates to:
  /// **'(split is an assumption)'**
  String get learnHbAssumption;

  /// No description provided for @learnHbPartLine.
  ///
  /// In en, this message translates to:
  /// **'{title}: {questions} items, {options, plural, =1{1 answer option} other{{options} answer options}}'**
  String learnHbPartLine(String title, int questions, int options);

  /// No description provided for @learnHbMainTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {questions, plural, =1{1 item} other{{questions} items}}, {minutes} min.'**
  String learnHbMainTotal(int questions, int minutes);

  /// No description provided for @learnHbSubjectTests.
  ///
  /// In en, this message translates to:
  /// **'Subject tests (optional)'**
  String get learnHbSubjectTests;

  /// No description provided for @learnHbStateLanguage.
  ///
  /// In en, this message translates to:
  /// **'{questions, plural, =1{1 item} other{{questions} items}}, {minutes} min. Required for the certificate; reported as level 1–4.'**
  String learnHbStateLanguage(int questions, int minutes);

  /// No description provided for @learnHbMaxScore.
  ///
  /// In en, this message translates to:
  /// **'The official maximum score of the main test is {score}.'**
  String learnHbMaxScore(int score);

  /// No description provided for @learnHbThresholdsUniversity.
  ///
  /// In en, this message translates to:
  /// **'University thresholds: {main} on the main test and {subject} on subject tests (2026–2027).'**
  String learnHbThresholdsUniversity(int main, int subject);

  /// No description provided for @learnHbThresholdCollege.
  ///
  /// In en, this message translates to:
  /// **'Colleges: {n} on the main test.'**
  String learnHbThresholdCollege(int n);

  /// No description provided for @learnHbThresholdsYearly.
  ///
  /// In en, this message translates to:
  /// **'Thresholds are set anew every year — check testing.kg.'**
  String get learnHbThresholdsYearly;

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

  /// No description provided for @learnAchievementsServerNote.
  ///
  /// In en, this message translates to:
  /// **'Achievements are granted automatically from your results on the server.'**
  String get learnAchievementsServerNote;

  /// No description provided for @learnAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get learnAchievementUnlocked;

  /// No description provided for @learnAchievementLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get learnAchievementLocked;

  /// No description provided for @learnAchievementUnlockedOn.
  ///
  /// In en, this message translates to:
  /// **'Unlocked on {date}'**
  String learnAchievementUnlockedOn(String date);

  /// No description provided for @learnLevelN.
  ///
  /// In en, this message translates to:
  /// **'Level {n}'**
  String learnLevelN(int n);

  /// No description provided for @learnStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 day} other{{n} days}}'**
  String learnStreakDays(int n);

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

  /// No description provided for @learnAchFirstLessonTitle.
  ///
  /// In en, this message translates to:
  /// **'First lesson'**
  String get learnAchFirstLessonTitle;

  /// No description provided for @learnAchFirstLessonDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete your first lesson'**
  String get learnAchFirstLessonDesc;

  /// No description provided for @learnAchXp100Title.
  ///
  /// In en, this message translates to:
  /// **'First 100 XP'**
  String get learnAchXp100Title;

  /// No description provided for @learnAchXp100Desc.
  ///
  /// In en, this message translates to:
  /// **'Earn 100 XP'**
  String get learnAchXp100Desc;

  /// No description provided for @learnAchStreak7Title.
  ///
  /// In en, this message translates to:
  /// **'Week streak'**
  String get learnAchStreak7Title;

  /// No description provided for @learnAchStreak7Desc.
  ///
  /// In en, this message translates to:
  /// **'Study 7 days in a row'**
  String get learnAchStreak7Desc;

  /// No description provided for @learnAchDays30Title.
  ///
  /// In en, this message translates to:
  /// **'30 study days'**
  String get learnAchDays30Title;

  /// No description provided for @learnAchDays30Desc.
  ///
  /// In en, this message translates to:
  /// **'Study on 30 different days'**
  String get learnAchDays30Desc;

  /// No description provided for @learnAchAccuracy90Title.
  ///
  /// In en, this message translates to:
  /// **'90% accuracy'**
  String get learnAchAccuracy90Title;

  /// No description provided for @learnAchAccuracy90Desc.
  ///
  /// In en, this message translates to:
  /// **'Score 90% on a mock exam'**
  String get learnAchAccuracy90Desc;

  /// No description provided for @learnAchMathExpertTitle.
  ///
  /// In en, this message translates to:
  /// **'Math expert'**
  String get learnAchMathExpertTitle;

  /// No description provided for @learnAchMathExpertDesc.
  ///
  /// In en, this message translates to:
  /// **'90% in math on three mock exams'**
  String get learnAchMathExpertDesc;

  /// No description provided for @learnAchAnalogiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Analogies master'**
  String get learnAchAnalogiesTitle;

  /// No description provided for @learnAchAnalogiesDesc.
  ///
  /// In en, this message translates to:
  /// **'A high score in the analogies section'**
  String get learnAchAnalogiesDesc;

  /// No description provided for @learnAchReaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get learnAchReaderTitle;

  /// No description provided for @learnAchReaderDesc.
  ///
  /// In en, this message translates to:
  /// **'A high score in the reading section'**
  String get learnAchReaderDesc;

  /// No description provided for @learnAchExamChampionTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock exam champion'**
  String get learnAchExamChampionTitle;

  /// No description provided for @learnAchExamChampionDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete 10 mock exams'**
  String get learnAchExamChampionDesc;

  /// No description provided for @learnLeaderboardWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get learnLeaderboardWeekly;

  /// No description provided for @learnLeaderboardAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get learnLeaderboardAllTime;

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

  /// No description provided for @learnLeaderboardAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get learnLeaderboardAnonymous;

  /// No description provided for @learnLeaderboardYou.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String learnLeaderboardYou(String name);

  /// No description provided for @learnXpShort.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String learnXpShort(int xp);

  /// No description provided for @learnMistakesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No mistakes to review'**
  String get learnMistakesEmptyTitle;

  /// No description provided for @learnMistakesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Wrong answers from practice and exams will appear here.'**
  String get learnMistakesEmptyBody;

  /// No description provided for @learnMistakesDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today: {n}'**
  String learnMistakesDueToday(int n);

  /// No description provided for @learnMistakesSrsNote.
  ///
  /// In en, this message translates to:
  /// **'Each mistake comes back after 1, 3, 7, 14 and 30 days. A correct answer moves it further; a wrong one restarts it.'**
  String get learnMistakesSrsNote;

  /// No description provided for @learnMistakesFilterDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get learnMistakesFilterDue;

  /// No description provided for @learnMistakesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get learnMistakesFilterAll;

  /// No description provided for @learnMistakesAllSubjects.
  ///
  /// In en, this message translates to:
  /// **'All subjects'**
  String get learnMistakesAllSubjects;

  /// No description provided for @learnMistakesPracticeN.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Review 1 question} other{Review {n} questions}}'**
  String learnMistakesPracticeN(int n);

  /// No description provided for @learnMistakesNothingDue.
  ///
  /// In en, this message translates to:
  /// **'All caught up for today. Come back tomorrow.'**
  String get learnMistakesNothingDue;

  /// No description provided for @learnMistakeFromExam.
  ///
  /// In en, this message translates to:
  /// **'Question from a mock exam'**
  String get learnMistakeFromExam;

  /// No description provided for @learnMistakeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get learnMistakeQuestion;

  /// No description provided for @learnMistakeReviewToday.
  ///
  /// In en, this message translates to:
  /// **'due today'**
  String get learnMistakeReviewToday;

  /// No description provided for @learnMistakeReviewOn.
  ///
  /// In en, this message translates to:
  /// **'review on {date}'**
  String learnMistakeReviewOn(String date);

  /// No description provided for @learnMistakeWrongCount.
  ///
  /// In en, this message translates to:
  /// **'wrong: {n}'**
  String learnMistakeWrongCount(int n);

  /// No description provided for @learnMistakeOpenReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get learnMistakeOpenReview;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get learnMore;

  /// No description provided for @learnMistakePractice.
  ///
  /// In en, this message translates to:
  /// **'Practise'**
  String get learnMistakePractice;

  /// No description provided for @learnMistakeResolve.
  ///
  /// In en, this message translates to:
  /// **'Mark as resolved'**
  String get learnMistakeResolve;

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

  /// No description provided for @learnQuestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily quests'**
  String get learnQuestsTitle;

  /// No description provided for @learnQuestsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset in {h} h {m} min'**
  String learnQuestsReset(int h, int m);

  /// No description provided for @learnQuestsDone.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String learnQuestsDone(int done, int total);

  /// No description provided for @learnProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get learnProgressTitle;

  /// No description provided for @learnStatLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get learnStatLevel;

  /// No description provided for @learnStatStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak, days'**
  String get learnStatStreak;

  /// No description provided for @learnStatBestStreak.
  ///
  /// In en, this message translates to:
  /// **'Best: {n}'**
  String learnStatBestStreak(int n);

  /// No description provided for @learnStatAnswered.
  ///
  /// In en, this message translates to:
  /// **'Practice answers'**
  String get learnStatAnswered;

  /// No description provided for @learnStatSessions.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 set} other{{n} sets}}'**
  String learnStatSessions(int n);

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

  /// No description provided for @learnDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String learnDurationMinutes(int n);

  /// No description provided for @learnStatPracticeTimeHint.
  ///
  /// In en, this message translates to:
  /// **'from finished sets'**
  String get learnStatPracticeTimeHint;

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

  /// No description provided for @learnRecommendationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommendations'**
  String get learnRecommendationsTitle;

  /// No description provided for @learnRecommendationsNone.
  ///
  /// In en, this message translates to:
  /// **'Everything looks good — keep going.'**
  String get learnRecommendationsNone;

  /// No description provided for @learnExamResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Mock exams'**
  String get learnExamResultsTitle;

  /// No description provided for @learnExamHistoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Exam history is unavailable right now.'**
  String get learnExamHistoryUnavailable;

  /// No description provided for @learnExamHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t finished a mock exam yet.'**
  String get learnExamHistoryEmpty;

  /// No description provided for @learnBestResult.
  ///
  /// In en, this message translates to:
  /// **'Best result'**
  String get learnBestResult;

  /// No description provided for @learnExamResultUnofficial.
  ///
  /// In en, this message translates to:
  /// **'Practice result, not an official ORT score.'**
  String get learnExamResultUnofficial;

  /// No description provided for @learnExamHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent attempts'**
  String get learnExamHistoryTitle;

  /// No description provided for @learnExamHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'Full history'**
  String get learnExamHistoryAll;

  /// No description provided for @learnExamSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Average by section'**
  String get learnExamSectionsTitle;

  /// No description provided for @learnPracticeBySubjectTitle.
  ///
  /// In en, this message translates to:
  /// **'Practice by subject'**
  String get learnPracticeBySubjectTitle;

  /// No description provided for @learnPracticeBySubjectEmpty.
  ///
  /// In en, this message translates to:
  /// **'Answer a few questions to see accuracy by subject.'**
  String get learnPracticeBySubjectEmpty;

  /// No description provided for @learnWeakTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Topics to review'**
  String get learnWeakTopicsTitle;

  /// No description provided for @learnWeakTopicsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough answers to spot weak topics yet (5+ per topic needed).'**
  String get learnWeakTopicsEmpty;

  /// No description provided for @learnProgressEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get learnProgressEmptyTitle;

  /// No description provided for @learnProgressEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Complete a lesson or practice set to see your real statistics.'**
  String get learnProgressEmptyBody;

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

  /// No description provided for @learnRecOpenExams.
  ///
  /// In en, this message translates to:
  /// **'Go to exams'**
  String get learnRecOpenExams;
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
