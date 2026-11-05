import '../../../core/content/topic_names.dart';
import '../../../core/utils/bishkek_time.dart';

/// Subject leaderboards the server writes (ARCHITECTURE §1.7, decision D10):
/// `leaderboards/subject_{id}_weekly_{YYYY}-W{ww}`, exam XP only, keyed by
/// the blueprint `subject_id` (`main` = the ORT main test). The learning
/// `subjects` collection uses different ids (russian, kyrgyz, …) and must
/// not be used to build these board ids (GAM-X2 / UX-03).
abstract final class SubjectBoards {
  static const main = 'main';

  /// In display order.
  static const ids = <String>[
    main,
    'math',
    'chemistry',
    'biology',
    'physics',
    'history',
    'english',
    'kyrgyz_lit',
    'russian_lit',
    'state_language',
  ];

  /// Weekly board id for [subjectId] in the ISO week of [now] (Bishkek).
  static String weeklyBoardId(String subjectId, DateTime now) =>
      BishkekTime.subjectWeeklyBoardId(subjectId, now);

  /// Chip label: [mainTestLabel] for the main test, otherwise the curriculum
  /// name of the subject (never the raw id).
  static String label(String subjectId, {required TopicNames names, required String lang, required String mainTestLabel}) =>
      subjectId == main ? mainTestLabel : names.label(subjectId, lang);
}
