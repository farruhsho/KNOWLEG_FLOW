import 'package:flutter/foundation.dart';

import 'json_utils.dart';
import 'localized_text.dart';

/// Kind of exam a blueprint describes (ARCHITECTURE §1.1).
enum BlueprintKind {
  main,
  subject,
  stateLanguage,
  unknown;

  static BlueprintKind parse(Object? v) => switch (asString(v)) {
        'main' => BlueprintKind.main,
        'subject' => BlueprintKind.subject,
        'state_language' => BlueprintKind.stateLanguage,
        _ => BlueprintKind.unknown,
      };

  String get wire => switch (this) {
        BlueprintKind.main => 'main',
        BlueprintKind.subject => 'subject',
        BlueprintKind.stateLanguage => 'state_language',
        BlueprintKind.unknown => 'unknown',
      };
}

/// How a part's questions are laid out.
enum ExamItemType {
  singleChoice,
  quantitativeComparison,
  analogy,
  completion,
  textBased,
  unknown;

  static ExamItemType parse(Object? v) => switch (asString(v)) {
        'single_choice' || 'singleChoice' => ExamItemType.singleChoice,
        'quantitative_comparison' ||
        'quantitativeComparison' =>
          ExamItemType.quantitativeComparison,
        'analogy' => ExamItemType.analogy,
        'completion' => ExamItemType.completion,
        'text_based' || 'textBased' => ExamItemType.textBased,
        _ => ExamItemType.unknown,
      };
}

@immutable
class FixedOption {
  final String id;
  final LocalizedText text;

  const FixedOption({required this.id, required this.text});

  factory FixedOption.fromJson(Object? json) {
    final m = asJsonMap(json);
    return FixedOption(
      id: asString(m['id']) ?? '',
      text: LocalizedText.fromJson(m['text']),
    );
  }
}

/// Sub-block of a section without its own timer (e.g. math part I / II).
@immutable
class ExamPart {
  final String id;
  final LocalizedText title;
  final int questionCount;
  final int optionsPerQuestion;
  final ExamItemType itemType;

  /// `false` means the official brochure does not publish this split; it is a
  /// working assumption.
  final bool verified;
  final List<FixedOption> fixedOptions;

  const ExamPart({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.optionsPerQuestion,
    required this.itemType,
    required this.verified,
    this.fixedOptions = const [],
  });

  factory ExamPart.fromJson(Object? json, {required int defaultOptions}) {
    final m = asJsonMap(json);
    return ExamPart(
      id: asString(m['id']) ?? '',
      title: LocalizedText.fromJson(m['title']),
      questionCount: asInt(m['question_count']) ?? 0,
      optionsPerQuestion: asInt(m['options_per_question']) ?? defaultOptions,
      itemType: ExamItemType.parse(m['item_type']),
      verified: asBool(m['verified'], fallback: true),
      fixedOptions: asJsonList(m['fixed_options'])
          .map(FixedOption.fromJson)
          .where((o) => o.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

@immutable
class ExamSection {
  final String id;
  final int order;
  final LocalizedText title;
  final int questionCount;
  final int durationMinutes;
  final int pointsPerQuestion;
  final String? subjectArea;
  final bool allowScratchpad;
  final bool usesPassages;
  final int lineNumberingEvery;
  final List<ExamPart> parts;

  const ExamSection({
    required this.id,
    required this.order,
    required this.title,
    required this.questionCount,
    required this.durationMinutes,
    this.pointsPerQuestion = 1,
    this.subjectArea,
    this.allowScratchpad = false,
    this.usesPassages = false,
    this.lineNumberingEvery = 5,
    this.parts = const [],
  });

  Duration get duration => Duration(minutes: durationMinutes);

  factory ExamSection.fromJson(
    Object? json, {
    required int defaultOptions,
    required List<String> scratchpadSections,
  }) {
    final m = asJsonMap(json);
    final id = asString(m['id']) ?? asString(m['section_id']) ?? '';
    final layout = asJsonMap(m['passage_layout']);
    final parts = asJsonList(m['parts'])
        .map((p) => ExamPart.fromJson(p, defaultOptions: defaultOptions))
        .toList(growable: false);
    final count = asInt(m['question_count']) ??
        parts.fold<int>(0, (sum, p) => sum + p.questionCount);
    return ExamSection(
      id: id,
      order: asInt(m['order']) ?? 0,
      title: LocalizedText.fromJson(m['title']),
      questionCount: count,
      durationMinutes: asInt(m['duration_minutes']) ?? 0,
      pointsPerQuestion: asInt(m['points_per_question']) ?? 1,
      subjectArea: asString(m['subject_area']),
      allowScratchpad: m.containsKey('allow_scratchpad')
          ? asBool(m['allow_scratchpad'])
          : scratchpadSections.contains(id),
      usesPassages: asBool(m['uses_passages']),
      lineNumberingEvery: asInt(layout['line_numbering_every']) ?? 5,
      parts: parts.isEmpty
          ? [
              ExamPart(
                id: id,
                title: LocalizedText.fromJson(m['title']),
                questionCount: count,
                optionsPerQuestion: defaultOptions,
                itemType: ExamItemType.singleChoice,
                verified: true,
              ),
            ]
          : parts,
    );
  }

  /// Part a question belongs to by its position in the section (parts are
  /// laid out sequentially). Clamped to the last part.
  ExamPart partForIndex(int questionIndex) {
    var start = 0;
    for (final p in parts) {
      if (questionIndex < start + p.questionCount) return p;
      start += p.questionCount;
    }
    return parts.last;
  }

  ExamPart? partById(String? partId) {
    if (partId == null) return null;
    for (final p in parts) {
      if (p.id == partId) return p;
    }
    return null;
  }
}

@immutable
class ScoringLevel {
  final int level;
  final LocalizedText title;

  const ScoringLevel({required this.level, required this.title});
}

@immutable
class ExamScoring {
  /// `raw` (number correct) or `level` (state-language test, levels 1–4).
  final String method;
  final bool officialScaleKnown;
  final bool levelCutoffsKnown;
  final List<ScoringLevel> levels;
  final LocalizedText disclaimer;

  const ExamScoring({
    required this.method,
    required this.officialScaleKnown,
    required this.levelCutoffsKnown,
    required this.levels,
    required this.disclaimer,
  });

  static const fallback = ExamScoring(
    method: 'raw',
    officialScaleKnown: false,
    levelCutoffsKnown: false,
    levels: [],
    disclaimer: LocalizedText.empty,
  );

  bool get isLevelBased => method == 'level';

  factory ExamScoring.fromJson(Object? json) {
    final m = asJsonMap(json);
    if (m.isEmpty) return fallback;
    return ExamScoring(
      method: asString(m['method']) ?? 'raw',
      officialScaleKnown: asBool(m['official_scale_known']),
      levelCutoffsKnown: asBool(m['level_cutoffs_known']),
      levels: asJsonList(m['levels']).map((l) {
        final lm = asJsonMap(l);
        return ScoringLevel(
          level: asInt(lm['level']) ?? 0,
          title: LocalizedText.fromJson(lm['title']),
        );
      }).toList(growable: false),
      disclaimer: LocalizedText.fromJson(m['disclaimer']),
    );
  }
}

@immutable
class ExamRules {
  final bool calculatorsAllowed;
  final List<String> scratchpadSections;

  const ExamRules({
    this.calculatorsAllowed = false,
    this.scratchpadSections = const [],
  });

  factory ExamRules.fromJson(Object? json) {
    final m = asJsonMap(json);
    return ExamRules(
      calculatorsAllowed: asBool(m['calculators']),
      scratchpadSections: asStringList(m['scratchpad_sections']),
    );
  }
}

/// Versioned ORT exam structure (`exam_blueprints/{id}`, or the bundled
/// `assets/data/exam_blueprints.json`). Exam mode never reads structure from
/// Dart constants — only from here.
@immutable
class ExamBlueprint {
  final String id;
  final BlueprintKind kind;
  final String? subjectId;
  final int examYear;
  final int version;
  final String status;
  final LocalizedText title;
  final List<String> languages;
  final int optionsPerQuestion;
  final bool freeNavigationWithinSection;
  final bool forwardOnlyAcrossSections;
  final List<ExamSection> sections;
  final ExamScoring scoring;
  final ExamRules rules;

  /// Source map, kept so a session can be persisted and restored offline.
  final Map<String, dynamic> raw;

  const ExamBlueprint({
    required this.id,
    required this.kind,
    required this.subjectId,
    required this.examYear,
    required this.version,
    required this.status,
    required this.title,
    required this.languages,
    required this.optionsPerQuestion,
    required this.freeNavigationWithinSection,
    required this.forwardOnlyAcrossSections,
    required this.sections,
    required this.scoring,
    required this.rules,
    this.raw = const {},
  });

  factory ExamBlueprint.fromJson(Object? json, {String? id}) {
    final m = asJsonMap(json);
    final defaultOptions = asInt(m['options_per_question']) ?? 4;
    final rules = ExamRules.fromJson(m['rules']);
    final nav = asJsonMap(m['navigation']);
    final sections = asJsonList(m['sections'])
        .map((s) => ExamSection.fromJson(
              s,
              defaultOptions: defaultOptions,
              scratchpadSections: rules.scratchpadSections,
            ))
        .where((s) => s.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final languages = asStringList(m['languages']);
    return ExamBlueprint(
      id: id ?? asString(m['id']) ?? '',
      kind: BlueprintKind.parse(m['kind']),
      subjectId: asString(m['subject_id']),
      examYear: asInt(m['exam_year']) ?? 0,
      version: asInt(m['version']) ?? 1,
      status: asString(m['status']) ?? 'active',
      title: LocalizedText.fromJson(m['title']),
      languages: languages.isEmpty ? const ['ru'] : languages,
      optionsPerQuestion: defaultOptions,
      freeNavigationWithinSection:
          (asString(nav['within_section']) ?? 'free') == 'free',
      forwardOnlyAcrossSections:
          (asString(nav['across_sections']) ?? 'forward_only') ==
              'forward_only',
      sections: List.unmodifiable(sections),
      scoring: ExamScoring.fromJson(m['scoring']),
      rules: rules,
      raw: Map.unmodifiable({...m, if (id != null) 'id': id}),
    );
  }

  /// Parses the bundled asset (`{schema_version, blueprints: [...]}`) or a
  /// bare list of blueprints. Entries without an id or sections are skipped.
  static List<ExamBlueprint> listFromJson(Object? json) {
    final list = json is List ? json : asJsonList(asJsonMap(json)['blueprints']);
    return list
        .map((b) => ExamBlueprint.fromJson(b))
        .where((b) => b.id.isNotEmpty && b.sections.isNotEmpty)
        .toList(growable: false);
  }

  bool get isActive => status == 'active';

  int get totalQuestions =>
      sections.fold(0, (sum, s) => sum + s.questionCount);

  int get totalMinutes =>
      sections.fold(0, (sum, s) => sum + s.durationMinutes);

  ExamSection? sectionById(String id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  int indexOfSection(String id) => sections.indexWhere((s) => s.id == id);

  /// Language used for exam content when the user has not chosen one:
  /// [preferred] if this blueprint offers it, else its first language.
  String languageFor(String preferred) =>
      languages.contains(preferred) ? preferred : languages.first;
}
