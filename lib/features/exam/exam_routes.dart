import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/route_paths.dart';
import 'presentation/pages/exam_history_page.dart';
import 'presentation/pages/exam_intro_page.dart';
import 'presentation/pages/exam_result_page.dart';
import 'presentation/pages/exam_review_page.dart';
import 'presentation/pages/exam_runner_page.dart';
import 'presentation/pages/exams_tab_page.dart';
import 'presentation/widgets/resume_banner.dart';

/// Integration point for the exam feature (owned by lib/features/exam).
/// The app router spreads [examRoutes] into its top-level (root navigator)
/// routes and uses [buildExamsTab] as the "Экзамены" tab root.
List<RouteBase> get examRoutes => [
      // Literal path first so it is never captured by a parameter route.
      GoRoute(
        path: RoutePaths.examHistory,
        builder: (context, state) => const ExamHistoryPage(),
      ),
      GoRoute(
        path: RoutePaths.examFresh,
        builder: (context, state) => ExamFreshIntroPage(
          blueprintId: state.pathParameters['blueprintId'] ?? '',
          language: state.uri.queryParameters['lang'],
        ),
      ),
      GoRoute(
        path: RoutePaths.examIntro,
        builder: (context, state) =>
            ExamIntroPage(variantId: state.pathParameters['variantId'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.examResult,
        builder: (context, state) =>
            ExamResultPage(attemptId: state.pathParameters['attemptId'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.examReview,
        builder: (context, state) =>
            ExamReviewPage(attemptId: state.pathParameters['attemptId'] ?? ''),
      ),
      GoRoute(
        path: RoutePaths.examRun,
        pageBuilder: (context, state) => MaterialPage<void>(
          key: state.pageKey,
          child: ExamRunnerPage(attemptId: state.pathParameters['attemptId'] ?? ''),
        ),
      ),
    ];

/// Root widget of the exams tab (catalog of blueprints/variants).
Widget buildExamsTab() => const ExamsTabPage();

/// Banner for the home screen that offers to resume an unfinished attempt.
/// Renders nothing when there is no attempt in progress.
Widget buildExamResumeBanner() => const ExamResumeBanner();
