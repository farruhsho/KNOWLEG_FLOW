class AppConstants {
  // App Info
  static const String appName = 'ORT Master KG';
  static const String appVersion = '1.0.0';

  // ORT Test Structure
  static const int mainTestQuestions = 60;
  static const int mainTestTimeMinutes = 90;
  static const int verbalQuestions = 30;
  static const int mathQuestions = 30;

  static const int subjectTestQuestions = 40;
  static const int subjectTestTimeMinutes = 60;

  static const int languageTestQuestions = 30;
  static const int languageTestTimeMinutes = 45;

  static const int totalQuestions = 130;
  static const int totalTimeMinutes = 195;
  static const int maxScore = 200;

  // Question Types
  static const String questionTypeMCQ = 'mcq';
  static const String questionTypeTF = 'tf';
  static const String questionTypeFillIn = 'fill';

  // Test Sections
  static const String sectionMain = 'main';
  static const String sectionSubject = 'subject';
  static const String sectionLanguage = 'language';

  // Subjects
  static const String subjectMath = 'math';
  static const String subjectPhysics = 'physics';
  static const String subjectChemistry = 'chemistry';
  static const String subjectBiology = 'biology';
  static const String subjectHistory = 'history';
  static const String subjectGeography = 'geography';

  // Languages
  static const String langKyrgyz = 'ky';
  static const String langRussian = 'ru';
  static const String langEnglish = 'en';

  // Grades
  static const int grade9 = 9;
  static const int grade10 = 10;
  static const int grade11 = 11;
  static const int gradeGraduate = 0;

  // Subscription Tiers
  static const String tierFree = 'free';
  static const String tierMonthly = 'monthly';
  static const String tierYearly = 'yearly';

  // Pricing (KGS)
  static const int priceMockTest = 100;
  static const int priceMockTest5Pack = 400;
  static const int priceMonthlySubscription = 500;

  // Payment Methods
  static const String paymentMBank = 'mbank';
  static const String paymentCard = 'card';
  static const String paymentGooglePlay = 'google_play';

  // Storage Keys
  static const String keyUserProfile = 'user_profile';
  static const String keyLanguage = 'language';
  static const String keyThemeMode = 'theme_mode';
  static const String keyOnboardingCompleted = 'onboarding_completed';

  // Firestore Collections
  static const String collectionUsers = 'users';
  static const String collectionSubjects = 'subjects';
  static const String collectionLessons = 'lessons';
  static const String collectionQuestions = 'questions';
  static const String collectionMockTests = 'mock_tests';
  static const String collectionUserAttempts = 'user_attempts';
  static const String collectionPayments = 'payments';
  static const String collectionFlashcards = 'flashcards';
  static const String collectionForumPosts = 'forum_posts';

  // External Links
  static const String urlTestingKG = 'https://testing.kg';
  static const String urlOrtKG = 'https://ort.kg';
  static const String urlCOOMO = 'https://coomocenter.kg';

  // Gamification
  static const int dailyGoalQuestions = 20;
  static const int streakBonusPoints = 5;

  // Score Thresholds
  static const int scoreExcellent = 180;
  static const int scoreGood = 160;
  static const int scoreAverage = 120;
  static const int scorePassable = 90;

  // SRS Algorithm (Flashcards)
  static const List<int> srsIntervals = [1, 3, 7, 14, 30, 90];

  // Pagination
  static const int lessonsPerPage = 10;
  static const int questionsPerPage = 20;

  // Cache Duration
  static const Duration cacheDuration = Duration(hours: 24);

  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
}
