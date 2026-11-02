import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_paths.dart';
import '../../../exam/presentation/pages/exams_tab_page.dart';
import '../../../exam/presentation/widgets/exam_common.dart';

/// Legacy entry point (`/mock-test/:id`, used by the dashboard). The old
/// page described a hard-coded exam structure and its "Начать" button did
/// nothing; it now forwards to the blueprint-driven exam catalog, where
/// every variant leads to the real timed runner.
class MockTestPage extends StatelessWidget {
  /// Kept for route compatibility; legacy ids (e.g. `demo`) do not map to
  /// exam variants, so the catalog is shown for every id.
  final String testId;

  const MockTestPage({
    super.key,
    required this.testId,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.examMockTitle),
        actions: [
          IconButton(
            tooltip: l.examHistoryAction,
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(RoutePaths.examHistory),
          ),
        ],
      ),
      body: const ExamCatalogView(),
    );
  }
}
