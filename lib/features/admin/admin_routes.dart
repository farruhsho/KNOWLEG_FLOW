import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes/admin_session.dart';
import '../../core/routes/route_paths.dart';
import 'domain/admin_nav.dart';
import 'domain/exam_question.dart';
import 'presentation/pages/admin_achievements_page.dart';
import 'presentation/pages/admin_dashboard_page.dart';
import 'presentation/pages/admin_login_page.dart';
import 'presentation/pages/admin_notifications_page.dart';
import 'presentation/pages/ai_drafts_page.dart';
import 'presentation/pages/exam_bank_page.dart';
import 'presentation/pages/exam_pool_page.dart';
import 'presentation/pages/exam_question_editor_page.dart';
import 'presentation/pages/lesson_editor_page.dart';
import 'presentation/pages/lessons_page.dart';
import 'presentation/pages/ops_pages.dart';
import 'presentation/pages/practice_question_editor_page.dart';
import 'presentation/pages/practice_questions_page.dart';
import 'presentation/pages/promo_codes_page.dart';
import 'presentation/pages/subjects_page.dart';
import 'presentation/pages/users_page.dart';
import 'presentation/pages/variant_builder_page.dart';
import 'presentation/pages/variants_page.dart';
import 'presentation/shell/admin_shell.dart';

/// Defence in depth: the app router already gates `/admin/*`, but every admin
/// route checks the verified session again.
String? _requireAdmin(BuildContext context, GoRouterState state) {
  final signedIn = FirebaseAuth.instance.currentUser != null;
  return signedIn && adminVerified.value ? null : RoutePaths.adminLogin;
}

Widget _sectionPage(AdminSection section) => switch (section) {
      AdminSection.dashboard => const AdminDashboardPage(),
      AdminSection.subjects => const SubjectsPage(),
      AdminSection.lessons => const LessonsPage(),
      AdminSection.practiceQuestions => const PracticeQuestionsPage(),
      AdminSection.examBank => const ExamBankPage(),
      AdminSection.variants => const VariantsPage(),
      AdminSection.examPool => const ExamPoolPage(),
      AdminSection.aiDrafts => const AiDraftsPage(),
      AdminSection.users => const UsersPage(),
      AdminSection.payments => const PaymentsPage(),
      AdminSection.pricing => const PricingPage(),
      AdminSection.logs => const AdminLogsPage(),
      AdminSection.notifications => const AdminNotificationsPage(),
      AdminSection.promoCodes => const PromoCodesPage(),
      AdminSection.achievements => const AdminAchievementsPage(),
    };

/// Full-screen editor route (outside the shell, on the root navigator).
GoRoute _editor(String path, AdminSection section, Widget Function(GoRouterState s) build) =>
    GoRoute(
      path: path,
      redirect: _requireAdmin,
      builder: (context, state) => AdminGate(section: section, standalone: true, child: build(state)),
    );

/// Integration point for the admin CMS (owned by lib/features/admin). Every
/// path here starts with /admin so the router's admin gate applies.
List<RouteBase> get adminRoutes => [
      GoRoute(
        path: RoutePaths.adminLogin,
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const AdminLoginPage(),
        ),
      ),
      GoRoute(path: '/admin', redirect: (_, __) => RoutePaths.adminDashboard),
      // Legacy entry of the removed template generator (CMS-01).
      GoRoute(path: '/admin/generate-questions', redirect: (_, __) => AdminSection.aiDrafts.path),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          for (final section in AdminSection.values)
            GoRoute(
              path: section.path,
              redirect: _requireAdmin,
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                child: AdminGate(section: section, child: _sectionPage(section)),
              ),
            ),
        ],
      ),
      _editor('/admin/lessons/:lessonId', AdminSection.lessons, (s) => LessonEditorPage(
            lessonId: s.pathParameters['lessonId']!,
            subjectId: s.uri.queryParameters['subject'],
          )),
      _editor('/admin/questions/:questionId', AdminSection.practiceQuestions,
          (s) => PracticeQuestionEditorPage(questionId: s.pathParameters['questionId']!)),
      _editor('/admin/exam-bank/:questionId', AdminSection.examBank, (s) => ExamQuestionEditorPage(
            questionId: s.pathParameters['questionId']!,
            prefill: s.extra is ExamQuestionDoc ? s.extra as ExamQuestionDoc : null,
          )),
      _editor('/admin/variants/:variantId', AdminSection.variants,
          (s) => VariantBuilderPage(variantId: s.pathParameters['variantId']!)),
      _editor('/admin/users/:uid', AdminSection.users, (s) => UserDetailPage(uid: s.pathParameters['uid']!)),
    ];
