import 'package:flutter/material.dart';

import '../../../../shared/services/firebase_data_service.dart';
import '../widgets/lesson_screen.dart';

class LessonPage extends StatelessWidget {
  final String lessonId;

  const LessonPage({
    super.key,
    required this.lessonId,
  });

  @override
  Widget build(BuildContext context) {
    return LessonScreen(
      key: ValueKey('lesson_$lessonId'),
      loadLesson: () => FirebaseDataService().getLessonById(lessonId),
    );
  }
}
