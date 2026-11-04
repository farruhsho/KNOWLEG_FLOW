import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/bishkek_time.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/lesson_model.dart';
import '../../../../shared/services/firebase_data_service.dart';
import '../../domain/daily_lesson_picker.dart';
import '../widgets/lesson_screen.dart';

/// "Урок дня": a different lesson every Bishkek day, the same one all day
/// (CMS-11). Content managers can pin a lesson for a date in
/// `daily_lessons/{YYYY-MM-DD}`; otherwise a deterministic rotation picks one.
class DailyLessonPage extends StatelessWidget {
  const DailyLessonPage({super.key});

  static const _prefsKey = 'learn_daily_lesson_v1';

  static Future<LessonModel?> resolveToday() async {
    final data = FirebaseDataService();
    final now = DateTime.now();
    final dayKey = BishkekTime.dayKey(now);

    final assigned = await data.getAssignedDailyLessonId(dayKey);
    if (assigned != null) {
      final lesson = await data.getLessonById(assigned);
      if (lesson != null) return lesson;
    }

    // Keep today's pick stable even after the student completes it.
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.startsWith('$dayKey|')) {
        final lesson = await data.getLessonById(saved.substring(dayKey.length + 1));
        if (lesson != null) return lesson;
      }
    } catch (_) {
      prefs = null;
    }

    final lessons = await data.getAllLessons();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final progress = uid == null ? null : await data.getUserProgress(uid);
    final pick = DailyLessonPicker.pick(
      lessons,
      dayNumber: BishkekTime.dayNumber(now),
      completed: {...?progress?.completedLessons},
    );
    if (pick != null) {
      try {
        await prefs?.setString(_prefsKey, '$dayKey|${pick.id}');
      } catch (_) {
        // Remembering the pick is a convenience; the rotation is deterministic anyway.
      }
    }
    return pick;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return LessonScreen(
      loadLesson: resolveToday,
      titleOverride: l.learnDailyLessonTitle,
    );
  }
}
