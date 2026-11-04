import 'package:flutter/foundation.dart';

import '../../../core/utils/bishkek_time.dart';

/// One completed mock exam, as far as the motivation rule needs it.
@immutable
class ExamPoint {
  final String attemptId;

  /// Blueprint without the year (`ort_main` for `ort_main_2026`): results
  /// are only compared within the same direction.
  final String direction;
  final double percent;
  final DateTime? completedAt;

  const ExamPoint({
    required this.attemptId,
    required this.direction,
    required this.percent,
    this.completedAt,
  });

  static String directionOf(String blueprintId) =>
      blueprintId.replaceFirst(RegExp(r'_\d{4}$'), '');
}

enum MotivationRiskReason {
  /// No server-recorded activity for [MotivationRules.inactiveDays] or more
  /// Bishkek calendar days.
  inactive,

  /// The latest completed mock exam scored lower than the previous one in
  /// the same direction.
  decliningResults,
}

/// Why the app nudges the student (ARCHITECTURE §9.5). Only built from real
/// data; never shown for a brand-new account with nothing recorded.
@immutable
class MotivationRisk {
  final Set<MotivationRiskReason> reasons;

  /// Whole Bishkek days since `user_stats.last_active_day` (inactive only).
  final int? inactiveDays;

  /// Previous and latest percent of the same direction (declining only).
  final double? previousPercent;
  final double? latestPercent;

  /// The latest completed attempt (to open its review).
  final String? latestAttemptId;

  const MotivationRisk({
    required this.reasons,
    this.inactiveDays,
    this.previousPercent,
    this.latestPercent,
    this.latestAttemptId,
  });

  bool get isInactive => reasons.contains(MotivationRiskReason.inactive);
  bool get isDeclining => reasons.contains(MotivationRiskReason.decliningResults);
}

/// Pure rules for the motivation-risk card (progress page and home).
abstract final class MotivationRules {
  /// "Нет активности ≥ 3 дней".
  static const inactiveDays = 3;

  /// Whole days between the Bishkek day [dayKey] (`YYYY-MM-DD`) and the
  /// Bishkek day of [now]. Null for a missing or malformed key.
  static int? daysSince(String? dayKey, DateTime now) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dayKey?.trim() ?? '');
    if (m == null) return null;
    final day = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    final w = BishkekTime.wallClock(now);
    final today = DateTime.utc(w.year, w.month, w.day);
    return today.difference(day).inDays;
  }

  /// The risk for the given data, or null when there is nothing to warn
  /// about. [exams] may be in any order.
  static MotivationRisk? evaluate({
    required String? lastActiveDay,
    required List<ExamPoint> exams,
    required DateTime now,
  }) {
    final reasons = <MotivationRiskReason>{};
    final days = daysSince(lastActiveDay, now);
    if (days != null && days >= inactiveDays) reasons.add(MotivationRiskReason.inactive);

    final sorted = [...exams]..sort((a, b) {
        final at = a.completedAt?.millisecondsSinceEpoch ?? 0;
        final bt = b.completedAt?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
    ExamPoint? latest;
    ExamPoint? previous;
    if (sorted.isNotEmpty) {
      latest = sorted.first;
      for (final e in sorted.skip(1)) {
        if (e.direction == latest.direction) {
          previous = e;
          break;
        }
      }
      if (previous != null && latest.percent < previous.percent) {
        reasons.add(MotivationRiskReason.decliningResults);
      }
    }
    if (reasons.isEmpty) return null;
    final declining = reasons.contains(MotivationRiskReason.decliningResults);
    return MotivationRisk(
      reasons: Set.unmodifiable(reasons),
      inactiveDays: reasons.contains(MotivationRiskReason.inactive) ? days : null,
      previousPercent: declining ? previous!.percent : null,
      latestPercent: declining ? latest!.percent : null,
      latestAttemptId: latest?.attemptId,
    );
  }
}
