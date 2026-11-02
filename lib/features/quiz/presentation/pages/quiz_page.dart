import 'package:flutter/material.dart';

import '../../../../core/utils/nav_utils.dart';
import '../../domain/practice_launch.dart';
import '../widgets/practice_session_view.dart';

/// Subject practice at `/quiz/:id` (`quizId` is the subject id).
///
/// Lesson practice and mistakes review reuse this route and pass a
/// [PracticeLaunch] (or a map with `questionIds`) as route `extra`.
class QuizPage extends StatelessWidget {
  final String quizId;

  const QuizPage({
    super.key,
    required this.quizId,
  });

  @override
  Widget build(BuildContext context) {
    final launch = PracticeLaunch.fromRoute(quizId, routeExtraOf(context));
    return PracticeSessionView(key: ValueKey('practice_$quizId'), launch: launch);
  }
}
