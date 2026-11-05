import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/admin_nav.dart';
import '../widgets/admin_widgets.dart';

/// Legacy `/admin/generate-questions` entry point (CMS-01 / FB-06).
///
/// The old screen wrote 100 template questions with rotated answer keys into
/// an in-memory service and reported success. Question generation now lives
/// in the AI drafts flow (`adminAiDraftQuestions` → review as `draft`), so
/// this page only forwards there.
class AdminGenerateQuestionsPage extends StatefulWidget {
  const AdminGenerateQuestionsPage({super.key});

  @override
  State<AdminGenerateQuestionsPage> createState() => _AdminGenerateQuestionsPageState();
}

class _AdminGenerateQuestionsPageState extends State<AdminGenerateQuestionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(AdminSection.aiDrafts.path);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: AdminLoadingView());
}
