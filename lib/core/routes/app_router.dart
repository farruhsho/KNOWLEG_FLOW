import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/signup_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/subjects/presentation/pages/subjects_page.dart';
import '../../features/subjects/presentation/pages/subject_detail_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/quiz/presentation/pages/quiz_results_page.dart';
import '../../features/mock_test/presentation/pages/mock_test_page.dart';
import '../../features/lessons/presentation/pages/lesson_page.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String subjects = '/subjects';
  static const String profile = '/profile';
  static const String subjectDetail = '/subjects/:id';
  static const String lesson = '/lessons/:id';
  static const String quiz = '/quiz/:id';
  static const String mockTest = '/mock-test/:id';
  static const String testReview = '/test-review/:id';
  static const String flashcards = '/flashcards/:subjectId';
  static const String payments = '/payments';
  static const String settings = '/settings';

  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: splash,
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: onboarding,
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: login,
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: signup,
          builder: (context, state) => const SignupPage(),
        ),
        GoRoute(
          path: dashboard,
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: subjects,
          builder: (context, state) => const SubjectsPage(),
        ),
        GoRoute(
          path: profile,
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: subjectDetail,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return SubjectDetailPage(subjectId: id);
          },
        ),
        GoRoute(
          path: lesson,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return LessonPage(lessonId: id);
          },
        ),
        GoRoute(
          path: quiz,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return QuizPage(quizId: id);
          },
        ),
        GoRoute(
          path: mockTest,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return MockTestPage(testId: id);
          },
        ),
        GoRoute(
          path: testReview,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return Scaffold(
              appBar: AppBar(title: const Text('Test Review')),
              body: Center(child: Text('Test Review Page - $id')),
            );
          },
        ),
        GoRoute(
          path: flashcards,
          builder: (context, state) {
            final subjectId = state.pathParameters['subjectId']!;
            return Scaffold(
              appBar: AppBar(title: const Text('Flashcards')),
              body: Center(child: Text('Flashcards Page - $subjectId')),
            );
          },
        ),
        GoRoute(
          path: payments,
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Payments')),
            body: const Center(child: Text('Payments Page')),
          ),
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const Center(child: Text('Settings Page')),
          ),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri.path}'),
        ),
      ),
    );
  }
}
