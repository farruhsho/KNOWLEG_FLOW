/// Every route path in the app. Never navigate with string literals — use
/// these constants (or the builder helpers) so a typo cannot dead-end on
/// "Page not found".
abstract final class RoutePaths {
  // Entry
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';

  // Bottom-tab shell roots
  static const home = '/home';
  static const learn = '/learn';
  static const exams = '/exams';
  static const progress = '/progress';
  static const profile = '/profile';

  // Learning (existing pages)
  static const subjectDetail = '/subjects/:id';
  static String subject(String id) => '/subjects/$id';
  static const lesson = '/lessons/:id';
  static String lessonById(String id) => '/lessons/$id';
  static const dailyLesson = '/daily-lesson';
  static const quiz = '/quiz/:id';
  static String quizById(String id) => '/quiz/$id';
  static const quizResults = '/quiz-results';
  static const quickTest = '/quick-test';
  static const handbookDetail = '/handbook/:categoryId';
  static String handbook(String categoryId) => '/handbook/$categoryId';

  // Exams (lib/features/exam)
  static const examIntro = '/exams/variant/:variantId';
  static String examIntroFor(String variantId) => '/exams/variant/$variantId';
  static const examRun = '/exams/attempt/:attemptId';
  static String examRunFor(String attemptId) => '/exams/attempt/$attemptId';
  static const examResult = '/exams/attempt/:attemptId/result';
  static String examResultFor(String attemptId) => '/exams/attempt/$attemptId/result';
  static const examReview = '/exams/attempt/:attemptId/review';
  static String examReviewFor(String attemptId) => '/exams/attempt/$attemptId/review';
  static const examHistory = '/exams/history';

  /// Rules / style / language screen of a fresh variant (§10.1). `lang` is
  /// the preselected content language.
  static const examFresh = '/exams/new/:blueprintId';
  static String examFreshFor(String blueprintId, {String? language}) => Uri(
        path: '/exams/new/$blueprintId',
        queryParameters: language == null ? null : {'lang': language},
      ).toString();

  // Billing (lib/features/billing)
  static const store = '/store';
  static const transactions = '/store/transactions';

  /// Web payments (BILLING_MODE=web, §10.3): the payment provider returns
  /// here with `?order={orderId}`.
  static const payReturn = '/pay/return';

  // Legal documents (lib/features/legal), shown next to the web pay button.
  static const legalOffer = '/legal/offer';
  static const legalRefund = '/legal/refund';

  // AI tutor (lib/features/tutor)
  static const tutor = '/tutor';

  // Gamification
  static const achievements = '/achievements';
  static const leaderboard = '/leaderboard';
  static const mistakes = '/mistakes';

  // Social & growth (ARCHITECTURE §9)
  static const invite = '/invite';
  static const groups = '/groups';
  static const groupDetail = '/groups/:groupId';
  static String groupById(String groupId) => '/groups/$groupId';

  // Settings & account
  static const settings = '/settings';
  static const accountDelete = '/account/delete';

  // Admin (lib/features/admin) — everything under /admin is gated by the router.
  static const adminLogin = '/admin/login';
  static const adminDashboard = '/admin/dashboard';
  static const adminNotifications = '/admin/notifications';
  static const adminPromoCodes = '/admin/promo-codes';
  static const adminAchievements = '/admin/achievements';

  // Phase 4 (ARCHITECTURE §10.1): fresh-variant pool settings and health.
  static const adminExamPool = '/admin/exam-pool';
}
