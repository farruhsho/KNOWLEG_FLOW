import 'package:flutter/material.dart';

import '../../domain/practice_launch.dart';
import '../widgets/practice_session_view.dart';

/// Quick practice: a random set across all subjects, instant feedback after
/// every answer, elapsed time (no fake countdown).
class QuickTestPage extends StatelessWidget {
  const QuickTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PracticeSessionView(launch: PracticeLaunch.quick());
  }
}
