import 'package:flutter/foundation.dart';

import 'exam_payload.dart';
import 'json_utils.dart';

/// Read-only view of an `exam_attempts/{id}` document (written only by Cloud
/// Functions). The data layer converts Firestore Timestamps to epoch ms
/// before calling [AttemptSummary.fromJson].
@immutable
class AttemptSummary {
  final String id;
  final String variantId;
  final String blueprintId;
  final String language;
  final String status;
  final int currentSectionIndex;
  final String? currentSectionId;
  final int? currentDeadlineAtMs;
  final int sectionCount;
  final int? startedAtMs;
  final int? completedAtMs;
  final ExamResult? result;

  const AttemptSummary({
    required this.id,
    required this.variantId,
    required this.blueprintId,
    required this.language,
    required this.status,
    this.currentSectionIndex = 0,
    this.currentSectionId,
    this.currentDeadlineAtMs,
    this.sectionCount = 0,
    this.startedAtMs,
    this.completedAtMs,
    this.result,
  });

  bool get isInProgress => status == 'in_progress';
  bool get isCompleted =>
      (status == 'completed' || status == 'expired') && result != null;

  double? get percent => result?.percent;

  factory AttemptSummary.fromJson(String id, Map<String, dynamic> m) {
    final res = m['result'];
    return AttemptSummary(
      id: id,
      variantId: asString(m['variant_id']) ?? '',
      blueprintId: asString(m['blueprint_id']) ?? '',
      language: asString(m['language']) ?? 'ru',
      status: asString(m['status']) ?? 'in_progress',
      currentSectionIndex: asInt(m['current_section_index']) ?? 0,
      currentSectionId: asString(m['current_section_id']),
      currentDeadlineAtMs: asEpochMs(m['current_deadline_at']),
      sectionCount: asJsonList(m['sections']).length,
      startedAtMs: asEpochMs(m['started_at']),
      completedAtMs: asEpochMs(m['completed_at']),
      result: res is Map ? ExamResult.fromJson(res) : null,
    );
  }
}

/// Status of a variant for the current user, derived from their attempts.
@immutable
class VariantAttemptStatus {
  final String? inProgressAttemptId;
  final int completedCount;
  final double? bestPercent;
  final String? lastCompletedAttemptId;

  const VariantAttemptStatus({
    this.inProgressAttemptId,
    this.completedCount = 0,
    this.bestPercent,
    this.lastCompletedAttemptId,
  });

  static const none = VariantAttemptStatus();

  bool get isInProgress => inProgressAttemptId != null;
  bool get isCompleted => completedCount > 0;

  /// Groups [attempts] by variant id.
  static Map<String, VariantAttemptStatus> fromAttempts(
      Iterable<AttemptSummary> attempts) {
    final byVariant = <String, List<AttemptSummary>>{};
    for (final a in attempts) {
      byVariant.putIfAbsent(a.variantId, () => []).add(a);
    }
    return byVariant.map((variantId, list) {
      String? inProgress;
      double? best;
      var completed = 0;
      AttemptSummary? last;
      for (final a in list) {
        if (a.isInProgress) inProgress = a.id;
        if (a.isCompleted) {
          completed++;
          final p = a.percent ?? 0;
          if (best == null || p > best) best = p;
          if (last == null || (a.completedAtMs ?? 0) > (last.completedAtMs ?? 0)) {
            last = a;
          }
        }
      }
      return MapEntry(
        variantId,
        VariantAttemptStatus(
          inProgressAttemptId: inProgress,
          completedCount: completed,
          bestPercent: best,
          lastCompletedAttemptId: last?.id,
        ),
      );
    });
  }
}

/// Best / last result per blueprint, for the history header.
@immutable
class BlueprintTrend {
  final String blueprintId;
  final double last;
  final double best;

  /// `last - previous`; null when only one attempt exists.
  final double? delta;
  final int attempts;

  const BlueprintTrend({
    required this.blueprintId,
    required this.last,
    required this.best,
    required this.delta,
    required this.attempts,
  });

  /// [completed] must be ordered newest first.
  static List<BlueprintTrend> fromAttempts(List<AttemptSummary> completed) {
    final byBp = <String, List<AttemptSummary>>{};
    for (final a in completed) {
      if (a.result == null) continue;
      byBp.putIfAbsent(a.blueprintId, () => []).add(a);
    }
    return byBp.entries.map((e) {
      final list = e.value;
      final last = list.first.percent ?? 0;
      final best = list
          .map((a) => a.percent ?? 0)
          .fold<double>(0, (m, p) => p > m ? p : m);
      return BlueprintTrend(
        blueprintId: e.key,
        last: last,
        best: best,
        delta: list.length > 1 ? last - (list[1].percent ?? 0) : null,
        attempts: list.length,
      );
    }).toList(growable: false);
  }
}
