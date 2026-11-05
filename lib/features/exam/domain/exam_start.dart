import 'package:flutter/foundation.dart';

import 'json_utils.dart';

/// How `examStart` picks the questions (ARCHITECTURE §10.1).
enum ExamMode {
  /// A published variant from the library (`variantId`), as before.
  library,

  /// A new variant assembled by the server from the verified bank for this
  /// attempt (`blueprintId` + `language`).
  fresh;

  String get wire => name;
}

/// Rules the attempt runs under (ARCHITECTURE §10.2).
enum ExamStyle {
  /// «Тренировка»: flags, free answer changes, finish a section early.
  standard,

  /// «Как на ОРТ»: a section ends only at its deadline, an answer can be
  /// corrected once, no flags, an instruction screen before every section.
  strict;

  String get wire => name;

  bool get isStrict => this == strict;

  /// Unknown or missing values mean [standard] (the server default).
  static ExamStyle parse(Object? v) =>
      asString(v)?.trim().toLowerCase() == 'strict' ? strict : standard;

  /// Null when [v] is absent (lets callers fall back to what they asked for).
  static ExamStyle? tryParse(Object? v) {
    final s = asString(v)?.trim().toLowerCase();
    return switch (s) {
      'strict' => strict,
      'standard' => standard,
      _ => null,
    };
  }
}

/// Input of `examStart`.
@immutable
class ExamStartRequest {
  final ExamMode mode;
  final String? variantId;
  final String? blueprintId;
  final String? language;
  final ExamStyle style;
  final String clientAppVersion;

  const ExamStartRequest.library({
    required String this.variantId,
    required this.clientAppVersion,
    this.style = ExamStyle.standard,
  })  : mode = ExamMode.library,
        blueprintId = null,
        language = null;

  const ExamStartRequest.fresh({
    required String this.blueprintId,
    required String this.language,
    required this.clientAppVersion,
    this.style = ExamStyle.standard,
  })  : mode = ExamMode.fresh,
        variantId = null;

  Map<String, dynamic> toCallableData() => {
        'mode': mode.wire,
        if (variantId != null) 'variantId': variantId,
        if (blueprintId != null) 'blueprintId': blueprintId,
        if (language != null) 'language': language,
        'examStyle': style.wire,
        'clientAppVersion': clientAppVersion,
      };
}

/// `examStart.freshness` of a fresh variant: how many of its [total]
/// questions the student already saw in earlier attempts.
@immutable
class ExamFreshness {
  final int total;
  final int repeated;

  const ExamFreshness({required this.total, required this.repeated});

  bool get hasRepeats => repeated > 0;

  static ExamFreshness? fromJson(Object? json) {
    if (json is! Map) return null;
    final m = asJsonMap(json);
    final total = asInt(m['total']);
    final repeated = asInt(m['repeated']);
    if (total == null || repeated == null || total < 0) return null;
    return ExamFreshness(total: total, repeated: repeated.clamp(0, total));
  }

  Map<String, dynamic> toJson() => {'total': total, 'repeated': repeated};

  @override
  bool operator ==(Object other) =>
      other is ExamFreshness && other.total == total && other.repeated == repeated;

  @override
  int get hashCode => Object.hash(total, repeated);
}

/// Client view of `config/exam_pool` (§10.1). Only [freshEnabled] matters to
/// students; a missing or unreadable document means "enabled".
@immutable
class ExamPoolConfig {
  final bool freshEnabled;
  final String minReviewStatus;

  const ExamPoolConfig({
    this.freshEnabled = true,
    this.minReviewStatus = 'methodologist_approved',
  });

  static const defaults = ExamPoolConfig();

  factory ExamPoolConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final fresh = data['fresh_enabled'] ?? data['freshEnabled'];
    final status = asString(data['min_review_status'] ?? data['minReviewStatus']);
    return ExamPoolConfig(
      freshEnabled: fresh is bool ? fresh : true,
      minReviewStatus: status == 'ai_verified' ? 'ai_verified' : 'methodologist_approved',
    );
  }
}
