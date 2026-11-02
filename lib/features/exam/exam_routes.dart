import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Integration point for the exam feature (owned by lib/features/exam).
/// The app router spreads [examRoutes] into its top-level (root navigator)
/// routes and uses [buildExamsTab] as the "Экзамены" tab root.
List<RouteBase> get examRoutes => const [];

/// Root widget of the exams tab (catalog of blueprints/variants).
Widget buildExamsTab() => const SizedBox.shrink();

/// Banner for the home screen that offers to resume an unfinished attempt.
/// Renders nothing when there is no attempt in progress.
Widget buildExamResumeBanner() => const SizedBox.shrink();
