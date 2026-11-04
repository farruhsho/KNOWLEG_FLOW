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

  /// No description provided for @billingStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Exam access'**
  String get billingStoreTitle;

  /// No description provided for @billingHistoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Purchase history'**
  String get billingHistoryTooltip;

  /// No description provided for @billingBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Your balance'**
  String get billingBalanceTitle;

  /// Exam credit balance
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 credit} other{{count} credits}}'**
  String billingCreditsCount(int count);

  /// No description provided for @billingCreditRule.
  ///
  /// In en, this message translates to:
  /// **'1 credit = 1 full mock exam'**
  String get billingCreditRule;

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

  /// No description provided for @billingBalanceError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your balance.'**
  String get billingBalanceError;

  /// No description provided for @billingRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get billingRetry;

  /// No description provided for @billingProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy mock exams'**
  String get billingProductsTitle;

  /// Product title by number of tests
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 test} other{{count} tests}}'**
  String billingProductTests(int count);

  /// No description provided for @billingProductSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 full mock exam} other{{count} full mock exams}}'**
  String billingProductSubtitle(int count);

  /// No description provided for @billingBuySemantics.
  ///
  /// In en, this message translates to:
  /// **'Buy {title} for {price}'**
  String billingBuySemantics(String title, String price);

  /// No description provided for @billingRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get billingRestore;

  /// No description provided for @billingRestoreStarted.
  ///
  /// In en, this message translates to:
  /// **'Checking unfinished purchases…'**
  String get billingRestoreStarted;

  /// No description provided for @billingRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Check finished. Your balance updates automatically.'**
  String get billingRestoreDone;

  /// No description provided for @billingLoadingProducts.
  ///
  /// In en, this message translates to:
  /// **'Loading offers…'**
  String get billingLoadingProducts;

  /// No description provided for @billingProductsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load offers from Google Play.'**
  String get billingProductsError;

  /// No description provided for @billingProductsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Offers are temporarily unavailable. Please try again later.'**
  String get billingProductsEmpty;

  /// No description provided for @billingUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases are unavailable'**
  String get billingUnavailableTitle;

  /// No description provided for @billingUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Google Play billing isn\'t available on this device. Make sure Google Play is installed and you\'re signed in to it.'**
  String get billingUnavailableBody;

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

  /// No description provided for @billingHonestServer.
  ///
  /// In en, this message translates to:
  /// **'Credits are added only after our server confirms the purchase.'**
  String get billingHonestServer;

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

  /// No description provided for @billingStatusLaunching.
  ///
  /// In en, this message translates to:
  /// **'Opening Google Play…'**
  String get billingStatusLaunching;

  /// No description provided for @billingStatusVerifying.
  ///
  /// In en, this message translates to:
  /// **'Confirming your purchase…'**
  String get billingStatusVerifying;

  /// No description provided for @billingStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'Purchase confirmed. Credits have been added.'**
  String get billingStatusGranted;

  /// No description provided for @billingStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment. Credits will be added once Google Play confirms the payment.'**
  String get billingStatusPending;

  /// No description provided for @billingStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Purchase canceled.'**
  String get billingStatusCanceled;

  /// No description provided for @billingErrorNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to buy tests.'**
  String get billingErrorNotSignedIn;

  /// No description provided for @billingErrorStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google Play is unavailable right now. Try again later.'**
  String get billingErrorStoreUnavailable;

  /// No description provided for @billingErrorProductUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This offer is no longer available.'**
  String get billingErrorProductUnavailable;

  /// No description provided for @billingErrorLaunch.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the purchase. Try again.'**
  String get billingErrorLaunch;

  /// No description provided for @billingErrorAlreadyOwned.
  ///
  /// In en, this message translates to:
  /// **'Your previous purchase is still being processed. We\'re checking it now.'**
  String get billingErrorAlreadyOwned;

  /// No description provided for @billingErrorStore.
  ///
  /// In en, this message translates to:
  /// **'Google Play returned an error. Try again.'**
  String get billingErrorStore;

  /// No description provided for @billingErrorVerifyDeferred.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm the purchase yet. We\'ll retry automatically, and your payment won\'t be lost.'**
  String get billingErrorVerifyDeferred;

  /// No description provided for @billingErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'The purchase couldn\'t be verified. If you were charged, Google Play will refund it automatically within 3 days.'**
  String get billingErrorInvalid;

  /// No description provided for @billingErrorAccountMismatch.
  ///
  /// In en, this message translates to:
  /// **'This purchase belongs to another account in the app. Sign in with that account to use it.'**
  String get billingErrorAccountMismatch;

  /// No description provided for @billingTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase history'**
  String get billingTransactionsTitle;

  /// No description provided for @billingTabPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get billingTabPurchases;

  /// No description provided for @billingTabLedger.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get billingTabLedger;

  /// No description provided for @billingPurchasesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet.'**
  String get billingPurchasesEmpty;

  /// No description provided for @billingLedgerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No credit changes yet.'**
  String get billingLedgerEmpty;

  /// No description provided for @billingHistoryError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the history.'**
  String get billingHistoryError;

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

  /// No description provided for @billingStateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get billingStateInvalid;

  /// No description provided for @billingOrderId.
  ///
  /// In en, this message translates to:
  /// **'Order {id}'**
  String billingOrderId(String id);

  /// No description provided for @billingBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance: {balance}'**
  String billingBalanceAfter(int balance);

  /// No description provided for @billingReasonPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get billingReasonPurchase;

  /// No description provided for @billingReasonExamStart.
  ///
  /// In en, this message translates to:
  /// **'Mock exam started'**
  String get billingReasonExamStart;

  /// No description provided for @billingReasonRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get billingReasonRefund;

  /// No description provided for @billingReasonAdminGrant.
  ///
  /// In en, this message translates to:
  /// **'Added by support'**
  String get billingReasonAdminGrant;

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

  /// No description provided for @billingLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get billingLoadMore;

  /// No description provided for @tutorTitle.
  ///
  /// In en, this message translates to:
  /// **'AI tutor'**
  String get tutorTitle;

  /// No description provided for @tutorModeExplainMistake.
  ///
  /// In en, this message translates to:
  /// **'Explain a mistake'**
  String get tutorModeExplainMistake;

  /// No description provided for @tutorModeStepByStep.
  ///
  /// In en, this message translates to:
  /// **'Step by step'**
  String get tutorModeStepByStep;

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

  /// No description provided for @tutorModeStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Study plan'**
  String get tutorModeStudyPlan;

  /// No description provided for @tutorModeChat.
  ///
  /// In en, this message translates to:
  /// **'Free question'**
  String get tutorModeChat;

  /// No description provided for @tutorHintExplainMistake.
  ///
  /// In en, this message translates to:
  /// **'Paste the task and your answer — I\'ll explain where the mistake is.'**
  String get tutorHintExplainMistake;

  /// No description provided for @tutorHintStepByStep.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem — we\'ll solve it step by step.'**
  String get tutorHintStepByStep;

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

  /// No description provided for @tutorHintStudyPlan.
  ///
  /// In en, this message translates to:
  /// **'Tell me your exam date and weak subjects.'**
  String get tutorHintStudyPlan;

  /// No description provided for @tutorHintChat.
  ///
  /// In en, this message translates to:
  /// **'Ask anything about ORT preparation.'**
  String get tutorHintChat;

  /// No description provided for @tutorSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get tutorSend;

  /// No description provided for @tutorClear.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get tutorClear;

  /// No description provided for @tutorDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI can make mistakes. Check important steps with your textbook or teacher.'**
  String get tutorDisclaimer;

  /// No description provided for @tutorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get tutorEmptyTitle;

  /// No description provided for @tutorEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a mode above and ask a question. I explain the reasoning instead of just giving the answer.'**
  String get tutorEmptyBody;

  /// No description provided for @tutorThinking.
  ///
  /// In en, this message translates to:
  /// **'The tutor is thinking…'**
  String get tutorThinking;

  /// No description provided for @tutorRemainingToday.
  ///
  /// In en, this message translates to:
  /// **'Requests left today: {count}'**
  String tutorRemainingToday(int count);

  /// No description provided for @tutorContextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Question attached'**
  String get tutorContextQuestion;

  /// No description provided for @tutorContextAttempt.
  ///
  /// In en, this message translates to:
  /// **'Exam attempt attached'**
  String get tutorContextAttempt;

  /// No description provided for @tutorContextRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get tutorContextRemove;

  /// No description provided for @tutorErrorQuota.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used today\'s AI requests. Come back tomorrow.'**
  String get tutorErrorQuota;

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

  /// No description provided for @tutorErrorSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use the AI tutor.'**
  String get tutorErrorSignIn;

  /// No description provided for @tutorErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'The message is empty or too long. Shorten it and try again.'**
  String get tutorErrorValidation;

  /// No description provided for @tutorErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'The tutor couldn\'t answer. Try again.'**
  String get tutorErrorUnknown;

  /// No description provided for @tutorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get tutorRetry;

  /// No description provided for @tutorYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get tutorYou;

  /// No description provided for @tutorAssistant.
  ///
  /// In en, this message translates to:
  /// **'Tutor'**
  String get tutorAssistant;

  /// No description provided for @tutorExplainerCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get tutorExplainerCorrect;

  /// No description provided for @tutorExplainerIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get tutorExplainerIncorrect;

  /// No description provided for @tutorExplainerCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String tutorExplainerCorrectAnswer(String answer);

  /// No description provided for @tutorExplainerYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer: {answer}'**
  String tutorExplainerYourAnswer(String answer);

  /// No description provided for @tutorExplainerNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'no answer'**
  String get tutorExplainerNoAnswer;

  /// No description provided for @tutorExplainerExplanation.
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get tutorExplainerExplanation;

  /// No description provided for @tutorExplainerAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Why is it wrong? Ask the AI tutor'**
  String get tutorExplainerAiTitle;

  /// No description provided for @tutorExplainerAiButton.
  ///
  /// In en, this message translates to:
  /// **'Explain my mistake'**
  String get tutorExplainerAiButton;

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

  /// No description provided for @tutorExplainerNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tutorExplainerNext;

  /// No description provided for @tutorExplainerClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get tutorExplainerClose;

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

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be undone'**
  String get accountDeleteWarningTitle;

  /// No description provided for @accountDeleteWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Your account and learning data will be permanently deleted. You won\'t be able to restore them.'**
  String get accountDeleteWarningBody;

  /// No description provided for @accountDeleteWhatDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'What will be deleted'**
  String get accountDeleteWhatDeletedTitle;

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

  /// No description provided for @accountDeleteItemLogin.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in (email and password or the Google link)'**
  String get accountDeleteItemLogin;

  /// No description provided for @accountDeleteWhatKeptTitle.
  ///
  /// In en, this message translates to:
  /// **'What we keep'**
  String get accountDeleteWhatKeptTitle;

  /// No description provided for @accountDeleteKeptPurchases.
  ///
  /// In en, this message translates to:
  /// **'Anonymized purchase records (date, product, amount, order number) without your name or email. We need them for financial reporting, refunds and fraud prevention.'**
  String get accountDeleteKeptPurchases;

  /// No description provided for @accountDeleteKeptGoogle.
  ///
  /// In en, this message translates to:
  /// **'Your Google Play payment history is kept by Google in your Google account.'**
  String get accountDeleteKeptGoogle;

  /// Word the user must type to confirm deletion
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get accountDeleteConfirmWord;

  /// No description provided for @accountDeleteConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'To confirm, type {word}'**
  String accountDeleteConfirmLabel(String word);

  /// No description provided for @accountDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete account permanently'**
  String get accountDeleteButton;

  /// No description provided for @accountDeleteInProgress.
  ///
  /// In en, this message translates to:
  /// **'Deleting your data…'**
  String get accountDeleteInProgress;

  /// No description provided for @accountDeleteDone.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get accountDeleteDone;

  /// No description provided for @accountDeleteSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in to delete your account.'**
  String get accountDeleteSignedOut;

  /// No description provided for @accountDeleteGoToLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountDeleteGoToLogin;

  /// No description provided for @accountReauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get accountReauthTitle;

  /// No description provided for @accountReauthBody.
  ///
  /// In en, this message translates to:
  /// **'For security, sign in again before deleting the account.'**
  String get accountReauthBody;

  /// No description provided for @accountReauthEmail.
  ///
  /// In en, this message translates to:
  /// **'Account: {email}'**
  String accountReauthEmail(String email);

  /// No description provided for @accountReauthPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountReauthPassword;

  /// No description provided for @accountReauthConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get accountReauthConfirm;

  /// No description provided for @accountReauthCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountReauthCancel;

  /// No description provided for @accountReauthGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get accountReauthGoogle;

  /// No description provided for @accountErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get accountErrorWrongPassword;

  /// No description provided for @accountErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get accountErrorTooManyRequests;

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

  /// No description provided for @accountErrorUserMismatch.
  ///
  /// In en, this message translates to:
  /// **'That\'s a different account. Sign in with the account you want to delete.'**
  String get accountErrorUserMismatch;

  /// No description provided for @accountErrorGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Try again.'**
  String get accountErrorGoogle;

  /// No description provided for @accountErrorService.
  ///
  /// In en, this message translates to:
  /// **'Account deletion is temporarily unavailable. Try again later.'**
  String get accountErrorService;

  /// No description provided for @accountErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the account. Try again.'**
  String get accountErrorUnknown;
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
