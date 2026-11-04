/// Read-only view of an exam blueprint (ARCHITECTURE.md §1.1) — just the parts
/// the admin CMS needs to build and validate variants. Parses both the
/// Firestore `exam_blueprints/{id}` document and the bundled
/// `assets/data/exam_blueprints.json` (`{"blueprints": [...]}` or a bare list).
library;

Map<String, String> _textMap(Object? raw) {
  if (raw is Map) {
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (k is String && v is String) out[k == 'kg' ? 'ky' : k] = v;
    });
    return out;
  }
  if (raw is String) return {'ru': raw};
  return const {};
}

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String pickLocalized(Map<String, String> m, String locale) =>
    m[locale] ?? m['ru'] ?? m['en'] ?? (m.isEmpty ? '' : m.values.first);

class PartSpec {
  final String id;
  final Map<String, String> title;
  final int questionCount;
  final int? optionsPerQuestion;
  final String itemType;
  final bool verified;

  /// Option ids that are fixed by the blueprint (quantitative comparison).
  final List<String> fixedOptionIds;

  /// Fixed option texts per option id, per locale.
  final Map<String, Map<String, String>> fixedOptionTexts;

  const PartSpec({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.optionsPerQuestion,
    required this.itemType,
    required this.verified,
    this.fixedOptionIds = const [],
    this.fixedOptionTexts = const {},
  });

  bool get hasFixedOptions => fixedOptionIds.isNotEmpty;
  bool get needsPassage => itemType == 'text_based';

  factory PartSpec.fromJson(Map<String, dynamic> j) {
    final fixed = <String>[];
    final fixedTexts = <String, Map<String, String>>{};
    final rawFixed = j['fixed_options'];
    if (rawFixed is List) {
      for (final o in rawFixed) {
        if (o is Map && o['id'] is String) {
          final id = o['id'] as String;
          fixed.add(id);
          fixedTexts[id] = _textMap(o['text']);
        }
      }
    }
    return PartSpec(
      id: (j['id'] ?? '').toString(),
      title: _textMap(j['title']),
      questionCount: _int(j['question_count']),
      optionsPerQuestion:
          j['options_per_question'] == null ? null : _int(j['options_per_question']),
      itemType: (j['item_type'] ?? 'single_choice').toString(),
      verified: j['verified'] == true,
      fixedOptionIds: fixed,
      fixedOptionTexts: fixedTexts,
    );
  }
}

class SectionSpec {
  final String id;
  final int order;
  final Map<String, String> title;
  final int questionCount;
  final int durationMinutes;
  final String? subjectArea;
  final bool usesPassages;
  final List<PartSpec> parts;

  const SectionSpec({
    required this.id,
    required this.order,
    required this.title,
    required this.questionCount,
    required this.durationMinutes,
    required this.subjectArea,
    required this.usesPassages,
    required this.parts,
  });

  PartSpec? part(String? id) {
    if (id == null) return null;
    for (final p in parts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// `part_id` the CMS stores on a question of this section (CP-06).
  ///
  /// A single-part section always gets that part's id — the content
  /// pipeline writes the same value, so CMS and pipeline items agree and the
  /// server's part check sees one explicit part for the whole section. In a
  /// multi-part section it is [chosen] when that is one of this section's
  /// parts, otherwise null (not chosen yet, or left over from another
  /// section).
  String? storedPartId(String? chosen) {
    if (parts.length == 1) return parts.first.id;
    return part(chosen)?.id;
  }

  factory SectionSpec.fromJson(Map<String, dynamic> j) {
    final parts = <PartSpec>[];
    final rawParts = j['parts'];
    if (rawParts is List) {
      for (final p in rawParts) {
        if (p is Map) parts.add(PartSpec.fromJson(Map<String, dynamic>.from(p)));
      }
    }
    return SectionSpec(
      id: (j['id'] ?? '').toString(),
      order: _int(j['order']),
      title: _textMap(j['title']),
      questionCount: _int(j['question_count']),
      durationMinutes: _int(j['duration_minutes']),
      subjectArea: j['subject_area'] as String?,
      usesPassages: j['uses_passages'] == true,
      parts: parts,
    );
  }
}

class BlueprintSpec {
  final String id;
  final String kind;
  final String? subjectId;
  final int version;
  final String status;
  final Map<String, String> title;
  final List<String> languages;
  final int optionsPerQuestion;
  final List<SectionSpec> sections;

  const BlueprintSpec({
    required this.id,
    required this.kind,
    required this.subjectId,
    required this.version,
    required this.status,
    required this.title,
    required this.languages,
    required this.optionsPerQuestion,
    required this.sections,
  });

  SectionSpec? section(String? id) {
    if (id == null) return null;
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  int get totalQuestions => sections.fold(0, (a, s) => a + s.questionCount);

  /// `subject_id` stored on exam questions of [section]: the blueprint's
  /// subject for subject tests, otherwise the section's subject area.
  String subjectIdFor(SectionSpec section) =>
      subjectId ?? section.subjectArea ?? section.id;

  /// Options expected for questions of [part] in this blueprint.
  int optionsFor(PartSpec? part) => part?.optionsPerQuestion ?? optionsPerQuestion;

  factory BlueprintSpec.fromJson(Map<String, dynamic> j, {String? id}) {
    final sections = <SectionSpec>[];
    final raw = j['sections'];
    if (raw is List) {
      for (final s in raw) {
        if (s is Map) sections.add(SectionSpec.fromJson(Map<String, dynamic>.from(s)));
      }
    }
    sections.sort((a, b) => a.order.compareTo(b.order));
    final langs = <String>[];
    final rawLangs = j['languages'];
    if (rawLangs is List) {
      for (final l in rawLangs) {
        if (l is String) langs.add(l == 'kg' ? 'ky' : l);
      }
    }
    return BlueprintSpec(
      id: id ?? (j['id'] ?? '').toString(),
      kind: (j['kind'] ?? 'main').toString(),
      subjectId: j['subject_id'] as String?,
      version: _int(j['version'], 1),
      status: (j['status'] ?? 'active').toString(),
      title: _textMap(j['title']),
      languages: langs.isEmpty ? const ['ru', 'ky'] : langs,
      optionsPerQuestion: _int(j['options_per_question'], 4),
      sections: sections,
    );
  }

  /// Parses the bundled asset (`{"blueprints": [...]}`) or a bare list.
  static List<BlueprintSpec> listFromJson(Object? decoded) {
    final list = decoded is Map ? decoded['blueprints'] : decoded;
    if (list is! List) return const [];
    return [
      for (final b in list)
        if (b is Map) BlueprintSpec.fromJson(Map<String, dynamic>.from(b)),
    ];
  }
}

/// Finds the blueprint section an exam question belongs to (exact subject +
/// section match first, then section id only).
({BlueprintSpec blueprint, SectionSpec section})? locateSection(
  List<BlueprintSpec> blueprints,
  String subjectId,
  String sectionId,
) {
  ({BlueprintSpec blueprint, SectionSpec section})? loose;
  for (final b in blueprints) {
    for (final s in b.sections) {
      if (s.id != sectionId) continue;
      if (b.subjectIdFor(s) == subjectId) return (blueprint: b, section: s);
      loose ??= (blueprint: b, section: s);
    }
  }
  return loose;
}

/// Fixed option texts of [part] in [language] (quantitative comparison).
List<({String id, String text})> fixedOptionsFor(PartSpec part, String language) => [
      for (final id in part.fixedOptionIds)
        (
          id: id,
          text: pickLocalized(part.fixedOptionTexts[id] ?? const {}, language),
        ),
    ];
