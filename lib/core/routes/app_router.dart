import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/account_routes.dart';
import '../../features/admin/admin_routes.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/billing/billing_routes.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/exam/exam_routes.dart';
import '../../features/gamification/gamification_routes.dart';
import '../../features/gamification/presentation/pages/achievements_page.dart';
import '../../features/handbook/presentation/pages/handbook_content_page.dart';
import '../../features/handbook/presentation/pages/handbook_page.dart';
import '../../features/legal/legal_routes.dart';
import '../../features/lessons/presentation/pages/daily_lesson_page.dart';
import '../../features/lessons/presentation/pages/lesson_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/progress/presentation/pages/progress_page.dart';
import '../../features/quiz/presentation/pages/quick_test_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/quiz/presentation/pages/quiz_results_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/social/social_routes.dart';
import '../../features/subjects/presentation/pages/subject_detail_page.dart';
import '../../features/subjects/presentation/pages/subjects_list_page.dart';
import '../../features/tutor/tutor_routes.dart';
import '../../l10n/app_localizations.dart';
import '../design/tokens.dart';
import '../navigation/app_shell.dart';
import '../navigation/nav_helpers.dart';
import '../navigation/route_guards.dart';
import '../navigation/safe_pop_router.dart';
import '../network/firebase_service.dart';
import 'admin_session.dart';
import 'route_paths.dart';

/// Builds the app's single [GoRouter] (created once by `appRouterProvider`
/// in main.dart — NAV-03).
///
/// Layout:
///  * entry screens (splash, onboarding, login, signup);
///  * a [StatefulShellRoute.indexedStack] with five lazily built tabs —
///    Home, Learn, Exams, Progress, Profile;
///  * full-screen drill-down routes on the root navigator (subject, lesson,
///    quiz, results, settings, …) plus the routes contributed by the feature
///    packages (exam, billing, tutor, account, gamification, admin).
///
/// Redirect rules live in [RouteGuards] (pure, unit-tested).
class AppRouter {
  AppRouter._();

  // Legacy names kept so pages that still reference `AppRouter.x` compile.
  // New code should use [RoutePaths].
  static const String splash = RoutePaths.splash;
  static const String onboarding = RoutePaths.onboarding;
  static const String login = RoutePaths.login;
  static const String signup = RoutePaths.signup;
  static const String home = RoutePaths.home;
  static const String dashboard = RoutePaths.home;
  static const String subjects = RoutePaths.learn;
  static const String learn = RoutePaths.learn;
  static const String exams = RoutePaths.exams;
  static const String profile = RoutePaths.profile;
  static const String progress = RoutePaths.progress;
  static const String subjectDetail = RoutePaths.subjectDetail;
  static const String lesson = RoutePaths.lesson;
  static const String quiz = RoutePaths.quiz;
  static const String quizResults = RoutePaths.quizResults;
  static const String quickTest = RoutePaths.quickTest;
  static const String dailyLesson = RoutePaths.dailyLesson;
  static const String mockTest = '/mock-test/:id'; // redirected to exams
  static const String payments = RoutePaths.store;
  static const String settings = RoutePaths.settings;
  static const String achievements = RoutePaths.achievements;
  static const String handbookDetail = RoutePaths.handbookDetail;
  static const String adminLogin = RoutePaths.adminLogin;
  static const String adminDashboard = RoutePaths.adminDashboard;
  static const String adminGenerateQuestions = '/admin/generate-questions';

  /// Handbook index (was a bottom tab before the 5-tab shell). Not part of
  /// [RoutePaths] yet.
  static const String handbookIndex = '/handbook';

  /// Creates the router.
  ///
  /// [isSignedIn] defaults to Firebase Auth's current user; tests pass a
  /// fake. [refreshListenable] must fire on auth changes and on
  /// [adminVerified] changes (main.dart merges both).
  static GoRouter createRouter({
    bool Function()? isSignedIn,
    ValueListenable<bool>? adminSession,
    Listenable? refreshListenable,
    String initialLocation = RoutePaths.splash,
    bool enableAnalytics = true,
    GlobalKey<NavigatorState>? navigatorKey,
  }) {
    final signedIn = isSignedIn ?? _firebaseSignedIn;
    final admin = adminSession ?? adminVerified;
    List<NavigatorObserver> observers() {
      if (!enableAnalytics) return const [];
      final observer = FirebaseService.createAnalyticsObserver();
      return observer == null ? const [] : [observer];
    }

    return SafePopGoRouter(
      navigatorKey: navigatorKey,
      initialLocation: initialLocation,
      debugLogDiagnostics: kDebugMode,
      refreshListenable: refreshListenable ?? admin,
      observers: observers(),
      redirect: (context, state) => RouteGuards.resolveRedirect(
        state.uri,
        signedIn: signedIn(),
        adminVerified: admin.value,
      ),
      routes: [
        // Entry
        GoRoute(
          path: RoutePaths.splash,
          name: 'splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: RoutePaths.onboarding,
          name: 'onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: RoutePaths.login,
          name: 'login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: RoutePaths.signup,
          name: 'signup',
          builder: (context, state) => const SignupPage(),
        ),

        // Bottom-tab shell
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              observers: observers(),
              routes: [
                GoRoute(
                  path: RoutePaths.home,
                  name: 'home',
                  builder: (context, state) => const DashboardPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              observers: observers(),
              routes: [
                GoRoute(
                  path: RoutePaths.learn,
                  name: 'learn',
                  builder: (context, state) => const SubjectsListPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              observers: observers(),
              routes: [
                GoRoute(
                  path: RoutePaths.exams,
                  name: 'exams',
                  builder: (context, state) => buildExamsTab(),
                ),
              ],
            ),
            StatefulShellBranch(
              observers: observers(),
              routes: [
                GoRoute(
                  path: RoutePaths.progress,
                  name: 'progress',
                  builder: (context, state) => const ProgressPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              observers: observers(),
              routes: [
                GoRoute(
                  path: RoutePaths.profile,
                  name: 'profile',
                  builder: (context, state) => const ProfilePage(),
                ),
              ],
            ),
          ],
        ),

        // Full-screen drill-downs (root navigator).
        _page(
          RoutePaths.subjectDetail,
          'subject_detail',
          (state) => SubjectDetailPage(subjectId: state.pathParameters['id']!),
        ),
        _page(
          RoutePaths.lesson,
          'lesson',
          (state) => LessonPage(lessonId: state.pathParameters['id']!),
        ),
        _page(
          RoutePaths.quiz,
          'quiz',
          (state) => QuizPage(quizId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: RoutePaths.quizResults,
          name: 'quiz_results',
          // Without a valid result payload (deep link, web reload) the page
          // would divide by zero; send the user home instead.
          redirect: (context, state) =>
              QuizResultsArgs.tryParse(state.extra) == null
                  ? RoutePaths.home
                  : null,
          builder: (context, state) {
            final args = QuizResultsArgs.tryParse(state.extra)!;
            return RootBackGuard(
              fallback: RouteGuards.popFallback(RoutePaths.quizResults),
              child: QuizResultsPage(
                totalQuestions: args.totalQuestions,
                correctAnswers: args.correctAnswers,
                totalTimeSeconds: args.totalTimeSeconds,
              ),
            );
          },
        ),
        _page(RoutePaths.quickTest, 'quick_test', (_) => const QuickTestPage()),
        _page(
          RoutePaths.dailyLesson,
          'daily_lesson',
          (_) => const DailyLessonPage(),
        ),
        _page(handbookIndex, 'handbook', (_) => const HandbookPage()),
        _page(
          RoutePaths.handbookDetail,
          'handbook_detail',
          (state) => HandbookContentPage(
            categoryId: state.pathParameters['categoryId']!,
          ),
        ),
        _page(
          RoutePaths.achievements,
          'achievements',
          (_) => const AchievementsPage(),
        ),
        _page(
          RoutePaths.settings,
          'settings',
          (_) => const SettingsPage(),
        ),

        // Feature packages.
        ...examRoutes,
        ...billingRoutes,
        ...legalRoutes,
        ...tutorRoutes,
        ...accountRoutes,
        ...gamificationRoutes,
        ...socialRoutes,
        ...adminRoutes,
      ],
      errorBuilder: (context, state) => const _NotFoundPage(),
    );
  }

  static bool _firebaseSignedIn() {
    if (!FirebaseService.isInitialized) return false;
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// A full-screen route on the root navigator. Android back on a page that
  /// was opened with `go()` (nothing below it) goes to the page's logical
  /// parent instead of closing the app.
  static GoRoute _page(
    String path,
    String name,
    Widget Function(GoRouterState state) build,
  ) {
    return GoRoute(
      path: path,
      name: name,
      builder: (context, state) => RootBackGuard(
        fallback: RouteGuards.popFallback(state.uri.path),
        child: build(state),
      ),
    );
  }
}

/// Typed view of the `extra` map QuickTestPage/QuizPage pass to
/// [RoutePaths.quizResults]. Tolerates missing or mistyped values.
@immutable
class QuizResultsArgs {
  const QuizResultsArgs({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalTimeSeconds,
  });

  final int totalQuestions;
  final int correctAnswers;
  final int totalTimeSeconds;

  static QuizResultsArgs? tryParse(Object? extra) {
    if (extra is QuizResultsArgs) return extra.totalQuestions > 0 ? extra : null;
    if (extra is! Map) return null;
    int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
    final total = asInt(extra['totalQuestions']);
    if (total == null || total <= 0) return null;
    final correct = (asInt(extra['correctAnswers']) ?? 0).clamp(0, total);
    final seconds = asInt(extra['totalTimeSeconds']) ?? 0;
    return QuizResultsArgs(
      totalQuestions: total,
      correctAnswers: correct,
      totalTimeSeconds: seconds < 0 ? 0 : seconds,
    );
  }
}

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.gutter(context)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_outlined,
                  size: 48,
                  color: context.tokens.textTertiary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.shellNotFoundTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.shellNotFoundMessage,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.tokens.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: Text(l.shellGoHome),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
