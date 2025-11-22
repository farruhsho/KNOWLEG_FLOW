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
import '../../features/mock_test/presentation/pages/mock_test_page.dart';
import '../../features/lessons/presentation/pages/lesson_page.dart';
import '../../features/gamification/presentation/pages/achievements_page.dart';
import '../../features/admin/presentation/pages/admin_login_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_generate_questions_page.dart';
import '../../screens/task_list_screen.dart';
import '../../screens/task_detail_screen.dart';
import '../../providers/task_provider.dart';

class AppRouter {
  // Custom page transition builders
  static CustomTransitionPage _buildPageWithSlideTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static CustomTransitionPage _buildPageWithFadeTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static CustomTransitionPage _buildPageWithScaleTransition({
    required Widget child,
    required GoRouterState state,
  }) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );
        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

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
  static const String achievements = '/achievements';
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminGenerateQuestions = '/admin/generate-questions';

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
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildPageWithSlideTransition(
              child: SubjectDetailPage(subjectId: id),
              state: state,
            );
          },
        ),
        GoRoute(
          path: lesson,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildPageWithSlideTransition(
              child: LessonPage(lessonId: id),
              state: state,
            );
          },
        ),
        GoRoute(
          path: quiz,
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildPageWithFadeTransition(
              child: QuizPage(quizId: id),
              state: state,
            );
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
        GoRoute(
          path: achievements,
          pageBuilder: (context, state) {
            return _buildPageWithSlideTransition(
              child: const AchievementsPage(),
              state: state,
            );
          },
        ),
        // Task routes
        GoRoute(
          path: tasks,
          pageBuilder: (context, state) {
            return _buildPageWithSlideTransition(
              child: const TaskListScreen(),
              state: state,
            );
          },
        ),
        GoRoute(
          path: taskDetail,
          pageBuilder: (context, state) {
            final taskId = state.pathParameters['id']!;
            return _buildPageWithSlideTransition(
              child: TaskDetailScreen(taskId: taskId),
              state: state,
            );
          },
        ),
        // Admin routes
        GoRoute(
          path: adminLogin,
          pageBuilder: (context, state) {
            return _buildPageWithFadeTransition(
              child: const AdminLoginPage(),
              state: state,
            );
          },
        ),
        GoRoute(
          path: adminDashboard,
          pageBuilder: (context, state) {
            return _buildPageWithSlideTransition(
              child: const AdminDashboardPage(),
              state: state,
            );
          },
        ),
        GoRoute(
          path: adminGenerateQuestions,
          pageBuilder: (context, state) {
            return _buildPageWithSlideTransition(
              child: const AdminGenerateQuestionsPage(),
              state: state,
            );
          },
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
