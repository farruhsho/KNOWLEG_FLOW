/// Fresh-variant pool (ARCHITECTURE.md §10.1) for the CMS: the settings in
/// `config/exam_pool` and the `adminExamPoolHealth` report.
///
/// * `config/exam_pool` = `{fresh_enabled (default true), min_review_status
///   ('methodologist_approved' default | 'ai_verified'), updated_at,
///   updated_by}` — read by every signed-in user, written only by
///   `adminUpdateExamPool({freshEnabled?, minReviewStatus?})` (super_admin).
/// * `adminExamPoolHealth({blueprintId, language})` (super_admin,
///   content_manager, methodologist) → `{sections: [{section_id, parts:
///   [{part_id, needed, available_by_status: {methodologist_approved,
///   ai_verified, draft}, eligible, passages: {standalone, paired, unknown},
///   disjoint_variants}]}], disjoint_variants, disjoint_variants_capped,
///   shortfalls: [...], freshEnabled, minReviewStatus}`.
///
/// Pure Dart (no Flutter / Firebase) so parsing and the derived numbers are
/// unit-tested.
library;

import 'exam_question.dart' show readDateTolerant;

/// `config/exam_pool.min_review_status`: the lowest review status a question
/// may have to enter a fresh variant.
enum MinReviewStatus {
  methodologistApproved('methodologist_approved'),

  /// Owner decision for the pilot: questions checked by an independent AI
  /// solver, **not** by a methodologist.
  aiVerified('ai_verified');

  const MinReviewStatus(this.wire);
  final String wire;

  /// Unknown or missing values fall back to the server default
  /// ([methodologistApproved]) — the stricter floor.
  static MinReviewStatus fromWire(Object? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return methodologistApproved;
  }
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? 0;
  return 0;
}

String _str(Object? v) => v is String ? v : (v == null ? '' : v.toString());

Map<String, dynamic> _map(Object? v) =>
    v is Map ? {for (final e in v.entries) e.key.toString(): e.value} : const {};

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) _map(e),
      ]
    : const [];

/// `config/exam_pool` as the CMS shows it.
class ExamPoolConfig {
  final bool freshEnabled;
  final MinReviewStatus minReviewStatus;
  final DateTime? updatedAt;
  final String? updatedBy;

  /// `false` when the document does not exist yet (server defaults apply).
  final bool exists;

  const ExamPoolConfig({
    required this.freshEnabled,
    required this.minReviewStatus,
    this.updatedAt,
    this.updatedBy,
    this.exists = true,
  });

  /// Server defaults (functions `parseExamPoolConfig`).
  static const ExamPoolConfig defaults = ExamPoolConfig(
    freshEnabled: true,
    minReviewStatus: MinReviewStatus.methodologistApproved,
    exists: false,
  );

  /// Same reading as the server: a non-boolean `fresh_enabled` means `true`,
  /// an unknown `min_review_status` means `methodologist_approved`.
  factory ExamPoolConfig.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return defaults;
    final by = raw['updated_by'];
    return ExamPoolConfig(
      freshEnabled: raw['fresh_enabled'] is bool ? raw['fresh_enabled'] as bool : true,
      minReviewStatus: MinReviewStatus.fromWire(raw['min_review_status']),
      updatedAt: readDateTolerant(raw['updated_at']),
      updatedBy: by is String && by.isNotEmpty ? by : null,
    );
  }

  ExamPoolConfig copyWith({bool? freshEnabled, MinReviewStatus? minReviewStatus}) => ExamPoolConfig(
        freshEnabled: freshEnabled ?? this.freshEnabled,
        minReviewStatus: minReviewStatus ?? this.minReviewStatus,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
        exists: exists,
      );
}

/// `adminUpdateExamPool` payload with only the fields that differ from
/// [current] (the server rejects an empty update). Empty map = nothing to do.
Map<String, Object> examPoolUpdatePayload(
  ExamPoolConfig current, {
  bool? freshEnabled,
  MinReviewStatus? minReviewStatus,
}) =>
    {
      if (freshEnabled != null && freshEnabled != current.freshEnabled) 'freshEnabled': freshEnabled,
      if (minReviewStatus != null && minReviewStatus != current.minReviewStatus)
        'minReviewStatus': minReviewStatus.wire,
    };

/// Questions of one slot by `review.status` (rejected ones are never counted).
class PoolStatusCounts {
  final int methodologistApproved;
  final int aiVerified;
  final int draft;

  const PoolStatusCounts({this.methodologistApproved = 0, this.aiVerified = 0, this.draft = 0});

  factory PoolStatusCounts.fromMap(Map<String, dynamic> m) => PoolStatusCounts(
        methodologistApproved: _int(m['methodologist_approved']),
        aiVerified: _int(m['ai_verified']),
        draft: _int(m['draft']),
      );

  int get total => methodologistApproved + aiVerified + draft;

  /// Questions whose status reaches [floor] (before the key / passage /
  /// topic checks that decide [PoolPartHealth.eligible]).
  int atLeast(MinReviewStatus floor) => switch (floor) {
        MinReviewStatus.methodologistApproved => methodologistApproved,
        MinReviewStatus.aiVerified => methodologistApproved + aiVerified,
      };
}

/// Eligible passages with enough questions, by `exam_passages.layout`.
class PoolPassageCounts {
  final int standalone;
  final int paired;

  /// Passages imported without a layout (the assembler may use them either way).
  final int unknown;

  const PoolPassageCounts({this.standalone = 0, this.paired = 0, this.unknown = 0});

  factory PoolPassageCounts.fromMap(Map<String, dynamic> m) => PoolPassageCounts(
        standalone: _int(m['standalone']),
        paired: _int(m['paired']),
        unknown: _int(m['unknown']),
      );

  int get total => standalone + paired + unknown;
}

class PoolPartHealth {
  final String partId;

  /// Questions this part has in one variant (blueprint `question_count`).
  final int needed;
  final PoolStatusCounts byStatus;

  /// Questions that may enter a variant now: status floor, answer key,
  /// passage document, topic in the matrix.
  final int eligible;
  final PoolPassageCounts passages;

  /// Fully disjoint variants this part alone could supply.
  final int disjointVariants;

  const PoolPartHealth({
    required this.partId,
    required this.needed,
    required this.byStatus,
    required this.eligible,
    required this.passages,
    required this.disjointVariants,
  });

  factory PoolPartHealth.fromMap(Map<String, dynamic> m) => PoolPartHealth(
        partId: _str(m['part_id']),
        needed: _int(m['needed']),
        byStatus: PoolStatusCounts.fromMap(_map(m['available_by_status'])),
        eligible: _int(m['eligible']),
        passages: PoolPassageCounts.fromMap(_map(m['passages'])),
        disjointVariants: _int(m['disjoint_variants'] ?? m['disjoint']),
      );

  /// Questions missing for one variant by count alone (the topic matrix may
  /// still block a part whose count is enough — see [disjointVariants]).
  int get missing => needed > eligible ? needed - eligible : 0;

  /// Whether at least one variant can be assembled for this part.
  bool get covered => disjointVariants > 0;
}

class PoolSectionHealth {
  final String sectionId;
  final List<PoolPartHealth> parts;

  const PoolSectionHealth({required this.sectionId, required this.parts});

  factory PoolSectionHealth.fromMap(Map<String, dynamic> m) => PoolSectionHealth(
        sectionId: _str(m['section_id']),
        parts: [for (final p in _maps(m['parts'])) PoolPartHealth.fromMap(p)],
      );

  int get needed => parts.fold(0, (a, p) => a + p.needed);
  int get eligible => parts.fold(0, (a, p) => a + p.eligible);
}

enum PoolShortfallKind { cell, passages }

/// One missing topic × difficulty cell or passage group for the *next*
/// disjoint variant (`disjoint_variants + 1`).
class PoolShortfall {
  final PoolShortfallKind kind;
  final String sectionId;
  final String partId;

  /// [PoolShortfallKind.cell] only.
  final String? topicId;
  final int? difficulty;

  /// [PoolShortfallKind.passages] only: `standalone` | `paired`.
  final String? layout;
  final int needed;
  final int available;

  const PoolShortfall({
    required this.kind,
    required this.sectionId,
    required this.partId,
    this.topicId,
    this.difficulty,
    this.layout,
    required this.needed,
    required this.available,
  });

  static PoolShortfall? tryParse(Map<String, dynamic> m) {
    final kind = switch (m['kind']) {
      'cell' => PoolShortfallKind.cell,
      'passages' => PoolShortfallKind.passages,
      _ => null,
    };
    if (kind == null) return null;
    return PoolShortfall(
      kind: kind,
      sectionId: _str(m['section_id']),
      partId: _str(m['part_id']),
      topicId: kind == PoolShortfallKind.cell ? _str(m['topic_id']) : null,
      difficulty: kind == PoolShortfallKind.cell ? _int(m['difficulty']) : null,
      layout: kind == PoolShortfallKind.passages ? _str(m['layout']) : null,
      needed: _int(m['needed']),
      available: _int(m['available']),
    );
  }

  int get missing => needed > available ? needed - available : 0;
}

/// Cell shortfalls of one topic in one part, summed over difficulties — what
/// the content team has to write next.
class TopicShortfall {
  final String sectionId;
  final String partId;
  final String topicId;
  final List<PoolShortfall> cells;

  const TopicShortfall({
    required this.sectionId,
    required this.partId,
    required this.topicId,
    required this.cells,
  });

  int get missing => cells.fold(0, (a, c) => a + c.missing);
}

class PoolHealth {
  final String blueprintId;
  final String language;
  final bool? freshEnabled;
  final MinReviewStatus? minReviewStatus;
  final List<PoolSectionHealth> sections;

  /// Fully disjoint variants the eligible pool supports now.
  final int disjointVariants;

  /// The server stopped counting (the real number is at least
  /// [disjointVariants]).
  final bool capped;
  final List<PoolShortfall> shortfalls;

  const PoolHealth({
    required this.blueprintId,
    required this.language,
    this.freshEnabled,
    this.minReviewStatus,
    required this.sections,
    required this.disjointVariants,
    required this.capped,
    required this.shortfalls,
  });

  factory PoolHealth.fromMap(Map<String, dynamic> m) {
    final status = m['minReviewStatus'] ?? m['min_review_status'];
    final fresh = m['freshEnabled'] ?? m['fresh_enabled'];
    return PoolHealth(
      blueprintId: _str(m['blueprintId'] ?? m['blueprint_id']),
      language: _str(m['language']),
      freshEnabled: fresh is bool ? fresh : null,
      minReviewStatus: status is String ? MinReviewStatus.fromWire(status) : null,
      sections: [for (final s in _maps(m['sections'])) PoolSectionHealth.fromMap(s)],
      disjointVariants: _int(m['disjoint_variants']),
      capped: m['disjoint_variants_capped'] == true,
      shortfalls: [
        for (final s in _maps(m['shortfalls'])) ?PoolShortfall.tryParse(s),
      ],
    );
  }

  int get needed => sections.fold(0, (a, s) => a + s.needed);
  int get eligible => sections.fold(0, (a, s) => a + s.eligible);

  /// Parts that cannot supply even one variant.
  List<({String sectionId, PoolPartHealth part})> get uncoveredParts => [
        for (final s in sections)
          for (final p in s.parts)
            if (!p.covered) (sectionId: s.sectionId, part: p),
      ];

  /// Cell shortfalls grouped by section / part / topic, largest gap first.
  List<TopicShortfall> get topicShortfalls {
    final groups = <String, List<PoolShortfall>>{};
    for (final s in shortfalls) {
      if (s.kind != PoolShortfallKind.cell || s.missing == 0) continue;
      groups.putIfAbsent('${s.sectionId}\u0000${s.partId}\u0000${s.topicId}', () => []).add(s);
    }
    final out = [
      for (final g in groups.values)
        TopicShortfall(
          sectionId: g.first.sectionId,
          partId: g.first.partId,
          topicId: g.first.topicId ?? '',
          cells: [...g]..sort((a, b) => (a.difficulty ?? 0).compareTo(b.difficulty ?? 0)),
        ),
    ];
    out.sort((a, b) {
      final c = b.missing.compareTo(a.missing);
      if (c != 0) return c;
      final k = '${a.sectionId}/${a.partId}/${a.topicId}';
      return k.compareTo('${b.sectionId}/${b.partId}/${b.topicId}');
    });
    return out;
  }

  /// Passage shortfalls (standalone / paired texts), in server order.
  List<PoolShortfall> get passageShortfalls =>
      [for (final s in shortfalls) if (s.kind == PoolShortfallKind.passages && s.missing > 0) s];
}
