import '../../../shared/models/practice_session_model.dart';
import '../../../shared/services/activity_reporter.dart';

/// Keeps the last finished practice session in memory so the results page
/// can show details (review list, retry target, server XP) even though the
/// router only passes three numbers through `extra`, and can still render
/// something meaningful after a refresh without `extra` (EXAM-15).
class PracticeSessionStore {
  PracticeSessionStore._();
  static final PracticeSessionStore instance = PracticeSessionStore._();

  PracticeSessionResult? _last;
  Future<ActivityResult?>? _lastXp;

  PracticeSessionResult? get last => _last;
  Future<ActivityResult?>? get lastXp => _lastXp;

  void put(PracticeSessionResult result, Future<ActivityResult?>? xp) {
    _last = result;
    _lastXp = xp;
  }

  /// The stored session if it matches the numbers the page was opened with
  /// (or any stored session when the page was opened without numbers).
  PracticeSessionResult? matching({required int total, required int correct}) {
    final l = _last;
    if (l == null) return null;
    if (total == 0) return l;
    return (l.total == total && l.correct == correct) ? l : null;
  }
}
