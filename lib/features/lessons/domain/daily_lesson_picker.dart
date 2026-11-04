import '../../../shared/models/lesson_model.dart';

/// Deterministic "lesson of the day" (CMS-11).
///
/// Lessons are put in a stable pseudo-random order (FNV-1a hash of the id,
/// identical on every device), and day N of the Bishkek calendar picks
/// position `N mod count`. Consecutive days therefore get different lessons
/// and no lesson repeats until the whole cycle has been shown. When the
/// picked lesson is already completed the next uncompleted one in the cycle
/// is used; if everything is completed the plain rotation applies.
abstract final class DailyLessonPicker {
  static LessonModel? pick(
    List<LessonModel> lessons, {
    required int dayNumber,
    Set<String> completed = const {},
  }) {
    final ordered = cycle(lessons);
    if (ordered.isEmpty) return null;
    final n = ordered.length;
    final start = dayNumber % n;
    for (var i = 0; i < n; i++) {
      final l = ordered[(start + i) % n];
      if (!completed.contains(l.id)) return l;
    }
    return ordered[start];
  }

  /// The stable rotation order (unique ids only).
  static List<LessonModel> cycle(List<LessonModel> lessons) {
    final seen = <String>{};
    final unique = [for (final l in lessons) if (l.id.isNotEmpty && seen.add(l.id)) l];
    unique.sort((a, b) {
      final c = fnv1a(a.id).compareTo(fnv1a(b.id));
      return c != 0 ? c : a.id.compareTo(b.id);
    });
    return unique;
  }

  /// 32-bit FNV-1a over UTF-16 code units.
  static int fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}
